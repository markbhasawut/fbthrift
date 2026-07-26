---
sidebar_position: 3
title: CMake code generation
---

# CMake code generation

fbthrift exposes three CMake surfaces. They serve different layers and should
not be mixed accidentally:

| Surface | Role |
| --- | --- |
| `thrift/cmake/FBThriftConfig.cmake.in` | Installed package discovery, imported runtime targets, compiler path, and component checks. It does not define code-generation functions. |
| `ThriftLibrary.cmake` | Low-level in-tree and installed code-generation macros. This is the authoritative OSS generated-file contract and supports special patch/schema integration. |
| `build/fbcode_builder/CMake/FBThrift*.cmake` | Higher-level fbcode_builder wrappers for downstream projects already using the fbcode_builder CMake modules. |

## Standalone source build

fbcode_builder/getdeps is not required by the root CMake project. Supply normal
CMake package prefixes for dependencies and configure the repository directly:

```bash
cmake -S . -B _build -G Ninja \
  -DCMAKE_PREFIX_PATH="/path/to/folly;/path/to/wangle;/path/to/proxygen" \
  -DTHRIFT_RPC=ON \
  -DTHRIFT_HTTP2=OFF \
  -Dthriftpy=ON \
  -Dthriftpy3=OFF \
  -Dthrift_python=ON
cmake --build _build --target thrift1 thriftcpp2
```

Homebrew installs some dependencies as keg-only formulae. Pass their roots to
CMake explicitly; otherwise Folly may find the ICU headers through the SDK but
fail to resolve the ICU libraries:

```bash
cmake -S . -B _build -G Ninja \
  -DICU_ROOT="$(brew --prefix icu4c@78)" \
  -DOPENSSL_ROOT_DIR="$(brew --prefix openssl@3)" \
  -DCMAKE_PREFIX_PATH="/path/to/folly;/path/to/wangle;/path/to/proxygen"
```

Boost is discovered through its installed CMake package; fbthrift does not pin
the obsolete 1.83 release. The standalone macOS configuration is validated
with Homebrew Boost 1.90.

The root build uses compatibility finders under `thrift/cmake`; it does not
load `build/fbcode_builder/CMake`. The legacy `py` archive manifest is produced
by fbthrift's own CMake logic. `py3` and `python` still require their documented
Python/Cython dependencies. Disable `THRIFT_RPC` for a protocol/type-only
library build; `FBThrift::thriftcpp2` and its component are then intentionally
absent. That mode also omits conformance-backed generated Any registration;
the Type, Any, Patch, and protocol data-model runtimes remain available through
their narrow library targets.

The fbcode_builder wrappers are an optional downstream convenience surface.
To use them, add `build/fbcode_builder/CMake` to `CMAKE_MODULE_PATH` explicitly;
the low-level `ThriftLibrary.cmake` path below does not need them.

Benchmarks are excluded by default, including when `enable_tests=ON`. Set
`THRIFT_BENCHMARKS=ON` for the regular benchmark set. The cross-protocol
Thrift/Carbon/Protobuf benchmark is separately gated because it needs a
mcrouter source checkout and Protobuf:

```bash
cmake -S . -B _build -G Ninja \
  -DTHRIFT_RPC=ON \
  -DTHRIFT_CARBON_PROTOCOL_BENCHMARK=ON \
  -DTHRIFT_MCROUTER_SOURCE_DIR=/absolute/path/to/mcrouter
cmake --build _build --target ThriftProtocolBenchmarks
```

This is a source-only Carbon dependency: fbthrift generates mcrouter's
`carbon_result.thrift` locally and compiles only the Carbon reader/appender
needed by the benchmark. It does not link a built mcrouter package back into
fbthrift, so the normal `mcrouter -> fbthrift` dependency remains acyclic. See
the [benchmark README](../../lib/cpp2/protocol/benchmark/README.md) for the
code-generation boundary and supported Carbon IDL subset.

## Find the installed package

```cmake
find_package(FBThrift CONFIG REQUIRED COMPONENTS compiler cpp2 python)

target_link_libraries(my_server PRIVATE FBThrift::thriftcpp2)
```

The public components are `compiler`, `cpp`, `cpp2`, `py`, `py3`, and `python`.
`cpp` and `cpp2` are equivalent names for the modern C++ RPC runtime. Python
components are true only when the matching runtime was enabled while building
fbthrift. `compiler` is false for a `THRIFT_LIB_ONLY` package; in that case
`FBTHRIFT_COMPILER` is empty.

The package defines `FBTHRIFT_COMPILER`, `FBTHRIFT_INCLUDE_DIR`, and imported
targets such as `FBThrift::thriftcpp2`. Component selection validates runtime
availability; it does not run the compiler.

The installed package carries the compatibility find-modules required by its
exported interfaces and scopes them while loading dependencies. Consumers do
not add either the fbthrift source tree or `build/fbcode_builder/CMake` to
`CMAKE_MODULE_PATH` for `find_package(FBThrift CONFIG ...)`.

## Imported target selection

Link the narrowest target that owns the API being used. Public dependencies are
transitive, so manually repeating the entire runtime library list is neither
necessary nor safe across fbthrift revisions.

| Imported target | Use it for | Availability |
| --- | --- | --- |
| `FBThrift::thriftcpp2` | Generated C++ services, clients, servers, Rocket/stream/sink RPC, and the complete modern C++ runtime | `THRIFT_RPC=ON`; primary C++ application entry point |
| `FBThrift::thriftprotocol` | Binary/Compact/JSON protocols, protocol objects, field masks, and generated non-RPC type serialization | Any library build; preferred RPC-free entry point |
| `FBThrift::thrift-core` | Core C++ types used below the protocol layer | Any library build; normally transitive through `thriftprotocol` |
| `FBThrift::thriftannotation` | Generated C++ definitions for `thrift/annotation` | Any library build; link directly only when C++ code names those definitions |
| `FBThrift::thrifttyperep` | Standard type/protocol representation IDLs | Any library build |
| `FBThrift::thrifttype` | Runtime Type, Any, and Patch APIs | Any library build |
| `FBThrift::thriftmetadata` | Schema, AST, service-catalog, and generated-registration APIs | Any library build |
| `FBThrift::thrift_path`, `FBThrift::thrift_dynamic_value` | Dynamic paths, values, descriptors, and schema-backed resolution | Any library build |
| `FBThrift::thriftfrozen2` | Frozen2 serialization/layout support | Any library build; not required merely because generated code has no `frozen2` option |
| `FBThrift::thrifttranscode` | Protocol-to-protocol transcoding | Any library build |
| `FBThrift::rpcmetadata`, `FBThrift::serverdbginfo` | RPC metadata and server debugging schemas | Exported in library builds; normally transitive through `thriftcpp2` |
| `FBThrift::thrift`, `FBThrift::async`, `FBThrift::transport`, `FBThrift::concurrency`, `FBThrift::runtime` | Lower RPC/runtime layers and legacy integration points | RPC targets require `THRIFT_RPC=ON`; prefer `thriftcpp2` for applications |
| `FBThrift::thrift1` | Imported compiler executable target | Compiler or full build; `FBTHRIFT_COMPILER` is the convenient path form |

`FBThrift::compiler_ast`, `FBThrift::compiler_base`,
`FBThrift::compiler_lib`, `FBThrift::compiler`, and `FBThrift::whisker` are
exported for compiler/codemod tooling. They are not substitutes for the runtime
targets above. The `FBThrift::thrift-codemod-*` executable targets are available
only in packages that built the compiler.

The legacy `py` runtime exports `FBThrift::thrift_py.py_lib` and
`FBThrift::thrift_py_inspect.py_lib` archive-manifest targets. The `py3` and
modern `python` runtimes are installed as Python/Cython artifacts (including
the built wheel for `python`), not as general-purpose CMake link interfaces.

Targets named `<idl>-<language>-target`, `<idl>-cpp2-obj`, and targets generated
by `add_fbthrift_library()` are build-tree targets owned by the consuming
project. They are not members of the installed `FBThrift::` namespace.

For the standard IDL-to-target mapping, including Any, Patch, metadata, and
annotations, see [standard IDL libraries](../features/standard-idl-libraries.md).

## Low-level `ThriftLibrary.cmake`

An installed consumer can use the helper separately from package discovery:

```cmake
find_package(FBThrift CONFIG REQUIRED COMPONENTS compiler cpp2)

set(THRIFT1 "${FBTHRIFT_COMPILER}")
set(THRIFTCPP2 FBThrift::thriftcpp2)
include("${FBTHRIFT_INCLUDE_DIR}/thrift/ThriftLibrary.cmake")

thrift_library(
  "catalog"                         # file basename, without .thrift
  "CatalogService"                  # every declared service that is consumed
  "cpp2"                            # cpp, cpp2, py, py3, or python
  "json,any,types_cpp_splits=4"     # comma-separated generator options
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}"
  "project/catalog"                 # generated C++ include prefix
  THRIFT_INCLUDE_DIRECTORIES "${PROJECT_SOURCE_DIR}"
)
```

For C++, this creates `catalog-cpp2-target`, `catalog-cpp2-obj`, and
`catalog-cpp2`. Python-family `thrift_library()` calls create a dependency-only
codegen target; Python packaging and Cython extension compilation remain
explicit.

`thrift_generate()` additionally exposes:

- `COMPILER <target-or-path>` to select bootstrap or stage-2 explicitly;
- `INJECT_SCHEMA` to use the global `--inject-schema-const` compiler flag;
- `NAMESPACE <name>` to declare the expected Python output namespace;
- `TARGET_NAME_BASE <name>` when the CMake target name differs from the IDL
  basename;
- `NO_INSTALL` for build-only generated artifacts.

The CMake-only C++ markers `layouts` and `patch` are removed before invoking
`thrift1`. `layouts` opts a `frozen2` layout translation unit into compilation.
`patch` runs the patch companion-IDL pipeline and then generates that companion
with `cpp2:any`. See [C++ code generation](cpp/code-generation.md) for the exact
file contract and [standard IDL libraries](../features/standard-idl-libraries.md)
for an Any/Patch example.

## fbcode_builder wrappers

Projects that already load `build/fbcode_builder/CMake` can use the higher-level
dispatcher:

```cmake
include(FBThriftLibrary)

add_fbthrift_library(
  catalog catalog.thrift
  LANGUAGES cpp python
  SERVICES CatalogService
  DEPENDS common_types
  CPP_OPTIONS json any types_cpp_splits=4
  PYTHON_OPTIONS no_metadata
  PYTHON_NAMESPACE project.catalog
)
```

The dispatcher expands dependency names and target suffixes consistently:

| Language | Function | Logical target suffix | Output |
| --- | --- | --- | --- |
| `cpp` or `cpp2` | `add_fbthrift_cpp_library` | `_cpp` | native library, `gen-cpp2` by default |
| `py` | `add_fbthrift_py_library` | `_py` | legacy pure-Python archive manifest, `gen-py` |
| `py3` | `add_fbthrift_py3_library` | `_py3` | codegen-only target, `gen-py3` |
| `python` | `add_fbthrift_python_library` | `_python` | modern Python archive manifest, `gen-python` |

Do not request both `cpp` and `cpp2` for one logical library: they select the
same backend and would claim the same output files. `py3` deliberately does not
infer a companion C++ target. Generate `cpp`/`cpp2` separately with matching
ABI options, then let the Cython extension own the dependency and link edges.

The packaged C++ wrapper accepts the CMake-only `layouts` marker with `frozen2`.
The full `patch` pipeline is currently available only through
`ThriftLibrary.cmake`; the packaged wrapper rejects `patch` instead of passing
an unknown generator option through to `thrift1`.

## Generator options

Use `thrift1 --help` for the compiler-matched option inventory. The detailed
OSS references are:

- [Complete compiler generator catalog](generators.md)
- [C++ code generation options](cpp/code-generation.md)
- [Java code generation and Maven build](java.md)
- [Python code generation options](python.md)

Options are backend-specific. Structured annotations are per-definition IDL
metadata; generator options are per-invocation build configuration. They are
not interchangeable.

## Static initialization and dependency direction

Generated `_sinit.cpp` files register Any types, schemas, and services during
process startup. A static linker can discard such an object because no ordinary
symbol refers to it. Compile it directly into the final target or whole-archive
the smallest generated library that owns the registration; whole-archiving a
large runtime archive increases binary size and link work.

Schema-aware builds preserve this direction:

```text
standalone standard-IDL embedder
thrift1_bootstrap -> generated runtime types -> stage-2 thrift1
```

Runtime libraries must use the bootstrap compiler. Only consumers requesting
`INJECT_SCHEMA` use stage 2. A py3 companion edge belongs to the consuming
extension target, not to the compiler or runtime libraries.

## Tradeoffs

- Split code reduces peak compiler memory and increases compile parallelism at
  the cost of more scheduler work, object files, and linker inputs.
- Keeping benchmarks opt-in avoids adding Protobuf, mcrouter source, codegen,
  and benchmark executables to ordinary test graphs; benchmark coverage must be
  enabled explicitly in performance jobs.
- Exact output declarations make clean and incremental builds deterministic,
  but every option that replaces or omits files must be modeled by the helper.
- Explicit py3/native edges require more downstream CMake, but prevent hidden
  runtime/compiler cycles and accidental native dependencies in Python-only
  targets.
