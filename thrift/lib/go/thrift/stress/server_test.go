/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package stress

import (
	"context"
	"fmt"
	"net"
	"os"
	"runtime"
	"strconv"
	"sync/atomic"
	"testing"
	"time"

	"golang.org/x/sync/errgroup"

	"github.com/facebook/fbthrift/thrift/lib/go/thrift"
	"github.com/facebook/fbthrift/thrift/lib/go/thrift/dummy"
	dummyif "github.com/facebook/fbthrift/thrift/test/go/if/dummy"

	"github.com/stretchr/testify/require"
)

func TestServerStress(t *testing.T) {
	t.Run("UpgradeToRocket", func(t *testing.T) {
		runStressTest(t, thrift.TransportIDUpgradeToRocket)
	})
	t.Run("Rocket", func(t *testing.T) {
		runStressTest(t, thrift.TransportIDRocket)
	})
}

func runStressTest(t *testing.T, serverTransport thrift.TransportID) {
	socketPath := fmt.Sprintf(
		"%s/fbthrift_go_stress_%d_%d.sock",
		os.TempDir(),
		os.Getpid(),
		time.Now().UnixNano(),
	)
	t.Cleanup(func() { _ = os.Remove(socketPath) })
	listener, err := net.Listen("unix", socketPath)
	require.NoError(t, err)
	addr := listener.Addr()
	t.Logf("Server listening on %v", addr)

	var clientTransportOption thrift.ClientOption
	switch serverTransport {
	case thrift.TransportIDUpgradeToRocket:
		clientTransportOption = thrift.WithUpgradeToRocket()
	case thrift.TransportIDRocket:
		clientTransportOption = thrift.WithRocket()
	default:
		panic("unsupported transport!")
	}

	// A special server option to allocate 10KB for each incoming connection,
	// for the purposes of stress testing and exposing memory leaks.
	connContextOption := thrift.WithConnContext(
		func(ctx context.Context, conn net.Conn) context.Context {
			type dummContextKey int
			const dummyKey dummContextKey = 12345
			const dummyAllocSize = 10 * 1024 // 10KB
			return context.WithValue(ctx, dummyKey, make([]byte, dummyAllocSize, dummyAllocSize))
		},
	)

	processor := dummyif.NewDummyProcessor(&dummy.DummyHandler{})
	server := thrift.NewServer(processor, listener, serverTransport, connContextOption, thrift.WithNumWorkers(10))

	serverCtx, serverCancel := context.WithCancel(context.Background())
	var serverEG errgroup.Group
	serverEG.Go(func() error {
		return server.ServeContext(serverCtx)
	})
	serverStopped := false
	t.Cleanup(func() {
		if !serverStopped {
			serverCancel()
			_ = serverEG.Wait()
		}
	})

	var successRequestCount atomic.Uint64

	makeRequestFunc := func() error {
		channel, err := thrift.NewClient(
			clientTransportOption,
			thrift.WithDialer(func() (net.Conn, error) {
				return net.DialTimeout("unix", addr.String(), 60*time.Second)
			}),
			thrift.WithIoTimeout(60*time.Second),
		)
		if err != nil {
			errRes := fmt.Errorf("failed to create client: %w", err)
			t.Log(errRes.Error())
			return errRes
		}
		client := dummyif.NewDummyChannelClient(channel)
		defer client.Close()
		result, err := client.Echo(context.Background(), "hello")
		if err != nil {
			errRes := fmt.Errorf("failed to make RPC: %w", err)
			t.Log(errRes.Error())
			return errRes
		}
		if result != "hello" {
			return fmt.Errorf("unexpected RPC result: %s", result)
		}
		successRequestCount.Add(1)
		return nil
	}

	runtime.GC()
	fdCountBefore, err := getNumFileDesciptors()
	require.NoError(t, err)

	requestCount := 100_000
	if configured := os.Getenv("FBTHRIFT_GO_STRESS_REQUESTS"); configured != "" {
		parsed, err := strconv.Atoi(configured)
		require.NoError(t, err)
		require.Positive(t, parsed)
		requestCount = parsed
	}
	const parallelism = 100

	var clientsEG errgroup.Group
	clientsEG.SetLimit(parallelism) // Max 100 Go-routines running at once
	startTime := time.Now()
	for range requestCount {
		clientsEG.Go(makeRequestFunc)
	}
	err = clientsEG.Wait()
	timeElapsed := time.Since(startTime)
	timePerRequest := timeElapsed / time.Duration(requestCount)
	t.Logf("successful requests: %d/%d", successRequestCount.Load(), requestCount)
	require.NoError(t, err)

	// Closing a Rocket client starts asynchronous connection teardown. Wait for
	// it to quiesce before evaluating leak thresholds; sampling immediately here
	// measures expected teardown work rather than retained resources.
	var fdCountAfter int
	require.Eventually(t, func() bool {
		count, err := getNumFileDesciptors()
		if err != nil {
			return false
		}
		fdCountAfter = count
		return runtime.NumGoroutine() < 100 && fdCountAfter <= fdCountBefore
	}, 10*time.Second, 10*time.Millisecond)

	var memStatsAfter runtime.MemStats
	runtime.GC()
	runtime.ReadMemStats(&memStatsAfter)

	// Go routine check (while server is still running)
	// We shouldn't exceed 100 Go-routines, if we do - server is likely leaking.
	require.Less(t, runtime.NumGoroutine(), 100)

	// Mem alloc check (while server is still running)
	require.Less(t, memStatsAfter.HeapAlloc, uint64(50*1024*1024) /* 50MB */)

	// FD count check (against FD leaks)
	require.LessOrEqual(t, fdCountAfter, fdCountBefore)

	// Latency per-request
	require.Less(t, timePerRequest, 500*time.Microsecond)

	// Shut down server.
	serverCancel()
	err = serverEG.Wait()
	serverStopped = true
	require.ErrorIs(t, err, context.Canceled)

	// Go routine check (after server shutdown)
	// We shouldn't exceed 10 Go-routines, if we do - something didn't get cleaned up properly.
	require.Eventually(t, func() bool {
		return runtime.NumGoroutine() <= 10
	}, 10*time.Second, 10*time.Millisecond)
}

func getNumFileDesciptors() (int, error) {
	fdPath := fmt.Sprintf("/proc/%d/fd", os.Getpid())
	if runtime.GOOS == "darwin" {
		fdPath = "/dev/fd"
	}

	fdDir, err := os.Open(fdPath)
	if err != nil {
		return -1, err
	}
	defer fdDir.Close()

	files, err := fdDir.Readdirnames(-1)
	if err != nil {
		return -1, err
	}
	return len(files), nil
}
