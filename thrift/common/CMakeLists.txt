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

set(COMPILER_DIR ${CMAKE_CURRENT_BINARY_DIR})

add_library(
  common

  detail/string.cc
  tree_printer.cc
  universal_name.cc
)

install(
  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/
  DESTINATION ${INCLUDE_INSTALL_DIR}/thrift/common
  FILES_MATCHING PATTERN "*.h" PATTERN "*.tcc"
)

# common is used by both compiler and runtime exports. Export it at its owning
# directory so compiler-only, library-only, and full builds all produce a
# self-contained FBThriftTargets.cmake.
install(
  TARGETS common
  EXPORT fbthrift-exports
  DESTINATION ${LIB_INSTALL_DIR}
)

target_link_libraries(
  common
  Boost::boost
  fmt::fmt
)

if (enable_tests)
  include(GoogleTest)
  set(COMMON_TEST_TARGETS)
  foreach (test_name tree_printer_test universal_name_test)
    set(test_target "Common_${test_name}")
    add_executable(${test_target}
      test/${test_name}.cc
    )
    target_link_libraries(${test_target}
      PRIVATE
        GTest::gtest_main
        common
        Folly::folly
        fmt::fmt
    )
    gtest_discover_tests(
      ${test_target}
      TEST_PREFIX "Common."
      PROPERTIES LABELS "common"
    )
    list(APPEND COMMON_TEST_TARGETS ${test_target})
  endforeach ()

  add_custom_target(common_tests DEPENDS ${COMMON_TEST_TARGETS})
endif ()
