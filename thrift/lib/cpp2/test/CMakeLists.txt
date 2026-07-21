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

# Generate Thrift test IDL dependencies in thrift/lib/cpp2/test
set(TEST_THRIFT_FILES
  AsyncProcessor
  Bug
  Coroutine
  Future
  HandlerGeneric
  Hierarchy
  Instrumentation
  Interaction
  MultiplexAsyncProcessor
  MultiplexAsyncProcessor2
  NativeTypeTest
  ObjectTest
  Paths
  Raiser
  Service
  ServiceName
  ServiceStack
  ThriftCatalogTest
  UnimplementedMethod
  except
  presult
)

foreach (thrift_file ${TEST_THRIFT_FILES})
  thrift_generate(
     "${thrift_file}" #file_name
     "" #services
     "cpp2" #language
     "frozen2" #options
     "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
     "${CMAKE_CURRENT_BINARY_DIR}" #output_path
     "thrift/lib/cpp2/test" #include_prefix
     THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )
  set_source_files_properties(${thrift_file} PROPERTIES GENERATED TRUE)
  set(TEST_GENERATED_THRIFT_SOURCES ${TEST_GENERATED_THRIFT_SOURCES}
      ${${thrift_file}-cpp2-SOURCES})
endforeach ()

# Core cpp2 unit tests
set(CPP2_CORE_TESTS
  AdaptTest
  AdaptiveConcurrencyTest
  AsyncProcessorTest
  BitTest
  BoxedValuePtrTest
  ChannelTest
  ClientTest
  CloneableIOBufTest
  CopyFieldTest
  CoroutineTest
  Cpp2TimeoutTest
  FieldRefRandomTest
  FutureTest
  GuardedRequestChannelTest
  HTTPClientChannelTest
  HandlerTest
  HibernatingRequestChannelTest
  IndexTest
  InstrumentationTest
  InteractionOverloadPolicyTest
  LoggingEventTest
  MultiplexAsyncProcessorTest
  NativeObjectTest
  NativeTypeTest
  ObjectTest
  OptionalFieldTest
  PatchTraitsTest
  PathsTest
  PluggableFunctionTest
  PointerComparisonTest
  PreprocessingAsyncProcessorWrapperTest
  PresultTest
  ProcessorEventHandlerInteractionTest
  ProcessorEventHandlerTest
  ReconnectingRequestChannelTest
  RequestChannelTest
  RetryingRequestChannelTest
  RocketClientChannelTest
  SerializationTest
  ServerAttributeTest
  ServiceHealthPollerTest
  ServiceNameTest
  ServiceStackTest
  ThriftClientTest
  ThriftServerExceptionTest
  ThriftServerFutureExceptionTest
  ThriftServerInheritanceTest
  TypeClassToTypeTagTest
  UnimplementedMethodTest
)

foreach (test_name ${CPP2_CORE_TESTS})
  add_executable(${test_name}
     ${test_name}.cpp
     ${TEST_GENERATED_THRIFT_SOURCES})
  target_link_libraries(${test_name}
     PUBLIC
       GTest::gtest_main
       thriftcpp2
       thriftprotocol
       thrifttype
       Folly::folly
       fmt::fmt
  )
  gtest_discover_tests(${test_name})
endforeach ()

# FlagsTest requires helper source
add_executable(FlagsTest
   FlagsTest.cpp
   FlagsTestHelper.cpp
   ${TEST_GENERATED_THRIFT_SOURCES})
target_link_libraries(FlagsTest
   PUBLIC
     GTest::gtest_main
     thriftcpp2
     thriftprotocol
     thrifttype
     Folly::folly
     fmt::fmt
)
gtest_discover_tests(FlagsTest)

# Server tests in thrift/lib/cpp2/test/server
set(CPP2_SERVER_TESTS
  Cpp2ConnContextTest
  RequestsRegistryTest
  ServiceHealthPollingTest
  SharedServerTests
  ThriftProcessorTest
  ThriftServerCustomCompressionTest
  ThriftServerTest
  ThriftSocketParserTest
)

foreach (test_name ${CPP2_SERVER_TESTS})
  add_executable(ServerTest_${test_name}
     server/${test_name}.cpp
     ${TEST_GENERATED_THRIFT_SOURCES})
  target_link_libraries(ServerTest_${test_name}
     PUBLIC
       GTest::gtest_main
       thriftcpp2
       thriftprotocol
       thrifttype
       Folly::folly
       fmt::fmt
  )
  gtest_discover_tests(ServerTest_${test_name})
endforeach ()

# E2E tests in thrift/lib/cpp2/test/e2e
set(E2E_THRIFT_FILES
  TestBackpressureService
  TestBiDiService
  TestGracefulShutdownService
  TestInteractionService
  TestOnewayService
  TestRequestResponseService
  TestResourcePoolService
  TestSinkE2EService
  TestStreamE2EService
)

foreach (thrift_file ${E2E_THRIFT_FILES})
  thrift_generate(
     "${thrift_file}" #file_name
     "" #services
     "cpp2" #language
     "frozen2" #options
     "${CMAKE_CURRENT_SOURCE_DIR}/e2e" #file_path
     "${CMAKE_CURRENT_BINARY_DIR}/e2e" #output_path
     "thrift/lib/cpp2/test/e2e" #include_prefix
     THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )
  set_source_files_properties(${thrift_file} PROPERTIES GENERATED TRUE)
  set(E2E_GENERATED_THRIFT_SOURCES ${E2E_GENERATED_THRIFT_SOURCES}
      ${${thrift_file}-cpp2-SOURCES})
endforeach ()

set(E2E_TESTS
  BackpressureE2ETest
  BiDiClientCrashE2ETest
  BiDiServiceE2ETest
  GracefulShutdownE2ETest
  InteractionServiceE2ETest
  OnewayServiceE2ETest
  RequestResponseServiceE2ETest
  ResourcePoolE2ETest
  SinkLoggingE2ETest
  SinkServiceE2ETest
  StreamCompressionE2ETest
  StreamLoggingE2ETest
  StreamServiceE2ETest
)

foreach (test_name ${E2E_TESTS})
  add_executable(E2E_${test_name}
     e2e/${test_name}.cpp
     ${TEST_GENERATED_THRIFT_SOURCES}
     ${E2E_GENERATED_THRIFT_SOURCES})
  target_link_libraries(E2E_${test_name}
     PUBLIC
       GTest::gtest_main
       thriftcpp2
       thriftprotocol
       thrifttype
       Folly::folly
       fmt::fmt
  )
  gtest_discover_tests(E2E_${test_name})
endforeach ()

# Benchmarks (if THRIFT_BENCHMARKS is enabled)
if (THRIFT_BENCHMARKS)
  # Obtain paths to other generated thrift files from the global property space.
  get_property(protocol-cpp2-SOURCES GLOBAL PROPERTY protocol-cpp2-SOURCES)
  get_property(protocol_detail-cpp2-SOURCES GLOBAL PROPERTY protocol_detail-cpp2-SOURCES)
  get_property(frozen-cpp2-SOURCES GLOBAL PROPERTY frozen-cpp2-SOURCES)
  get_property(field_mask-cpp2-SOURCES GLOBAL PROPERTY field_mask-cpp2-SOURCES)

  thrift_generate(
    "ProtocolBenchData" #file_name
    "" #services
    "cpp2" #language
    "frozen2,layouts" #options
    "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
    "${CMAKE_CURRENT_BINARY_DIR}" #output_path
    "thrift/lib/cpp2/test" #include_prefix
    THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )

  set(GENERATED_BENCH_SOURCES ${ProtocolBenchData-cpp2-SOURCES}
    ${protocol-cpp2-SOURCES}
    ${protocol_detail-cpp2-SOURCES}
    ${field_mask-cpp2-SOURCES}
    ${frozen-cpp2-SOURCES})

  foreach (GENERATED ${GENERATED_BENCH_SOURCES})
    set_source_files_properties(${GENERATED} PROPERTIES GENERATED TRUE)
  endforeach ()

  add_executable(ProtocolBench
    ProtocolBench.cpp
    ../../thrift/detail/protocol.cpp
    ../../thrift/TypeToMaskAdapter.cpp
    ${GENERATED_BENCH_SOURCES}
  )
  target_link_libraries(ProtocolBench PUBLIC thriftcpp2 Folly::folly fmt::fmt)
endif ()
