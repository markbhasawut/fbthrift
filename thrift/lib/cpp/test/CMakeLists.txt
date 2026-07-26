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

add_library(cpp1_test_support STATIC
  ../../cpp2/test/util/TrackingTProcessorEventHandler.cpp
)
target_link_libraries(cpp1_test_support PUBLIC thriftcpp2)

set(CPP1_CORE_TESTS
  Base64Test
  ContextStackFrameworkMetadataTest
  ContextStackTest
  DistinctTableTest
  EventHandlerBaseTest
  SSLUtilsTests
)

foreach (test_name ${CPP1_CORE_TESTS})
  add_executable(Cpp1_${test_name}
    ${test_name}.cpp
  )
  target_link_libraries(Cpp1_${test_name}
    PUBLIC
      GTest::gtest_main
      async
      concurrency
      transport
      thrift-core
      Folly::folly
      fmt::fmt
  )
  if (test_name STREQUAL "ContextStackFrameworkMetadataTest"
      OR test_name STREQUAL "ContextStackTest")
    target_link_libraries(Cpp1_${test_name} PUBLIC cpp1_test_support)
  endif ()
  gtest_discover_tests(Cpp1_${test_name})
endforeach ()
