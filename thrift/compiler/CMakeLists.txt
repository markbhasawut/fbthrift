# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Set the compiler directory.
set(COMPILER_DIR ${CMAKE_CURRENT_BINARY_DIR})

# CMake is the OSS build. Apply this to every compiler target so generators,
# codemods, diagnostics, and their tests agree on which internal-only text is
# available.
add_compile_definitions(THRIFT_OSS)

# Override the default install path for `make install` step.
set(CMAKE_INSTALL_PREFIX ${THRIFT_SOURCE_DIR})

check_cxx_source_compiles("
  #include <type_traits>
  #if _GLIBCXX_RELEASE
  int main() {}
  #endif"
  FBTHRIFT_COMPILER_STDLIB_LIBSTDCXX
)
check_cxx_source_compiles("
  #include <type_traits>
  #if _GLIBCXX_RELEASE >= 9
  int main() {}
  #endif"
  FBTHRIFT_COMPILER_STDLIB_LIBSTDCXX_GE_9
)
check_cxx_source_compiles("
  #include <type_traits>
  #if _LIBCPP_VERSION
  int main() {}
  #endif"
  FBTHRIFT_COMPILER_STDLIB_LIBCXX
)
check_cxx_source_compiles("
  #include <type_traits>
  #if _LIBCPP_VERSION >= 9000
  int main() {}
  #endif"
  FBTHRIFT_COMPILER_STDLIB_LIBCXX_GE_9
)

if (FBTHRIFT_COMPILER_STDLIB_LIBSTDCXX AND NOT FBTHRIFT_COMPILER_STDLIB_LIBSTDCXX_GE_9)
  list (APPEND FBTHRIFT_COMPILER_LINK_CXXFS stdc++fs)
endif()
if (FBTHRIFT_COMPILER_STDLIB_LIBCXX AND NOT FBTHRIFT_COMPILER_STDLIB_LIBCXX_GE_9)
  list (APPEND FBTHRIFT_COMPILER_LINK_CXXFS c++fs)
endif ()

# The Thrift AST library.
add_library(
  compiler_ast

  ast/t_primitive_type.cc
  ast/t_const.cc
  ast/t_const_value.cc
  ast/t_container.cc
  ast/t_enum.cc
  ast/t_exception.cc
  ast/t_field.cc
  ast/t_function.cc
  ast/t_interaction.cc
  ast/t_interface.cc
  ast/t_list.cc
  ast/t_named.cc
  ast/t_node.cc
  ast/t_map.cc
  ast/t_package.cc
  ast/t_program.cc
  ast/t_global_scope.cc
  ast/t_set.cc
  ast/t_structured.cc
  ast/t_type.cc
  ast/t_typedef.cc
  ast/t_union.cc
  ast/scope_identifier.cc
  ast/thrift_ast_debug_tree_utils.cc
)
target_link_libraries(
  compiler_ast
  ${OPENSSL_LIBRARIES}
  Boost::boost
  fmt::fmt
  Folly::folly
)

# The base compiler infrastructure library
add_library(
  compiler_base
  STATIC

  detail/system.cc
  detail/pluggable_functions.cc
  diagnostic.cc
  source_location.cc
)
target_link_libraries(
  compiler_base
  fmt::fmt
  Boost::boost
  Folly::folly
  common
  ${FBTHRIFT_COMPILER_LINK_CXXFS}
)

# Embed the standard Thrift IDLs as compiler resources. This executable is
# deliberately independent of thrift1 and all generated runtime libraries, so
# the resource edge cannot participate in the bootstrap -> runtime -> stage-2
# compiler dependency chain.
add_executable(
  compiler_generate_bundled_thrift
  detail/generate_bundled_thrift.cc
)
target_link_libraries(
  compiler_generate_bundled_thrift
  PRIVATE
    fmt::fmt
    ${FBTHRIFT_COMPILER_LINK_CXXFS}
)

function(add_bundled_thrift_source output_variable key_prefix function_name source_directory)
  file(
    GLOB_RECURSE bundled_thrift_inputs
    CONFIGURE_DEPENDS
    "${source_directory}/*.thrift"
  )
  set(output_file "${CMAKE_CURRENT_BINARY_DIR}/${function_name}.cpp")
  add_custom_command(
    OUTPUT "${output_file}"
    COMMAND
      compiler_generate_bundled_thrift
      "${key_prefix}"
      "${function_name}"
      "${source_directory}"
      "${output_file}"
    DEPENDS
      compiler_generate_bundled_thrift
      ${bundled_thrift_inputs}
    COMMENT "Embedding ${key_prefix}/*.thrift in the Thrift compiler"
    VERBATIM
  )
  set(${output_variable} "${output_file}" PARENT_SCOPE)
endfunction()

add_bundled_thrift_source(
  BUNDLED_ANNOTATION_SOURCE
  "thrift/annotation"
  bundled_annotation_files
  "${THRIFT_SOURCE_DIR}/thrift/annotation"
)
add_bundled_thrift_source(
  BUNDLED_LIB_THRIFT_SOURCE
  "thrift/lib/thrift"
  bundled_lib_thrift_files
  "${THRIFT_SOURCE_DIR}/thrift/lib/thrift"
)
add_bundled_thrift_source(
  BUNDLED_CONFORMANCE_IF_SOURCE
  "thrift/conformance/if"
  bundled_conformance_if_files
  "${THRIFT_SOURCE_DIR}/thrift/conformance/if"
)

# The base Thrift compiler library.
add_library(
  compiler_lib
  STATIC

  ${BUNDLED_ANNOTATION_SOURCE}
  ${BUNDLED_LIB_THRIFT_SOURCE}
  ${BUNDLED_CONFORMANCE_IF_SOURCE}
  parse/lexer.cc
  parse/lexer.h
  parse/parser.cc
  parse/parser.h
  parse/parse_ast.cc
  parse/parse_ast.h
  parse/token.cc
  parse/token.h
  sema/ast_uri_utils.cc
  sema/check_initializer.cc
  sema/check_map_keys.cc
  sema/explicit_include_validator.cc
  sema/scope_validator.cc
  sema/sema.cc
  sema/sema_context.cc
  sema/schematizer.cc
  sema/standard_validator.cc
  sema/resolution_mismatch.cc
)
target_link_libraries(
  compiler_lib
  compiler_base
  compiler_ast
  Boost::regex
  fmt::fmt
  Folly::folly
)

# The Thrift compiler library.
add_library(
  compiler

  generate/cpp/reference_type.cc
  generate/cpp/name_resolver.cc
  generate/cpp/util.cc
  generate/csharp/util.cc
  generate/go/util.cc
  generate/java/util.cc
  generate/python/util.cc
  generate/rust/util.cc
  generate/swift/util.cc
)
target_link_libraries(
  compiler
  compiler_ast
  compiler_base
  fmt::fmt
  Folly::folly
  ${FBTHRIFT_COMPILER_LINK_CXXFS}
)

add_library(
  whisker
  STATIC

  whisker/ast.cc
  whisker/dsl.cc
  whisker/detail/string.cc
  whisker/eval_context.cc
  whisker/lexer.cc
  whisker/object.cc
  whisker/parser.cc
  whisker/print_ast.cc
  whisker/render.cc
  whisker/standard_library.cc
  whisker/token.cc
)
target_link_libraries(
  whisker
  fmt::fmt
  Folly::folly
  compiler_base
)

add_subdirectory(generate)

# Force compiler_generators linking (compiler will optimize it out otherwise).
if (MSVC)
  set(GENERATE_LINKED compiler_generators) # MSVC WHOLEARCHIVE is set after exe.
elseif (APPLE)
  set(GENERATE_LINKED -Wl,-force_load compiler_generators)
else ()
  set(GENERATE_LINKED
      -Wl,--whole-archive compiler_generators -Wl,--no-whole-archive)
endif ()

# compiler.cc is shared by the bootstrap compiler, the final compiler, the
# codemods, and compiler tests. Keeping it in a library exposes parse_args()
# and compile_with_options() without duplicating its object or changing the
# bootstrap -> generated runtime -> final compiler dependency direction.
add_library(compiler_driver STATIC compiler.cc)
target_link_libraries(
  compiler_driver
  PUBLIC
    compiler_ast
    compiler_lib
    ${FBTHRIFT_COMPILER_LINK_CXXFS}
)

# Create the compiler used to generate the runtime types. A compiler-only build
# keeps the public thrift1 name because no second stage is available.
set(THRIFT1_BOOTSTRAP_TARGET thrift1)
if(build_all)
  set(THRIFT1_BOOTSTRAP_TARGET thrift1_bootstrap)
endif()
add_executable(
  ${THRIFT1_BOOTSTRAP_TARGET}
  main.cc
)
target_link_libraries(
  ${THRIFT1_BOOTSTRAP_TARGET}
  PRIVATE
    compiler_driver
    ${GENERATE_LINKED}
)
# Force compiler_generators linking (compiler will optimize it out otherwise).
if (MSVC)
  set_target_properties(
    ${THRIFT1_BOOTSTRAP_TARGET}
    PROPERTIES LINK_FLAGS "/WHOLEARCHIVE:compiler_generators"
  )
endif ()

if(build_all)
  if(MSVC)
    set(SCHEMA_GENERATE_LINKED compiler_schema_generators)
  elseif(APPLE)
    set(SCHEMA_GENERATE_LINKED -Wl,-force_load compiler_schema_generators)
  else()
    set(SCHEMA_GENERATE_LINKED
        -Wl,--whole-archive compiler_schema_generators -Wl,--no-whole-archive)
  endif()

  # The public compiler is the second stage. Its schema generator depends on
  # runtime types produced by thrift1_bootstrap, keeping the dependency graph
  # acyclic: bootstrap -> runtime -> thrift1.
  add_executable(
    thrift1
    main.cc
  )
  target_link_libraries(
    thrift1
    PRIVATE
      compiler_driver
      ${GENERATE_LINKED}
      ${SCHEMA_GENERATE_LINKED}
  )
  if(MSVC)
    set_target_properties(
      thrift1
      PROPERTIES LINK_FLAGS
        "/WHOLEARCHIVE:compiler_generators /WHOLEARCHIVE:compiler_schema_generators"
    )
  endif()
endif()

find_package(re2 CONFIG REQUIRED)
find_package(range-v3 CONFIG REQUIRED)

# Create the Thrift Formatter executable binary
add_executable(
  thrift-fmt
  formatter_main.cc
)
target_link_libraries(
  thrift-fmt
  compiler_ast
  compiler_base
  compiler_lib
  ${FBTHRIFT_COMPILER_LINK_CXXFS}
  ${GENERATE_LINKED}
)

# Build the infrastructure shared by the standalone codemod binaries.
add_library(
  compiler_codemod
  STATIC
  codemod/codemod.cc
  codemod/file_manager.cc
)
target_link_libraries(
  compiler_codemod
  compiler_driver
  compiler_ast
  compiler_base
  compiler_lib
  ${FBTHRIFT_COMPILER_LINK_CXXFS}
  ${GENERATE_LINKED}
)

# Each remaining codemod source has its own main(). They must be separate
# executables; combining them into one target creates a duplicate-main link.
set(THRIFT_CODEMOD_NAMES
  add_namespace_py3
  add_operational_annotations
  add_package
  annotate_allow_legacy_missing_uris
  annotate_allow_unsafe_non_sealed_key_type
  annotate_custom_default_optional_fields
  annotate_deprecated_terse_writes_fields
  annotate_hack_legacy_json_serialization
  annotate_non_optional_cpp_ref_fields
  annotate_required_fields
  cppref_to_structured
  migrate_php_namespace_to_hack_name_prefix
  relative_include
  remove_cpp_noexcept_move
  remove_duplicate_namespaces
  remove_function_param_qualifiers
  remove_php_namespace_if_hack_present
  remove_redundant_field_custom_default_values
  specify_implicit_field_id
  specify_implicit_func_param_id
  structure_annotations
)
set(THRIFT_CODEMOD_TARGETS)
foreach (codemod_name ${THRIFT_CODEMOD_NAMES})
  set(codemod_target "thrift-codemod-${codemod_name}")
  add_executable(
    ${codemod_target}
    "codemod/${codemod_name}.cc"
  )
  set_target_properties(
    ${codemod_target}
    PROPERTIES OUTPUT_NAME ${codemod_name}
  )
  target_link_libraries(
    ${codemod_target}
    PRIVATE compiler_codemod
  )
  if (codemod_name STREQUAL "add_package")
    target_link_libraries(${codemod_target} PRIVATE re2::re2)
  elseif (codemod_name STREQUAL "structure_annotations")
    target_link_libraries(${codemod_target} PRIVATE range-v3)
    if (APPLE)
      # range-v3's bundled meta library still emits libc++ forward
      # declarations that conflict with newer Xcode libc++ headers.
      target_compile_definitions(
        ${codemod_target} PRIVATE META_NO_STD_FORWARD_DECLARATIONS)
    endif ()
  endif ()
  list(APPEND THRIFT_CODEMOD_TARGETS ${codemod_target})
endforeach ()
add_custom_target(thrift-codemod ALL DEPENDS ${THRIFT_CODEMOD_TARGETS})

if (enable_tests)
  add_subdirectory(test)
endif ()

if (BUILD_SHARED_LIBS)
  # All but thrift1 since it's a binary.
  set_target_properties(
    compiler_ast
    compiler_base
    compiler_lib
    compiler
    whisker
    compiler_generators
    PROPERTIES VERSION ${PACKAGE_VERSION}
  )
  if(build_all)
    set_target_properties(
      compiler_schema_generators
      PROPERTIES VERSION ${PACKAGE_VERSION}
    )
  endif()
endif ()

install(
  TARGETS thrift1
    thrift-fmt
    ${THRIFT_CODEMOD_TARGETS}
    compiler_ast
    compiler_base
    compiler_lib
    compiler
    whisker
  EXPORT fbthrift-exports
  RUNTIME DESTINATION ${BIN_INSTALL_DIR}
  LIBRARY DESTINATION ${LIB_INSTALL_DIR}
  ARCHIVE DESTINATION ${LIB_INSTALL_DIR}
)
