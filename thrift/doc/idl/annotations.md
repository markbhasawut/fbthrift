---
state: draft
---

# Annotations

## Structured Annotations

Structured annotations are structural constants attached to the named IDL entities, typically representing some metadata or altering the compiler behavior. They are specified via `@Annotation{key1=value1, key2=value2, ...}` syntax before the [Definitions](/idl/index.md#definitions). Each definition may have several annotations with no duplicates allowed. `@Annotation` can be used as a syntactic sugar for `@Annotation{}`.

### Grammar

```
StructuredAnnotations ::= NonEmptyStructuredAnnotationList | ""

NonEmptyStructuredAnnotationList ::=
    NonEmptyStructuredAnnotationList StructuredAnnotation
  | StructuredAnnotation

StructuredAnnotation ::= "@" ConstStruct | "@" ConstStructType
```

### Examples

Here's an example of various annotated entities.

```
struct FirstAnnotation {
  1: string name;
  2: i64 count = 1;
}

struct SecondAnnotation {
  2: i64 total = 0;
  @thrift.Box
  3: optional SecondAnnotation recurse;
  4: bool is_cool;
}

@FirstAnnotation{name="my_type"}
typedef string AnnotatedString

@FirstAnnotation{name="my_struct", count=3}
@SecondAnnotation
struct MyStruct {
  @SecondAnnotation{}
  5: AnnotatedString tag;
}

@FirstAnnotationexception
MyException {
  1: string message;
}

@SecondAnnotation{total=1, is_cool=true}
union MyUnion {
  1: i64 int_value;
  2: string string_value;
}

@SecondAnnotation{total=4, recurse=SecondAnnotation{total=5}}
service MyService {
  @SecondAnnotation
  i64 my_function(2: AnnotatedString param);
}

@FirstAnnotation{name="shiny"}
enum MyEnum {
  UNKNOWN = 0;
  @SecondAnnotation
  FIRST = 1;
}

@FirstAnnotation{name="my_hack_enum"}
const map<string, string> MyConst = {
  "ENUMERATOR": "value",
}
```

## Unstructured Annotations (Deprecated)

Unstructured annotations are key-value pairs where the key is an identifier and the value is either a string or an identifier. Both identifiers are interpreted as strings. These annotations may be applied to [definitions](/idl/index.md#definitions) in the Thrift language, following that construct.

```
Annotations ::=
  "(" AnnotationList ["," | ";"] ")" |
  "(" ")"

AnnotationList ::=
  AnnotationList ("," | ";") Annotation |
  Annotation

Annotation ::=
  Name [ "=" ( Name | StringLiteral ) ]
```

If a value is not present, then the default value of `"1"` (a string) is assumed.

There are two equivalent ways to apply them, with the former being preferred:
```thrift
struct S {
  @thrift.DeprecatedUnvalidatedAnnotations{items = {
    "perl.name", "foo_"
  }}
  1: i32 foo;
  2: i32 bar (perl.name = "bar_")
}
```

:::caution
Unrecognized unstructured annotations are *silently ignored*. So, for example, passing `cpp2.adapter` does absolutely nothing (the correct syntax is `cpp.adapter`). This is not a problem for structured annotation.
:::

## Standard Annotations

The standard Thrift annotation library is defined in `thrift/annotation`.
Include files by their repository-relative paths; the basename is the qualifier
used at annotation sites:

```thrift
include "thrift/annotation/thrift.thrift"
include "thrift/annotation/cpp.thrift"
include "thrift/annotation/python.thrift"

@thrift.Uri{value = "example.com/project/Record"}
struct Record {
  @cpp.Adapter{name = "::project::TimestampAdapter"}
  @python.Adapter{
    name = "project.adapters.TimestampAdapter",
    typeHint = "datetime.datetime",
  }
  1: i64 timestamp;
}
```

The installed OSS compiler embeds this tree, so these includes resolve without
an implicit source checkout. A file found through `-I` overrides the embedded
copy. This keeps compiler and standard annotations version-matched while still
supporting source-tree development.

`scope.thrift` is for annotation-library authors: it declares which IDL nodes
may carry another structured annotation. `thrift.thrift` is language-neutral;
`cpp.thrift` and `python.thrift` affect their corresponding backends.
`compat.thrift` supports legacy migrations, while `internal.thrift` is not a
public application annotation API.

See [standard IDL libraries](../features/standard-idl-libraries.md) for runtime
schemas under `thrift/lib/thrift`, Any/Patch usage, and CMake integration.

### Scope Annotations

```thrift file=annotation/scope.thrift start=start
```

### Thrift annotations

Thrift annotations provide language-agnostic functionality.

```thrift file=annotation/thrift.thrift start=start
```


### C++ annotations

<details>
  <summary>cpp.thrift</summary>

  ```thrift file=annotation/cpp.thrift start=start
  ```

</details>

#### Deprecated functionality

##### cpp.noncopyable and cpp.noncomparable

* Where to use: struct/union/exception
* Value: none
* Example:

```
typedef binary (cpp.type = "folly::IOBuf") IOBuf

union NonCopyableUnion {
  1: i32 a,
  2: IOBuf buf,
} (cpp.noncopyable, cpp.noncomparable)
```

This is to avoid generating copy constructor/copy assignment constructor and overridden equality operator for types. You rarely need to use them.

##### cpp.declare_hash and cpp.declare_equal_to

* Where to use: struct
* Value: none

Adds a `std::hash` and `std::equal_to` specialization for the Thrift struct. You need to provide your own hash and equal_to implementation. Use this annotation if you want to use your Thrift struct as the key type of `std::unordered_map` or other unordered associative containers.

#### Annotations for C++ Allocator Awareness

Example C++:

```
using MyAlloc = std::scoped_allocator_adaptor<folly::SysArenaAllocator<char>>;
template <class T> using MyVector = std::vector<T, MyAlloc>;
template <class K, class V> using MyMap = std::map<K, V, std::less<K>, MyAlloc>;
```

Thrift IDL usage example (assuming `cpp_include` the above):

```
struct aa_struct {
  1: list<i32> (cpp.use_allocator, cpp.template = "MyVector") aa_list;
  2: map<i32, i32> (cpp.use_allocator, cpp.template = "MyMap") aa_map;
  3: set<i32> not_aa_set;
} (cpp.allocator = "MyAlloc", cpp.allocator_via = "aa_list")
```

##### cpp.allocator

* Where to use: struct
* Value: string name of a type conforming to the [C++ named requirement "Allocator"](https://en.cppreference.com/w/cpp/named_req/Allocator)

Declares that this is an allocator-aware structure, using the specified C++ allocator type. When this annotation is present, the Thrift compiler will generate additional code sufficient to meet the [C++ named requirement "AllocatorAwareContainer":](https://en.cppreference.com/w/cpp/named_req/AllocatorAwareContainer)

* `allocator_type` typedef
* `get_allocator()` function
* Three "allocator-extended" constructors

##### cpp.use_allocator

* Where to use: field
* Value: none

Indicates that the structure's allocator should be passed down to this field at construction time.

##### cpp.allocator_via

* Where to use: struct
* Value: string with a name of a field in this struct

This is a structure size optimization. The naive implementation of `get_allocator()` requires an additional data member to “remember” the allocator. With `cpp.allocator_via`, we instead delegate this responsibility to one of the allocator-aware fields.

### Hack annotations

<details>
  <summary>hack.thrift</summary>

  ```thrift file=annotation/hack.thrift start=start
  ```

</details>

### Python annotations

<details>
  <summary>python.thrift</summary>

  ```thrift file=annotation/python.thrift start=start
  ```

</details>

See [Adapters](/features/adapters.md) for more detail about `@python.Adapter`.

### Rust annotations

Rust annotations are defined in `thrift/annotation/rust.thrift`.

### Go annotations

<details>
  <summary>go.thrift</summary>

  ```thrift file=annotation/go.thrift start=start
  ```

</details>

## Consumption in languages

### C++

Structured annotations are accessible through generated metadata and the
`get_field_metadata` C++ API. Codegen with `no_metadata` deliberately omits the
module metadata translation unit.

### Hack

The annotations are exposed on structs, exceptions, unions, services and constants via `getAllStructuredAnnotations` methods. Their return values are structured depending on the entity type. The leaf nodes of this data are annotations' key-value pairs. The key is the annotation struct's Hack name (with a namespace if applicable) and the value is the Thrift object with the annotation value.

Structs, exceptions and unions include annotations for themselves and for both fields and types (annotations from typedefs are propagated there). The getter method is defined in the corresponding structs, exceptions and unions.

Services include annotations for themselves and functions. The getter method is defined in a new `<SERVICE>StaticMetadata` class, which implements `\IThriftServiceStaticMetadata`. Services have many classes generated for them, so I didn't want to duplicate the annotations on every one.

Constants include annotations just for themselves. The getter method is defined on the existing `<MODULE>_CONSTANTS` class, which now implements `\IThriftConstants`.

### Python

Structured annotations are accessible through generated Python metadata for
structs, exceptions, unions, fields, services, and enums. The modern `python`
generator's `no_metadata` option deliberately omits that module.

You can view an example for how to use these [here](https://github.com/facebook/fbthrift/tree/main/thrift/lib/py3/test/metadata.py?commit=80443af2713dbfa63ccd487d6d5f7d0850b2f022&lines=192).

### Notable annotations that don't exist

- ~~`cpp.coroutine`~~ coroutine stubs are always generated in C++
- ~~`code`~~ this never did anything
- ~~`deprecated`~~ this never did anything
