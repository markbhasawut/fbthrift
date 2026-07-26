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

# Generate required Thrift dependencies for transcode tests.
foreach (thrift_file GoldenFixtures InterpreterRoundTripFixtures)
  thrift_generate(
     "${thrift_file}" #file_name
     "" #services
     "cpp2" #language
     "" #options
     "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
     "${CMAKE_CURRENT_BINARY_DIR}" #output_path
     "thrift/lib/cpp2/transcode/test" #include_prefix
     THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  )
  bypass_source_check(${${thrift_file}-cpp2-SOURCES})
  set(TRANSCODE_GENERATED_THRIFT_SOURCES ${TRANSCODE_GENERATED_THRIFT_SOURCES}
      ${${thrift_file}-cpp2-SOURCES})
endforeach ()

add_library(transcode_test_generated STATIC
  ${TRANSCODE_GENERATED_THRIFT_SOURCES})
target_link_libraries(transcode_test_generated PUBLIC thriftcpp2)

# Test executables
set(TRANSCODE_TESTS
  BinaryIntrinsicsTest
  CodecFactoryTest
  CompactIntrinsicsTest
  CursorTest
  InterpreterJsonReadTest
  InterpreterRoundTripTest
  IntrinsicsCommonTest
  JsonReadPrimitivesTest
  PlanFuseTest
  ProtobufIntrinsicsTest
  TranscoderTest
  WireTypeGuardTest
)

foreach (test_name ${TRANSCODE_TESTS})
  add_executable(${test_name}
     ${test_name}.cpp)
  target_link_libraries(${test_name}
     PUBLIC
       GTest::gtest_main
       transcode_test_generated
       thrifttranscode
       thriftprotocol
       thriftcpp2
       Folly::folly
       fmt::fmt
  )
  gtest_discover_tests(${test_name})
endforeach ()

# GoldenTranscodeTest also needs GoldenTestData.cpp
add_executable(GoldenTranscodeTest
   GoldenTranscodeTest.cpp
   GoldenTestData.cpp)
target_link_libraries(GoldenTranscodeTest
   PUBLIC
     GTest::gtest_main
     transcode_test_generated
     thrifttranscode
     thriftprotocol
     thriftcpp2
     Folly::folly
     fmt::fmt
)
gtest_discover_tests(GoldenTranscodeTest)
