---
sidebar_position: 1
title: Compiler generator catalog
---

# Compiler generator catalog

This catalog is derived from `THRIFT_REGISTER_GENERATOR` registrations and the
public alias table in `t_generator.cc`. It distinguishes compiler backends from
template families and generator framework classes.

Use the help emitted by the exact compiler binary in the build:

```sh
thrift1 --help
thrift1 --gen 'GENERATOR[:OPTION[,...]]' -I INCLUDE_ROOT FILE
```

`-o DIR` writes below a generator-specific `gen-*` directory. `-out DIR`
writes directly below `DIR` and suppresses that extra directory. Build rules
must declare the path form they actually invoke.

## Registered generators

| Public name | Legacy registered name | Default output | Contract and options |
| --- | --- | --- | --- |
| `android_lite` | `android` | `gen-android` | Constrained Java types for `thrift/lib/android_lite`; uses `namespace android`; no options. |
| `ast` | same | `gen-ast/<program>.ast` | Serialized schema AST. Required `protocol=json\|debug\|compact\|binary`; flags `include_generated`, `source_ranges`, `no_backcompat`, `use_hash`, and `root_program_only`. The last option requires `use_hash`. `ast` is an accepted compatibility marker. |
| `cocoa` | same | `gen-cocoa` | Legacy Objective-C types/RPC. Options: `import_path=<path>`, `log_unexpected`, `nullability`, `validate_required`, and `simple_value_equality`. |
| `cpp`, `cpp2` | `mstch_cpp2` | `gen-cpp2` or `gen-py3cpp` | Modern C++ types/RPC. See [C++ code generation](cpp/code-generation.md) for every option, file, link dependency, and static-initializer rule. |
| `cpp2_patch` | same | `gen-patch` | C++ patch companion IDL and traits. Required `source_include=<include/path.thrift>`. This is normally orchestrated by the CMake `patch` marker. |
| `csharp_EXPERIMENTAL` | same | `gen-csharp/<program>.cs` | Experimental C# data types/codecs; no RPC and no options. |
| `go` | `mstch_go` | `gen-go` | Go 1.26 types/RPC using `namespace go`. Options: `package_prefix=IMPORT_PATH`, `gen_metadata=true\|false`, and `use_reflect_codec=true\|false`. See [Go code generation and runtime](go.md). |
| `hack` | same | `gen-hack` | Hack types/RPC. Active options are listed below. |
| `java` | `mstch_java` | `gen-java` | Modern Reactive Java using `namespace java.swift`. See [Java code generation](java.md). |
| `javadeprecated` | `java_deprecated` | `gen-javadeprecated` | Legacy synchronous Java using `namespace java`; no options. See [Java code generation](java.md). |
| `json` | same | `gen-json/<program>.json` | Legacy JSON representation of the IDL. Option: `annotate`. |
| `json_experimental` | same | `gen-json_experimental/<program>.json` | Experimental Whisker JSON schema output. Option: `include_prefix=<path>`. |
| `py` | same | `gen-py` | Legacy pure-Python runtime. See [Python code generation](python.md). |
| `py3` | `mstch_py3` | `gen-py3` | Cython/native `thrift.py3` runtime. See [Python code generation](python.md). |
| `pyi` | `mstch_pyi` | `gen-py` | Interface companion for `py`, not a runtime. See [Python code generation](python.md). |
| `python` | `mstch_python` | `gen-python` | Modern `thrift.python` runtime. See [Python code generation](python.md). |
| `python_capi` | `mstch_python_capi` | `gen-python-capi` | C++/Cython bridge between companion `python` and `cpp2` outputs. See [Python code generation](python.md). |
| `python_patch` | same | `gen-python-patch` | Patch companion for modern Python. Option: `use_mutable_types_for_patch`. |
| `rust` | `mstch_rust` | `gen-rust` | Rust types/RPC. The complete option names are listed below. |
| `starlark` | same | `gen-star/<program>.star` | Restricted Starlark schema/constants output; no RPC and no options. |
| `swift_EXPERIMENTAL` | same | `gen-swift/<program>.swift` | Experimental Swift data types/codecs; no RPC and no options. |
| `typescript` | same | `<output>/<program>.ts` | Experimental TypeScript schematization primitives; no RPC and no options. This generator currently has no `gen-typescript` subdirectory. |

`cpp` and `cpp2` are two public names for one backend, so requesting both for
the same IDL would claim identical output files.

## Complete option-name inventory

Detailed C++, Python, Java, Go, and Rust descriptions are embedded in
`thrift1 --help`. See [Go code generation and runtime](go.md) for Go option,
module, protocol, and validation details. This section records the
cross-generator inventory and options on older generators whose help was
historically incomplete.

### Hack

The options read by the current Hack generator are:

- `json`, `server`, `stricttypes`, `arraysets`, `nonullables`,
  `frommap_construct`, `shapes`, `shape_arraykeys`,
  `shapes_allow_unknown_fields`;
- `array_migration`, `legacy_arrays`, `hack_collections`,
  `nullable_everything`, `const_collections`;
- `enum_extratype`, `enum_transparenttype`, `soft_attribute`;
- `strict_unions`, `protected_unions`, `legacy_default_values`,
  `legacy_union_json_serialization`;
- `mangledsvcs`, `typedef`, `server_stream`, `skip_constants`, and
  `split_types`;
- internal compatibility switches `__service_metadata_full_name` and
  `__union_logger_rollout`.

`mangledsvcs` accepts an explicit boolean value. `legacy_arrays` implies
`arraysets`; `const_collections` implies `hack_collections`; incompatible
collection combinations are rejected. The old help entries `rest` and
`structtrait` are not read by the current generator and must not be relied on.

### Rust

The Rust generator recognizes:

- flags `serde`, `skip_none_serialization`, `valuable`, `any`,
  `deprecated_default_enum_min_i32`, and
  `deprecated_optional_with_default_is_some`;
- values `include_prefix`, `types_include_srcs`, `clients_include_srcs`,
  `services_include_srcs`, `include_docs`, `cratemap`, `types_crate`,
  `clients_crate`, `crate_name`, `default_crate_name`,
  `types_split_count`, and `gen_metadata`.

`skip_none_serialization` requires `serde`. Crate-name and multifile options
are constrained by `namespace rust`; use `thrift1 --help` from the built
compiler for the exact accepted value form.

### Python

The Python-family inventory is:

- `py`: `asyncio`, `compare_t_fields_only`, `cpp_transport`, `future`, `json`,
  `new_style`, `slots`, `sort_keys`, `thrift_port`, `utf8strings`;
- `py3`: `auto_migrate`, `enable_container_pickling_DO_NOT_USE`,
  `gen_legacy_container_converters`, `include_prefix`, `inplace_migrate`,
  `intercompatible`, `no_stream`, `py3cpp`, `python_capi_converter`,
  `single_file_service`, `stack_arguments`;
- `pyi`: `asyncio`, `enable_pos_args`, plus the documented `py` compatibility
  no-ops;
- `python`: `auto_migrate`, `avoid_enum_metadata_circular_reference`,
  `base_library_package`, `disable_field_cache`, `does_not_have_py_deprecated`,
  `does_not_have_py_deprecated_asyncio`, `enable_isset_deprecated_unsafe`,
  `include_prefix`, `no_metadata`, `root_module_prefix`;
- `python_capi`: `include_prefix`, `root_module_prefix`,
  `enable_isset_deprecated_unsafe`, `marshal_python_capi`,
  `serialize_python_capi`;
- `python_patch`: `use_mutable_types_for_patch`.

See [Python code generation](python.md) for semantics and companion edges.

## Source and template directories

These files are generator infrastructure and are not valid `--gen` names:

| Source | Role |
| --- | --- |
| `t_generator` | Base interface, registry, aliases, documentation, and common option validation. |
| `t_concat_generator` | Legacy concatenating framework used by generators such as `py`, `cocoa`, `hack`, and legacy JSON/Java. |
| `t_whisker_generator` | Whisker-backed framework and prototype/context plumbing. |
| `build_templates.cc`, `templates_map.cc` | Embed template resources in the compiler binary. |

Likewise, a directory below `generate/templates` identifies a template prefix,
not necessarily a public generator. The `patch` templates serve companion
patch generation; `python_capi` and `pyi` are public companions; `cpp2`, `go`,
`java`, `py3`, `python`, and `rust` correspond to legacy `mstch_*` registered
names through public aliases.

## Build-system support boundary

The compiler can run every registered generator directly. The low-level
`thrift_generate()`/`thrift_library()` and fbcode_builder dispatcher currently
package `cpp`/`cpp2`, `py`, `py3`, and `python`. Other generators require an
explicit custom command and a target that declares the exact generated files.

This boundary is deliberate for companion and native-extension outputs:

- `py3` must not implicitly pull a cpp2 target into the compiler/runtime graph;
- `python_capi` must be owned by the final Cython extension that links cpp2;
- `pyi` shares `gen-py` with `py`, so one build edge must own each output;
- `cpp2_patch` is orchestrated by the low-level CMake patch pipeline.

See [CMake code generation](cmake.md) for standalone builds, installed targets,
stage-1/stage-2 compiler selection, and circular-dependency constraints.

## Tradeoffs

- Direct generators are easy to invoke but leave packaging, native compilation,
  and dependency edges to the caller.
- Higher-level CMake helpers declare file contracts and install behavior, but
  support only backends whose output and runtime ownership are modeled.
- Legacy implementation names preserve existing Buck/CMake fixtures. Public
  aliases improve the OSS CLI without changing generated code.
- Experimental generators have a narrow data-model surface and no stability
  guarantee; do not infer RPC/runtime support from the presence of templates.
