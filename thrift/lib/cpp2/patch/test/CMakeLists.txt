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

foreach(thrift_file DynamicPatchTest OldTerseWrite)
  thrift_generate(
    "${thrift_file}"
    ""
    "cpp2"
    "patch"
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}"
    "thrift/lib/cpp2/patch/test"
    TARGET_NAME_BASE "patch_test_${thrift_file}"
    THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )
  list(APPEND PATCH_TEST_GENERATED_THRIFT_SOURCES
    ${patch_test_${thrift_file}-cpp2-SOURCES})
endforeach()

bypass_source_check(${PATCH_TEST_GENERATED_THRIFT_SOURCES})
add_library(patch_test_generated STATIC
  ${PATCH_TEST_GENERATED_THRIFT_SOURCES})
target_link_libraries(patch_test_generated PUBLIC thriftcpp2)

add_executable(Patch_DynamicPatchTest DynamicPatchTest.cpp)
target_link_libraries(Patch_DynamicPatchTest
  PUBLIC
    GTest::gtest_main
    patch_test_generated
    thriftcpp2
    thriftprotocol
    Folly::folly
    fmt::fmt
)
gtest_discover_tests(Patch_DynamicPatchTest)
