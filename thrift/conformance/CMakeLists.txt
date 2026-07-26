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

set(CONFORMANCE_IDLS
  any
  conformance
  patch_data
  protocol
  rpc
  rpc_setup
  serialization
  test_suite
  test_value
  type
)

set(CONFORMANCE_SERVICES_conformance ConformanceService)
set(CONFORMANCE_SERVICES_rpc
  RPCConformanceService
  RPCStatelessConformanceService
)
set(CONFORMANCE_SERVICES_rpc_setup RPCConformanceSetupService)

find_path(FATAL_INCLUDE_DIR
  NAMES fatal/type/sequence.h
)
if (NOT FATAL_INCLUDE_DIR)
  message(FATAL_ERROR
    "fatal/type/sequence.h is required by thrift/test/testset/Testset.h")
endif ()

set(CONFORMANCE_GENERATED_THRIFT_HEADERS)
set(CONFORMANCE_GENERATED_THRIFT_SOURCES)
foreach (thrift_file ${CONFORMANCE_IDLS})
  set(generated_target_name "conformance_${thrift_file}")
  thrift_generate(
    "${thrift_file}"
    "${CONFORMANCE_SERVICES_${thrift_file}}"
    "cpp2"
    ""
    "${CMAKE_CURRENT_SOURCE_DIR}/if"
    "${CMAKE_CURRENT_BINARY_DIR}/if"
    "thrift/conformance/if"
    NO_INSTALL
    THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
    TARGET_NAME_BASE "${generated_target_name}"
  )
  list(APPEND CONFORMANCE_GENERATED_THRIFT_HEADERS
    ${${generated_target_name}-cpp2-HEADERS})
  list(APPEND CONFORMANCE_GENERATED_THRIFT_SOURCES
    ${${generated_target_name}-cpp2-SOURCES})
endforeach ()

# Keep generated code in one archive. Every conformance component includes the
# same IDL closure, so compiling the generated sources in each test would
# multiply both object count and code-generation ordering edges.
add_library(thriftconformance_generated STATIC
  ${CONFORMANCE_GENERATED_THRIFT_SOURCES}
)
target_link_libraries(thriftconformance_generated
  PUBLIC
    thriftcpp2
    thriftmetadata
    thriftprotocol
    thrifttype
    Folly::folly
)

# The cpp2 `any` option emits registration and serializer calls from generated
# translation units. Keep that ABI in a small lower-layer library so generated
# archives can carry their actual dependency without depending on the complete
# conformance service implementation (or forming a conformance <-> testset
# archive cycle).
add_library(thriftconformance_any_registry STATIC
  cpp2/Any.cpp
  cpp2/AnyRef.cpp
  cpp2/AnyRegistry.cpp
  cpp2/AnySerializer.cpp
  cpp2/Protocol.cpp
  cpp2/ThriftTypeInfo.cpp
)
target_link_libraries(thriftconformance_any_registry
  PUBLIC
    thriftconformance_generated
    thriftcpp2
    thriftprotocol
    thrifttype
    Folly::folly
    fmt::fmt
)

# Shared cpp/cpp2 tests need the testset types and JSON support, but not the
# generated Any registry. Keeping `any` out of this archive prevents every test
# binary from running the complete testset registration matrix at startup.
# Split the large generated implementations so a clean Clang build does not
# instantiate the entire testset in four monolithic TUs.
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/thrift/test/testset")
configure_file(
  "${THRIFT_SOURCE_DIR}/thrift/test/testset/golden/Testset.h"
  "${CMAKE_BINARY_DIR}/thrift/test/testset/Testset.h"
  COPYONLY
)
thrift_generate(
  "testset"
  ""
  "cpp2"
  "json,types_cpp_splits=16"
  "${THRIFT_SOURCE_DIR}/thrift/test/testset/golden"
  "${CMAKE_BINARY_DIR}/thrift/test/testset"
  "thrift/test/testset"
  NO_INSTALL
  TARGET_NAME_BASE "conformance_testset"
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)
add_library(thrift_testset_generated STATIC
  ${conformance_testset-cpp2-SOURCES}
)
target_include_directories(thrift_testset_generated
  PUBLIC
    "${CMAKE_BINARY_DIR}"
    "${FATAL_INCLUDE_DIR}"
)
target_link_libraries(thrift_testset_generated
  PUBLIC thriftcpp2
)

# Conformance additionally needs generated Any serializers and registration.
# Generate the same ABI in an isolated physical include root so it is never
# linked together with the ordinary testset archive. Consumers see the normal
# include root; only this target compiles against its option-specific headers.
set(CONFORMANCE_ANY_TESTSET_ROOT
  "${CMAKE_CURRENT_BINARY_DIR}/testset_any_root")
set(CONFORMANCE_ANY_TESTSET_OUTPUT
  "${CONFORMANCE_ANY_TESTSET_ROOT}/thrift/test/testset")
file(MAKE_DIRECTORY "${CONFORMANCE_ANY_TESTSET_OUTPUT}")
thrift_generate(
  "testset"
  ""
  "cpp2"
  "json,any,types_cpp_splits=16"
  "${THRIFT_SOURCE_DIR}/thrift/test/testset/golden"
  "${CONFORMANCE_ANY_TESTSET_OUTPUT}"
  "thrift/test/testset"
  NO_INSTALL
  TARGET_NAME_BASE "conformance_any_testset"
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)
add_library(thrift_testset_any_generated STATIC
  ${conformance_any_testset-cpp2-SOURCES}
)
target_include_directories(thrift_testset_any_generated
  BEFORE PRIVATE "${CONFORMANCE_ANY_TESTSET_ROOT}"
  PUBLIC
    "${CMAKE_BINARY_DIR}"
    "${FATAL_INCLUDE_DIR}"
)
target_link_libraries(thrift_testset_any_generated
  PUBLIC
    thriftconformance_any_registry
    thriftcpp2
)

add_library(thriftconformance
  PluggableFunctions.cpp
  Utils.cpp
  cpp2/ConformanceHandler.cpp
  cpp2/Testing.cpp
)
target_link_libraries(thriftconformance
  PUBLIC
    thriftconformance_any_registry
    thriftconformance_generated
    thriftcpp2
    $<LINK_LIBRARY:WHOLE_ARCHIVE,thriftmetadata>
    thriftprotocol
    thrifttype
    Folly::folly
    fmt::fmt
)

# Keep entry points out of thriftconformance. Putting ConformanceServer.cpp in
# a static library allows its main() to satisfy test executables before
# gtest_main is selected, silently running the server entry point instead.
add_library(thriftconformance_json5 STATIC data/Json5Registration.cpp)
target_link_libraries(thriftconformance_json5
  PUBLIC thriftconformance
  PRIVATE $<LINK_LIBRARY:WHOLE_ARCHIVE,thrift_testset_any_generated>
)

add_executable(ConformanceServer cpp2/ConformanceServer.cpp)
target_link_libraries(ConformanceServer PRIVATE thriftconformance_json5)

add_executable(ConformanceRPCClient cpp2/RPCClient.cpp)
target_link_libraries(ConformanceRPCClient PRIVATE thriftconformance)

file(GLOB CONFORMANCE_ROOT_HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/*.h")
install(
  FILES ${CONFORMANCE_ROOT_HEADERS}
  DESTINATION ${INCLUDE_INSTALL_DIR}/thrift/conformance
)
install(
  DIRECTORY cpp2
  DESTINATION ${INCLUDE_INSTALL_DIR}/thrift/conformance
  FILES_MATCHING PATTERN "*.h" PATTERN "*.tcc"
)
install(
  DIRECTORY if
  DESTINATION ${INCLUDE_INSTALL_DIR}/thrift/conformance
  FILES_MATCHING PATTERN "*.thrift"
)
install(
  FILES ${CONFORMANCE_GENERATED_THRIFT_HEADERS}
  DESTINATION ${INCLUDE_INSTALL_DIR}/thrift/conformance/if/gen-cpp2
)

if (enable_tests)
  include(GoogleTest)

  set(CONFORMANCE_CPP2_TESTS
    UtilsTest
    cpp2/AnyRefTest
    cpp2/AnyRegistryTest
    cpp2/AnySerializerTest
    cpp2/AnyStructSerializerTest
    cpp2/AnyTest
    cpp2/ProtocolTest
    cpp2/TestValueTest
    cpp2/TestingTest
    cpp2/ThriftTypeInfoTest
  )

  set(CONFORMANCE_TEST_TARGETS)
  foreach (test_path ${CONFORMANCE_CPP2_TESTS})
    get_filename_component(test_name "${test_path}" NAME)
    set(test_target "Conformance_${test_name}")
    add_executable(${test_target} ${test_path}.cpp)
    target_link_libraries(${test_target}
      PRIVATE
        GTest::gtest_main
        GTest::gmock
        thriftconformance
    )
    if (test_name STREQUAL "TestValueTest")
      # The generated registration entry point lives in testset_sinit.cpp and
      # has no ordinary referenced symbol. Preserve that object and the split
      # registration units without whole-archiving the broader runtime.
      target_link_libraries(${test_target} PRIVATE
        $<LINK_LIBRARY:WHOLE_ARCHIVE,thrift_testset_any_generated>)
      # The registration matrix makes process startup intentionally expensive.
      # Run the complete typed suite in one process instead of paying that cost
      # once during discovery and again for every discovered case.
      add_test(NAME "Conformance.${test_name}" COMMAND ${test_target})
      set_tests_properties(
        "Conformance.${test_name}" PROPERTIES LABELS "conformance")
    else ()
      gtest_discover_tests(
        ${test_target}
        TEST_PREFIX "Conformance."
        PROPERTIES LABELS "conformance"
      )
    endif ()
    list(APPEND CONFORMANCE_TEST_TARGETS ${test_target})
  endforeach ()

  add_custom_target(conformance_tests DEPENDS ${CONFORMANCE_TEST_TARGETS})
endif ()
