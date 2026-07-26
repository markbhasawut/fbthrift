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

# Generate Thrift files for util tests
foreach (thrift_file DebugString DebugTree DebugTreeNoUri)
  thrift_generate(
     "${thrift_file}" #file_name
     "" #services
     "cpp2" #language
     "" #options
     "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
     "${CMAKE_CURRENT_BINARY_DIR}" #output_path
     "thrift/lib/cpp2/util/test" #include_prefix
     THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )
  bypass_source_check(${${thrift_file}-cpp2-SOURCES})
  set(UTIL_TEST_GENERATED_THRIFT_SOURCES ${UTIL_TEST_GENERATED_THRIFT_SOURCES}
      ${${thrift_file}-cpp2-SOURCES})
endforeach ()

add_library(util_test_generated STATIC ${UTIL_TEST_GENERATED_THRIFT_SOURCES})
target_link_libraries(util_test_generated PUBLIC thriftcpp2)

set(UTIL_TESTS
  AllocationColocatorTest
  DebugStringTest
  DebugTreeTest
  IntrusiveSharedPtrTest
  ManagedStringViewTest
  MethodMetadataTest
  TypeErasedRefTest
  TypeErasedTupleRefTest
  TypeErasedValueTest
)
if (NOT EXISTS
    "${CMAKE_CURRENT_SOURCE_DIR}/gen-cpp2/gen_patch_DebugTree_types.h")
  message(STATUS
    "Skipping DebugTreeTest: its Buck-generated patch fixture is absent")
  list(REMOVE_ITEM UTIL_TESTS DebugTreeTest)
endif ()

foreach (test_name ${UTIL_TESTS})
  add_executable(Util_${test_name}
    ${test_name}.cpp
  )
  target_link_libraries(Util_${test_name}
    PUBLIC
      GTest::gtest_main
      util_test_generated
      thriftcpp2
      thriftprotocol
      Folly::folly
      fmt::fmt
  )
  gtest_discover_tests(Util_${test_name})
endforeach ()
