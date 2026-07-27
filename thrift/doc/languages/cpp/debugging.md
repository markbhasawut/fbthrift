---
sidebar_position: 4
---

# Debugging C++ FBThrift with LLDB

Use LLDB for control flow, ownership, exceptions, and coroutine state. Use
FBThrift's Debug protocol to render generated values. They solve different
problems: Debug protocol is a write-only diagnostic formatter, not an RPC wire
protocol and not a replacement for Compact or Binary.

## Build debuggable binaries

For application debugging, prefer an out-of-source `RelWithDebInfo` build. Use
`Debug` when optimized-out locals or inlining prevent inspection.

```bash
cmake -S . -B build-debug -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build-debug -j8
```

Keep generated code and the installed FBThrift/Folly headers and libraries on
one package revision. A mixed package graph can turn an apparent container,
coroutine, or allocator failure into an ABI mismatch.

On macOS, launching the process from LLDB is usually more reliable than
attaching to an already running hardened process:

```bash
lldb -- ./build-debug/my_server
```

```text
(lldb) settings set target.run-args --port=9090 --logtostderr=1
(lldb) run
(lldb) thread backtrace all
(lldb) frame variable
```

Do not disable SIP or system-wide security to make attach work. Use a
development-signed binary with appropriate debugging entitlement when the
platform policy requires it.

## Useful breakpoints

Break on the application handler first; generated processors and coroutine
machinery add many frames and templates:

```text
(lldb) breakpoint set --name 'my::Handler::co_get'
(lldb) breakpoint set --name 'my::Handler::sync_get'
(lldb) breakpoint set --regex 'MyService.*AsyncProcessor.*process'
(lldb) breakpoint set --name __cxa_throw
(lldb) breakpoint list
```

For an RPC that returns `TApplicationException: Method name ... not found`, use
the generated processor breakpoint to prove which service owns the connection,
then verify the client and server were generated from the same IDL and are
using the expected port/routing layer. The exception is dispatch evidence; it
is not a serialization-protocol failure.

Useful state inspection patterns for generated field references and IOBufs:

```text
(lldb) frame variable request
(lldb) expression -- *request->user_id()
(lldb) expression -- request->payload()->computeChainDataLength()
(lldb) expression -- request->payload()->isChained()
(lldb) memory read --format x --size 1 --count 32 <address>
```

Call expressions may fail when LLDB cannot instantiate an optimized template.
In that case, bind the value to a concrete local in a temporary diagnostic
build and inspect that local. Avoid relying on debugger-side mutation for a
reproduction that involves races or coroutine scheduling.

## Coroutines, streams, and sinks

A suspended coroutine frame is heap-resident and may not appear as a normal
contiguous call stack. Set breakpoints at handler entry and immediately before
and after the relevant `co_await`/`co_yield`. Inspect cancellation and executor
state on every thread:

```text
(lldb) breakpoint set --regex 'co_(stream|sink|exchange)'
(lldb) thread list
(lldb) thread backtrace all
(lldb) frame variable
```

For hangs, collect all thread stacks before interrupting workers. Distinguish:

- EventBase thread blocked in I/O;
- CPU executor saturation or queueing;
- producer waiting for stream/sink credit;
- consumer stopped without propagating cancellation;
- shutdown drain/reap waiting for an in-flight handler.

Debug builds perturb scheduling and allocation. Reconfirm any timing-sensitive
result in an optimized build with symbols.

## Render generated values with Debug protocol

Link the generated type library and `FBThrift::thriftprotocol` (or
`FBThrift::thriftcpp2` for an RPC application), then include:

```cpp
#include <thrift/lib/cpp2/protocol/DebugProtocol.h>
```

`debugStringViaEncode()` is the preferred generic entry point:

```cpp
apache::thrift::DebugProtocolWriter::Options options;
options.stringLengthLimit = 64;
options.skipListIndices = true;

const std::string rendered =
    apache::thrift::debugStringViaEncode(value, options);
LOG(INFO) << rendered;
```

For compact output without field IDs or wire types:

```cpp
const auto rendered = apache::thrift::debugStringViaEncode(
    value,
    apache::thrift::DebugProtocolWriter::Options::simple());
```

The process-wide defaults are also gflags:

```text
--thrift_cpp2_debug_string_limit=64
--thrift_cpp2_debug_skip_list_indices=true
```

The default string limit is 256 bytes. `0` disables the limit and is unsafe for
untrusted or large values. Binary data is C-escaped and truncated with its
original length. Rendering an `IOBuf` clones and coalesces it, so Debug protocol
allocates and copies; never put it in a hot path or use it for benchmarking.

`debugString()` remains available for generated `Cpp2Ops<T>` types, but
`debugStringViaEncode()` follows the newer op/type-tag encoding path. GoogleTest
also discovers the generated `PrintTo` overload, so failed equality assertions
normally include Debug-protocol output.

:::caution

Debug protocol is write-only, intentionally unstable, and for diagnostics
only. Do not persist its output, parse it, negotiate it as an RPC protocol, or
use it as a compatibility contract.

:::

## Redaction and production safety

Debug protocol has no schema-aware secret-redaction policy. It can print
tokens, personal data, metadata, plaintext, ciphertext, nonces, authentication
tags, and key identifiers. A length limit is not redaction.

Prefer a purpose-built diagnostic projection containing only allowlisted
fields. If full rendering is necessary in a controlled debug build, keep the
scope local, bound the output, never log cryptographic keys or credentials, and
remove the instrumentation before merging.

## Debugging serialized bytes

Debug protocol renders a typed in-memory value; it does not decode arbitrary
Compact/Binary bytes. To inspect bytes, deserialize with the exact generated
type and production protocol, check the error, then render the decoded value:

```cpp
MyType decoded;
apache::thrift::CompactSerializer::deserialize(serialized, decoded);
LOG(INFO) << apache::thrift::debugStringViaEncode(decoded);
```

When the type is not statically known, use FBThrift Any/Dynamic APIs with a
schema/type registry. Do not guess a protocol or type from payload contents.

## Sanitizers and LLDB

LLDB is best for a concrete stop; sanitizers are better for memory safety and
races. Run ASan/UBSan builds for ownership and bounds failures and a separate
TSan build for concurrency. Do not combine TSan with ASan, and do not infer
production latency from sanitizer builds. Preserve the sanitizer report and
all-thread LLDB backtrace at the first failing access.

## Cost tradeoffs

- `Debug`: best locals and control-flow visibility; largest timing distortion.
- `RelWithDebInfo`: useful stacks with representative optimization; some locals
  and template frames are optimized out.
- Debug protocol: high diagnostic value but allocates, coalesces IOBufs, and
  risks data disclosure.
- Targeted breakpoints: lower noise than breaking inside every generated
  processor, but require knowing the application ownership boundary.
