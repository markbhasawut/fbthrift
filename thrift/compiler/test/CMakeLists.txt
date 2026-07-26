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

include(GoogleTest)

set(COMPILER_TESTS
  ast_visitor_test
  compiler_test
  const_util_test
  cpp2_util_test
  cpp_name_resolver_test
  diagnostic_test
  fork_intercept_test
  formatter_test
  generate_common_test
  go_util_test
  java_util_test
  json_test
  lexer_test
  metadata_test
  node_metadata_cache_test
  parser_test
  pluggable_functions_test
  python_util_test
  reference_type_test
  reserved_identifier_test
  reserved_identifier_validator_test
  schematizer_test
  scope_identifier_test
  scoped_validator_test
  sema_context_test
  sema_test
  source_location_test
  standard_validator_test
  system_test
  t_enum_test
  t_program_test
  t_typedef_test
  token_test
  whisker_templates_test
)

thrift_generate(
  "const_util_test"
  ""
  "cpp2"
  "no_metadata"
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}"
  "thrift/compiler/test"
  COMPILER ${THRIFT1_BOOTSTRAP_TARGET}
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  NO_INSTALL
)

# These helpers are common to every compiler test. Building them once keeps the
# CMake test graph compact and avoids recompiling the parser harness 34 times.
add_library(
  compiler_test_support
  STATIC
    parser_test_helpers.cc
    fork_intercept.cc
    compiler.cc
)
target_link_libraries(
  compiler_test_support
  PUBLIC
    GTest::gmock
    compiler_ast
    compiler_base
    compiler_lib
    compiler_driver
    compiler
    whisker
    Folly::folly
    fmt::fmt
    re2::re2
    ${FBTHRIFT_COMPILER_LINK_CXXFS}
)

foreach (test_name ${COMPILER_TESTS})
  add_executable(
    Compiler_${test_name}
    ${test_name}.cc
  )
  target_link_libraries(
    Compiler_${test_name}
    PRIVATE
      GTest::gtest_main
      compiler_test_support
      ${GENERATE_LINKED}
  )
  gtest_discover_tests(
    Compiler_${test_name}
    TEST_PREFIX "Compiler."
    PROPERTIES ENVIRONMENT "IMPLICIT_INCLUDES=${THRIFT_SOURCE_DIR};THRIFT_INCLUDE_PATH=${THRIFT_SOURCE_DIR}"
  )
endforeach ()

target_sources(
  Compiler_const_util_test
  PRIVATE ${const_util_test-cpp2-SOURCES}
)
add_dependencies(Compiler_const_util_test const_util_test-cpp2-target)
target_link_libraries(Compiler_const_util_test PRIVATE thriftcpp2)

if(APPLE)
  # range-v3's bundled meta forward declarations conflict with the newer
  # libc++ declarations reached through folly::Subprocess and Boost.
  target_compile_definitions(
    Compiler_fork_intercept_test
    PRIVATE META_NO_STD_FORWARD_DECLARATIONS
  )
endif ()

# These two tests consume generated runtime schema types. Keeping those
# dependencies test-local preserves the bootstrap compiler -> generated
# runtime direction and avoids a thrift1/runtime cycle.
set(COMPILER_METADATA_SCHEMA_ROOT
  "${CMAKE_CURRENT_BINARY_DIR}/metadata_schema")
set(COMPILER_METADATA_SCHEMA_OUTPUT
  "${COMPILER_METADATA_SCHEMA_ROOT}/thrift/lib/thrift")
file(MAKE_DIRECTORY "${COMPILER_METADATA_SCHEMA_OUTPUT}")
thrift_generate(
  "metadata"
  ""
  "cpp2"
  "no_metadata"
  "${THRIFT_SOURCE_DIR}/thrift/lib/thrift"
  "${COMPILER_METADATA_SCHEMA_OUTPUT}"
  "thrift/lib/thrift"
  COMPILER thrift1
  TARGET_NAME_BASE compiler_metadata_schema
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  INJECT_SCHEMA
  NO_INSTALL
)
set(COMPILER_METADATA_SCHEMA_SOURCES
  ${compiler_metadata_schema-cpp2-SOURCES})
list(FILTER COMPILER_METADATA_SCHEMA_SOURCES INCLUDE REGEX
  "/metadata_(constants|sinit)\\.cpp$")
target_sources(
  Compiler_metadata_test
  PRIVATE ${COMPILER_METADATA_SCHEMA_SOURCES}
)
target_include_directories(
  Compiler_metadata_test
  BEFORE PRIVATE "${COMPILER_METADATA_SCHEMA_ROOT}"
)
add_dependencies(
  Compiler_metadata_test compiler_metadata_schema-cpp2-target)
target_link_libraries(
  Compiler_metadata_test
  PRIVATE
    thriftmetadata
    thriftcpp2
)
target_sources(
  Compiler_schematizer_test
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../generate/schema_populator.cc
)
target_link_libraries(
  Compiler_schematizer_test
  PRIVATE
    thriftmetadata
    thriftprotocol
)

set(WHISKER_TESTS
  dsl_test
  eval_context_test
  expected_test
  lexer_test
  object_test
  parser_test
  render_test
  standard_library_test
)

foreach (test_name ${WHISKER_TESTS})
  add_executable(
    Whisker_${test_name}
    ../whisker/test/${test_name}.cc
  )
  target_link_libraries(
    Whisker_${test_name}
    PRIVATE
      GTest::gtest_main
      GTest::gmock
      whisker
      compiler_base
      Folly::folly
      fmt::fmt
  )
  gtest_discover_tests(
    Whisker_${test_name}
    TEST_PREFIX "Whisker."
  )
endforeach ()
