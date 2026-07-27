---
sidebar_position: 6
title: Go code generation and runtime
---

# Go code generation and runtime

fbthrift's Go backend generates data types, codecs, clients, processors,
streams, sinks, interactions, and bidirectional Rocket RPC. The public
generator name is `go`; `mstch_go` is the legacy registered name for the same
backend.

This tree targets **Go 1.26**. Generated metadata intentionally uses Go 1.26's
`new(expression)` form. Streaming APIs also use range-over-function iterators.
Do not rewrite generated `new(expression)` calls to pointer helper functions.

## Generate code

Declare a Go namespace in every IDL:

```thrift
package "example.com/chat"
namespace go example.chat

struct Message {
  1: string text;
}
```

Run the compiler with the repository root on the include path:

```bash
thrift1 -I /path/to/fbthrift \
  --gen go \
  -o _generated \
  chat.thrift
```

The files are written to `_generated/gen-go`. The generator does not create a
directory matching the import path; the build rule must place that output in
the directory represented by `namespace go`. `metadata.go` is emitted by
default, matching Meta's `omit_metadata = false` behavior. Pass
`gen_metadata=false` only when deliberately opting out.

### Generator options

| Option | Default | Effect |
| --- | --- | --- |
| `package_prefix=IMPORT_PATH` | empty | Prefixes namespace imports whose first path component is not already module-qualified. It does not rewrite domain-qualified imports and does not move output files. |
| `gen_metadata=true\|false` | `true` | Emits `metadata.go` and the generated schema/service metadata APIs. |
| `use_reflect_codec=true\|false` | `false` | Uses the reflection codec for generated structs instead of emitting the normal direct field codec path. This reduces repeated generated codec logic at the cost of reflection overhead. |

Use the help from the compiler being invoked as the authoritative option list:

```bash
thrift1 --help
```

For an external module, `package_prefix` maps unqualified IDL namespaces into
that module without changing fbthrift's already-qualified runtime imports:

```bash
thrift1 -I . \
  --gen 'go:package_prefix=example.com/acme/chat' \
  service.thrift
```

For example, `namespace go shared.types` is imported as
`example.com/acme/chat/shared/types`. A namespace such as
`github.com/vendor/project/types` remains unchanged.

## Internal and public import domains

The repository deliberately contains two Go import domains:

| Domain | Example | Ownership |
| --- | --- | --- |
| fbthrift internal | `thrift/lib/thrift/any` | Generated standard IDLs and other namespaces declared as `thrift...` in the monorepo. |
| Published runtime | `github.com/facebook/fbthrift/thrift/lib/go/thrift` | Handwritten Go runtime packages and IDLs that explicitly declare that full namespace. |

Do not mechanically replace internal imports with GitHub paths. For example,
the Any serializer correctly imports:

```go
import (
    thriftany "thrift/lib/thrift/any"
    thriftstandard "thrift/lib/thrift/standard"
    thrifttyperep "thrift/lib/thrift/type_rep"
)
```

An OSS test or generated-code workspace can resolve both domains locally with
two modules:

```text
workspace/
  go.work                    # use ./public and ./internal
  public/go.mod              # module github.com/facebook/fbthrift
  public/thrift/lib/go/...   # handwritten runtime
  internal/go.mod            # module thrift
  internal/lib/thrift/...    # generated standard IDLs
```

This models the import contract without editing generated files, fetching a
second copy of fbthrift, or creating a runtime/codegen dependency cycle. The
CMake Go targets construct this workspace under the build directory.

## Serialization protocols

Standalone generated values support these APIs from
`github.com/facebook/fbthrift/thrift/lib/go/thrift`:

| Encoding | Encode | Decode | RPC payload |
| --- | --- | --- | --- |
| Compact | `EncodeCompact` | `DecodeCompact` | Yes; default |
| Binary | `EncodeBinary` | `DecodeBinary` | Yes |
| Typed CompactJSON | `EncodeCompactJSON` | `DecodeCompactJSON` | No |
| SimpleJSON | `EncodeSimpleJSON` | `DecodeSimpleJSON` | No |
| SimpleJSON V2 | `EncodeSimpleJSONV2` | `DecodeSimpleJSONV2` | No |

```go
encoded, err := thrift.EncodeCompact(message)
if err != nil {
    return err
}

decoded := example.NewMessage()
if err := thrift.DecodeCompact(encoded, decoded); err != nil {
    return err
}
```

Only Binary and Compact are accepted by Header, HTTP, and Rocket generated RPC
paths. Rocket and Header are transports/framing layers, not serialization
formats. See [Serialization protocols](../features/serialization/protocols.md)
and [RPC transports and runtime stacks](../features/rpc-transports.md).

## Rocket client and server

Create the generated processor and explicitly select the server transport:

```go
listener, err := net.Listen("tcp", "127.0.0.1:0")
if err != nil {
    return err
}

processor := chat.NewChatServiceProcessor(handler)
server := thrift.NewServer(
    processor,
    listener,
    thrift.TransportIDRocket,
    thrift.WithNumWorkers(runtime.GOMAXPROCS(0)),
)
return server.ServeContext(ctx)
```

The client must also select a transport. Compact is the default payload
protocol; select Binary explicitly with `WithProtocolID` when required:

```go
channel, err := thrift.NewClient(
    thrift.WithRocket(),
    thrift.WithProtocolID(thrift.FormatIDCompact),
    thrift.WithDialer(func() (net.Conn, error) {
        return net.DialTimeout("tcp", address, 5*time.Second)
    }),
    thrift.WithIoTimeout(5*time.Second),
)
if err != nil {
    return err
}
client := chat.NewChatServiceChannelClient(channel)
defer client.Close()
```

`WithUpgradeToRocket` supports the Header-to-Rocket upgrade path.
`TransportIDHeader` is deprecated. For TLS, pass a verified `tls.Config` to
`WithTLS`; the runtime clones it and applies the transport ALPN. Production
callers still own trust roots, server-name verification, dial deadlines, RPC
deadlines, and certificate rotation.

Streaming, sink, interaction, and bidirectional APIs are documented beside the
runtime:

- [Streaming](../../lib/go/thrift/docs/streaming.md)
- [Sink](../../lib/go/thrift/docs/sink.md)
- [Interactions](../../lib/go/thrift/docs/interactions.md)
- [Bidirectional streaming](../../lib/go/thrift/docs/bidi.md)

## CMake validation targets

Go support is opt-in and does not increase the ordinary C++ target graph:

```bash
cmake -S . -B _build -G Ninja -DTHRIFT_GO=ON
cmake --build _build --target thrift-go-check
```

The bounded targets are:

| Target | Coverage |
| --- | --- |
| `thrift-go-smoke` | Runtime, formats, Rocket, metadata, and end-to-end packages. |
| `thrift-go-fixtures` | Generated `thrift/test/go` fixture behavior. |
| `thrift-go-conformance` | Generates the official conformance IDLs and builds the Go conformance/RPC executables. It does not launch the cross-language harness. |
| `thrift-go-stress` | Explicit server stress run, excluded from `thrift-go-check`. |
| `thrift-go-check` | Aggregate smoke, fixture, and conformance-build validation. |

Bound stress work at configure time:

```bash
cmake -S . -B _build -DTHRIFT_GO=ON \
  -DTHRIFT_GO_STRESS_REQUESTS=1000
cmake --build _build --target thrift-go-stress
```

When `enable_tests=ON`, CTest registers the smoke, fixture, and
conformance-build suites with the `go` label. Stress remains explicit so a
normal test run cannot accidentally execute the historical 100,000-request
load per transport.

## Tradeoffs

- Direct generated codecs maximize throughput and avoid reflection, but
  increase generated source and compile work; `use_reflect_codec` reverses that
  tradeoff.
- Compact usually minimizes wire size; Binary avoids varint work for
  fixed-width numeric fields.
- The two-module workspace preserves internal namespaces and the published
  runtime API, at the cost of requiring Go workspace mode for combined OSS
  validation.
- Opt-in CMake targets keep Go code generation out of default C++ builds, so
  language coverage must be selected explicitly in CI.
