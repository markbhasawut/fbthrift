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

# thrift_generate(
#   "load"
#   "LoadTest"
#   "cpp2"
#   ""
#   "${CMAKE_CURRENT_SOURCE_DIR}/if"
#   "${CMAKE_CURRENT_BINARY_DIR}/if"
#   "thrift/perf/if"
#   THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
# )

# add_library(perf_load_cpp2 OBJECT
#   ${load-cpp2-SOURCES}
# )
# target_link_libraries(perf_load_cpp2 PUBLIC thriftcpp2 Folly::folly)

# add_library(perf_client_lib OBJECT
#   cpp/AsyncClientWorker2.cpp
#   cpp/AsyncLoadHandler2.cpp
#   cpp/ClientLoadConfig.cpp
#   cpp/ClientWorker2.cpp
# )
# target_link_libraries(perf_client_lib PUBLIC thriftcpp2 Folly::folly)

# add_executable(Cpp2Server
#   cpp/Cpp2Server.cpp
#   $<TARGET_OBJECTS:perf_load_cpp2>
#   $<TARGET_OBJECTS:perf_client_lib>
# )
# target_link_libraries(Cpp2Server PUBLIC thriftcpp2 Folly::folly fmt::fmt)

# add_executable(loadgen
#   cpp/loadgen.cpp
#   $<TARGET_OBJECTS:perf_load_cpp2>
#   $<TARGET_OBJECTS:perf_client_lib>
# )
# target_link_libraries(loadgen PUBLIC thriftcpp2 Folly::folly fmt::fmt)
