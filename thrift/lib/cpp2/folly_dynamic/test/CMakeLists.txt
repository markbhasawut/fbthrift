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

foreach (reflection_file compat global)
  thrift_generate(
    "${reflection_file}"
    ""
    "cpp2"
    ""
    "${THRIFT_SOURCE_DIR}/thrift/test/reflection"
    "${CMAKE_BINARY_DIR}/thrift/test/reflection"
    "thrift/test/reflection"
    TARGET_NAME_BASE "folly_dynamic_${reflection_file}"
    THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )
  list(APPEND FOLLY_DYNAMIC_GENERATED_THRIFT_SOURCES
    ${folly_dynamic_${reflection_file}-cpp2-SOURCES})
endforeach ()
add_library(folly_dynamic_test_generated STATIC
  ${FOLLY_DYNAMIC_GENERATED_THRIFT_SOURCES})
target_link_libraries(folly_dynamic_test_generated
  PUBLIC
    cpp2_test_adapter_generated
    thriftcpp2)

add_executable(FollyDynamic_folly_dynamic_test
  folly_dynamic_test.cpp
)
target_link_libraries(FollyDynamic_folly_dynamic_test
  PUBLIC
    GTest::gmock
    GTest::gtest_main
    debug_diff_test_generated
    folly_dynamic_test_generated
    thriftcpp2
    thriftprotocol
    Folly::folly
    fmt::fmt
)
gtest_discover_tests(FollyDynamic_folly_dynamic_test)
