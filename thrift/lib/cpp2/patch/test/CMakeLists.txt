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

foreach (thrift_file DynamicPatchTest OldTerseWrite)
  thrift_generate(
     "${thrift_file}" #file_name
     "" #services
     "cpp2" #language
     "frozen2" #options
     "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
     "${CMAKE_CURRENT_BINARY_DIR}" #output_path
     "thrift/lib/cpp2/patch/test" #include_prefix
     THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )
  set_source_files_properties(${thrift_file} PROPERTIES GENERATED TRUE)
  set(PATCH_TEST_GENERATED_THRIFT_SOURCES ${PATCH_TEST_GENERATED_THRIFT_SOURCES}
      ${${thrift_file}-cpp2-SOURCES})
endforeach ()

add_executable(Patch_DynamicPatchTest
  DynamicPatchTest.cpp
  ${PATCH_TEST_GENERATED_THRIFT_SOURCES}
)
target_link_libraries(Patch_DynamicPatchTest
  PUBLIC
    GTest::gtest_main
    thrifttype
    thriftcpp2
    thriftprotocol
    Folly::folly
    fmt::fmt
)
gtest_discover_tests(Patch_DynamicPatchTest)
