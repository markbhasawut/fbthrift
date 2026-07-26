---
sidebar_position: 1
title: C++ code generation options
---

# C++ code generation options

The modern C++ generator has two equivalent public names, `cpp` and `cpp2`;
`mstch_cpp2` is its legacy implementation name. There is no separate cpp1
backend in fbthrift.

```sh
thrift1 --gen 'cpp2[:OPTION[,...]]' -I . path/to/model.thrift
```

Quote the complete `--gen` argument when it contains braces, angle brackets,
or quotes. Options are comma-separated. Flag options are disabled by default.
Unknown options and invalid values are errors.

For example, this generates SimpleJSON and AnyRegistry support, splits the
large type implementation files, and writes includes rooted at `project/api`:

```sh
thrift1 --gen \
  'cpp2:json,any,types_cpp_splits=8,include_prefix=project/api' \
  -I . project/api/model.thrift
```

## Supported options

### Registration and serialization

| Option | Effect and integration requirements |
| --- | --- |
| `any` | Registers URI-bearing structs, unions, and exceptions for Binary and Compact in `AnyRegistry::generated()`. With `json`, it also registers SimpleJSON. The generated `<module>_sinit.cpp` must survive static-library dead stripping. |
| `json` | Emits SimpleJSON reader/writer instantiations. This increases generated code size and compile time; use it only where SimpleJSON is consumed. |
| `tablebased` | Uses generated table-based serialization metadata. It is incompatible with structures annotated with `@cpp.PackIsset`. |
| `frozen` | Generates legacy Frozen/Frozen1 support. This capability is not actively maintained. |
| `frozen=packed` | As above, and packs generated structures at alignment 1. This saves padding but can impose unaligned-access costs and changes layout/ABI. |
| `frozen2` | Emits `<module>_layouts.h` and `<module>_layouts.cpp` for Frozen2. Compile and link the layout translation unit when layouts are used. Frozen2 is opt-in, not globally enabled, and not actively maintained. |

### Generated API

| Option | Effect and integration requirements |
| --- | --- |
| `no_getters_setters` | Suppresses deprecated generated `get_*` and `set_*` methods. Prefer field reference accessors such as `field()` and `field_ref()`. |
| `no_metadata` | Omits `<module>_metadata.cpp`. A minimal `<module>_metadata.h` is still emitted. Do not use this when a consumer needs legacy module metadata definitions. |
| `stack_arguments` | Changes generated server-handler arguments so complex values are passed by reference instead of moved through owning pointers. This is an ABI/API choice and must be consistent with handler implementations. The legacy per-method `cpp.stack_arguments=0` annotation opts out. |
| `sync_methods_return_try` | Emits deprecated `sync_complete_*` client methods returning `folly::Try<RpcResponseComplete<T>>` for eligible non-oneway, non-sink RPCs. |
| `deprecated_clear` | Makes generated clear operations assign standard defaults instead of intrinsic defaults. This exists for legacy behavioral compatibility. |
| `deprecated_enforce_required` | Rejects payloads that omit required fields during deserialization. Required fields and this mode are deprecated. |
| `deprecated_public_required_fields` | Makes required-field storage public and suppresses the corresponding unsuffixed reference accessors. This is unsafe legacy API compatibility. |

### Output structure and build scaling

| Option | Effect and integration requirements |
| --- | --- |
| `types_cpp_splits=<count>` | Replaces each unsplit type implementation with `<count>` numbered files for all four families: `_types`, `_types_binary`, `_types_compact`, and `_types_serialization`. The count must be positive and no greater than the number of structured types plus enums. Build rules must compile the split files instead of the unsplit names. |
| `client_cpp_splits={<service>:<count>[,...]}` | Replaces each named `<service>AsyncClient.cpp` with numbered `<service>.<id>.async_client_split.cpp` files. Each count must be positive and no greater than the service's method count. Every named service must exist. |
| `single_file_service` | Emits module-level `<module>_clients.cpp` and `<module>_handlers.cpp` instead of per-service implementation and process-map files. It is incompatible with `client_cpp_splits`. |
| `py3cpp` | Writes C++ output to `gen-py3cpp` instead of `gen-cpp2`. It does not generate Python bindings. Build output paths and include roots must use `gen-py3cpp`. |
| `include_prefix=<path>` | Changes the prefix in generated `#include` directives. It does not move output files. The compiler's output directory and the build's include root must still resolve `<path>/gen-cpp2/...` or `<path>/gen-py3cpp/...`. |
| `includes=<header>[:<header>...]` | Adds verbatim include operands to generated type, client, and handler headers. Include delimiters are required, for example `includes=<vector>:"project/support.h"`. |

For double-digit split counts, generated IDs are zero-padded. For example,
`types_cpp_splits=12` emits `_types.00.split.cpp` through
`_types.11.split.cpp`, plus the corresponding Binary, Compact, and
serialization files.

### Compatibility no-ops

These names remain accepted so existing build configurations do not fail, but
they do not change generated output:

- `reflection`: legacy Fatal `*_fatal*.h` generation was removed. Current
  inline C++ reflection metadata is always generated.
- `disable_custom_type_ordering_if_structure_has_uri`: its behavior is always
  enabled. Custom set/map types are not assumed orderable merely because the
  containing structure has a URI.
- `deprecated_private_fields_for_cpp_ref`: `cpp.Ref` storage is always private.
- `nimble`: the experimental Nimble code-generation path was removed.
- `service_cpp_splits={<service>:<count>[,...]}`: retained for old fixture and
  build compatibility, but it does not split current output. Use
  `client_cpp_splits` for AsyncClient translation units.
- `visitation`: legacy option-gated visitation generation was removed.
- `templates`: the modern C++ generator always uses its bundled templates. The
  marker remains accepted for older CMake and Buck-generated invocations.

Removed options such as `deprecated_terse_writes` are not compatibility
no-ops. Use the corresponding IDL annotations while migrating legacy schemas;
for terse writes, prefer `@thrift.TerseWrite`.

## Schema injection is not a cpp2 option

`schema` must not appear in the cpp2 option list. Schema injection is the
global compiler flag `--inject-schema-const`:

```sh
thrift1 --inject-schema-const --gen cpp2 -I . path/to/service.thrift
```

In the OSS full build, `thrift1_bootstrap` generates the runtime schema types.
The stage-2 `thrift1` then links those runtime types and can inject a compact
bundled schema. This dependency direction is intentional:

```text
thrift1_bootstrap -> generated schema runtime -> stage-2 thrift1
```

Using stage-2 schema injection while building the runtime that stage 2 itself
depends on would introduce a cycle. Runtime IDLs therefore use the bootstrap
compiler; only consumers which request schema injection use stage 2.

Schema registration also runs from `<module>_sinit.cpp`. If that file is put in
a static archive, normal symbol-driven linking can discard it because it is
referenced only for startup side effects. Compile it directly into the final
target, use a narrow object library, or whole-archive the smallest generated
library that owns it. Whole-archiving a monolithic generated library increases
link time and binary size substantially.

## Generated-file contract

Without split or single-file options, cpp2 emits these implementation groups:

- module files: `_constants.cpp`, `_data.cpp`, `_metadata.cpp`, `_sinit.cpp`,
  `_types.cpp`, `_types_binary.cpp`, `_types_compact.cpp`, and
  `_types_serialization.cpp`;
- per-service files: `<Service>.cpp`, `<Service>AsyncClient.cpp`, and Binary
  and Compact `<Service>_processmap_*.cpp` files;
- the corresponding headers and `.tcc` files.

Option-dependent differences are not additive in every case:

| Option | Files replaced or omitted |
| --- | --- |
| `no_metadata` | Omits `_metadata.cpp`. |
| `types_cpp_splits=N` | Replaces the four unsplit `_types*.cpp` files with `4 * N` split files. |
| `client_cpp_splits=...` | Replaces the selected `AsyncClient.cpp` files with split files. |
| `single_file_service` | Replaces all per-service source/header groups with module-level client/handler files. |
| `frozen2` | Adds `_layouts.h` and `_layouts.cpp`. |
| `py3cpp` | Changes the output directory to `gen-py3cpp`. |

Build systems must declare exactly the selected file set. Listing both split
and unsplit names, or treating generated files as merely optional byproducts,
causes stale incremental builds and clean-build failures.

## OSS CMake integration

The repository's `thrift_generate()` wrapper accepts the same cpp2 option
string and models all option-dependent filenames described above:

```cmake
thrift_generate(
  "catalog"                         # file name, without .thrift
  "CatalogService"                  # services declared by the IDL
  "cpp2"
  "json,any,types_cpp_splits=8"
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}"
  "project/api"                     # generated include prefix
  THRIFT_INCLUDE_DIRECTORIES "${PROJECT_SOURCE_DIR}"
  INJECT_SCHEMA                      # separate from cpp2 options
)
```

The services argument is part of the output contract. It must list every
service whose per-service files the target consumes. `include_prefix` is passed
by `thrift_generate()` from its positional argument; do not duplicate it in the
option string.

`thrift_generate()` also defines two CMake-only markers. They are removed
before invoking `thrift1` and are rejected if passed directly to `--gen cpp2`:

| Marker | Effect |
| --- | --- |
| `layouts` | With `frozen2`, compiles `_layouts.cpp` as part of the generated target. Without it, the source is declared only as a code-generation byproduct. |
| `patch` | Runs the cpp2 patch companion pipeline, then generates the resulting `gen_patch_<module>.thrift` with `cpp2:any`. |

`INJECT_SCHEMA` similarly maps to the global `--inject-schema-const` flag and
selects stage-2 `thrift1`; it is not serialized into the generator option list.

## Tradeoffs

- More type/client splits reduce peak compiler memory and improve parallelism,
  but increase scheduler, object-file, archive-index, and link overhead.
- `any`, injected schemas, and other startup registration rely on static
  initializers; retaining those objects costs link time and binary size.
- `json`, Frozen, and metadata features add generated code. Select features per
  IDL target rather than enabling them globally.
- ABI-shaping options (`frozen=packed`, `stack_arguments`, and
  `single_file_service`) require coordinated regeneration of producers,
  consumers, and handler implementations.
