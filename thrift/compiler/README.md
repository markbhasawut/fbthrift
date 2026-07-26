# Facebook Thrift Compiler

This directory contains a Thrift compiler library and the driver program,
`thrift1`, that parses `.thrift` files and generates code in different
languages.

The complete OSS cpp2 option reference, generated-file contract, static-link
requirements, and CMake usage are documented in
[`../doc/languages/cpp/code-generation.md`](../doc/languages/cpp/code-generation.md).
The `py`, `py3`, and `python` runtime matrix, option references, output
contracts, and CMake integration are documented in
[`../doc/languages/python.md`](../doc/languages/python.md).

## Directory Layout

* `ast`: abstract syntax tree
* `codemod`: codemods for Thrift code
* `detail`: implementation details shared between compiler phases
* `generate`: code generators for target languages
* `parse`: lexer and parser
* `sema`: semantic analyzer
* `test`: compiler tests
* `whisker`: templating engine used in generators
