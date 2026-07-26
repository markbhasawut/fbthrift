# Facebook Thrift Compiler

This directory contains a Thrift compiler library and the driver program,
`thrift1`, that parses `.thrift` files and generates code in different
languages.

The complete OSS cpp2 option reference, generated-file contract, static-link
requirements, and CMake usage are documented in
[`../doc/languages/cpp/code-generation.md`](../doc/languages/cpp/code-generation.md).
The Python runtime matrix, `pyi`, `python_capi`, and `python_patch` companions,
option references, output contracts, and CMake integration are documented in
[`../doc/languages/python.md`](../doc/languages/python.md).
The modern, deprecated, and Android Lite Java generators and Maven reactor are
documented in
[`../doc/languages/java.md`](../doc/languages/java.md).
The registration-derived inventory of every generator, legacy name, output
directory, option family, and framework/template distinction is documented in
[`../doc/languages/generators.md`](../doc/languages/generators.md).

## Directory Layout

* `ast`: abstract syntax tree
* `codemod`: codemods for Thrift code
* `detail`: implementation details shared between compiler phases
* `generate`: code generators for target languages
* `parse`: lexer and parser
* `sema`: semantic analyzer
* `test`: compiler tests
* `whisker`: templating engine used in generators
