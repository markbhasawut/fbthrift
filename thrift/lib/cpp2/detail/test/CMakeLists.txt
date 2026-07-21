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

thrift_generate(
   "EventHandler" #file_name
   "" #services
   "cpp2" #language
   "frozen2" #options
   "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
   "${CMAKE_CURRENT_BINARY_DIR}" #output_path
   "thrift/lib/cpp2/detail/test" #include_prefix
   THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)
set_source_files_properties(EventHandler PROPERTIES GENERATED TRUE)

add_executable(Detail_EventHandlerRuntimeTest
  EventHandlerRuntimeTest.cpp
  ${EventHandler-cpp2-SOURCES}
)
target_link_libraries(Detail_EventHandlerRuntimeTest
  PUBLIC
    GTest::gtest_main
    thriftcpp2
    thriftprotocol
    Folly::folly
    fmt::fmt
)
gtest_discover_tests(Detail_EventHandlerRuntimeTest)
