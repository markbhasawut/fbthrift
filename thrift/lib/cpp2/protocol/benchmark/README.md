# Thrift, Carbon, and Protobuf protocol benchmark

`ThriftProtocolBenchmarks` compares Thrift Binary, Thrift Compact, the
cursor-based Thrift serializer, Protobuf, and mcrouter Carbon for the same
small, medium, and large value shapes.

The target is deliberately opt-in. mcrouter depends on fbthrift, so making a
built mcrouter package an unconditional fbthrift dependency would introduce a
package cycle. Instead, the benchmark consumes a mcrouter *source checkout* and
compiles only `CarbonProtocolReader.cpp` and `CarbonQueueAppender.cpp`.

```bash
git clone https://github.com/facebook/mcrouter.git /path/to/mcrouter
cmake -S . -B _build -G Ninja \
  -DTHRIFT_RPC=ON \
  -DTHRIFT_CARBON_PROTOCOL_BENCHMARK=ON \
  -DTHRIFT_MCROUTER_SOURCE_DIR=/path/to/mcrouter
cmake --build _build --target ThriftProtocolBenchmarks
_build/bin/ThriftProtocolBenchmarks
```

Protobuf must be discoverable through `CMAKE_PREFIX_PATH` or the normal CMake
package search path.

## Code-generation pipeline

```text
CarbonTestData.idl
  -> generate_carbon_benchmark.py
     -> CarbonTestData.thrift
     -> Carbon serialization/deserialization glue
  -> thrift1 --gen mstch_cpp2:no_metadata
     -> CarbonTestData C++2 value types
```

The local Python bridge implements only the strict, value-only Carbon IDL
subset used by this benchmark: structs, scalar fields, `std::vector`, and
`std::map`. It does not claim to replace mcrouter's full Carbon request/reply,
router, and service generator. The narrow scope keeps the OSS benchmark
reproducible without importing mcrouter as a reverse build dependency.

## Updating mcrouter's committed Carbon output

The public mcrouter checkout contains Carbon IDLs and their generated C++ but
does not contain Meta's full Carbon compiler. fbthrift therefore exposes an
explicit provider boundary instead of treating the benchmark bridge as a full
compiler. Configure an external provider together with the mcrouter checkout:

```bash
cmake -S . -B _build -G Ninja \
  -DTHRIFT_MCROUTER_SOURCE_DIR=/path/to/mcrouter \
  -DTHRIFT_MCROUTER_CARBON_CODEGEN_EXECUTABLE=/path/to/carbon-codegen

# Read-only CI verification. The target fails if committed output is stale.
cmake --build _build --target McrouterCarbonCodegenCheck

# Regenerate changed output in the mcrouter checkout.
cmake --build _build --target McrouterCarbonCodegen
```

The provider is invoked once for every `.idl`, in import-topological order:

```text
carbon-codegen \
  --input <absolute-idl> \
  --output-dir <empty-temporary-directory> \
  --include-prefix <repository-relative-gen-directory> \
  --source-root <absolute-mcrouter-root>
```

It must emit at least one regular file. Every emitted basename must begin with
the input IDL stem; this ownership rule lets update mode delete stale files
without touching output owned by another IDL in the same `gen` directory.
`McrouterCarbonCodegenCheck` never modifies the checkout. The update target
atomically replaces changed files, adds missing files, and removes stale owned
files.

For direct or incremental use, the repository driver also accepts repeatable
`--idl <path>` and `--generator-arg <argument>` options:

```bash
python3 thrift/lib/cpp2/protocol/benchmark/regenerate_mcrouter_carbon.py \
  --mcrouter-root /path/to/mcrouter \
  --generator /path/to/carbon-codegen \
  --mode check \
  --idl mcrouter/lib/carbon/test/CarbonTest.idl
```

The CMake targets are intentionally independent of
`THRIFT_CARBON_PROTOCOL_BENCHMARK`; configuring the provider enables source
maintenance without adding the benchmark and its Protobuf/mcrouter objects to
the normal build graph.
