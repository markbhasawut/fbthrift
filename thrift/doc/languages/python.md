---
sidebar_position: 2
title: Python code generation options
---

# Python code generation options

fbthrift has three Python backends. They are not aliases:

| Generator | Runtime | Output | Integration model |
| --- | --- | --- | --- |
| `py` | legacy `thrift.py` | `gen-py` | Pure Python modules. |
| `py3` | `thrift.py3` | `gen-py3` | Cython sources plus C++ wrapper glue; requires separately generated cpp2 types. |
| `python` | `thrift.python` | `gen-python` | Pure Python generated modules over the native `thrift.python` runtime. |

`mstch_py3` and `mstch_python` are legacy implementation names. Prefer the
public `py3` and `python` names:

```sh
thrift1 --gen 'py[:OPTION[,...]]' FILE
thrift1 --gen 'py3[:OPTION[,...]]' FILE
thrift1 --gen 'python[:OPTION[,...]]' FILE
```

Options are comma-separated. Unknown names and invalid flag/value forms are
errors. Output paths follow the IDL namespaces: `py` uses `namespace py` (or
`namespace py.asyncio` with `asyncio`), while `py3` and `python` use
`namespace py3`.

## `py`: legacy pure-Python backend

| Option | Effect |
| --- | --- |
| `asyncio` | Generates asyncio clients/processors and uses `namespace py.asyncio` when present. Incompatible with `cpp_transport`. |
| `compare_t_fields_only` | Compares declared Thrift fields instead of the complete instance dictionary, changing equality and ordering semantics. |
| `cpp_transport` | Generates integration with the legacy C++ transport bridge. Incompatible with `asyncio`. |
| `future` | Generates `concurrent.futures` service interfaces and processors. |
| `json` | Generates `readFromJson` helpers. |
| `slots` | Stores fields in `__slots__`, reducing per-instance memory while preventing arbitrary attributes. |
| `sort_keys` | Sorts maps and sets before serialization for deterministic output at an O(n log n) CPU cost. |
| `thrift_port=<port>` | Changes the default port in remote-client scripts from 9090. |
| `utf8strings` | Decodes Thrift strings as UTF-8 text; Python 3 code enables this behavior regardless. |
| `new_style` | Compatibility no-op; old-style class generation was removed. |

The module directory contains `__init__.py`, `ttypes.py`, `constants.py`, and
one `<Service>.py` file per declared service.

## `py3`: Cython backend

| Option | Effect and integration requirement |
| --- | --- |
| `auto_migrate` | Generates migration shims exposing `thrift.python`-compatible Python types. |
| `inplace_migrate` | Wraps `thrift.python` structures and adds `types_inplace_FBTHRIFT_ONLY_DO_NOT_USE.py`. |
| `gen_legacy_container_converters` | Generates legacy container-conversion paths for migration. |
| `no_stream` | Suppresses streaming RPC bindings when the required C++ coroutine support is unavailable. |
| `py3cpp` | References companion C++ output in `gen-py3cpp`; invoke `cpp2:py3cpp` separately. |
| `python_capi_converter` | Generates conversion hooks for the `thrift.python` C API. |
| `single_file_service` | Emits the fixed module-level service artifact set even when the IDL has no services. |
| `stack_arguments` | Matches cpp2 stack-argument handler signatures; use the same setting for companion C++ codegen. |
| `include_prefix=<path>` | Changes generated C++ include operands without moving `gen-py3`. |
| `enable_container_pickling_DO_NOT_USE` | Emits the legacy package initializer used by internal container-pickling integration. Avoid for new OSS code. |
| `intercompatible` | Compatibility no-op; the old template property was removed. |

`py3` emits `.py`, `.pyi`, `.pyx`, `.pxd`, C++ wrapper headers, and wrapper
translation units. Cython still must compile the `.pyx` files into extension
modules. The generator only references cpp2 headers; it does not generate or
link them.

Keep companion generation explicit:

```sh
thrift1 --gen 'cpp2:py3cpp,stack_arguments' api.thrift
thrift1 --gen 'py3:py3cpp,stack_arguments' api.thrift
```

This explicit edge prevents a generated py3 target from pulling stage-2
`thrift1` back into the runtime libraries used to build that compiler.

## `python`: modern Python backend

| Option | Effect |
| --- | --- |
| `auto_migrate` | Enables compatibility hooks for py3-to-python migration. |
| `avoid_enum_metadata_circular_reference` | Resolves enum metadata lazily to avoid circular module imports. |
| `base_library_package=<module>` | Overrides the runtime import package; default `thrift.python`. |
| `disable_field_cache` | Disables field-value caching globally, trading retained memory for repeated conversions. |
| `does_not_have_py_deprecated` | Omits migration imports for legacy `thrift.py`. |
| `does_not_have_py_deprecated_asyncio` | Omits migration imports for legacy asyncio modules. |
| `enable_isset_deprecated_unsafe[=1]` | Tracks legacy isset bits for eligible structures and disables unsafe tuple fast comparisons. |
| `include_prefix=<path>` | Changes the source include prefix recorded for integration code without moving output. |
| `no_metadata` | Omits `thrift_metadata.py` and metadata integration in generated types/enums. |
| `root_module_prefix=<module>` | Prepends an import-module prefix without changing the output filesystem path. |

The base output includes immutable, mutable, and abstract type modules, enum
and reflection modules, stubs, and `thrift_uris.txt`. Service IDLs additionally
emit client, service, mutable client/service, and service-reflection modules.
`python` uses PEP 420 namespace packages and therefore does not emit
`__init__.py`.

## OSS CMake integration

`thrift_generate()` supports `cpp`, `cpp2`, `py`, `py3`, and `python` and
declares a backend-specific output set. For Python-family targets,
`NAMESPACE` must match the effective IDL namespace whenever it is non-empty:

```cmake
thrift_generate(
  "catalog"
  "CatalogService"
  "python"
  "no_metadata"
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}"
  "project/catalog"
  NAMESPACE "project.catalog"
  THRIFT_INCLUDE_DIRECTORIES "${PROJECT_SOURCE_DIR}"
)
```

For `py3`, generate the companion `cpp2` target separately and add only the
dependency/link edges required by the Cython extension target. The helper does
not infer such an edge. This keeps the bootstrap/runtime/stage-2 compiler graph
acyclic and avoids pulling unrelated native libraries into pure-Python targets.

## Tradeoffs

- `py` is the smallest pure-Python integration but targets the deprecated
  runtime.
- `py3` provides native/Cython performance but has the largest compile and link
  surface and requires ABI-consistent cpp2 options.
- `python` keeps generated code pure Python while relying on a native runtime;
  field caching trades memory for conversion CPU.
- Migration options intentionally increase generated surface area. Enable them
  per module and remove them after the runtime transition.
