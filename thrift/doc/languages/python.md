---
sidebar_position: 2
title: Python code generation options
---

# Python code generation options

fbthrift has three Python runtime backends and three companion generators. They
are separate compiler invocations, not aliases:

| Generator | Runtime or role | Output | Integration model |
| --- | --- | --- | --- |
| `py` | legacy `thrift.py` | `gen-py` | Pure Python runtime modules. |
| `py3` | `thrift.py3` | `gen-py3` | Cython sources plus C++ wrapper glue; requires separately generated cpp2 types. |
| `python` | `thrift.python` | `gen-python` | Pure Python generated modules over the native `thrift.python` runtime. |
| `pyi` | companion for `py` | `gen-py` | PEP 484 interfaces for legacy `py` modules; no runtime implementation. |
| `python_capi` | companion for `python` + `cpp2` | `gen-python-capi` | C++ and Cython conversion bridge between modern Python and native cpp2 objects. |
| `python_patch` | companion for `python` | `gen-python-patch` | Python patch classes generated from patch-aware IDLs. |

`mstch_py3`, `mstch_pyi`, `mstch_python`, and `mstch_python_capi` are legacy
implementation names. Prefer the public names:

```sh
thrift1 --gen 'py[:OPTION[,...]]' FILE
thrift1 --gen 'py3[:OPTION[,...]]' FILE
thrift1 --gen 'python[:OPTION[,...]]' FILE
thrift1 --gen 'pyi[:OPTION[,...]]' FILE
thrift1 --gen 'python_capi[:OPTION[,...]]' FILE
thrift1 --gen 'python_patch[:OPTION[,...]]' FILE
```

Options are comma-separated. Unknown names and invalid flag/value forms are
errors. Output paths follow the IDL namespaces: `py` uses `namespace py` (or
`namespace py.asyncio` with `asyncio`), while `py3` and `python` use
`namespace py3`.

## Protocols and transports

Modern `thrift.python` standalone serialization supports Binary, Compact,
deprecated typed JSON, SimpleJSON, and JSON5. The public enum deliberately
calls SimpleJSON `Protocol.JSON`; the old typed encoding is
`Protocol.DEPRECATED_VERBOSE_JSON`. Modern generated RPC accepts Binary or
Compact and defaults to Compact.

Legacy `thrift.py` exposes `TBinaryProtocol`, `TCompactProtocol`,
`TJSONProtocol`, `TSimpleJSONProtocol`, and `THeaderProtocol`. The last one is
a framing/negotiation wrapper, not another value encoding. See
[serialization protocols and runtime APIs](../features/serialization/protocols.md)
for exact IDs and examples, and
[RPC transports and runtime stacks](../features/rpc-transports.md) for the
Rocket/Header boundary.

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

## `pyi`: legacy Python interface companion

`pyi` emits interfaces for the modules generated by `py`; it is not the type
stub output of `py3` or `python`. Both invocations write below `gen-py` and must
use the same effective `namespace py` or `namespace py.asyncio`.

```sh
thrift1 --gen 'py:asyncio,json' api.thrift
thrift1 --gen 'pyi:asyncio,json' api.thrift
```

The output consists of namespace `__init__.pyi` files, `constants.pyi`,
`ttypes.pyi`, and one `<Service>.pyi` per declared service.

| Option | Effect |
| --- | --- |
| `asyncio` | Uses `namespace py.asyncio`, when present, instead of `namespace py`. Match the `py` invocation. |
| `enable_pos_args` | Emits positional parameters in service method signatures. Without it, service arguments are keyword-only. |
| `compare_t_fields_only`, `cpp_transport`, `future`, `json`, `new_style`, `slots`, `sort_keys`, `thrift_port=<port>`, `utf8strings` | Accepted compatibility no-ops so a build rule can reuse the companion `py` option list. |

The stub generator omits interactions and sink/stream methods because the
legacy `py` runtime does not support those interfaces. A successful `pyi`
invocation therefore does not imply that every service method has a generated
stub.

## `python_capi`: cpp2-to-modern-Python bridge

`python_capi` is not a fourth Python runtime backend. It emits a conversion
layer for the types generated by both `cpp2` and `python` from the same IDL.
The consuming build must:

1. generate cpp2 types;
2. generate modern Python types;
3. generate the C API bridge;
4. compile the bridge's C++ source and Cython `.pyx` sources into an extension
   linked with `thrift/lib/python/capi` and the companion cpp2 target.

For a program `api.thrift` with `namespace py3 project.catalog`, the bridge
emits:

- `gen-python-capi/api/thrift_types_capi.{h,cpp}`;
- `gen-python-capi/project/catalog/api/thrift_types_capi.{pxd,pyx}`;
- `gen-python-capi/project/catalog/api/thrift_converter.{pxd,pyx}`.

Keep all path- and layout-affecting options consistent:

```sh
thrift1 --gen 'cpp2:include_prefix=project/idl' project/idl/api.thrift
thrift1 --gen \
  'python:include_prefix=project/idl,root_module_prefix=company' \
  project/idl/api.thrift
thrift1 --gen \
  'python_capi:include_prefix=project/idl,root_module_prefix=company' \
  project/idl/api.thrift
```

| Option | Effect and matching requirement |
| --- | --- |
| `include_prefix=<path>` | Changes C++ include operands. Match the companion cpp2 layout and build include roots. |
| `root_module_prefix=<module>` | Changes generated Python imports. Match the `python` invocation. |
| `enable_isset_deprecated_unsafe[=1]` | Matches the legacy isset tuple layout produced by `python`; use the same option on both invocations. |
| `marshal_python_capi[=1]` | Forces direct C API marshalling for eligible structured types. |
| `serialize_python_capi[=1]` | Forces the serialization fallback and takes precedence over `marshal_python_capi`. |

Direct marshalling avoids a protocol encode/decode round trip, but only
supports eligible native layouts. Serialization performs more allocation,
copies, and CPU work but covers layouts that cannot be converted directly.
The generator chooses direct marshalling by default for eligible structures.

Per type, include `thrift/annotation/python.thrift` and use
`@python.UseCAPI{}` to force direct marshalling or
`@python.UseCAPI{serialize = true}` to force serialization:

```thrift
include "thrift/annotation/python.thrift"

@python.UseCAPI{}
struct Direct {
  1: string value;
}

@python.UseCAPI{serialize = true}
struct Serialized {
  1: string value;
}
```

`@python.EnableUnsafeIssetInspection` changes the modern Python data-holder
tuple. When it is used, the bridge accounts for the layout automatically on
that type; the generator-wide `enable_isset_deprecated_unsafe` option applies
the legacy layout broadly and must match the `python` invocation.

The `py3:python_capi_converter` option is different: it adds modern-Python
conversion hooks to the `py3` output. It does not run the standalone
`python_capi` bridge generator.

## `python_patch`: modern Python patch companion

`python_patch` emits one
`gen-python-patch/<py3-namespace>/<program>/thrift_patch.py`. It consumes the
patch definitions synthesized from IDLs using the annotations in
`thrift/annotation/patch.thrift` and imports the separately generated modern
Python types.

```sh
thrift1 --gen python model.thrift
thrift1 --gen python_patch model.thrift
```

The `use_mutable_types_for_patch` option makes the generated patch classes
depend on `thrift_mutable_types` instead of immutable `thrift_types`. This
changes the Python object model consumed by the patch API; it is not a
performance-only switch.

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

`pyi`, `python_capi`, and `python_patch` are currently compiler-level companion
generators rather than packaging modes in `thrift_generate()` or
`add_fbthrift_library()`. Invoke them from explicit `add_custom_command()` rules
and make the final Python package or Cython extension own the dependencies.
This avoids creating an implicit `python -> cpp2 -> thrift1` edge in runtime
libraries. The [generator catalog](generators.md) records this support boundary
for every backend.

## Tradeoffs

- `py` is the smallest pure-Python integration but targets the deprecated
  runtime.
- `py3` provides native/Cython performance but has the largest compile and link
  surface and requires ABI-consistent cpp2 options.
- `python` keeps generated code pure Python while relying on a native runtime;
  field caching trades memory for conversion CPU.
- `pyi` adds static checking for legacy modules without runtime code, but it
  intentionally cannot describe unsupported stream, sink, or interaction APIs.
- `python_capi` can avoid serialization for eligible types at the cost of a
  native ABI/Cython build surface; the serialization fallback is broader but
  slower.
- `python_patch` adds a dependency layer over modern Python types; mutable and
  immutable patch modes are distinct object models.
- Migration options intentionally increase generated surface area. Enable them
  per module and remove them after the runtime transition.
