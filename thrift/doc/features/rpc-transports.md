---
sidebar_position: 2
title: RPC transports and runtime stacks
---

# RPC transports and runtime stacks

FBThrift RPC combines a Binary or Compact serialized payload with request
metadata, framing, and a byte transport. Choosing Rocket, Header, HTTP/2, or
`fast_thrift` does not select a serialization format.

Read [Serialization protocols and runtime APIs](serialization/protocols.md)
first for the wire formats and protocol IDs.

## Support matrix

| Stack | Payload protocols | RPC shapes | Languages in this OSS tree | Status |
| --- | --- | --- | --- | --- |
| Rocket over TCP/TLS | Binary, Compact | Unary, oneway, stream, sink, bidirectional stream, interactions | C++, modern Java, modern Python | Primary modern RPC transport |
| Thrift Header | Binary, Compact | Unary and oneway | C++, modern/legacy Java, legacy Python | Compatibility transport |
| HTTP/2 | Binary, Compact in generated C++ RPC | Unary and oneway; no stream or sink channel support | C++ | Optional, requires Proxygen |
| Rocket over QUIC | Binary, Compact | Rocket shapes over a QUIC async transport | C++ | Experimental |
| C++ `fast_thrift` Rocket | Binary, Compact | Generated fast client/server: unary request-response only | C++ | Experimental, opt-in code generation |
| Java RSocket | Binary, Compact | Unary, fire-and-forget, streams, channels/sinks as exposed by generated Java | Modern Java | Rocket-compatible Java implementation |

The ordinary C++ `RocketClientChannel` and `ThriftServer` are the complete,
production-oriented C++ surface. The `fast_thrift` classes are a separate
pipeline implementation and do not yet have feature parity.

## C++ Rocket

`RocketClientChannel` uses RSocket 1.0 framing plus FBThrift request/response
metadata. It defaults to Compact and supports Binary when
`setProtocolId(T_BINARY_PROTOCOL)` is called before the generated client is
created.

```cpp
#include <folly/io/async/AsyncSocket.h>
#include <thrift/lib/cpp/protocol/TProtocolTypes.h>
#include <thrift/lib/cpp2/async/RocketClientChannel.h>

auto socket = folly::AsyncSocket::newSocket(&eventBase, serverAddress);
auto channel =
    apache::thrift::RocketClientChannel::newChannel(std::move(socket));
channel->setProtocolId(apache::thrift::protocol::T_COMPACT_PROTOCOL);

catalog::CatalogServiceAsyncClient client(std::move(channel));
```

Use `newChannelWithMetadata()` when the caller must provide explicit
`RequestSetupMetadata`. TLS uses an `AsyncTransport` established through the
Fizz/security integration; payload and protocol selection are unchanged.

Rocket carries:

- `RequestRpcMetadata` and `ResponseRpcMetadata`;
- method name, RPC kind, timeouts, headers, checksums, and compression;
- RSocket stream IDs and backpressure;
- request-response, fire-and-forget, request-stream, request-channel/sink, and
  bidirectional-stream frame lifecycles.

Transport-level error payloads use Compact metadata even when the application
payload uses Binary. Do not deserialize framework metadata with the
application protocol.

### Server

`apache::thrift::ThriftServer` owns routing, worker/resource pools, overload
control, interceptors, TLS, and Rocket/Header connection detection. Generated
processors dispatch Binary and Compact according to request metadata; no
server-wide payload protocol needs to be hard-coded.

Link the complete runtime:

```cmake
target_link_libraries(catalog_server PRIVATE
  catalog-cpp2
  FBThrift::thriftcpp2
)
```

`THRIFT_RPC=OFF` intentionally removes `FBThrift::thriftcpp2` and all Rocket,
Header, server, Fizz, Wangle, and mvfst edges. Serialization-only programs
should link `FBThrift::thriftprotocol`.

## C++ Header

Thrift Header adds a length-delimited header containing the payload protocol
ID, transforms/compression, sequence number, client type, and string headers.
It exists for compatibility with older clients and transports.

```cpp
auto channel = apache::thrift::HeaderClientChannel::newChannel(
    folly::AsyncSocket::newSocket(&eventBase, serverAddress),
    apache::thrift::HeaderClientChannel::Options()
        .setProtocolId(apache::thrift::protocol::T_COMPACT_PROTOCOL));

catalog::CatalogServiceAsyncClient client(std::move(channel));
```

Header supports unary and oneway RPC. Its `sendRequestStream()` and
`sendRequestSink()` implementations return a transport error. Use Rocket for
streams, sinks, bidirectional streams, and interactions.

The old framed/unframed client types are compatibility modes behind the same
channel implementation. They do not carry the complete Header metadata
surface and should not be selected for new services. The non-TLS
Header-to-Rocket upgrade path is also a migration mechanism, not the default
for a new client.

## C++ HTTP/2

Configure with `-DTHRIFT_HTTP2=ON`; this adds the Proxygen dependency and
builds `HTTPClientChannel` plus `HTTP2RoutingHandler`.

```cpp
auto channel =
    apache::thrift::HTTPClientChannel::newHTTP2Channel(std::move(socket));
channel->setProtocolId(apache::thrift::protocol::T_COMPACT_PROTOCOL);
catalog::CatalogServiceAsyncClient client(std::move(channel));
```

The HTTP request uses `application/x-thrift` and records the protocol in
`x-thrift-protocol`. Although `HTTPClientChannel` can spell JSON protocol
header values for compatibility, generated C++ RPC serialization dispatch
accepts only Binary and Compact. The channel rejects stream and sink RPCs.

## C++ Rocket over QUIC

`ThriftQuicServer` and `quic_thriftcpp2` run the ordinary Rocket stack over an
mvfst QUIC async transport. This is explicitly experimental. It does not
define a new serialization or RPC framing protocol, and the target is not a
portable installed-package contract. Treat it as a source-tree integration
surface until its API and deployment model stabilize.

## C++ `fast_thrift`

`thrift/lib/cpp2/fast_thrift` is a second C++ channel-pipeline, connection, and
Rocket framing implementation designed to reduce indirection, allocation, and
hot-path overhead. It still speaks Rocket and still serializes application
payloads with Binary or Compact.

It is not enabled by a `--gen cpp2` option. Opt in per service with structured
annotations:

```thrift
include "thrift/annotation/cpp.thrift"

package "example.com/catalog"

@cpp.FastClient
@cpp.FastServer
service CatalogService {
  Item getItem(1: i64 id);
}
```

`@cpp.FastClient` generates the fast client rather than the standard
`AsyncClient`. `@cpp.FastServer` generates a
`FastServiceHandler<CatalogService>` specialization and per-connection app
adapter rather than the standard `SvIf`/`AsyncProcessor` server path.

Current constraints are architectural, not documentation caveats:

- only single-request/single-response functions are generated;
- oneway, stream, sink, bidirectional stream, and interaction methods are
  skipped;
- `fast_thrift::thrift::ThriftClientChannel` requires a caller-built,
  connected `RocketClientConnection`;
- unsupported client channel operations currently terminate through
  `XLOG(FATAL)`;
- the fast generated server dispatches only `ProtocolId::COMPACT` and
  `ProtocolId::BINARY`;
- this surface has its own server configuration, lifecycle, TLS, batching,
  backpressure, monitoring, and metadata integration.

The server entry points are:

- `fast_thrift::thrift::FastThriftServer` for generated
  `@cpp.FastServer` handlers;
- `fast_thrift::thrift::FastThriftChannelServer` for the compatibility
  `AsyncProcessorFactory` path;
- `fast_thrift::thrift::ThriftClientChannel` for a generated client over a
  prebuilt fast Rocket connection.

Use the ordinary `RocketClientChannel`/`ThriftServer` unless the service is
unary-only and has been benchmarked with the fast pipeline. The tradeoff is a
narrower, less stable API and duplicated transport integration in exchange for
a lower-overhead hot path.

## Java transports

Modern Java serializes generated requests through `TProtocolType` and carries
them over either RSocket or the unified Header transport. Client configuration
defaults to Compact:

```java
ThriftClientConfig config =
    new ThriftClientConfig().setProtocol(ProtocolId.COMPACT);
RSocketRpcClientFactory factory = new RSocketRpcClientFactory(config);
```

The Java RSocket implementation maps unary, fire-and-forget, streaming, and
channel-style calls to the corresponding RSocket operations. It uses zero-copy
Netty payload decoding, so `Payload`/`ByteBuf` ownership is reference-counted;
custom direct subscribers must release payloads they consume.

`UnifiedServerTransport` can identify RSocket versus Header framing on an
accepted connection. Java still supports only Binary and Compact for generated
RPC, regardless of which transport is selected.

## Python transports

Modern Python clients use native FBThrift channels underneath the generated
Python API and default to Compact. The client factories accept a `Protocol`
value for Binary or Compact payloads. Legacy `thrift.py` exposes
`THeaderProtocol` and the older socket/transport factories directly.

Do not infer transport support from standalone
`thrift.python.serializer.Protocol`: JSON and JSON5 are valid standalone
serialization choices but are not generated RPC payload choices.

## Performance and compatibility tradeoffs

- Compact usually reduces bandwidth and cache footprint; varint and zigzag
  work can cost more CPU than Binary for uniformly large integer fields.
- Binary uses more bytes for small integers but has simpler fixed-width scalar
  decoding and is required by cursor-based serialization.
- Rocket multiplexes streams and carries rich metadata, but its state machine,
  backpressure, and reference-counted payload lifetime are more complex than
  Header unary RPC.
- Header has the broadest legacy interoperability but cannot express the full
  modern stream/sink/interaction surface.
- `fast_thrift` removes generality from the hot path; feature parity and API
  stability are deliberately traded for latency/throughput experiments.
- HTTP/2 integrates with HTTP infrastructure at the cost of Proxygen and a
  unary-only channel surface.
- QUIC changes loss recovery and connection migration behavior, not the
  Thrift/Rocket payload contract; the current C++ integration is experimental.
