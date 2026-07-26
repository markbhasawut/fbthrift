---
sidebar_position: 3
title: Java code generation and build
---

# Java code generation and build

FBThrift has three Java generators with different runtimes and API models.
These are FBThrift outputs; do not substitute the Apache Thrift compiler or
runtime artifacts.

| Generator | Namespace | Output | Runtime/API |
| --- | --- | --- | --- |
| `java` | `java.swift` | `gen-java` | Modern Reactive Streams/Netty FBThrift runtime in `thrift/lib/java`. |
| `javadeprecated` | `java` | `gen-javadeprecated` | Legacy synchronous FBThrift API in `thrift/lib/javadeprecated`. |
| `android_lite` | `android` | `gen-android` | Dependency-free constrained Android API in `thrift/lib/android_lite`. |

The legacy registered names are `mstch_java`, `java_deprecated`, and `android`.
Prefer the public names above.

## Modern `java`

```thrift
namespace java.swift com.example.catalog
```

```sh
thrift1 --gen java -o generated catalog.thrift
```

The generator emits Java types and Reactive RPC clients/processors under the
package directory in `gen-java`. It recognizes:

| Option | Effect |
| --- | --- |
| `separate_data_type_from_services` | Writes data types below `gen-java/data-type` and service artifacts below `gen-java/services`. This lets Maven/Buck model a narrow data-type library without pulling the RPC runtime. |
| `deprecated_allow_leagcy_reflection_client` | Emits the deprecated reflection-client compatibility surface. The misspelled `leagcy` spelling is the stable option name. |

The Java Maven reactor uses `separate_data_type_from_services` for standard
IDLs and fixtures so `java-generated-core` remains below the full RPC runtime
in the dependency graph:

```text
common -> generated core data types -> runtime -> fixtures/tests/conformance
```

Do not add a generated-source edge from the stage-2 compiler back into a
runtime library used to build that compiler. Pass an already built `thrift1`
path to Maven.

## Legacy `javadeprecated`

```thrift
namespace java com.example.catalog
```

```sh
thrift1 --gen javadeprecated -o generated catalog.thrift
```

This generator has no options. It emits the synchronous legacy API and uses the
runtime sources under `thrift/lib/javadeprecated`. It is tested against the
same IDLs as modern Java and Android Lite to catch semantic drift, but the
generated APIs are intentionally not source-compatible.

## `android_lite`

```thrift
namespace android com.example.catalog
```

```sh
thrift1 --gen android_lite -o generated catalog.thrift
```

This generator has no options. Its runtime targets Java 8 bytecode and avoids
the Netty/Reactor dependency surface. Build and test it with JDK 21 or 25; the
compiler release controls the emitted bytecode, not the JDK used to run Maven.

## Protocols and transports

The modern standalone runtime exposes Binary, Compact, typed JSON, SimpleJSON,
and SimpleJSONBase64 through `SerializerUtil` and `SerializationProtocol`.
Generated modern RPC uses `org.apache.thrift.ProtocolId`, supports Binary and
Compact, and defaults to Compact. RSocket and unified Header are transports;
they do not define a third payload format.

`javadeprecated` exposes the corresponding legacy protocol classes.
Android Lite deliberately implements only `TBinaryProtocol`. See
[serialization protocols and runtime APIs](../features/serialization/protocols.md)
for code examples and exact naming, and
[RPC transports and runtime stacks](../features/rpc-transports.md) for RSocket,
Header, reference-counted payload ownership, and C++ interoperability.

## Maven reactor

JDK 21 is the baseline. JDK 25 is supported and activates the Java 25
multi-release overlay and tests. JDK 22 through 24 are intentionally outside
the declared support window.

```sh
mvn -f thrift/lib/java/pom.xml \
  -Dfbthrift.compiler=/absolute/path/to/thrift1 \
  verify
```

The runtime JAR is multi-release: the base is compiled for Java 21, with
versioned implementations from `src/main/java11`, `src/main/java21`, and, on
JDK 25, `src/main/java25`. Java 25 tests add
`--enable-native-access=ALL-UNNAMED` for the Foreign Function and Memory API
paths.

The reactor modules are:

| Module | Responsibility |
| --- | --- |
| `common` | Runtime-neutral Java support. |
| `generated` | Standard FBThrift IDLs generated as data types only. |
| `runtime` | Modern transport, protocol, serialization, Netty, Reactor, stream, sink, and server/client APIs. |
| `test-fixtures` | Generated modern Java fixtures plus shared fixture code. |
| `tests` | Runtime and serialization tests, including native transport and TLS variants. |
| `thrift/conformance/java` | Generated Java conformance handlers/executables. |
| `benchmarks` | Portable JMH benchmarks and load generators. |
| `varint` | Varint implementation and tests. |
| `example/ping` | Generated ping example. |
| `fbthrift-maven-plugin` | Maven source-generation plugin and its integration example. |
| `android_lite` | Constrained runtime and tests. |
| `javadeprecated` | Legacy runtime plus cross-generator fixture tests. |

Run a focused module with upstream dependencies:

```sh
mvn -f thrift/lib/java/pom.xml \
  -pl tests -am \
  -Dfbthrift.compiler=/absolute/path/to/thrift1 \
  test
```

Tests tagged `large-memory` allocate frames in the 1–5 GiB range and are
excluded by default:

```sh
mvn -f thrift/lib/java/pom.xml \
  -pl tests -am \
  -Plarge-memory-tests \
  -Dfbthrift.compiler=/absolute/path/to/thrift1 \
  test
```

On macOS ARM64, the tests module activates the matching Netty kqueue and DNS
native classifiers. TLS tests prefer Folly's canonical
`folly/io/async/test/certs` fixtures when found through
`fbthrift.source.root`, `FOLLY_ROOT`, `FOLLY_TEST_CERTS`, or
`CMAKE_PREFIX_PATH`; they fall back to a generated self-signed certificate for
a standalone FBThrift checkout.

## Maven code-generation plugin

`com.facebook.mojo:fbthrift-maven-plugin` runs the FBThrift compiler during
`generate-sources`. Configure the compiler path/options, include root, input
files, output directory, and generator explicitly. The plugin defaults to
`java`; `javadeprecated` is also supported.

The plugin uses `-out`, so `targetDirectory` is the exact Java source root and
does not contain an additional `gen-java` directory. Its checksum includes the
compiler command and source contents; recursive `-r` generation always reruns.

## Benchmarks and conformance

Build the portable benchmark JAR:

```sh
mvn -f thrift/lib/java/pom.xml \
  -pl benchmarks -am \
  -Dfbthrift.compiler=/absolute/path/to/thrift1 \
  -DskipTests package

java -jar thrift/lib/java/benchmarks/target/fbthrift-java-benchmarks.jar
```

`SRProxyClient` and `StatsBenchmark` are excluded because they require
Meta-internal service-router/statistics dependencies. The remaining JMH
sources use the OSS runtime and generated fixtures.

The conformance module generates directly from `thrift/conformance/if` with the
modern `java` backend. It is a Java protocol/behavior surface, not Apache
Thrift compatibility validation.

## Tradeoffs

- `java` provides the complete async/streaming runtime but carries the largest
  dependency, native-transport, and test matrix.
- `javadeprecated` preserves synchronous callers at the cost of a separate
  generated/runtime API that should not be mixed with modern services.
- `android_lite` minimizes bytecode and dependencies, but intentionally omits
  the modern server, streaming, sink, and Netty/Reactor surface.
- `separate_data_type_from_services` improves dependency layering; consumers
  must add both generated source roots when they need RPC services.
