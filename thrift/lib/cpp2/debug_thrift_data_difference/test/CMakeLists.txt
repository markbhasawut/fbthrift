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

set(DEBUG_DIFF_REFLECTION_OUTPUT
  "${CMAKE_BINARY_DIR}/thrift/test/reflection")
file(MAKE_DIRECTORY "${DEBUG_DIFF_REFLECTION_OUTPUT}")
set(reflection_SERVICES
  service1 service2 service3 service_with_special_names)
foreach (thrift_file
    reflection_dep_B
    reflection_dep_C
    reflection_dep_D
    reflection)
  thrift_generate(
    "${thrift_file}"
    "${${thrift_file}_SERVICES}"
    "cpp2"
    ""
    "${THRIFT_SOURCE_DIR}/thrift/test/reflection"
    "${DEBUG_DIFF_REFLECTION_OUTPUT}"
    "thrift/test/reflection"
    TARGET_NAME_BASE "debug_diff_${thrift_file}"
    THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )
  list(APPEND DEBUG_DIFF_GENERATED_THRIFT_SOURCES
    ${debug_diff_${thrift_file}-cpp2-SOURCES})
endforeach ()
add_library(debug_diff_test_generated STATIC
  ${DEBUG_DIFF_GENERATED_THRIFT_SOURCES})
target_link_libraries(debug_diff_test_generated PUBLIC thriftcpp2)

set(DEBUG_DIFF_TESTS
  debug_test
  diff_test
  pretty_print_test
)

foreach (test_name ${DEBUG_DIFF_TESTS})
  add_executable(DebugDiff_${test_name}
    ${test_name}.cpp
  )
  target_link_libraries(DebugDiff_${test_name}
    PUBLIC
      GTest::gmock
      GTest::gtest_main
      debug_diff_test_generated
      thriftcpp2
      thriftprotocol
      Folly::folly
      fmt::fmt
  )
  gtest_discover_tests(DebugDiff_${test_name})
endforeach ()
