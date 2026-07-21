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

foreach (thrift_file ${CONFORMANCE_IDLS})
  thrift_generate(
     "${thrift_file}" #file_name
     "" #services
     "cpp2" #language
     "frozen2" #options
     "${CMAKE_CURRENT_SOURCE_DIR}/if" #file_path
     "${CMAKE_CURRENT_BINARY_DIR}/if" #output_path
     "thrift/conformance/if" #include_prefix
     THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )
  set_source_files_properties(${thrift_file} PROPERTIES GENERATED TRUE)
  set(CONFORMANCE_GENERATED_THRIFT_SOURCES ${CONFORMANCE_GENERATED_THRIFT_SOURCES}
      ${${thrift_file}-cpp2-SOURCES})
endforeach ()

add_library(thriftconformance
  GTestHarness.cpp
  PluggableFunctions.cpp
  Utils.cpp
  cpp2/Any.cpp
  cpp2/AnyRef.cpp
  cpp2/AnyRegistry.cpp
  cpp2/AnySerializer.cpp
  cpp2/AnyTest.cpp
  cpp2/ConformanceHandler.cpp
  cpp2/ConformanceServer.cpp
  cpp2/Protocol.cpp
  cpp2/RPCClient.cpp
  cpp2/Testing.cpp
  cpp2/ThriftTypeInfo.cpp
  ${CONFORMANCE_GENERATED_THRIFT_SOURCES}
)
target_link_libraries(thriftconformance
  PUBLIC
    thriftcpp2
    thriftprotocol
    thrifttype
    Folly::folly
    fmt::fmt
)

# Install includes
file(GLOB CONFORMANCE_ROOT_HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/*.h")
install(
  FILES ${CONFORMANCE_ROOT_HEADERS}
  DESTINATION ${INCLUDE_INSTALL_DIR}/thrift/conformance
)
install(
  DIRECTORY cpp2 if
  DESTINATION ${INCLUDE_INSTALL_DIR}/thrift/conformance
  FILES_MATCHING PATTERN "*.h" PATTERN "*.tcc"
)

if (enable_tests)
  include(GoogleTest)

  set(CONFORMANCE_CPP2_TESTS
    UtilsTest
    cpp2/AnyRefTest
    cpp2/AnyRegistryTest
    cpp2/AnySerializerTest
    cpp2/AnyStructSerializerTest
    cpp2/ProtocolTest
    cpp2/TestValueTest
    cpp2/TestingTest
    cpp2/ThriftTypeInfoTest
  )

  foreach (test_path ${CONFORMANCE_CPP2_TESTS})
    get_filename_component(test_name "${test_path}" NAME)
    add_executable(Conformance_${test_name}
      ${test_path}.cpp
    )
    target_link_libraries(Conformance_${test_name}
      PUBLIC
        GTest::gtest_main
        thriftconformance
        thriftcpp2
        thriftprotocol
        thrifttype
        Folly::folly
        fmt::fmt
    )
    gtest_discover_tests(Conformance_${test_name})
  endforeach ()
endif ()
