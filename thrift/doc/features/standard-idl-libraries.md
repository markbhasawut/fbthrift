---
sidebar_position: 2
title: Standard IDL libraries
---

# Standard IDL libraries

fbthrift ships two compiler-matched IDL trees:

- `thrift/annotation` defines structured annotations used to control schema
  semantics and language code generation.
- `thrift/lib/thrift` defines shared runtime schemas such as type identity,
  Any, Patch, metadata, and schema representations.

Use repository-relative include names; a leading filesystem `/` is not part of
the IDL path:

```thrift
include "thrift/annotation/thrift.thrift"
include "thrift/annotation/cpp.thrift"
include "thrift/annotation/python.thrift"
include "thrift/lib/thrift/any.thrift"
include "thrift/lib/thrift/patch.thrift"
```

The include basename becomes the qualifier: `thrift.Uri`, `cpp.Adapter`,
`python.Adapter`, `any.Any`, and `patch.GeneratePatchNew`.

## Standard annotations

`thrift/annotation/thrift.thrift` contains language-neutral annotations such as
`@thrift.Uri`, `@thrift.Box`, and `@thrift.TerseWrite`.
`cpp.thrift` and `python.thrift` contain backend-specific annotations.

```thrift
include "thrift/annotation/thrift.thrift"
include "thrift/annotation/cpp.thrift"
include "thrift/annotation/python.thrift"

@thrift.Uri{value = "example.com/catalog/ItemId"}
@cpp.Adapter{name = "::project::ItemIdAdapter"}
@python.Adapter{
  name = "project.adapters.ItemIdAdapter",
  typeHint = "project.types.ItemId",
}
typedef i64 ItemId
```

`scope.thrift` defines annotations used to declare where another annotation is
legal. It is primarily for authors of structured-annotation libraries, not an
application feature toggle. `compat.thrift` supports legacy annotation
migrations. Treat `internal.thrift` as implementation detail rather than an OSS
application API.

Structured annotations are checked against their declared scopes and remain
part of the schema. Generator options such as `cpp2:any` or `python:no_metadata`
apply to an entire compiler invocation and are not schema metadata.

## Runtime schemas

The runtime IDLs are layered. Include the narrowest public schema needed by the
application and link the corresponding generated runtime library rather than
regenerating fbthrift's own standard types in every target.

| IDL family | Purpose | Principal CMake target |
| --- | --- | --- |
| `id.thrift`, `standard.thrift`, `type_rep.thrift` | field/type identifiers and wire-level type/protocol representations | `FBThrift::thrifttyperep` |
| `type.thrift`, `any.thrift`, `any_rep.thrift`, `any_patch*.thrift`, `patch.thrift` | Any values, runtime type APIs, and patch representations | `FBThrift::thrifttype` |
| `field_mask.thrift`, `patch_op.thrift`, protocol object APIs | masks, protocol values, and patch operations | `FBThrift::thriftprotocol` |
| `metadata.thrift`, `schema.thrift`, `ast.thrift`, `record.thrift`, `type_id.thrift`, `type_system.thrift`, `service_catalog.thrift` | schema/AST metadata and runtime registries | `FBThrift::thriftmetadata` |
| `dynamic.thrift` | dynamic values and schema-backed descriptors | `FBThrift::thrift_dynamic_value` |
| `RpcMetadata.thrift`, `RocketUpgrade.thrift` | RPC transport metadata and Rocket upgrade protocol | RPC-only targets such as `FBThrift::rpcmetadata` and `FBThrift::thriftcpp2` |

Some files are transitively included implementation detail. Public stability is
also constrained by annotations such as `@thrift.Experimental`; presence in
the source tree alone is not a compatibility guarantee.

## Any and generated Patch

Including `any.thrift` makes the standard `any.Any` type available. The C++
`any` generator option separately emits startup registration for URI-bearing
user types. Both are needed when generated `AnyRegistry` lookup is expected.

Patch generation is a two-step codegen workflow. The annotation marks eligible
types, while the CMake `patch` marker runs the companion generator:

```thrift
include "thrift/lib/thrift/any.thrift"
include "thrift/lib/thrift/patch.thrift"

package "example.com/catalog/patch"

@patch.GeneratePatchNew
struct Item {
  1: any.Any payload;
}
```

```cmake
thrift_library(
  "item"
  ""
  "cpp2"
  "any,patch"
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}"
  "project/catalog"
  THRIFT_INCLUDE_DIRECTORIES "${PROJECT_SOURCE_DIR}"
)
```

`ThriftLibrary.cmake` first invokes `cpp2_patch` to emit
`gen-patch/gen_patch_item.thrift`, its traits header, and patch instantiations.
It then compiles the companion IDL with `cpp2:any`, producing
`gen-cpp2/gen_patch_item_*`. Merely including `patch.thrift`, or passing
`cpp2:any` alone, does not create these generated patch classes.

## Include resolution and installation

The OSS compiler embeds `thrift/annotation`, `thrift/lib/thrift`, and
`thrift/conformance/if` as build-time resources. An installed `thrift1` can
therefore resolve those standard paths from any working directory. Include
search paths still win: a matching file supplied with `-I` overrides the
embedded copy, which is useful for source-tree development and controlled
toolchain tests.

The embedding step is a standalone C++ resource generator. It does not invoke
Thrift code generation and therefore cannot create a compiler bootstrap cycle.
The CMake install also copies the annotation IDLs into the include tree for
editors and downstream build systems that need physical source files.

## Static registration

`cpp2:any`, schema injection, and service catalogs use generated `_sinit.cpp`
translation units. Static libraries are symbol-selected, so a linker may drop a
registration-only object. Compile that source directly into the final binary or
whole-archive the smallest owning generated library. The latter is convenient
but increases link time and binary size in proportion to the archive.
