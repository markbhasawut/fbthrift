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

add_subdirectory(common)

if (THRIFT_COMPILER_ONLY OR build_all)
  add_subdirectory(compiler)
endif ()

if (THRIFT_LIB_ONLY OR build_all)
  add_subdirectory(annotation)
  if (THRIFT_RPC)
    add_subdirectory(conformance)
  endif ()
  add_subdirectory(lib)
endif ()

if (THRIFT_RPC AND THRIFT_BENCHMARKS)
  add_subdirectory(perf)
endif ()

if (enable_tests)
  add_subdirectory(test)
endif ()

# Install CMake package configuration files for Thrift.
include(CMakePackageConfigHelpers)

# Normalize build options before substituting them into the installed package
# config. In particular, thriftpy may be the truthy cache value AUTO; package
# component results must be canonical booleans. Keep compiler and library
# capabilities separate because modular installs do not contain both.
set(FBTHRIFT_BUILD_COMPILER OFF)
if (THRIFT_COMPILER_ONLY OR build_all)
  set(FBTHRIFT_BUILD_COMPILER ON)
endif ()

set(FBTHRIFT_BUILD_LIBRARIES OFF)
if (THRIFT_LIB_ONLY OR build_all)
  set(FBTHRIFT_BUILD_LIBRARIES ON)
endif ()

set(FBTHRIFT_BUILD_RPC OFF)
if (FBTHRIFT_BUILD_LIBRARIES AND THRIFT_RPC)
  set(FBTHRIFT_BUILD_RPC ON)
endif ()

set(FBTHRIFT_BUILD_HTTP2 OFF)
if (FBTHRIFT_BUILD_RPC AND THRIFT_HTTP2)
  set(FBTHRIFT_BUILD_HTTP2 ON)
endif ()

set(FBTHRIFT_COMPONENT_PY OFF)
if (FBTHRIFT_BUILD_LIBRARIES AND thriftpy)
  set(FBTHRIFT_COMPONENT_PY ON)
endif ()

set(FBTHRIFT_COMPONENT_PY3 OFF)
if (FBTHRIFT_BUILD_LIBRARIES AND thriftpy3)
  set(FBTHRIFT_COMPONENT_PY3 ON)
endif ()

set(FBTHRIFT_COMPONENT_PYTHON OFF)
if (FBTHRIFT_BUILD_LIBRARIES AND thrift_python)
  set(FBTHRIFT_COMPONENT_PYTHON ON)
endif ()

configure_package_config_file(
  cmake/FBThriftConfig.cmake.in
  FBThriftConfig.cmake
  INSTALL_DESTINATION ${CMAKE_INSTALL_DIR}
  PATH_VARS
    CMAKE_INSTALL_DIR
    BIN_INSTALL_DIR
    INCLUDE_INSTALL_DIR
)
install(
  FILES ${CMAKE_CURRENT_BINARY_DIR}/FBThriftConfig.cmake
  DESTINATION ${CMAKE_INSTALL_DIR}
)
# Keep installed package discovery independent of fbcode_builder and of the
# fbthrift source tree. These compatibility finders cover dependencies that do
# not consistently ship upstream CMake package configs.
install(
  FILES
    cmake/FindGflags.cmake
    cmake/FindGlog.cmake
    cmake/FindOpenSSL.cmake
    cmake/FindSodium.cmake
    cmake/FindXxhash.cmake
  DESTINATION ${CMAKE_INSTALL_DIR}
)
install(
  EXPORT fbthrift-exports
  FILE FBThriftTargets.cmake
  NAMESPACE FBThrift::
  DESTINATION ${CMAKE_INSTALL_DIR}
)

install(
  DIRECTORY annotation ${CMAKE_CURRENT_SOURCE_DIR}/annotation
  DESTINATION include/thrift
  FILES_MATCHING PATTERN *.thrift
)

install(
  DIRECTORY annotation ${CMAKE_CURRENT_BINARY_DIR}/annotation
  DESTINATION include/thrift
  FILES_MATCHING
    PATTERN *.h
    PATTERN *.tcc
    PATTERN CMakeFiles EXCLUDE
)
