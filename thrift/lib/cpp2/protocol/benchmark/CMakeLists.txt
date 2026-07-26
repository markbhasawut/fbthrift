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

if (THRIFT_MCROUTER_SOURCE_DIR STREQUAL "" OR
    NOT IS_ABSOLUTE "${THRIFT_MCROUTER_SOURCE_DIR}")
  message(FATAL_ERROR
    "THRIFT_MCROUTER_SOURCE_DIR must be an absolute path to a mcrouter "
    "source checkout.")
endif ()

set(MCROUTER_CARBON_DIR
  "${THRIFT_MCROUTER_SOURCE_DIR}/mcrouter/lib/carbon")
if (NOT IS_DIRECTORY "${MCROUTER_CARBON_DIR}")
  message(FATAL_ERROR
    "THRIFT_MCROUTER_SOURCE_DIR is not an mcrouter source checkout: "
    "${THRIFT_MCROUTER_SOURCE_DIR}")
endif ()

find_package(Python3 REQUIRED COMPONENTS Interpreter)

if (NOT THRIFT_MCROUTER_CARBON_CODEGEN_EXECUTABLE STREQUAL "")
  if (NOT IS_ABSOLUTE "${THRIFT_MCROUTER_CARBON_CODEGEN_EXECUTABLE}" OR
      NOT EXISTS "${THRIFT_MCROUTER_CARBON_CODEGEN_EXECUTABLE}")
    message(FATAL_ERROR
      "THRIFT_MCROUTER_CARBON_CODEGEN_EXECUTABLE must be an existing "
      "absolute path: ${THRIFT_MCROUTER_CARBON_CODEGEN_EXECUTABLE}")
  endif ()
  set(MCROUTER_CARBON_REGEN_DRIVER
    "${CMAKE_CURRENT_SOURCE_DIR}/regenerate_mcrouter_carbon.py")
  add_custom_target(McrouterCarbonCodegen
    COMMAND
      "${Python3_EXECUTABLE}"
      "${MCROUTER_CARBON_REGEN_DRIVER}"
      --mcrouter-root "${THRIFT_MCROUTER_SOURCE_DIR}"
      --generator "${THRIFT_MCROUTER_CARBON_CODEGEN_EXECUTABLE}"
      --mode update
    DEPENDS
      "${MCROUTER_CARBON_REGEN_DRIVER}"
      "${THRIFT_MCROUTER_CARBON_CODEGEN_EXECUTABLE}"
    COMMENT "Updating mcrouter's committed Carbon outputs"
    USES_TERMINAL
    VERBATIM)
  add_custom_target(McrouterCarbonCodegenCheck
    COMMAND
      "${Python3_EXECUTABLE}"
      "${MCROUTER_CARBON_REGEN_DRIVER}"
      --mcrouter-root "${THRIFT_MCROUTER_SOURCE_DIR}"
      --generator "${THRIFT_MCROUTER_CARBON_CODEGEN_EXECUTABLE}"
      --mode check
    DEPENDS
      "${MCROUTER_CARBON_REGEN_DRIVER}"
      "${THRIFT_MCROUTER_CARBON_CODEGEN_EXECUTABLE}"
    COMMENT "Checking mcrouter's committed Carbon outputs"
    USES_TERMINAL
    VERBATIM)
endif ()

if (NOT THRIFT_CARBON_PROTOCOL_BENCHMARK)
  return()
endif ()

foreach(required_file
    carbon_result.thrift
    CarbonProtocolReader.cpp
    CarbonProtocolReader.h
    CarbonProtocolWriter.h
    CarbonQueueAppender.cpp
    CarbonQueueAppender.h)
  if (NOT EXISTS "${MCROUTER_CARBON_DIR}/${required_file}")
    message(FATAL_ERROR
      "THRIFT_MCROUTER_SOURCE_DIR does not contain "
      "mcrouter/lib/carbon/${required_file}: ${THRIFT_MCROUTER_SOURCE_DIR}")
  endif ()
endforeach ()

find_package(Protobuf CONFIG QUIET)
if (NOT Protobuf_FOUND)
  find_package(Protobuf REQUIRED)
endif ()
if (NOT COMMAND protobuf_generate)
  message(FATAL_ERROR
    "The discovered Protobuf package does not provide protobuf_generate().")
endif ()

# Carbon codegen is intentionally local to this benchmark. The OSS mcrouter
# repository commits its generated Carbon files but does not ship Meta's full
# Carbon generator. This deterministic bridge covers the benchmark IDL subset,
# emits a Thrift companion schema and Carbon serialization glue, and then lets
# the in-tree thrift1 own the ordinary C++2 generation step.
set(CARBON_CODEGEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/gen")
set(CARBON_INCLUDE_PREFIX
  "thrift/lib/cpp2/protocol/benchmark/gen")
set(CARBON_CODEGEN_OUTPUTS
  "${CARBON_CODEGEN_DIR}/CarbonTestData.h"
  "${CARBON_CODEGEN_DIR}/CarbonTestData.thrift"
  "${CARBON_CODEGEN_DIR}/CarbonTestDataMessages-decl.h"
  "${CARBON_CODEGEN_DIR}/CarbonTestDataMessages-inl.h"
  "${CARBON_CODEGEN_DIR}/CarbonTestDataMessages.cpp"
  "${CARBON_CODEGEN_DIR}/CarbonTestDataMessages.h"
  "${CARBON_CODEGEN_DIR}/CarbonTestDataMessagesThrift.cpp"
)
add_custom_command(
  OUTPUT ${CARBON_CODEGEN_OUTPUTS}
  COMMAND
    "${Python3_EXECUTABLE}"
    "${CMAKE_CURRENT_SOURCE_DIR}/generate_carbon_benchmark.py"
    --input "${CMAKE_CURRENT_SOURCE_DIR}/CarbonTestData.idl"
    --output-dir "${CARBON_CODEGEN_DIR}"
    --include-prefix "${CARBON_INCLUDE_PREFIX}"
  MAIN_DEPENDENCY "${CMAKE_CURRENT_SOURCE_DIR}/CarbonTestData.idl"
  DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/generate_carbon_benchmark.py"
  COMMENT "Generating the Carbon protocol benchmark bridge"
  VERBATIM
)
add_custom_target(CarbonProtocolBenchmarkCodegen
  DEPENDS ${CARBON_CODEGEN_OUTPUTS})

# CarbonProtocolReader/Writer include carbon::Result even though this benchmark
# has no Result field. Generate precisely that mcrouter IDL instead of linking
# the complete mcrouter library back into fbthrift and creating a package cycle.
set(CARBON_RESULT_OUTPUT_DIR
  "${CMAKE_BINARY_DIR}/mcrouter/lib/carbon")
thrift_generate(
  "carbon_result"
  ""
  "cpp2"
  "no_metadata"
  "${MCROUTER_CARBON_DIR}"
  "${CARBON_RESULT_OUTPUT_DIR}"
  "mcrouter/lib/carbon"
  TARGET_NAME_BASE "BenchmarkCarbonResult"
  THRIFT_INCLUDE_DIRECTORIES
    "${THRIFT_SOURCE_DIR}"
    "${THRIFT_MCROUTER_SOURCE_DIR}"
  NO_INSTALL
)
bypass_source_check("${BenchmarkCarbonResult-cpp2-SOURCES}")
add_library(benchmark_carbon_result STATIC
  ${BenchmarkCarbonResult-cpp2-SOURCES})
add_dependencies(benchmark_carbon_result
  BenchmarkCarbonResult-cpp2-target)
target_include_directories(benchmark_carbon_result PUBLIC
  "${CMAKE_BINARY_DIR}"
  "${THRIFT_MCROUTER_SOURCE_DIR}")
target_link_libraries(benchmark_carbon_result PUBLIC thriftcpp2)

add_library(benchmark_carbon_protocol STATIC
  "${MCROUTER_CARBON_DIR}/CarbonProtocolReader.cpp"
  "${MCROUTER_CARBON_DIR}/CarbonQueueAppender.cpp"
)
target_compile_definitions(benchmark_carbon_protocol PUBLIC
  LIBMC_FBTRACE_DISABLE
  MCROUTER_OSS_BUILD)
target_include_directories(benchmark_carbon_protocol PUBLIC
  "${CMAKE_BINARY_DIR}"
  "${THRIFT_MCROUTER_SOURCE_DIR}")
target_link_libraries(benchmark_carbon_protocol PUBLIC
  benchmark_carbon_result
  thriftcpp2
  Folly::folly)

thrift_generate(
  "CarbonTestData"
  ""
  "cpp2"
  "no_metadata"
  "${CARBON_CODEGEN_DIR}"
  "${CARBON_CODEGEN_DIR}"
  "${CARBON_INCLUDE_PREFIX}"
  THRIFT_INCLUDE_DIRECTORIES
    "${THRIFT_SOURCE_DIR}"
    "${THRIFT_MCROUTER_SOURCE_DIR}"
  NO_INSTALL
)
add_dependencies(CarbonTestData-cpp2-target
  CarbonProtocolBenchmarkCodegen)
bypass_source_check("${CarbonTestData-cpp2-SOURCES}")

thrift_generate(
  "ThriftTestData"
  ""
  "cpp2"
  "no_metadata"
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_BINARY_DIR}"
  "thrift/lib/cpp2/protocol/benchmark"
  THRIFT_INCLUDE_DIRECTORIES "${THRIFT_SOURCE_DIR}"
  NO_INSTALL
)
bypass_source_check("${ThriftTestData-cpp2-SOURCES}")

add_library(ThriftProtocolBenchmarkProtobuf STATIC
  ProtobufTestData.proto)
target_link_libraries(ThriftProtocolBenchmarkProtobuf PUBLIC
  protobuf::libprotobuf)
target_include_directories(ThriftProtocolBenchmarkProtobuf PUBLIC
  "${CMAKE_BINARY_DIR}")
protobuf_generate(
  TARGET ThriftProtocolBenchmarkProtobuf
  LANGUAGE cpp
  PROTOC_OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}"
)

add_executable(ThriftProtocolBenchmarks
  ThriftProtocolBenchmarkHelper.cpp
  ThriftProtocolBenchmarks.cpp
  "${CARBON_CODEGEN_DIR}/CarbonTestDataMessages.cpp"
  "${CARBON_CODEGEN_DIR}/CarbonTestDataMessagesThrift.cpp"
  ${CarbonTestData-cpp2-SOURCES}
  ${ThriftTestData-cpp2-SOURCES}
)
add_dependencies(ThriftProtocolBenchmarks
  CarbonProtocolBenchmarkCodegen
  CarbonTestData-cpp2-target
  ThriftTestData-cpp2-target)
target_include_directories(ThriftProtocolBenchmarks PRIVATE
  "${CMAKE_BINARY_DIR}"
  "${THRIFT_MCROUTER_SOURCE_DIR}")
target_link_libraries(ThriftProtocolBenchmarks PRIVATE
  ThriftProtocolBenchmarkProtobuf
  benchmark_carbon_protocol
  thriftcpp2
  Folly::folly
  Folly::follybenchmark)

install(TARGETS ThriftProtocolBenchmarks
  RUNTIME DESTINATION "${BIN_INSTALL_DIR}")
