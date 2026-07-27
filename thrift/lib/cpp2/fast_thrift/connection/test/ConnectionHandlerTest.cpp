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

#include <gtest/gtest.h>

#include <atomic>
#include <chrono>
#include <memory>
#include <vector>

#include <folly/SocketAddress.h>
#include <folly/init/Init.h>
#include <folly/io/async/AsyncSocket.h>
#include <folly/io/async/EventBase.h>
#include <folly/io/async/ScopedEventBaseThread.h>
#include <folly/observer/SimpleObservable.h>
#include <folly/synchronization/Baton.h>

#include <thrift/lib/cpp2/fast_thrift/connection/ConnectionHandler.h>

namespace apache::thrift::fast_thrift::connection {
namespace {

// Test connection — keeps the transport alive, counts close calls via a
// shared atomic so tests can verify teardown, and treats drain() as an
// immediate close (firing the close callback so the handler can erase
// the entry).
//
// `closeOnStart` exists to exercise the synchronous-close-during-start
// invariant: when set, start() immediately invokes close(), which fires
// the close callback under the same installer-lambda frame that just
// registered this connection.
struct TestConnection {
  folly::AsyncTransport::UniquePtr transport;
  std::shared_ptr<std::atomic<size_t>> closeCount;
  std::function<void()> closeCb;
  bool closed{false};
  bool closeOnStart{false};
  bool repeatCloseCallbackOnDestroy{false};

  TestConnection() = default;
  TestConnection(TestConnection&& other) noexcept
      : transport(std::move(other.transport)),
        closeCount(std::move(other.closeCount)),
        closeCb(std::move(other.closeCb)),
        closed(other.closed),
        closeOnStart(other.closeOnStart),
        repeatCloseCallbackOnDestroy(other.repeatCloseCallbackOnDestroy) {
    other.repeatCloseCallbackOnDestroy = false;
  }
  TestConnection& operator=(TestConnection&& other) noexcept {
    if (this == &other) {
      return *this;
    }
    transport = std::move(other.transport);
    closeCount = std::move(other.closeCount);
    closeCb = std::move(other.closeCb);
    closed = other.closed;
    closeOnStart = other.closeOnStart;
    repeatCloseCallbackOnDestroy = other.repeatCloseCallbackOnDestroy;
    other.repeatCloseCallbackOnDestroy = false;
    return *this;
  }
  TestConnection(const TestConnection&) = delete;
  TestConnection& operator=(const TestConnection&) = delete;

  ~TestConnection() {
    if (repeatCloseCallbackOnDestroy && closeCb) {
      auto cb = std::move(closeCb);
      cb();
    }
  }

  void setCloseCallback(std::function<void()> cb) { closeCb = std::move(cb); }

  void start() noexcept {
    if (closeOnStart) {
      close();
    }
  }

  void drain() noexcept { close(); }

  void close() noexcept {
    if (closed) {
      return;
    }
    closed = true;
    if (transport) {
      transport->closeNow();
    }
    if (closeCount) {
      closeCount->fetch_add(1, std::memory_order_relaxed);
    }
    if (closeCb) {
      // Keep a copy installed for the destructor when requested. This models
      // independent terminal notifications from the pipeline and adapter
      // fallback paths, both of which identify the same connection.
      auto cb = repeatCloseCallbackOnDestroy ? closeCb : std::move(closeCb);
      cb();
    }
  }
};

// Factory satisfying connection::ConnectionFactory.
class TestConnectionFactory {
 public:
  explicit TestConnectionFactory(
      std::shared_ptr<std::atomic<size_t>> closeCount = nullptr,
      bool closeOnStart = false,
      bool repeatCloseCallbackOnDestroy = false) noexcept
      : closeCount_(std::move(closeCount)),
        closeOnStart_(closeOnStart),
        repeatCloseCallbackOnDestroy_(repeatCloseCallbackOnDestroy) {}

  TestConnection getConnection(folly::AsyncTransport::UniquePtr socket) {
    TestConnection connection;
    connection.transport = std::move(socket);
    connection.closeCount = closeCount_;
    connection.closeOnStart = closeOnStart_;
    connection.repeatCloseCallbackOnDestroy =
        repeatCloseCallbackOnDestroy_;
    return connection;
  }

 private:
  std::shared_ptr<std::atomic<size_t>> closeCount_;
  bool closeOnStart_;
  bool repeatCloseCallbackOnDestroy_;
};

} // namespace

class ConnectionHandlerTest : public ::testing::Test {
 protected:
  void SetUp() override {
    evbThread_ = std::make_unique<folly::ScopedEventBaseThread>();
    evb_ = evbThread_->getEventBase();
  }

  void TearDown() override {
    clientConnections_.clear();
    evbThread_.reset();
  }

  std::unique_ptr<ConnectionHandler> createConnectionHandler() {
    // DISABLED never reads tlsParams, but the ctor needs a valid Observer.
    return std::make_unique<ConnectionHandler>(
        *evb_,
        folly::SocketAddress("::1", 0),
        fast_security::SSLPolicy::DISABLED,
        // DISABLED never reads tlsParams, but the ctor needs a valid Observer.
        folly::observer::SimpleObservable<
            std::shared_ptr<const fast_security::TLSParams>>(
            std::shared_ptr<const fast_security::TLSParams>{})
            .getObserver(),
        SocketOptions{},
        /*enableReusePortBpfSpread=*/false);
  }

  // Wires the factory + starts the acceptance pipeline. Runs on the
  // owning EVB because setConnectionFactory builds + activates the pipeline.
  // Factory is stored on the test fixture so it outlives the handler.
  void wireFactory(ConnectionHandler& h) {
    factory_ = std::make_unique<TestConnectionFactory>(closeCount_);
    evb_->runInEventBaseThreadAndWait(
        [&] { h.setConnectionFactory(*factory_); });
  }

  // Owns a client socket + its EVB thread. The dtor destroys the socket
  // on its own EVB thread (AsyncSocket asserts this).
  struct ClientConnection {
    std::shared_ptr<folly::AsyncSocket> socket;
    std::unique_ptr<folly::ScopedEventBaseThread> thread;

    ClientConnection() = default;
    ClientConnection(ClientConnection&&) = default;
    ClientConnection& operator=(ClientConnection&&) = default;

    ~ClientConnection() {
      if (thread && socket) {
        thread->getEventBase()->runInEventBaseThreadAndWait(
            [s = std::move(socket)]() mutable { s.reset(); });
      }
    }
  };

  // Connects a client to the server and waits for the server's accept to
  // produce a connection (observed via handler.connectionCount()).
  void connectAndWait(
      ConnectionHandler& handler, const folly::SocketAddress& address) {
    struct ConnectCb : folly::AsyncSocket::ConnectCallback {
      folly::Baton<>& baton;
      explicit ConnectCb(folly::Baton<>& b) : baton(b) {}
      void connectSuccess() noexcept override { baton.post(); }
      void connectErr(const folly::AsyncSocketException&) noexcept override {}
    };

    const size_t before = handler.connectionCount();

    folly::Baton<> connected;
    ConnectCb cb(connected);
    auto clientThread = std::make_unique<folly::ScopedEventBaseThread>();
    auto* clientEvb = clientThread->getEventBase();
    std::shared_ptr<folly::AsyncSocket> clientSocket;
    clientEvb->runInEventBaseThreadAndWait([&] {
      clientSocket = folly::AsyncSocket::newSocket(clientEvb);
      clientSocket->connect(&cb, address, 1000);
    });
    connected.wait();

    // Server-side accept is asynchronous w.r.t. the client's connect-success.
    // Spin-wait on the count (with a generous deadline) until the factory
    // has produced the new connection.
    const auto deadline =
        std::chrono::steady_clock::now() + std::chrono::seconds{5};
    while (handler.connectionCount() == before) {
      ASSERT_LT(std::chrono::steady_clock::now(), deadline)
          << "timed out waiting for server to accept connection";
      // Short poll; server-side accept is asynchronous and has no synchronous
      // hand-off, so we wait on its observable side-effect (connectionCount).
      // NOLINTNEXTLINE(facebook-hte-BadCall-sleep_for)
      std::this_thread::sleep_for(std::chrono::milliseconds{5});
    }

    ClientConnection cc;
    cc.socket = std::move(clientSocket);
    cc.thread = std::move(clientThread);
    clientConnections_.push_back(std::move(cc));
  }

  std::unique_ptr<folly::ScopedEventBaseThread> evbThread_;
  folly::EventBase* evb_{nullptr};
  std::shared_ptr<std::atomic<size_t>> closeCount_ =
      std::make_shared<std::atomic<size_t>>(0);
  std::unique_ptr<TestConnectionFactory> factory_;
  std::vector<ClientConnection> clientConnections_;
};

TEST_F(ConnectionHandlerTest, ConstructDoesNotStart) {
  auto handler = createConnectionHandler();
  EXPECT_NE(handler, nullptr);
  EXPECT_EQ(handler->connectionCount(), 0);
}

TEST_F(ConnectionHandlerTest, GetAddressAfterFactoryBindsPort) {
  auto handler = createConnectionHandler();
  wireFactory(*handler);

  auto bound = handler->getAddress();
  EXPECT_NE(bound.getPort(), 0);
}

TEST_F(ConnectionHandlerTest, AcceptsSingleConnection) {
  auto handler = createConnectionHandler();
  wireFactory(*handler);

  connectAndWait(*handler, handler->getAddress());

  EXPECT_EQ(handler->connectionCount(), 1);
}

TEST_F(ConnectionHandlerTest, AcceptsMultipleConnections) {
  auto handler = createConnectionHandler();
  wireFactory(*handler);

  auto addr = handler->getAddress();
  for (int i = 0; i < 3; ++i) {
    connectAndWait(*handler, addr);
  }

  EXPECT_EQ(handler->connectionCount(), 3);
}

TEST_F(ConnectionHandlerTest, StopDrainsAllConnections) {
  auto handler = createConnectionHandler();
  wireFactory(*handler);

  auto addr = handler->getAddress();
  for (int i = 0; i < 3; ++i) {
    connectAndWait(*handler, addr);
  }
  ASSERT_EQ(handler->connectionCount(), 3);

  // stop() is off-EVB — bounces internally for the synchronous phases.
  handler->stop();

  EXPECT_EQ(handler->connectionCount(), 0);
  EXPECT_EQ(closeCount_->load(), 3);
}

// Regression: a connection can report terminal state through its pipeline
// and repeat that notification from an adapter destructor fallback. The map
// entry must be removed before destroying the mapped connection; otherwise
// the destructor re-enters erase() for the same F14 node and corrupts the
// node pointer while the outer erase still owns it.
TEST_F(ConnectionHandlerTest, RepeatedCloseDuringDestructionIsIdempotent) {
  auto handler = createConnectionHandler();
  factory_ = std::make_unique<TestConnectionFactory>(
      closeCount_,
      /*closeOnStart=*/false,
      /*repeatCloseCallbackOnDestroy=*/true);
  evb_->runInEventBaseThreadAndWait(
      [&] { handler->setConnectionFactory(*factory_); });

  connectAndWait(*handler, handler->getAddress());
  ASSERT_EQ(handler->connectionCount(), 1);

  handler->stop();

  EXPECT_EQ(handler->connectionCount(), 0);
  EXPECT_EQ(closeCount_->load(), 1);
}

TEST_F(ConnectionHandlerTest, StopWithNoConnections) {
  auto handler = createConnectionHandler();
  wireFactory(*handler);
  ASSERT_EQ(handler->connectionCount(), 0);

  handler->stop();

  EXPECT_EQ(handler->connectionCount(), 0);
}

TEST_F(ConnectionHandlerTest, DestroyWithActiveConnections) {
  auto handler = createConnectionHandler();
  wireFactory(*handler);
  auto addr = handler->getAddress();
  connectAndWait(*handler, addr);
  ASSERT_EQ(handler->connectionCount(), 1);

  // Destructor drives stop() — should release live connections cleanly.
  handler.reset();
  EXPECT_EQ(closeCount_->load(), 1);
}

// Regression: the installer lambda must register the connection in
// connections_ BEFORE calling start(). A factory-built connection whose
// start() synchronously closes (modelling a post-StopTLS handoff that
// dispatches and tears down inline) would otherwise fire its close callback
// against a not-yet-registered entry, missing the erase + count decrement.
TEST_F(ConnectionHandlerTest, SynchronousCloseDuringStartIsSafe) {
  auto handler = createConnectionHandler();
  factory_ = std::make_unique<TestConnectionFactory>(
      closeCount_, /*closeOnStart=*/true);
  evb_->runInEventBaseThreadAndWait(
      [&] { handler->setConnectionFactory(*factory_); });

  // Open a client socket — the server-side install will run start(), which
  // synchronously closes, firing the close callback under the install
  // lambda. We wait on closeCount_ rather than connectionCount() because
  // the count briefly hits 1 and returns to 0 in the same EVB iteration;
  // a spin-wait on connectionCount() would race the synchronous close.
  folly::Baton<> connected;
  struct ConnectCb : folly::AsyncSocket::ConnectCallback {
    folly::Baton<>& baton;
    explicit ConnectCb(folly::Baton<>& b) : baton(b) {}
    void connectSuccess() noexcept override { baton.post(); }
    void connectErr(const folly::AsyncSocketException&) noexcept override {}
  };
  ConnectCb cb(connected);
  auto clientThread = std::make_unique<folly::ScopedEventBaseThread>();
  auto* clientEvb = clientThread->getEventBase();
  std::shared_ptr<folly::AsyncSocket> clientSocket;
  clientEvb->runInEventBaseThreadAndWait([&] {
    clientSocket = folly::AsyncSocket::newSocket(clientEvb);
    clientSocket->connect(&cb, handler->getAddress(), 1000);
  });
  connected.wait();

  const auto deadline =
      std::chrono::steady_clock::now() + std::chrono::seconds{5};
  while (closeCount_->load() == 0) {
    ASSERT_LT(std::chrono::steady_clock::now(), deadline)
        << "timed out waiting for server-side install + synchronous close";
    // NOLINTNEXTLINE(facebook-hte-BadCall-sleep_for)
    std::this_thread::sleep_for(std::chrono::milliseconds{5});
  }
  EXPECT_EQ(handler->connectionCount(), 0)
      << "synchronous close during start() must remove the registered entry";
  EXPECT_EQ(closeCount_->load(), 1);

  // Hand off the client socket so its dtor runs on its EVB.
  ClientConnection cc;
  cc.socket = std::move(clientSocket);
  cc.thread = std::move(clientThread);
  clientConnections_.push_back(std::move(cc));
}

} // namespace apache::thrift::fast_thrift::connection

int main(int argc, char** argv) {
  ::testing::InitGoogleTest(&argc, argv);
  folly::Init init(&argc, &argv);
  return RUN_ALL_TESTS();
}
