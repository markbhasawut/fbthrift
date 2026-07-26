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

set(service_descriptor_test_SERVICES ServiceDescriptorTestService)

foreach (thrift_file digest_expected_values digest_fixture_enum digest_fixture_multiple_types digest_fixture_single_empty_struct digest_fixture_struct_with_fields service_catalog_digest_expected_values service_descriptor_test)
  thrift_generate(
     "${thrift_file}" #file_name
     "${${thrift_file}_SERVICES}" #services
     "cpp2" #language
     "" #options
     "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
     "${CMAKE_CURRENT_BINARY_DIR}" #output_path
     "thrift/lib/cpp2/dynamic/test" #include_prefix
     THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )
  bypass_source_check(${${thrift_file}-cpp2-SOURCES})
  set(DYNAMIC_TEST_GENERATED_THRIFT_SOURCES ${DYNAMIC_TEST_GENERATED_THRIFT_SOURCES}
      ${${thrift_file}-cpp2-SOURCES})
endforeach ()

set(DYNAMIC_TEST_SYNTAX_GRAPH_OUTPUT
  "${CMAKE_BINARY_DIR}/thrift/lib/cpp2/schema/test")
file(MAKE_DIRECTORY "${DYNAMIC_TEST_SYNTAX_GRAPH_OUTPUT}")
thrift_generate(
  "syntax_graph"
  "TestService;ServiceWithDocBlock"
  "cpp2"
  ""
  "${THRIFT_SOURCE_DIR}/thrift/lib/cpp2/schema/test"
  "${DYNAMIC_TEST_SYNTAX_GRAPH_OUTPUT}"
  "thrift/lib/cpp2/schema/test"
  TARGET_NAME_BASE "dynamic_test_syntax_graph"
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)
list(APPEND DYNAMIC_TEST_GENERATED_THRIFT_SOURCES
  ${dynamic_test_syntax_graph-cpp2-SOURCES})

add_library(dynamic_test_generated STATIC
  ${DYNAMIC_TEST_GENERATED_THRIFT_SOURCES})
target_link_libraries(dynamic_test_generated PUBLIC thriftcpp2)

set(DYNAMIC_TESTS
  AccumulatingTypeSystemTest
  AnyTest
  DefinitionNodeNameTest
  DynamicValueTest
  ListTest
  MapTest
  PathTest
  SerializableRecordTest
  ServiceCatalogDigestTest
  ServiceCatalogTest
  ServiceDescriptorSerializationTest
  ServiceDescriptorTest
  SetTest
  SmallBufferTest
  StringBinaryTest
  StructTest
  TypeIdTest
  TypeSystemBuilderDeriveTest
  TypeSystemDigestFixtureTest
  TypeSystemDigestTest
  TypeSystemPrunerTest
  TypeSystemTest
  UnionTest
)
if (NOT EXISTS "${THRIFT_SOURCE_DIR}/tools/cxx/Resources.h")
  message(STATUS
    "Skipping TypeSystemDigestFixtureTest: fbcode resource support is absent")
  list(REMOVE_ITEM DYNAMIC_TESTS TypeSystemDigestFixtureTest)
endif ()

foreach (test_name ${DYNAMIC_TESTS})
  add_executable(Dynamic_${test_name}
    ${test_name}.cpp
  )
  target_link_libraries(Dynamic_${test_name}
    PUBLIC
      GTest::gtest_main
      dynamic_test_generated
      thrift_dynamic_value
      thriftmetadata
      thriftcpp2
      thriftprotocol
      Folly::folly
      fmt::fmt
  )
  gtest_discover_tests(Dynamic_${test_name})
endforeach ()
