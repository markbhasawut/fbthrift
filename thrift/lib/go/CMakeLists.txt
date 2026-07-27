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

find_program(THRIFT_GO_EXECUTABLE go REQUIRED)

set(THRIFT_GO_STRESS_REQUESTS 1000 CACHE STRING
  "Requests per transport in the explicit thrift-go-stress target")

set(_go_test_script "${CMAKE_CURRENT_SOURCE_DIR}/run_oss_tests.sh")
set(_go_test_root "${CMAKE_CURRENT_BINARY_DIR}/oss-tests")

function(add_thrift_go_suite suite)
  set(target "thrift-go-${suite}")
  add_custom_target(${target}
    COMMAND
      "${CMAKE_COMMAND}" -E env
      "THRIFT_GO_EXECUTABLE=${THRIFT_GO_EXECUTABLE}"
      "${_go_test_script}"
      "$<TARGET_FILE:thrift1>"
      "${_go_test_root}/${suite}"
      "${suite}"
      "${THRIFT_GO_STRESS_REQUESTS}"
    DEPENDS
      thrift1
      "${_go_test_script}"
    USES_TERMINAL
    VERBATIM
  )
endfunction()

add_thrift_go_suite(smoke)
add_thrift_go_suite(fixtures)
add_thrift_go_suite(conformance)
add_thrift_go_suite(stress)

add_custom_target(thrift-go-check)
add_dependencies(thrift-go-check
  thrift-go-smoke
  thrift-go-fixtures
  thrift-go-conformance
)

if(enable_tests)
  add_test(
    NAME ThriftGo.smoke
    COMMAND
      "${CMAKE_COMMAND}" -E env
      "THRIFT_GO_EXECUTABLE=${THRIFT_GO_EXECUTABLE}"
      "${_go_test_script}"
      "$<TARGET_FILE:thrift1>"
      "${_go_test_root}/ctest-smoke"
      smoke
  )
  add_test(
    NAME ThriftGo.fixtures
    COMMAND
      "${CMAKE_COMMAND}" -E env
      "THRIFT_GO_EXECUTABLE=${THRIFT_GO_EXECUTABLE}"
      "${_go_test_script}"
      "$<TARGET_FILE:thrift1>"
      "${_go_test_root}/ctest-fixtures"
      fixtures
  )
  add_test(
    NAME ThriftGo.conformance-build
    COMMAND
      "${CMAKE_COMMAND}" -E env
      "THRIFT_GO_EXECUTABLE=${THRIFT_GO_EXECUTABLE}"
      "${_go_test_script}"
      "$<TARGET_FILE:thrift1>"
      "${_go_test_root}/ctest-conformance"
      conformance
  )
  set_tests_properties(
    ThriftGo.smoke
    ThriftGo.fixtures
    ThriftGo.conformance-build
    PROPERTIES
      LABELS "go"
      TIMEOUT 600
  )
endif()
