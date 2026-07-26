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
  "any_rep" #file_name
  "" #services
  "cpp2" #language
  "json,no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "metadata" #file_name
  "" #services
  "cpp2" #language
  "" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "frozen" #file_name
  "" #services
  "cpp2" #language
  "" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "RpcMetadata" #file_name
  "" #services
  "cpp2" #language
  "json,no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "RocketUpgrade" #file_name
  "RocketUpgrade" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "id" #file_name
  "" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "standard" #file_name
  "" #services
  "cpp2" #language
  "json,no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "type_rep" #file_name
  "" #services
  "cpp2" #language
  "json,no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "type" #file_name
  "" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "serverdbginfo" #file_name
  "" #services
  "cpp2" #language
  "json,no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

# The cpp2 `any` option emits registration code against
# thrift/conformance/cpp2/AnyRegistry.h. Conformance is part of the RPC graph;
# a protocol/type-only build must not acquire that otherwise-hidden dependency.
set(THRIFT_PROTOCOL_CPP2_OPTIONS "")
if (THRIFT_RPC)
  set(THRIFT_PROTOCOL_CPP2_OPTIONS "any")
endif ()

thrift_generate(
  "protocol" #file_name
  "" #services
  "cpp2" #language
  "${THRIFT_PROTOCOL_CPP2_OPTIONS}" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "protocol_detail" #file_name
  "" #services
  "cpp2" #language
  "${THRIFT_PROTOCOL_CPP2_OPTIONS}" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "field_mask" #file_name
  "" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "record" #file_name
  "" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "schema" #file_name
  "" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "type_id" #file_name
  "" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "type_system" #file_name
  "" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "service_catalog" #file_name
  "" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "thrift_catalog_service" #file_name
  "ThriftCatalogService" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "any" #file_name
  "" #services
  "cpp2" #language
  "json,no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "any_patch" #file_name
  "" #services
  "cpp2" #language
  "json,no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "any_patch_detail" #file_name
  "" #services
  "cpp2" #language
  "json,no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "ast" #file_name
  "" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "dynamic" #file_name
  "" #services
  "cpp2" #language
  "json,no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "patch" #file_name
  "" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

thrift_generate(
  "patch_op" #file_name
  "" #services
  "cpp2" #language
  "no_metadata" #options
  "${CMAKE_CURRENT_SOURCE_DIR}" #file_path
  "${CMAKE_CURRENT_BINARY_DIR}" #output_path
  "thrift/lib/thrift" #include_prefix
  THRIFT_INCLUDE_DIRECTORIES ${THRIFT_SOURCE_DIR}
)

set_property(GLOBAL PROPERTY any-cpp2-SOURCES ${any-cpp2-SOURCES})
set_property(GLOBAL PROPERTY any_patch-cpp2-SOURCES ${any_patch-cpp2-SOURCES})
set_property(GLOBAL PROPERTY any_patch_detail-cpp2-SOURCES ${any_patch_detail-cpp2-SOURCES})
set_property(GLOBAL PROPERTY any_rep-cpp2-SOURCES ${any_rep-cpp2-SOURCES})
set_property(GLOBAL PROPERTY ast-cpp2-SOURCES ${ast-cpp2-SOURCES})
set_property(GLOBAL PROPERTY dynamic-cpp2-SOURCES ${dynamic-cpp2-SOURCES})
set_property(GLOBAL PROPERTY patch-cpp2-SOURCES ${patch-cpp2-SOURCES})
set_property(GLOBAL PROPERTY patch_op-cpp2-SOURCES ${patch_op-cpp2-SOURCES})
set_property(GLOBAL PROPERTY RpcMetadata-cpp2-SOURCES
  ${RpcMetadata-cpp2-SOURCES})
set_property(GLOBAL PROPERTY frozen-cpp2-SOURCES ${frozen-cpp2-SOURCES})
set_property(GLOBAL PROPERTY metadata-cpp2-SOURCES ${metadata-cpp2-SOURCES})
set_property(GLOBAL PROPERTY RocketUpgrade-cpp2-SOURCES
  ${RocketUpgrade-cpp2-SOURCES})
set_property(GLOBAL PROPERTY id-cpp2-SOURCES ${id-cpp2-SOURCES})
set_property(GLOBAL PROPERTY record-cpp2-SOURCES ${record-cpp2-SOURCES})
set_property(GLOBAL PROPERTY schema-cpp2-SOURCES ${schema-cpp2-SOURCES})
set_property(GLOBAL PROPERTY type_id-cpp2-SOURCES ${type_id-cpp2-SOURCES})
set_property(GLOBAL PROPERTY
  type_system-cpp2-SOURCES ${type_system-cpp2-SOURCES})
set_property(GLOBAL PROPERTY
  service_catalog-cpp2-SOURCES ${service_catalog-cpp2-SOURCES})
set_property(GLOBAL PROPERTY thrift_catalog_service-cpp2-SOURCES
  ${thrift_catalog_service-cpp2-SOURCES})
set_property(GLOBAL PROPERTY standard-cpp2-SOURCES ${standard-cpp2-SOURCES})

set_property(GLOBAL PROPERTY type_rep-cpp2-SOURCES ${type_rep-cpp2-SOURCES})
set_property(GLOBAL PROPERTY type-cpp2-SOURCES ${type-cpp2-SOURCES})
set_property(GLOBAL PROPERTY serverdbginfo-cpp2-SOURCES
  ${serverdbginfo-cpp2-SOURCES})
set_property(GLOBAL PROPERTY protocol-cpp2-SOURCES
  ${protocol-cpp2-SOURCES})
set_property(GLOBAL PROPERTY protocol_detail-cpp2-SOURCES
  ${protocol_detail-cpp2-SOURCES})
set_property(GLOBAL PROPERTY field_mask-cpp2-SOURCES
  ${field_mask-cpp2-SOURCES})

# Install includes
file(GLOB THRIFT_LIB_THRIFT_ROOT_HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/*.h")
install(
  FILES ${THRIFT_LIB_THRIFT_ROOT_HEADERS}
  DESTINATION ${INCLUDE_INSTALL_DIR}/thrift/lib/thrift
)

install(
  DIRECTORY detail
  DESTINATION ${INCLUDE_INSTALL_DIR}/thrift/lib/thrift
  FILES_MATCHING PATTERN "*.h" PATTERN "*.tcc"
)
