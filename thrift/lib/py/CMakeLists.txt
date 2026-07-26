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

set(
  THRIFT_PY_SRCS
  "TMultiplexedProcessor.py"
  "Thrift.py"
  "__init__.py"
  "async_common.py"
  "client/common.py"
  "protocol/TBinaryProtocol.py"
  "protocol/TCompactProtocol.py"
  "protocol/THeaderProtocol.py"
  "protocol/TJSONProtocol.py"
  "protocol/TMultiplexedProtocol.py"
  "protocol/TProtocol.py"
  "protocol/TProtocolDecorator.py"
  "protocol/TSimpleJSONProtocol.py"
  "protocol/__init__.py"
  "protocol/exceptions.py"
  "reflection/__init__.py"
  "server/TAsyncioServer.py"
  "server/TCppServer.py"
  "server/TServer.py"
  "server/__init__.py"
  "transport/THeaderTransport.py"
  "transport/THttpClient.py"
  "transport/TSSLSocket.py"
  "transport/TSocket.py"
  "transport/TTransport.py"
  "transport/__init__.py"
  "util/BytesStrIO.py"
  "util/Decorators.py"
  "util/Recursive.py"
  "util/Serializer.py"
  "util/TValidator.py"
  "util/__init__.py"
  "util/async_common.py"
  "util/fuzzer.py"
  "util/randomizer.py"
  "util/remote.py"
)

# Preserve the FB Python archive-manifest contract without requiring
# FBPythonBinary.cmake in a standalone OSS build. Downstream fbcode_builder
# consumers can still consume these imported interface targets because their
# INTERFACE_SOURCES and manifest properties are identical.
set(
  FBTHRIFT_PY_ARCHIVE_INSTALL_DIR
  "lib/fb-py-libs"
  CACHE STRING
  "Install directory for legacy py runtime archive manifests"
)

function(add_fbthrift_py_archive library_name namespace)
  string(REPLACE "." "/" namespace_dir "${namespace}")
  set(manifest "${CMAKE_CURRENT_BINARY_DIR}/${library_name}.manifest")
  set(manifest_tmp "${manifest}.tmp")
  file(WRITE "${manifest_tmp}" "FBPY_MANIFEST 1\n")

  add_library("${library_name}.py_lib" INTERFACE)
  foreach(source IN LISTS ARGN)
    get_filename_component(
      absolute_source "${source}" ABSOLUTE
      BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}"
    )
    set(destination "${namespace_dir}/${source}")
    target_sources(
      "${library_name}.py_lib"
      INTERFACE
        "$<BUILD_INTERFACE:${absolute_source}>"
        "$<INSTALL_INTERFACE:${FBTHRIFT_PY_ARCHIVE_INSTALL_DIR}/${library_name}/${destination}>"
    )
    file(APPEND "${manifest_tmp}" "${absolute_source} :: ${destination}\n")

    get_filename_component(destination_directory "${destination}" DIRECTORY)
    install(
      FILES "${absolute_source}"
      DESTINATION
        "${FBTHRIFT_PY_ARCHIVE_INSTALL_DIR}/${library_name}/${destination_directory}"
    )
  endforeach ()

  configure_file("${manifest_tmp}" "${manifest}" COPYONLY)
  target_include_directories(
    "${library_name}.py_lib"
    INTERFACE
      "$<BUILD_INTERFACE:${manifest}>"
      "$<INSTALL_INTERFACE:${FBTHRIFT_PY_ARCHIVE_INSTALL_DIR}/${library_name}.manifest>"
  )
  install(
    TARGETS "${library_name}.py_lib"
    EXPORT fbthrift-exports
  )
  install(
    FILES "${manifest}"
    DESTINATION "${FBTHRIFT_PY_ARCHIVE_INSTALL_DIR}"
  )
endfunction()

# thrift_py has an external dependency on the "future" Python package. It uses
# snappy and zstd when available, but does not require them.
add_fbthrift_py_archive(thrift_py thrift ${THRIFT_PY_SRCS})
add_fbthrift_py_archive(thrift_py_inspect thrift "util/inspect.py")
