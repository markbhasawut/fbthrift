# Serialization

Start with [Serialization protocols and runtime APIs](protocols.md) for the
Binary, Compact, JSON, JSON5, C++, Java, and Python APIs. Rocket, RSocket,
Header, HTTP/2, and `fast_thrift` are documented separately as
[RPC transports and runtime stacks](../rpc-transports.md).

<!-- https://www.internalfb.com/intern/wiki/Thrift/Overview/Serialization/?noredirect -->

## Protocols

There are two compatibility models used by the standard serialization
protocols:

* Serialization by field id
   * Binary and Compact encode the numeric field id and value; the wire type is
     encoded explicitly or implied by the Compact type tag. The name is not
     included. Enum values are encoded as integers, not named constants.
   * The deprecated typed JSON protocol also addresses fields by numeric id and
     carries explicit Thrift type tags despite its textual representation.
* Serialization by field name
   * SimpleJSON and the normal JSON5 object form identify fields by their IDL
     names. Renaming a field is therefore a wire change for these formats.
   * These formats are schema-aware during deserialization because ordinary
     JSON does not carry the complete Thrift wire-type information.

*Caution: Never mix serialization by field id and serialization by field name within the same use case.*

Frozen2 is a separate layout-based storage format rather than either RPC
model. See [serialization protocols and runtime APIs](protocols.md) for the
complete protocol matrix and language-specific entry points.

## Qualifiers

For different qualifiers, the serialization behavior is slightly different:

* Unqualified field is always serialized.
* Optional field is only serialized when the field is set.
* Required field is always serialized. (**deprecated**)
* Terse field is only serialized when the field is not equal to the [intrinsic default value](../../idl/#intrinsic-default-value).

```
include "thrift/annotation/thrift.thrift"

struct ThriftStruct {
  1: string unqual_field; // unqualified
  2: optional string opt_field; // optional
  3: required string req_field; // required (deprecated)
  @thrift.TerseWrite
  4: terse_field; // terse
}
```

The representation of unqualified, optional, required, and terse fields in serialized data are identical.

:::caution
The removed `deprecated_terse_writes` cpp2 option globally changed unqualified
field serialization. Do not pass it to current compilers. Prefer the
per-field `@thrift.TerseWrite` annotation; migrate legacy
`@cpp.DeprecatedTerseWrite` annotations when possible.
:::

:::caution
In C++, due to historical reason, by using deprecated API (e.g. `value_unchecked()`), it is possible to change underlying value without setting the field. This field will not be serialized.
:::

## Class type

The serialized data for structs, unions, and exceptions are indistinguishable.

---

# Deserialization

## Protocols

When serialized data is deserialized into a struct object, the fields in the serialized data are *matched* to fields in the struct object:

* If serialized by id, fields with the same id are matched.
* If serialized by name, fields with the same name are matched.

The value of the field in the serialized data is assigned to the matching field in the struct object, thus

1. After deserialization, this field in the struct object will be *present* with that value.
2. Any unmatched fields in the serialized data are ignored.
3. Any matched fields with mismatched types in the serialized data are ignored.
4. For given field in struct object, if there is no matching fields in the serialized data, it remains untouched.

## Qualifiers

The terse qualifier affects the deserialization behavior. Unmatched terse fields in the struct will be set to the [intrinsic default value](../../idl/#intrinsic-default-value).

## Class type

Deserialization into an union object may fail when there is more than one match between the serialized data and the union object. Otherwise structs, unions, and exceptions have same behavior.
