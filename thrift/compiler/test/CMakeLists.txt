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

foreach (test_name ${COMPILER_TESTS})
  add_executable(Compiler_${test_name}
    ${test_name}.cc
    parser_test_helpers.cc
    fork_intercept.cc
    compiler.cc
  )
  target_link_libraries(Compiler_${test_name}
    PUBLIC
      GTest::gtest_main
      compiler_ast
      compiler_base
      compiler_lib
      compiler
      whisker
      ${GENERATE_LINKED}
      Folly::folly
      fmt::fmt
      ${FBTHRIFT_COMPILER_LINK_CXXFS}
  )
  gtest_discover_tests(Compiler_${test_name})
endforeach ()

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
  add_executable(Whisker_${test_name}
    ../whisker/test/${test_name}.cc
  )
  target_link_libraries(Whisker_${test_name}
    PUBLIC
      GTest::gtest_main
      whisker
      compiler_base
      Folly::folly
      fmt::fmt
  )
  gtest_discover_tests(Whisker_${test_name})
endforeach ()
