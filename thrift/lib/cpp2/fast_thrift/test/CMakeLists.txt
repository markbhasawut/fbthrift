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

# Channel Pipeline Tests
set(FAST_THRIFT_PIPELINE_TESTS
  BackpressureTest
  DelayedDestructionTest
  EventTest
  HandlerNodeTest
  PipelineBuilderTest
  PipelineImplTest
  TypeErasedBoxTest
)

foreach (test_name ${FAST_THRIFT_PIPELINE_TESTS})
  add_executable(FastThrift_${test_name}
    ../channel_pipeline/test/${test_name}.cpp
  )
  target_link_libraries(FastThrift_${test_name}
    PUBLIC
      GTest::gmock
      GTest::gtest_main
      thriftcpp2
      Folly::folly
      fmt::fmt
  )
  gtest_discover_tests(FastThrift_${test_name})
endforeach ()

# Frame Tests
set(FAST_THRIFT_FRAME_TESTS
  frame/test/FrameDescriptorTest
  frame/read/test/DirectStreamMapTest
  frame/read/test/FrameMetadataTest
  frame/read/test/FrameParserTest
  frame/read/test/FrameViewsTest
  frame/read/test/ParsedFrameTest
  frame/read/handler/test/FrameDefragmentationHandlerTest
  frame/read/handler/test/FrameLengthParserHandlerTest
  frame/write/test/FrameWriterTest
  frame/write/test/SrptHeapTest
  frame/write/handler/test/BatchingFrameHandlerTest
  frame/write/handler/test/FragmentCompletionTrackerTest
  frame/write/handler/test/FrameFragmentationHandlerTest
  frame/write/handler/test/FrameLengthEncoderHandlerTest
  frame/write/handler/test/IntervalBatchingFrameHandlerTest
  frame/write/handler/test/LoopBatchingFrameHandlerTest
  frame/write/handler/test/WriteCompletionTrackerTest
  frame/handler/test/FrameWriteCompletionHandlerTest
)

foreach (test_path ${FAST_THRIFT_FRAME_TESTS})
  get_filename_component(test_name "${test_path}" NAME)
  add_executable(FastThrift_${test_name}
    ../${test_path}.cpp
  )
  target_link_libraries(FastThrift_${test_name}
    PUBLIC
      GTest::gmock
      GTest::gtest_main
      thriftcpp2
      Folly::folly
      fmt::fmt
  )
  gtest_discover_tests(FastThrift_${test_name})
endforeach ()

# Connection & Security Tests
set(FAST_THRIFT_CONN_TESTS
  connection/test/ConnectionHandlerTest
  connection/test/ConnectionManagerTest
  connection/test/ConnectionPipelineIntegrationTest
  connection/security/util/test/StopTLSHelperTest
  security/test/FizzHandshakeHelperTest
  security/test/FizzServerContextBuilderTest
)

foreach (test_path ${FAST_THRIFT_CONN_TESTS})
  get_filename_component(test_name "${test_path}" NAME)
  add_executable(FastThrift_${test_name}
    ../${test_path}.cpp
  )
  target_link_libraries(FastThrift_${test_name}
    PUBLIC
      GTest::gmock
      GTest::gtest_main
      thriftcpp2
      Folly::folly
      fmt::fmt
  )
  gtest_discover_tests(FastThrift_${test_name})
endforeach ()

# Transport Tests
add_executable(FastThrift_TransportHandlerTest
  ../transport/test/TransportHandlerTest.cpp
)
target_link_libraries(FastThrift_TransportHandlerTest
  PUBLIC
    GTest::gmock
    GTest::gtest_main
    thriftcpp2
    Folly::folly
    fmt::fmt
)
gtest_discover_tests(FastThrift_TransportHandlerTest)
