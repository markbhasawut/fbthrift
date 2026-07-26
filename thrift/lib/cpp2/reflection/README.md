# C++ reflection support

Current cpp2 code generation emits inline reflection metadata as part of the
ordinary generated type headers. No generator option is required.

The legacy Fatal static-reflection generator, which emitted
`<module>_fatal.h`, `<module>_fatal_types.h`, and `<module>_fatal_all.h`, has
been removed. The `reflection` cpp2 option remains accepted as a no-op for
build-configuration compatibility; it does not emit those headers.

The headers in this directory remain for source compatibility with code that
uses the reflection runtime and with previously generated sources. New build
rules must not declare the removed `*_fatal*.h` files as outputs.

See the [cpp2 code-generation option reference](../../../doc/languages/cpp/code-generation.md)
for the current option and generated-file contracts.
