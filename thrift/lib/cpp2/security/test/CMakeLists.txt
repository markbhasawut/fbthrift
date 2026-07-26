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

set(SECURITY_TESTS
  SSLUtilTest
  StopTLSTest
  ThriftTLSHandshakeTest
)

foreach (test_name ${SECURITY_TESTS})
  add_executable(Security_${test_name}
    ${test_name}.cpp
  )
  target_link_libraries(Security_${test_name}
    PUBLIC
      GTest::gmock
      GTest::gtest_main
      thriftcpp2
      thriftprotocol
      Folly::folly
      fmt::fmt
  )
  if (test_name STREQUAL "ThriftTLSHandshakeTest")
    target_link_libraries(Security_${test_name}
      PUBLIC fizz::fizz_test_support)
  endif ()
  gtest_discover_tests(Security_${test_name})
endforeach ()

set(SECURITY_EXTENSION_TESTS
  extensions/test/ThriftParametersClientExtensionTest
  extensions/test/ThriftParametersServerExtensionTest
  extensions/test/ThriftParametersStopTLSExtensionTest
  extensions/test/ThriftParametersTest
)

foreach (test_path ${SECURITY_EXTENSION_TESTS})
  get_filename_component(test_name "${test_path}" NAME)
  add_executable(Security_${test_name}
    ../${test_path}.cpp
  )
  target_link_libraries(Security_${test_name}
    PUBLIC
      GTest::gtest_main
      thriftcpp2
      thriftprotocol
      Folly::folly
      fmt::fmt
  )
  gtest_discover_tests(Security_${test_name})
endforeach ()
