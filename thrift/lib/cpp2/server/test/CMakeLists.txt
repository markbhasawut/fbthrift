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
  "TestService"
  "TestService"
  "cpp2"
  ""
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}"
  "thrift/lib/cpp2/server/test"
  TARGET_NAME_BASE "cpp2_server_test_service"
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

set(SERVICE_METHOD_DECORATOR_SERVICES
  ServiceMethodDecoratorTest
  TestAdapter
  PerformInteractionTest
  ReturnsInteractionTest
  InheritsInteractionTest
)
thrift_generate(
  "ServiceMethodDecorator"
  "${SERVICE_METHOD_DECORATOR_SERVICES}"
  "cpp2"
  ""
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}"
  "thrift/lib/cpp2/server/test"
  TARGET_NAME_BASE "cpp2_server_service_method_decorator"
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

add_library(cpp2_server_test_generated STATIC
  ${cpp2_server_test_service-cpp2-SOURCES}
  ${cpp2_server_service_method_decorator-cpp2-SOURCES}
)
add_dependencies(
  cpp2_server_test_generated
  cpp2_server_test_service-cpp2-target
  cpp2_server_service_method_decorator-cpp2-target
)
target_link_libraries(cpp2_server_test_generated PUBLIC thriftcpp2)

set(SERVER_TESTS
  CPUConcurrencyControllerTest
  DecoratorDataTest
  InternalPriorityTest
  MockCPUConcurrencyControllerConfigTest
  ParallelConcurrencyControllerTest
  PerturbSourceTest
  QueuedBytesTrackingTest
  ReactiveToggleTest
  ResourcePoolMigrationHelperTest
  ResourcePoolSetTest
  ResourcePoolsTest
  RoundRobinRequestPileTest
  ServiceInterceptorControlTest
  ServiceInterceptorQualifiedNameTest
  ServiceMethodDecoratorTest
  SingleBucketRequestPileQueueTest
  ThriftServerConfigTest
  ThriftServerCpuCCTest
  ThriftServerDestroyTest
  ThriftServerDuplicateModuleTest
  TokenBucketConcurrencyControllerTest
  WeightedRequestPileQueueTest
)
if (NOT THRIFT_HTTP2)
  list(REMOVE_ITEM SERVER_TESTS ServiceMethodDecoratorTest)
endif ()

foreach (test_name ${SERVER_TESTS})
  add_executable(Server_${test_name}
    ${test_name}.cpp
  )
  target_link_libraries(Server_${test_name}
    PUBLIC
      GTest::gmock
      GTest::gtest_main
      cpp2_server_test_generated
      cpp2_test_support
      thriftcpp2
      thriftprotocol
      Folly::folly
      fmt::fmt
  )
  if (test_name STREQUAL "ServiceMethodDecoratorTest")
    target_link_libraries(
      Server_${test_name} PRIVATE proxygen::proxygen)
  endif ()
  gtest_discover_tests(Server_${test_name})
endforeach ()
