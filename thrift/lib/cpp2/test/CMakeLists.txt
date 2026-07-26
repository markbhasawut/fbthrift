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

find_path(FATAL_INCLUDE_DIR
  NAMES fatal/type/sequence.h
)
if (NOT FATAL_INCLUDE_DIR)
  message(FATAL_ERROR
    "fatal/type/sequence.h is required by thrift/test/testset/Testset.h")
endif ()

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

# thrift_generate() needs the declared service names to expose the generated
# service and async-client translation units through <file>-cpp2-SOURCES.
set(AsyncProcessor_SERVICES
  Parent Child DummyMonitor DummyStatus DummyControl DummySecurity SchemaService)
set(Bug_SERVICES Bug)
set(Coroutine_SERVICES Coroutine)
set(Future_SERVICES FutureService)
set(HandlerGeneric_SERVICES HandlerGeneric)
set(Hierarchy_SERVICES MyRoot MyNode MyLeaf)
set(Instrumentation_SERVICES DebugTestService InstrumentationTestService)
set(Interaction_SERVICES Calculator Streamer)
set(MultiplexAsyncProcessor_SERVICES
  First Second Third Conflicts Interaction1 Interaction2 SomeService)
set(MultiplexAsyncProcessor2_SERVICES ConflictsInteraction1)
set(Raiser_SERVICES Raiser)
set(Service_SERVICES TestService)
set(ServiceName_SERVICES ServiceNameA ServiceNameB ServiceNameC)
set(ServiceStack_SERVICES TestServiceStack)
set(ThriftCatalogTest_SERVICES CatalogTestService)
set(UnimplementedMethod_SERVICES UnimplementedMethod)
set(except_SERVICES SampleService SampleService2 SampleService3)
set(presult_SERVICES PresultService)
set(AsyncProcessor_INJECT_SCHEMA TRUE)
set(ThriftCatalogTest_INJECT_SCHEMA TRUE)
set(ThriftCatalogTest_OPTIONS "any")
set(Service_OPTIONS "json,sync_methods_return_try")

set(CPP2_TEST_GENERATED_THRIFT_SOURCES)
set(CPP2_TEST_CATALOG_GENERATED_SOURCES)
foreach (thrift_file ${TEST_THRIFT_FILES})
  set(thrift_options "")
  if (DEFINED ${thrift_file}_OPTIONS)
    set(thrift_options "${${thrift_file}_OPTIONS}")
  endif ()
  set(extra_args "")
  if (${thrift_file}_INJECT_SCHEMA)
    set(extra_args INJECT_SCHEMA)
  endif ()
  thrift_generate(
     "${thrift_file}" #file_name
     "${${thrift_file}_SERVICES}" #services
     "cpp2" #language
     "${thrift_options}" #options
     "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
     "${CMAKE_CURRENT_BINARY_DIR}" #output_path
     "thrift/lib/cpp2/test" #include_prefix
     THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
     ${extra_args}
  )
  bypass_source_check(${${thrift_file}-cpp2-SOURCES})
  if (thrift_file STREQUAL "ThriftCatalogTest")
    set(CPP2_TEST_CATALOG_GENERATED_SOURCES
      ${${thrift_file}-cpp2-SOURCES})
  else ()
    list(APPEND CPP2_TEST_GENERATED_THRIFT_SOURCES
      ${${thrift_file}-cpp2-SOURCES})
  endif ()
endforeach ()

file(MAKE_DIRECTORY
  "${CMAKE_CURRENT_BINARY_DIR}/util"
)
thrift_generate(
  "enum"
  ""
  "cpp2"
  ""
  "${CMAKE_CURRENT_SOURCE_DIR}/util"
  "${CMAKE_CURRENT_BINARY_DIR}/util"
  "thrift/lib/cpp2/test/util"
  TARGET_NAME_BASE "cpp2_test_enum"
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)
thrift_generate(
  "adapter"
  "AdapterService"
  "cpp2"
  ""
  "${THRIFT_SOURCE_DIR}/thrift/test"
  "${CMAKE_BINARY_DIR}/thrift/test"
  "thrift/test"
  TARGET_NAME_BASE "cpp2_test_adapter"
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)
list(APPEND CPP2_TEST_GENERATED_THRIFT_SOURCES
  ${cpp2_test_enum-cpp2-SOURCES})

add_library(cpp2_test_adapter_generated STATIC
  ${cpp2_test_adapter-cpp2-SOURCES})
target_link_libraries(cpp2_test_adapter_generated PUBLIC thriftcpp2)


add_library(cpp2_test_generated STATIC
  ${CPP2_TEST_GENERATED_THRIFT_SOURCES})
target_link_libraries(cpp2_test_generated
  PUBLIC
    thrift_testset_generated
    thriftconformance_generated
    thriftcpp2
)

# Keep the catalog fixture as a module-shaped object library. Its generated
# _sinit translation unit registers the service schema at process startup;
# object-library consumers retain that unit without force-loading every
# unrelated cpp2 test fixture from cpp2_test_generated.
add_library(cpp2_test_catalog_generated OBJECT
  ${CPP2_TEST_CATALOG_GENERATED_SOURCES})
target_link_libraries(cpp2_test_catalog_generated PUBLIC thriftcpp2)


add_library(cpp2_test_support STATIC
  util/TestHandler.cpp
  util/TrackingTProcessorEventHandler.cpp
)
target_link_libraries(cpp2_test_support PUBLIC cpp2_test_generated thriftcpp2)

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
if (NOT THRIFT_HTTP2)
  list(REMOVE_ITEM CPP2_CORE_TESTS
    AsyncProcessorTest
    HTTPClientChannelTest
  )
endif ()
set(CPP2_FOLLY_TEST_SUPPORT_TESTS
  ChannelTest
  ReconnectingRequestChannelTest
  RequestChannelTest
  RetryingRequestChannelTest
)
set(CPP2_PROXYGEN_TESTS
  AsyncProcessorTest
  HTTPClientChannelTest
)
if (TARGET Folly::folly_test_support)
  set(CPP2_FOLLY_TEST_SUPPORT_TARGET Folly::folly_test_support)
else ()
  find_library(
    FOLLY_TEST_SUPPORT_LIBRARY
    NAMES folly_test_support)
  if (FOLLY_TEST_SUPPORT_LIBRARY)
    add_library(folly_test_support_for_fbthrift UNKNOWN IMPORTED)
    set_target_properties(
      folly_test_support_for_fbthrift
      PROPERTIES IMPORTED_LOCATION "${FOLLY_TEST_SUPPORT_LIBRARY}")
    set(CPP2_FOLLY_TEST_SUPPORT_TARGET folly_test_support_for_fbthrift)
  else ()
    message(STATUS
      "Skipping cpp2 tests that require uninstalled "
      "folly_test_support")
    list(REMOVE_ITEM CPP2_CORE_TESTS ${CPP2_FOLLY_TEST_SUPPORT_TESTS})
  endif ()
endif ()

foreach (test_name ${CPP2_CORE_TESTS})
  add_executable(${test_name}
     ${test_name}.cpp)
  if (test_name STREQUAL "ObjectTest")
    target_sources(ObjectTest PRIVATE
      ${THRIFT_SOURCE_DIR}/thrift/conformance/data/ValueGenerator.cpp
    )
    target_include_directories(ObjectTest PRIVATE "${FATAL_INCLUDE_DIR}")
    target_link_libraries(ObjectTest
      PRIVATE
        cpp2_test_adapter_generated
        thriftconformance
    )
  endif ()
  target_link_libraries(${test_name}
     PUBLIC
       GTest::gmock
       GTest::gtest_main
       cpp2_test_generated
       cpp2_test_support
       thriftcpp2
       thriftprotocol
       thrifttype
       Folly::folly
       fmt::fmt
  )



  if (test_name IN_LIST CPP2_FOLLY_TEST_SUPPORT_TESTS)
    target_link_libraries(
      ${test_name}
      PUBLIC
        ${CPP2_FOLLY_TEST_SUPPORT_TARGET}
        Folly::folly_test_util
    )
  endif ()
  if (test_name IN_LIST CPP2_PROXYGEN_TESTS)
    target_link_libraries(${test_name} PRIVATE proxygen::proxygen)
  endif ()
  if (test_name STREQUAL "AsyncProcessorTest")
    target_link_libraries(${test_name} PRIVATE cpp2_test_catalog_generated)
  endif ()

  if (test_name STREQUAL "HTTPClientChannelTest")
    target_link_libraries(${test_name}
      PRIVATE proxygen::proxygen_httpserver_scoped_httpserver)
  endif ()
  gtest_discover_tests(${test_name})
endforeach ()

# FlagsTest requires helper source
add_executable(FlagsTest
   FlagsTest.cpp
   FlagsTestHelper.cpp)
target_link_libraries(FlagsTest
   PUBLIC
     GTest::gmock
     GTest::gtest_main
     cpp2_test_generated
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
if (NOT THRIFT_HTTP2)
  list(REMOVE_ITEM CPP2_SERVER_TESTS ThriftServerTest)
endif ()
if (NOT CPP2_FOLLY_TEST_SUPPORT_TARGET)
  list(REMOVE_ITEM CPP2_SERVER_TESTS
    ThriftServerTest
    ThriftSocketParserTest
  )
endif ()
if (NOT EXISTS
    "${THRIFT_SOURCE_DIR}/thrift/lib/cpp2/transport/core/testutil/IntermHeaderService.thrift")
  message(STATUS
    "Skipping ThriftProcessorTest: its internal generated test IDLs are absent")
  list(REMOVE_ITEM CPP2_SERVER_TESTS ThriftProcessorTest)
endif ()

foreach (test_name ${CPP2_SERVER_TESTS})
  add_executable(ServerTest_${test_name}
     server/${test_name}.cpp)
  target_link_libraries(ServerTest_${test_name}
     PUBLIC
       GTest::gmock
       GTest::gtest_main
       cpp2_test_generated
       cpp2_test_support
       thriftcpp2
       thriftprotocol
       thrifttype
       Folly::folly
       fmt::fmt
  )
  if (test_name STREQUAL "ThriftServerTest" OR
      test_name STREQUAL "ThriftSocketParserTest")
    target_link_libraries(
      ServerTest_${test_name}
      PUBLIC
        ${CPP2_FOLLY_TEST_SUPPORT_TARGET}
        Folly::folly_test_util
    )
  endif ()
  if (test_name STREQUAL "ThriftServerTest")
    target_link_libraries(
      ServerTest_${test_name}
      PRIVATE
        proxygen::proxygen
        quic_thriftcpp2
    )
  endif ()
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

set(TestBackpressureService_SERVICES TestBackpressureService)
set(TestBiDiService_SERVICES TestBiDiService)
set(TestGracefulShutdownService_SERVICES TestGracefulShutdownService)
set(TestInteractionService_SERVICES Calculator Streamer)
set(TestOnewayService_SERVICES TestOnewayService)
set(TestRequestResponseService_SERVICES TestRequestResponseService)
set(TestResourcePoolService_SERVICES TestResourcePoolService)
set(TestSinkE2EService_SERVICES TestSinkE2EService)
set(TestStreamE2EService_SERVICES TestStreamE2EService)

foreach (thrift_file ${E2E_THRIFT_FILES})
  thrift_generate(
     "${thrift_file}" #file_name
     "${${thrift_file}_SERVICES}" #services
     "cpp2" #language
     "" #options
     "${CMAKE_CURRENT_SOURCE_DIR}/e2e" #file_path
     "${CMAKE_CURRENT_BINARY_DIR}/e2e" #output_path
     "thrift/lib/cpp2/test/e2e" #include_prefix
     THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )
  bypass_source_check(${${thrift_file}-cpp2-SOURCES})
  set(E2E_GENERATED_THRIFT_SOURCES ${E2E_GENERATED_THRIFT_SOURCES}
      ${${thrift_file}-cpp2-SOURCES})
endforeach ()

add_library(cpp2_e2e_test_generated STATIC ${E2E_GENERATED_THRIFT_SOURCES})
target_link_libraries(cpp2_e2e_test_generated PUBLIC thriftcpp2)

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
     e2e/${test_name}.cpp)
  target_link_libraries(E2E_${test_name}
     PUBLIC
       GTest::gmock
       GTest::gtest_main
       cpp2_test_generated
       cpp2_e2e_test_generated
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
  find_package(benchmark CONFIG REQUIRED)

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

  set(GENERATED_BENCH_SOURCES ${ProtocolBenchData-cpp2-SOURCES})

  foreach (GENERATED ${GENERATED_BENCH_SOURCES})
    set_source_files_properties(${GENERATED} PROPERTIES GENERATED TRUE)
  endforeach ()

  add_executable(ProtocolBench
    ProtocolBench.cpp
    ${GENERATED_BENCH_SOURCES}
  )
  target_link_libraries(ProtocolBench
    PUBLIC thriftcpp2 Folly::folly fmt::fmt benchmark::benchmark)
endif ()
