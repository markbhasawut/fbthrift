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
  adapter
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

foreach (thrift_file ${THRIFT_TEST_IDLS})
  thrift_generate(
     "${thrift_file}" #file_name
     "" #services
     "cpp2" #language
     "frozen2" #options
     "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
     "${CMAKE_CURRENT_BINARY_DIR}" #output_path
     "thrift/test" #include_prefix
     THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )
  set_source_files_properties(${thrift_file} PROPERTIES GENERATED TRUE)
  set(TEST_GENERATED_THRIFT_SOURCES ${TEST_GENERATED_THRIFT_SOURCES}
      ${${thrift_file}-cpp2-SOURCES})
endforeach ()

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
  UnionTest2
  UnionThriftBoxRandomTest
  UseOpEncodeTest
  VarintTest
  ZlibTest
)

foreach (test_name ${THRIFT_CPP2_TESTS})
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
