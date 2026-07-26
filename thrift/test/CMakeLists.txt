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

set(THRIFT_TEST_IDLS
  adapter_no_uri
  adapter_terse
  clear
  container_size
  copy
  cpp_name
  ensure
  enum
  field_interceptor
  field_ref_codegen
  get_value_or_null
  inject_metadata_fields
  inject_metadata_fields_annot
  minimize_padding
  optionals
  qualified_enum
  schema
  schema_evolution_test
  structs
  structs_terse
  test
  traits
  transitive
  AnyTest1
  AnyTest2
  AnyTest3
  Bitpack
  Cpp2OpsNative
  CppAllocatorTest
  CustomStruct
  DebugProtoTest
  DefaultValuesTest
  DocTest
  DynamicTest
  ExceptionTest
  ExceptionThrowing
  FastProto
  FieldMask
  FieldNameAccess
  FieldRefConstPropagation
  FloatTest
  GetterSetterTest
  HashMapTest
  HashSetTest
  IOBufPtrTest
  ManyTypedefs
  MixinTest
  MixinTestStrict
  NoExcept
  OptionalRequiredTest
  OrderTest
  ProtocolMethodsTest
  ProtocolTruncatedData
  Recursive
  Recursive2
  References
  ReferencesConstants
  SerializationInFieldIdOrder
  SplitsTest
  ThriftTest
  TopologicallySortObjectsTest
  UnionFieldRef
  UnionTest
  UnionTest2
  UnionTest3
  UnionThriftBoxRandomTest
  UseOpEncode
  UseOpEncodeProgram
)

# These IDLs intentionally reuse generated service basenames or qualified C++
# type names. Keep their include paths and object files isolated so generated
# headers cannot resolve to an unrelated fixture and schema symbols remain
# ODR-safe.
set(THRIFT_TEST_ISOLATED_IDLS
  clear
  copy
  cpp_name
  ensure
  traits
  schema
  FieldMask
  FieldNameAccess
  FieldRefConstPropagation
  FloatTest
  HashMapTest
  HashSetTest
  NoExcept
  OptionalRequiredTest
  ProtocolMethodsTest
  Recursive
  ReferencesConstants
  SerializationInFieldIdOrder
  SplitsTest
  UnionFieldRef
  UnionTest
  UnionTest2
  UseOpEncode
  DebugProtoTest
  DocTest
  ThriftTest
  get_value_or_null
  structs
)

set(THRIFT_TEST_SERVICES_adapter AdapterService)
set(THRIFT_TEST_SERVICES_cpp_name MyService)
set(THRIFT_TEST_SERVICES_schema EmptyService TestService)
set(THRIFT_TEST_SERVICES_CustomStruct CustomStruct)
set(THRIFT_TEST_SERVICES_DebugProtoTest
  Srv Inherited EmptyService ReverseOrderService)
set(THRIFT_TEST_SERVICES_DocTest ThriftTest)
set(THRIFT_TEST_SERVICES_DynamicTest DynamicTestService)
set(THRIFT_TEST_SERVICES_ExceptionThrowing ExceptionThrowingService)
set(THRIFT_TEST_SERVICES_IOBufPtrTest IOBufPtrTestService)
set(THRIFT_TEST_SERVICES_ManyTypedefs AService)
set(THRIFT_TEST_SERVICES_SplitsTest Service1 Service2)
set(THRIFT_TEST_SERVICES_ThriftTest ThriftTest SecondService)

set(THRIFT_TEST_OPTIONS_cpp_name "json")
set(THRIFT_TEST_OPTIONS_CppAllocatorTest "json")
set(THRIFT_TEST_OPTIONS_Recursive "json")
set(THRIFT_TEST_OPTIONS_Recursive2 "json")
set(THRIFT_TEST_OPTIONS_schema_evolution_test "json")
set(THRIFT_TEST_OPTIONS_SplitsTest "json")
set(THRIFT_TEST_OPTIONS_UseOpEncode "json")
set(THRIFT_TEST_OPTIONS_UseOpEncodeProgram "json")

set(TEST_GENERATED_THRIFT_HEADERS)
set(TEST_GENERATED_INCLUDE_ROOTS)
set(TEST_GENERATED_THRIFT_SOURCES)
foreach (thrift_file ${THRIFT_TEST_IDLS})
  set(generated_target_name "root_test_${thrift_file}")
  set(generated_include_root
    "${CMAKE_CURRENT_BINARY_DIR}/generated/${thrift_file}")
  set(generated_output_path
    "${generated_include_root}/thrift/test")
  set(generated_options "")
  if (DEFINED THRIFT_TEST_OPTIONS_${thrift_file})
    set(generated_options "${THRIFT_TEST_OPTIONS_${thrift_file}}")
  endif ()
  file(MAKE_DIRECTORY "${generated_output_path}")
  thrift_generate(
    "${thrift_file}"
    "${THRIFT_TEST_SERVICES_${thrift_file}}"
    "cpp2"
    "${generated_options}"
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${generated_output_path}"
    "thrift/test"
    NO_INSTALL
    COMPILER thrift1
    THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
    TARGET_NAME_BASE "${generated_target_name}"
  )
  list(APPEND TEST_GENERATED_THRIFT_HEADERS
    ${${generated_target_name}-cpp2-HEADERS})
  list(APPEND TEST_GENERATED_INCLUDE_ROOTS
    "${generated_include_root}")
  if (thrift_file IN_LIST THRIFT_TEST_ISOLATED_IDLS)
    set("THRIFT_TEST_${thrift_file}_INCLUDE_ROOT" "${generated_include_root}")
    set("THRIFT_TEST_${thrift_file}_SOURCES"
      ${${generated_target_name}-cpp2-SOURCES})
  else ()
    list(APPEND TEST_GENERATED_THRIFT_SOURCES
      ${${generated_target_name}-cpp2-SOURCES})
  endif ()
endforeach ()

# FieldRefTraitsTest also exercises terse-write field references. Generate this
# subdirectory fixture into its logical include prefix and compile it into the
# same shared fixture archive as the non-colliding root test IDLs.
set(terse_write_generated_include_root
  "${CMAKE_CURRENT_BINARY_DIR}/generated/terse_write")
set(terse_write_generated_output_path
  "${terse_write_generated_include_root}/thrift/test/terse_write")
file(MAKE_DIRECTORY "${terse_write_generated_output_path}")
thrift_generate(
  "terse_write"
  ""
  "cpp2"
  ""
  "${CMAKE_CURRENT_SOURCE_DIR}/terse_write"
  "${terse_write_generated_output_path}"
  "thrift/test/terse_write"
  NO_INSTALL
  COMPILER thrift1
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  TARGET_NAME_BASE "root_test_terse_write"
)
list(APPEND TEST_GENERATED_THRIFT_HEADERS
  ${root_test_terse_write-cpp2-HEADERS})
list(APPEND TEST_GENERATED_INCLUDE_ROOTS
  "${terse_write_generated_include_root}")
list(APPEND TEST_GENERATED_THRIFT_SOURCES
  ${root_test_terse_write-cpp2-SOURCES})

# Compile the IDL closure once. The old form placed every generated source in
# every test executable, producing tens of thousands of duplicate Ninja edges.
add_library(thrift_test_fixture_dependencies INTERFACE)
target_include_directories(
  thrift_test_fixture_dependencies INTERFACE ${TEST_GENERATED_INCLUDE_ROOTS})
target_link_libraries(thrift_test_fixture_dependencies
  INTERFACE
    cpp2_test_adapter_generated
    thriftconformance_generated
    thriftcpp2
    thriftmetadata
    thriftprotocol
    thrifttype
    thriftanyrep
    Folly::folly
    fmt::fmt
)

add_library(thrift_test_generated STATIC ${TEST_GENERATED_THRIFT_SOURCES})
target_include_directories(thrift_test_generated
  PUBLIC
    ${TEST_GENERATED_INCLUDE_ROOTS}
)
target_link_libraries(
  thrift_test_generated PUBLIC thrift_test_fixture_dependencies)

set(THRIFT_TEST_ISOLATED_TARGETS)
foreach (thrift_file ${THRIFT_TEST_ISOLATED_IDLS})
  set(isolated_target "thrift_test_${thrift_file}_generated")
  add_library(${isolated_target} STATIC ${THRIFT_TEST_${thrift_file}_SOURCES})
  target_include_directories(${isolated_target}
    BEFORE PUBLIC "${THRIFT_TEST_${thrift_file}_INCLUDE_ROOT}"
  )
  target_link_libraries(
    ${isolated_target} PUBLIC thrift_test_fixture_dependencies)
  list(APPEND THRIFT_TEST_ISOLATED_TARGETS ${isolated_target})
endforeach ()
target_sources(thrift_test_ThriftTest_generated PRIVATE ThriftTest_extras.cpp)

set(THRIFT_CPP2_TESTS
  AdapterTest
  AnyDebugWriterTest
  AnyTest
  BitPackTest
  BufferBaseTest
  ClearTest
  CompactProtocolTest
  CompressTest
  ConstantsTest
  ContainerSizeTest
  CopyTest
  Cpp2OpsTest
  Cpp2ProtocolTest
  CppAllocatorTest
  CppNameTest
  CustomStructTest
  DebugProtoTest
  DynamicCpp2Test
  EnumTestCpp2
  ExceptionTest
  ExceptionThrowingTest
  ExpectThriftEqTest
  FieldInterceptorTest
  FieldMaskTest
  FieldNameAccessTest
  FieldRefCodegenTest
  FieldRefConstPropagationTest
  FieldRefTest
  FieldRefTraitsTest
  FloatTest
  GetterSetterCpp2Test
  HashMapTest
  HashSetTest
  IOBufPtrTest
  InjectMetadataFieldsTest
  JSONProtoTest
  MinimizePaddingTest
  MixinTest
  NoExceptTest
  OptionalsTest
  OrderTest
  PatchTest
  ProtocolMethodsTest
  ProtocolSkipTest
  ProtocolTruncatedDataTest
  QualifiedEnumTest
  RecursiveCppTest
  ReferencesConstantsCpp2Test
  ReferencesCpp2Test
  ReservedIdTest
  SchemaEvolutionTest
  SchemaTest
  SerializationInFieldIdOrderTest
  SerializationRoundTripTest
  SplitsTest
  StructTest
  SwapTest
  THeaderTest
  ThriftTypeInfoTest
  TopologicallySortObjectsTest
  TraitsTest
  TransitiveTest
  TransportTest
  UnionFieldRefTest
  UnionTest2
  UnionThriftBoxRandomTest
  UseOpEncodeTest
  VarintTest
  ZlibTest
)

set(THRIFT_TEST_FIXTURES_ClearTest clear)
set(THRIFT_TEST_FIXTURES_CompressTest ThriftTest)
set(THRIFT_TEST_FIXTURES_CopyTest copy)
set(THRIFT_TEST_FIXTURES_Cpp2ProtocolTest DebugProtoTest)
set(THRIFT_TEST_FIXTURES_CppNameTest cpp_name)
set(THRIFT_TEST_FIXTURES_DebugProtoTest DebugProtoTest)
set(THRIFT_TEST_FIXTURES_ExpectThriftEqTest structs)
set(THRIFT_TEST_FIXTURES_FieldMaskTest FieldMask)
set(THRIFT_TEST_FIXTURES_FieldNameAccessTest FieldNameAccess)
set(THRIFT_TEST_FIXTURES_FieldRefConstPropagationTest
  FieldRefConstPropagation)
set(THRIFT_TEST_FIXTURES_FloatTest FloatTest)
set(THRIFT_TEST_FIXTURES_HashMapTest HashMapTest)
set(THRIFT_TEST_FIXTURES_HashSetTest HashSetTest)
set(THRIFT_TEST_FIXTURES_InjectMetadataFieldsTest clear)
set(THRIFT_TEST_FIXTURES_JSONProtoTest DebugProtoTest)
set(THRIFT_TEST_FIXTURES_NoExceptTest NoExcept)
set(THRIFT_TEST_FIXTURES_ProtocolMethodsTest ProtocolMethodsTest)
set(THRIFT_TEST_FIXTURES_RecursiveCppTest Recursive)
set(THRIFT_TEST_FIXTURES_ReferencesConstantsCpp2Test ReferencesConstants)
set(THRIFT_TEST_FIXTURES_SchemaTest schema UseOpEncode)
set(THRIFT_TEST_FIXTURES_SerializationInFieldIdOrderTest
  SerializationInFieldIdOrder)
set(THRIFT_TEST_FIXTURES_SplitsTest SplitsTest)
set(THRIFT_TEST_FIXTURES_StructTest structs)
set(THRIFT_TEST_FIXTURES_SwapTest OptionalRequiredTest ThriftTest)
set(THRIFT_TEST_FIXTURES_TraitsTest traits)
set(THRIFT_TEST_FIXTURES_UnionFieldRefTest UnionFieldRef)
set(THRIFT_TEST_FIXTURES_UnionTest2 UnionTest2)
set(THRIFT_TEST_FIXTURES_UseOpEncodeTest UseOpEncode)

# These binaries contain large randomized/typed matrices or parameter names
# that span multiple lines. Expanding every case into CTest makes discovery
# dominate configuration, creates more than ten thousand entries, and can
# misparse parameter values as test names. Keep these matrices aggregated.
set(THRIFT_TEST_AGGREGATED_TESTS
  BitPackTest
  DebugProtoTest
  SerializationRoundTripTest
  TransportTest
  UnionThriftBoxRandomTest
)

set(THRIFT_TEST_TARGETS)
foreach (test_name ${THRIFT_CPP2_TESTS})
  set(test_target "ThriftTest_${test_name}")
  add_executable(${test_target} ${test_name}.cpp)
  target_link_libraries(${test_target}
    PRIVATE
      GTest::gtest_main
      GTest::gmock
  )
  foreach (fixture ${THRIFT_TEST_FIXTURES_${test_name}})
    target_include_directories(${test_target}
      BEFORE PRIVATE "${THRIFT_TEST_${fixture}_INCLUDE_ROOT}")
    target_link_libraries(${test_target}
      PRIVATE thrift_test_${fixture}_generated)
  endforeach ()
  # Keep the shared closure after isolated fixtures. An isolated IDL may
  # include a non-colliding IDL from this archive (for example Recursive
  # includes Recursive2), and static linkers resolve that edge left-to-right.
  target_link_libraries(${test_target}
    PRIVATE
      thrift_test_generated
      ZLIB::ZLIB
  )
  if (test_name STREQUAL "CompressTest")
    target_link_libraries(${test_target}
      PRIVATE Folly::follybenchmark)
  elseif (test_name MATCHES "^(SerializationRoundTripTest|FieldRefTraitsTest)$")
    target_link_libraries(${test_target} PRIVATE thrift_testset_generated)
  elseif (test_name MATCHES "^(Any|ThriftTypeInfo|UseOpEncode)Test$")
    target_link_libraries(${test_target} PRIVATE thriftconformance)
  endif ()
  if (test_name STREQUAL "UnionThriftBoxRandomTest")
    # The optimized matrix is a billion iterations (1000 seeds x 1M). Keep the
    # complete matrix in the executable for explicit stress runs, but make the
    # default CTest entry a deterministic one-seed smoke test.
    add_test(
      NAME "ThriftTest.${test_name}"
      COMMAND ${test_target}
              --gtest_filter=RandomTest/RandomTestWithSeed.test/0)
    set_tests_properties(
      "ThriftTest.${test_name}" PROPERTIES LABELS "thrift-test;smoke")
  elseif (test_name IN_LIST THRIFT_TEST_AGGREGATED_TESTS)
    add_test(NAME "ThriftTest.${test_name}" COMMAND ${test_target})
    set_tests_properties(
      "ThriftTest.${test_name}" PROPERTIES LABELS "thrift-test")
  else ()
    gtest_discover_tests(
      ${test_target}
      TEST_PREFIX "ThriftTest."
      PROPERTIES LABELS "thrift-test"
    )
  endif ()
  list(APPEND THRIFT_TEST_TARGETS ${test_target})
endforeach ()

add_custom_target(thrift_root_tests
  DEPENDS
    ${THRIFT_TEST_TARGETS}
    ${THRIFT_TEST_ISOLATED_TARGETS}
)
