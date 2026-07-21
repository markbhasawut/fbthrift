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

set(DEBUG_DIFF_TESTS
  debug_test
  diff_test
  pretty_print_test
)

foreach (test_name ${DEBUG_DIFF_TESTS})
  add_executable(DebugDiff_${test_name}
    ${test_name}.cpp
  )
  target_link_libraries(DebugDiff_${test_name}
    PUBLIC
      GTest::gtest_main
      thriftcpp2
      thriftprotocol
      Folly::folly
      fmt::fmt
  )
  gtest_discover_tests(DebugDiff_${test_name})
endforeach ()
