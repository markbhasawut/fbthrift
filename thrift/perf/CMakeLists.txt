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

thrift_generate(
  "load"
  "LoadTest"
  "cpp2"
  ""
  "${CMAKE_CURRENT_SOURCE_DIR}/if"
  "${CMAKE_CURRENT_BINARY_DIR}/if"
  "thrift/perf/if"
  NO_INSTALL
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
  TARGET_NAME_BASE "perf_load"
)

# Compile generated code and the legacy load-generator implementation once.
# Putting either source set directly in both executables multiplies the Ninja
# graph and makes generated-header ordering depend on parallel build timing.
add_library(perf_load_cpp2 STATIC ${perf_load-cpp2-SOURCES})
target_link_libraries(perf_load_cpp2
  PUBLIC
    thriftcpp2
    thriftprotocol
    Folly::folly
)

add_library(perf_loadgen_support STATIC
  ../lib/cpp/test/loadgen/Controller.cpp
  ../lib/cpp/test/loadgen/GaussianMixtureModel.cpp
  ../lib/cpp/test/loadgen/LatencyMonitor.cpp
  ../lib/cpp/test/loadgen/LatencyScoreBoard.cpp
  ../lib/cpp/test/loadgen/LoadConfig.cpp
  ../lib/cpp/test/loadgen/QpsMonitor.cpp
  ../lib/cpp/test/loadgen/QpsScoreBoard.cpp
  ../lib/cpp/test/loadgen/RNG.cpp
  ../lib/cpp/test/loadgen/TerminalMonitor.cpp
  ../lib/cpp/test/loadgen/WeightedLoadConfig.cpp
  ../lib/cpp/test/loadgen/loadgen.cpp
)
target_link_libraries(perf_loadgen_support
  PUBLIC
    thriftcpp2
    Folly::folly
    Boost::boost
    glog::glog
)

add_library(perf_client_lib STATIC
  cpp/AsyncClientWorker2.cpp
  cpp/AsyncLoadHandler2.cpp
  cpp/ClientLoadConfig.cpp
  cpp/ClientWorker2.cpp
)
target_link_libraries(perf_client_lib
  PUBLIC
    perf_load_cpp2
    perf_loadgen_support
    thriftcpp2
    Folly::folly
    glog::glog
)

add_executable(Cpp2Server cpp/Cpp2Server.cpp)
target_link_libraries(Cpp2Server
  PRIVATE
    perf_client_lib
    perf_load_cpp2
    thriftcpp2
    Folly::folly
    fmt::fmt
    glog::glog
)

add_executable(loadgen cpp/loadgen.cpp)
target_link_libraries(loadgen
  PRIVATE
    perf_client_lib
    perf_load_cpp2
    perf_loadgen_support
    thriftcpp2
    Folly::folly
    fmt::fmt
    glog::glog
)

add_custom_target(thrift_perf_tools DEPENDS Cpp2Server loadgen)
