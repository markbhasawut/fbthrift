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

#
# Requirements:
# Please provide the following two variables before using these macros:
#   ${THRIFT1} - path/to/bin/thrift1
#   ${THRIFTCPP2} - path/to/lib/thriftcpp2
#

#
# thrift_object
# This creates a object that will contain the source files and all the proper
# dependencies to generate and compile thrift generated files
#
# Params:
#   @file_name - The name of the thrift file
#   @services  - A list of services that are declared in the thrift file
#   @language  - The generator to use (cpp, cpp2, py, py3, or python)
#   @options   - Extra options to pass to the generator
#   @file_path - The directory where the thrift file lives
#   @output_path - The directory where the thrift objects will be built
#   @include_prefix - The last part of output_path, relative include prefix
#
# Output:
#  A object file named `${file-name}-${language}-obj` to include into your
#  project's library
#
# Notes:
# If any of the fields is empty, it is still required to provide an empty string
#
# Usage:
#   thrift_object(
#     #file_name
#     #services
#     #language
#     #options
#     #file_path
#     #output_path
#     #include_prefix
#   )
#   add_library(somelib $<TARGET_OBJECTS:${file_name}-${language}-obj> ...)
#

macro(thrift_object
  file_name
  services
  language
  options
  file_path
  output_path
  include_prefix
)
  thrift_generate(
    "${file_name}"
    "${services}"
    "${language}"
    "${options}"
    "${file_path}"
    "${output_path}"
    "${include_prefix}"
    ${ARGN}
  )
  if("${language}" STREQUAL "cpp" OR "${language}" STREQUAL "cpp2")
    bypass_source_check(${${file_name}-${language}-SOURCES})
    add_library(
      "${file_name}-${language}-obj"
      OBJECT
      ${${file_name}-${language}-SOURCES}
    )
    add_dependencies(
      "${file_name}-${language}-obj"
      "${file_name}-${language}-target"
    )
    message("Thrift will create the Object file : ${file_name}-${language}-obj")
  else()
    # Python-family generators emit source artifacts for a separate Python or
    # Cython packaging step; they are not directly compilable CMake objects.
    message("Thrift will generate ${language} files for : ${file_name}-${language}")
  endif()
endmacro()

# thrift_library
# Same as thrift object in terms of usage but creates the library instead of
# object so that you can use to link against your library instead of including
# all symbols into your library
#
# Params:
#   @file_name - The name of the thrift file
#   @services  - A list of services that are declared in the thrift file
#   @language  - The generator to use (cpp, cpp2, py, py3, or python)
#   @options   - Extra options to pass to the generator
#   @file_path - The directory where the thrift file lives
#   @output_path - The directory where the thrift objects will be built
#   @include_prefix - The last part of output_path, relative include prefix
#
# Output:
#  A library file named `${file-name}-${language}` to link against your
#  project's library
#
# Notes:
# If any of the fields is empty, it is still required to provide an empty string
#
# Usage:
#   thrift_library(
#     #file_name
#     #services
#     #language
#     #options
#     #file_path
#     #output_path
#     #include_prefix
#   )
#   add_library(somelib ...)
#   target_link_libraries(somelib ${file_name}-${language} ...)
#

macro(thrift_library
  file_name
  services
  language
  options
  file_path
  output_path
  include_prefix
)
  thrift_object(
    "${file_name}"
    "${services}"
    "${language}"
    "${options}"
    "${file_path}"
    "${output_path}"
    "${include_prefix}"
    ${ARGN}
  )
  if("${language}" STREQUAL "cpp" OR "${language}" STREQUAL "cpp2")
    add_library(
      "${file_name}-${language}"
      $<TARGET_OBJECTS:${file_name}-${language}-obj>
    )
    target_link_libraries("${file_name}-${language}" ${THRIFTCPP2})
    message("Thrift will create the Library file : ${file_name}-${language}")
  else()
    # Create a dependency-only target; packaging/extension compilation remains
    # explicit so py3 does not acquire an implicit dependency cycle through its
    # companion cpp2 output.
    add_custom_target("${file_name}-${language}" ALL)
    add_dependencies("${file_name}-${language}" "${file_name}-${language}-target")
    message("Thrift will create the ${language} codegen target : ${file_name}-${language}")
  endif()
endmacro()

#
# bypass_source_check
# This tells cmake to ignore if it doesn't see the following sources in
# the library that will be installed. Thrift files are generated at compile
# time so they do not exist at source check time
#
# Params:
#   @sources - The list of files to ignore in source check
#

macro(bypass_source_check sources)
  set_source_files_properties(
    ${sources}
    PROPERTIES GENERATED TRUE
  )
endmacro()

#
# thrift_generate
# This is used to codegen thrift files using the thrift compiler
# Supports library names that differ from the file name (to handle two libraries
# with the same filename on disk (in different folders))
# Params:
#   @file_name - Input file name. Will be used for naming the CMake
#       target if TARGET_NAME_BASE is not specified.
#   @services  - A list of services that are declared in the thrift file
#   @language  - The generator to use (cpp, cpp2, py, py3, or python)
#   @options   - Extra options to pass to the generator
#   @output_path - The directory where the thrift file lives
#   @include_prefix - Prefix to use for thrift includes in generated sources
#   @TARGET_NAME_BASE (optional) - name used for target instead of real filename
#   @THRIFT_INCLUDE_DIRECTORIES (optional) path to thrift include directories
#   @COMPILER (optional) - compiler target or executable for this invocation.
#       Defaults to ${THRIFT1}.
#   @INJECT_SCHEMA (optional) - inject the compact bundled schema constant.
#       This requires a compiler linked with the AST/schema generator.
#   @NAMESPACE (optional) - Output namespace for Python-family generators.
#       It must match namespace py (or py.asyncio) for py, and namespace py3
#       for py3/python. Dot-separated values map to output directories.
#
# Output:
#  file-language-target     - A custom target to add a dependency
#  ${file-language-HEADERS} - The generated Header Files.
#  ${file-language-SOURCES} - The generated Source Files.
#
# Notes:
# If any of the fields is empty, it is still required to provide an empty string
#
# When using file_language-SOURCES it should always call:
#   bypass_source_check(${file_language-SOURCES})
# This will prevent cmake from complaining about missing source files
#
macro(thrift_generate
  file_name
  services
  language
  options
  file_path
  output_path
  include_prefix
)
  cmake_parse_arguments(THRIFT_GENERATE   # Prefix
    "INJECT_SCHEMA;NO_INSTALL" # Options
    "COMPILER;TARGET_NAME_BASE;NAMESPACE" # One Value args
    "THRIFT_INCLUDE_DIRECTORIES" # Multi-value args
    "${ARGN}")

  set(thrift_compiler "${THRIFT1}")
  if(DEFINED THRIFT_GENERATE_COMPILER
     AND NOT THRIFT_GENERATE_COMPILER STREQUAL "")
    set(thrift_compiler "${THRIFT_GENERATE_COMPILER}")
  elseif(THRIFT_GENERATE_INJECT_SCHEMA)
    set(thrift_compiler "thrift1")
  endif()
  set(thrift_schema_arguments)
  if(THRIFT_GENERATE_INJECT_SCHEMA)
    list(APPEND thrift_schema_arguments --inject-schema-const)
  endif()

  set(source_file_name ${file_name})
  set(target_file_name ${file_name})
  set(thrift_include_directories)
  foreach(dir ${THRIFT_GENERATE_THRIFT_INCLUDE_DIRECTORIES})
    list(APPEND thrift_include_directories "-I" "${dir}")
  endforeach()
  if(DEFINED THRIFT_GENERATE_TARGET_NAME_BASE
     AND NOT THRIFT_GENERATE_TARGET_NAME_BASE STREQUAL "")
    set(target_file_name ${THRIFT_GENERATE_TARGET_NAME_BASE})
  endif()

  set(thrift_is_cpp FALSE)
  if("${language}" STREQUAL "cpp" OR "${language}" STREQUAL "cpp2")
    set(thrift_is_cpp TRUE)
    set(gen_language "mstch_cpp2")
    set(thrift_codegen_output_directory "gen-cpp2")
  elseif("${language}" STREQUAL "py")
    set(gen_language "py")
    set(thrift_codegen_output_directory "gen-py")
  elseif("${language}" STREQUAL "py3")
    set(gen_language "mstch_py3")
    set(thrift_codegen_output_directory "gen-py3")
  elseif("${language}" STREQUAL "python")
    set(gen_language "mstch_python")
    set(thrift_codegen_output_directory "gen-python")
  else()
    message(FATAL_ERROR
      "Unsupported thrift_generate language '${language}'. Supported "
      "languages are cpp, cpp2, py, py3, and python")
  endif()

  # "layouts" and "patch" are CMake-only markers. "layouts" controls whether
  # the frozen2 layout translation unit is compiled. "patch" adds the
  # thrift_patch_library pipeline: generate gen_patch_<file>.thrift and run
  # ordinary mstch_cpp2:any code generation over that companion IDL.
  string(REPLACE "," ";" thrift_codegen_option_list "${options}")
  set(thrift_generate_patch FALSE)
  set(thrift_generate_layouts FALSE)
  if("patch" IN_LIST thrift_codegen_option_list)
    if(NOT thrift_is_cpp)
      message(FATAL_ERROR
        "The CMake-only patch option is supported only for cpp/cpp2")
    endif()
    set(thrift_generate_patch TRUE)
  endif()
  if("layouts" IN_LIST thrift_codegen_option_list)
    if(NOT thrift_is_cpp OR NOT "frozen2" IN_LIST thrift_codegen_option_list)
      message(FATAL_ERROR
        "The CMake-only layouts marker requires cpp/cpp2:frozen2")
    endif()
    set(thrift_generate_layouts TRUE)
  endif()
  list(REMOVE_ITEM thrift_codegen_option_list "layouts")
  list(REMOVE_ITEM thrift_codegen_option_list "patch")
  list(JOIN thrift_codegen_option_list "," thrift_codegen_options)

  if(thrift_is_cpp AND "py3cpp" IN_LIST thrift_codegen_option_list)
    set(thrift_codegen_output_directory "gen-py3cpp")
    if(thrift_generate_patch)
      message(FATAL_ERROR
        "The CMake-only patch marker is incompatible with cpp/cpp2:py3cpp")
    endif()
  endif()

  set(thrift_single_file_service FALSE)
  if("single_file_service" IN_LIST thrift_codegen_option_list)
    set(thrift_single_file_service TRUE)
  endif()

  set("${target_file_name}-${language}-HEADERS")
  set("${target_file_name}-${language}-SOURCES")
  set(thrift_codegen_byproducts)
  set(thrift_post_codegen_commands)

  if(thrift_is_cpp)

  set(thrift_types_cpp_splits "")
  foreach(thrift_codegen_option ${thrift_codegen_option_list})
    if(thrift_codegen_option MATCHES "^types_cpp_splits=([1-9][0-9]*)$")
      set(thrift_types_cpp_splits "${CMAKE_MATCH_1}")
    elseif(thrift_codegen_option MATCHES "^types_cpp_splits=")
      message(FATAL_ERROR
        "types_cpp_splits must be a positive integer, got: "
        "${thrift_codegen_option}")
    endif()
  endforeach()

  set(thrift_declared_services ${services})
  set(thrift_client_split_services)
  set(thrift_client_split_counts)
  if("${thrift_codegen_options}" MATCHES
     "(^|,)client_cpp_splits=\\{([^}]*)\\}($|,)")
    set(thrift_client_split_map "${CMAKE_MATCH_2}")
    if("${thrift_client_split_map}" STREQUAL "")
      message(FATAL_ERROR "client_cpp_splits requires at least one service")
    endif()
    string(REPLACE "," ";" thrift_client_split_pairs
      "${thrift_client_split_map}")
    foreach(thrift_client_split_pair ${thrift_client_split_pairs})
      if(NOT thrift_client_split_pair MATCHES
         "^([^:]+):([1-9][0-9]*)$")
        message(FATAL_ERROR
          "Invalid client_cpp_splits pair: ${thrift_client_split_pair}")
      endif()
      set(thrift_client_split_service "${CMAKE_MATCH_1}")
      set(thrift_client_split_count "${CMAKE_MATCH_2}")
      if(NOT thrift_client_split_service IN_LIST thrift_declared_services)
        message(FATAL_ERROR
          "client_cpp_splits names service "
          "${thrift_client_split_service}, but it is absent from the "
          "thrift_generate services argument")
      endif()
      if(thrift_client_split_service IN_LIST thrift_client_split_services)
        message(FATAL_ERROR
          "Duplicate service in client_cpp_splits: "
          "${thrift_client_split_service}")
      endif()
      list(APPEND thrift_client_split_services
        "${thrift_client_split_service}")
      list(APPEND thrift_client_split_counts "${thrift_client_split_count}")
    endforeach()
  elseif("${thrift_codegen_options}" MATCHES
         "(^|,)client_cpp_splits=")
    message(FATAL_ERROR
      "Malformed client_cpp_splits option: ${thrift_codegen_options}")
  endif()

  if(thrift_single_file_service AND thrift_client_split_services)
    message(FATAL_ERROR
      "single_file_service is incompatible with client_cpp_splits")
  endif()

  set("${target_file_name}-${language}-HEADERS"
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_clients.h
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_clients_fwd.h
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_constants.h
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_data.h
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_handlers.h
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_metadata.h
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_types.h
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_types.tcc
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_types_custom_protocol.h
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_types_fwd.h
  )
  set("${target_file_name}-${language}-SOURCES"
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_constants.cpp
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_data.cpp
    ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_sinit.cpp
  )

  set(thrift_type_source_stems
    types
    types_binary
    types_compact
    types_serialization
  )
  if(NOT "${thrift_types_cpp_splits}" STREQUAL "")
    math(EXPR thrift_types_cpp_last_split
      "${thrift_types_cpp_splits} - 1")
    string(LENGTH "${thrift_types_cpp_last_split}"
      thrift_types_cpp_split_width)
    foreach(thrift_types_cpp_split_id RANGE ${thrift_types_cpp_last_split})
      string(LENGTH "${thrift_types_cpp_split_id}"
        thrift_types_cpp_split_id_width)
      math(EXPR thrift_types_cpp_split_padding
        "${thrift_types_cpp_split_width} - ${thrift_types_cpp_split_id_width}")
      string(REPEAT "0" ${thrift_types_cpp_split_padding}
        thrift_types_cpp_split_prefix)
      set(thrift_types_cpp_split_id_text
        "${thrift_types_cpp_split_prefix}${thrift_types_cpp_split_id}")
      foreach(thrift_type_source_stem ${thrift_type_source_stems})
        list(APPEND "${target_file_name}-${language}-SOURCES"
          ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_${thrift_type_source_stem}.${thrift_types_cpp_split_id_text}.split.cpp
        )
      endforeach()
    endforeach()
  else()
    foreach(thrift_type_source_stem ${thrift_type_source_stems})
      list(APPEND "${target_file_name}-${language}-SOURCES"
        ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_${thrift_type_source_stem}.cpp
      )
    endforeach()
  endif()

  # frozen2 makes the compiler emit the layout header, while the additional
  # CMake-only "layouts" marker opts the layout translation unit into the
  # consuming target. Some frozen2 fixtures intentionally use types which
  # cannot instantiate a frozen layout.
  if("frozen2" IN_LIST thrift_codegen_option_list)
    list(APPEND "${target_file_name}-${language}-HEADERS"
      ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_layouts.h
    )
    if(thrift_generate_layouts)
      list(APPEND "${target_file_name}-${language}-SOURCES"
        ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_layouts.cpp
      )
    else()
      list(APPEND thrift_codegen_byproducts
        ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_layouts.cpp
      )
    endif()
  endif()
  if(NOT "no_metadata" IN_LIST thrift_codegen_option_list)
    list(APPEND "${target_file_name}-${language}-SOURCES"
      ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_metadata.cpp
    )
  endif()

  if(thrift_single_file_service)
    list(APPEND "${target_file_name}-${language}-HEADERS"
      ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_handlers-inl.h
    )
    list(APPEND "${target_file_name}-${language}-SOURCES"
      ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_clients.cpp
      ${output_path}/${thrift_codegen_output_directory}/${source_file_name}_handlers.cpp
    )
  else()
    foreach(service ${services})
      list(APPEND "${target_file_name}-${language}-HEADERS"
        ${output_path}/${thrift_codegen_output_directory}/${service}.h
        ${output_path}/${thrift_codegen_output_directory}/${service}.tcc
        ${output_path}/${thrift_codegen_output_directory}/${service}AsyncClient.h
        ${output_path}/${thrift_codegen_output_directory}/${service}_custom_protocol.h
      )
      list(APPEND "${target_file_name}-${language}-SOURCES"
        ${output_path}/${thrift_codegen_output_directory}/${service}.cpp
        ${output_path}/${thrift_codegen_output_directory}/${service}_processmap_binary.cpp
        ${output_path}/${thrift_codegen_output_directory}/${service}_processmap_compact.cpp
      )
      list(FIND thrift_client_split_services "${service}"
        thrift_client_split_index)
      if(thrift_client_split_index EQUAL -1)
        list(APPEND "${target_file_name}-${language}-SOURCES"
          ${output_path}/${thrift_codegen_output_directory}/${service}AsyncClient.cpp
        )
      else()
        list(GET thrift_client_split_counts ${thrift_client_split_index}
          thrift_client_split_count)
        math(EXPR thrift_client_last_split
          "${thrift_client_split_count} - 1")
        string(LENGTH "${thrift_client_last_split}"
          thrift_client_split_width)
        foreach(thrift_client_split_id RANGE ${thrift_client_last_split})
          string(LENGTH "${thrift_client_split_id}"
            thrift_client_split_id_width)
          math(EXPR thrift_client_split_padding
            "${thrift_client_split_width} - ${thrift_client_split_id_width}")
          string(REPEAT "0" ${thrift_client_split_padding}
            thrift_client_split_prefix)
          list(APPEND "${target_file_name}-${language}-SOURCES"
            ${output_path}/${thrift_codegen_output_directory}/${service}.${thrift_client_split_prefix}${thrift_client_split_id}.async_client_split.cpp
          )
        endforeach()
      endif()
    endforeach()
  endif()

  elseif("${language}" STREQUAL "py")
    # The legacy py generator owns the namespace directory and emits one
    # module per declared service. NAMESPACE must match namespace py (or
    # namespace py.asyncio when the asyncio option is selected).
    if(DEFINED THRIFT_GENERATE_NAMESPACE AND
       NOT THRIFT_GENERATE_NAMESPACE STREQUAL "")
      string(REPLACE "." "/" thrift_python_module_dir
        "${THRIFT_GENERATE_NAMESPACE}")
    else()
      set(thrift_python_module_dir "${source_file_name}")
    endif()
    set(thrift_python_output_base
      "${output_path}/gen-py/${thrift_python_module_dir}")
    list(APPEND thrift_codegen_byproducts
      "${output_path}/gen-py/__init__.py")
    set(thrift_python_package_path "${output_path}/gen-py")
    string(REPLACE "/" ";" thrift_python_package_parts
      "${thrift_python_module_dir}")
    foreach(thrift_python_package_part ${thrift_python_package_parts})
      string(APPEND thrift_python_package_path
        "/${thrift_python_package_part}")
      if(NOT thrift_python_package_path STREQUAL thrift_python_output_base)
        list(APPEND thrift_codegen_byproducts
          "${thrift_python_package_path}/__init__.py")
      endif()
    endforeach()
    set("${target_file_name}-${language}-SOURCES"
      ${thrift_python_output_base}/__init__.py
      ${thrift_python_output_base}/ttypes.py
      ${thrift_python_output_base}/constants.py
    )
    foreach(service ${services})
      list(APPEND "${target_file_name}-${language}-SOURCES"
        ${thrift_python_output_base}/${service}.py)
      list(APPEND thrift_codegen_byproducts
        ${thrift_python_output_base}/${service}-remote
        ${thrift_python_output_base}/${service}-fuzzer)
    endforeach()

  elseif("${language}" STREQUAL "py3")
    # The py3 generator emits a Cython package plus native wrapper glue. It
    # references cpp2 output but deliberately does not add a CMake dependency
    # on it; callers own the matching cpp2[:py3cpp] target and link topology.
    if(DEFINED THRIFT_GENERATE_NAMESPACE AND
       NOT THRIFT_GENERATE_NAMESPACE STREQUAL "")
      string(REPLACE "." "/" thrift_python_namespace_dir
        "${THRIFT_GENERATE_NAMESPACE}")
      set(thrift_python_module_dir
        "${thrift_python_namespace_dir}/${source_file_name}")
    else()
      set(thrift_python_module_dir "${source_file_name}")
    endif()
    set(thrift_python_output_base
      "${output_path}/gen-py3/${thrift_python_module_dir}")
    # Native wrapper sources are keyed only by the Thrift program name. The
    # Python/Cython package follows namespace py3 and can live elsewhere.
    set(thrift_py3_cpp_output_base
      "${output_path}/gen-py3/${source_file_name}")
    if(DEFINED THRIFT_GENERATE_NAMESPACE AND
       NOT THRIFT_GENERATE_NAMESPACE STREQUAL "")
      set(thrift_py3_namespace_path "${output_path}/gen-py3")
      string(REPLACE "." ";" thrift_py3_namespace_parts
        "${THRIFT_GENERATE_NAMESPACE}")
      foreach(thrift_py3_namespace_part ${thrift_py3_namespace_parts})
        string(APPEND thrift_py3_namespace_path
          "/${thrift_py3_namespace_part}")
        list(APPEND thrift_codegen_byproducts
          "${thrift_py3_namespace_path}/__init__.py")
      endforeach()
    endif()
    list(APPEND thrift_post_codegen_commands
      COMMAND ${CMAKE_COMMAND} -E touch
        "${thrift_python_output_base}/__init__.py")
    set("${target_file_name}-${language}-HEADERS"
      ${thrift_python_output_base}/cbindings.pxd
      ${thrift_python_output_base}/converter.pxd
      ${thrift_python_output_base}/metadata.pxd
      ${thrift_python_output_base}/metadata.pyi
      ${thrift_python_output_base}/types.pxd
      ${thrift_python_output_base}/types.pyi
      ${thrift_python_output_base}/types_fields.pxd
      ${thrift_py3_cpp_output_base}/metadata.h
      ${thrift_py3_cpp_output_base}/types.h
    )
    set("${target_file_name}-${language}-SOURCES"
      ${thrift_python_output_base}/__init__.py
      ${thrift_python_output_base}/builders.py
      ${thrift_python_output_base}/constants_FBTHRIFT_ONLY_DO_NOT_USE.py
      ${thrift_python_output_base}/containers_FBTHRIFT_ONLY_DO_NOT_USE.py
      ${thrift_python_output_base}/converter.pyx
      ${thrift_python_output_base}/metadata.py
      ${thrift_python_output_base}/metadata.pyx
      ${thrift_python_output_base}/types.py
      ${thrift_python_output_base}/types.pyx
      ${thrift_python_output_base}/types_auto_FBTHRIFT_ONLY_DO_NOT_USE.py
      ${thrift_python_output_base}/types_auto_migrated.py
      ${thrift_python_output_base}/types_empty.pyx
      ${thrift_python_output_base}/types_fields.pyx
      ${thrift_python_output_base}/types_impl_FBTHRIFT_ONLY_DO_NOT_USE.py
      ${thrift_python_output_base}/types_reflection.py
      ${thrift_py3_cpp_output_base}/metadata.cpp
    )
    if("inplace_migrate" IN_LIST thrift_codegen_option_list)
      list(APPEND "${target_file_name}-${language}-SOURCES"
        ${thrift_python_output_base}/types_inplace_FBTHRIFT_ONLY_DO_NOT_USE.py)
    endif()
    if(NOT "${services}" STREQUAL "" OR thrift_single_file_service)
      list(APPEND "${target_file_name}-${language}-HEADERS"
        ${thrift_python_output_base}/clients.pxd
        ${thrift_python_output_base}/clients.pyi
        ${thrift_python_output_base}/clients_wrapper.pxd
        ${thrift_python_output_base}/services.pxd
        ${thrift_python_output_base}/services.pyi
        ${thrift_python_output_base}/services_interface.pxd
        ${thrift_python_output_base}/services_wrapper.pxd
        ${thrift_py3_cpp_output_base}/clients_wrapper.h
        ${thrift_py3_cpp_output_base}/services_wrapper.h
      )
      list(APPEND "${target_file_name}-${language}-SOURCES"
        ${thrift_python_output_base}/clients.py
        ${thrift_python_output_base}/clients.pyx
        ${thrift_python_output_base}/services.py
        ${thrift_python_output_base}/services.pyx
        ${thrift_py3_cpp_output_base}/clients_wrapper.cpp
        ${thrift_py3_cpp_output_base}/services_wrapper.cpp
      )
    endif()

  elseif("${language}" STREQUAL "python")
    # thrift.python uses PEP 420 namespace packages, so no __init__.py is
    # generated. NAMESPACE must match namespace py3 when it is non-empty.
    if(DEFINED THRIFT_GENERATE_NAMESPACE AND
       NOT THRIFT_GENERATE_NAMESPACE STREQUAL "")
      string(REPLACE "." "/" thrift_python_namespace_dir
        "${THRIFT_GENERATE_NAMESPACE}")
      set(thrift_python_module_dir
        "${thrift_python_namespace_dir}/${source_file_name}")
    else()
      set(thrift_python_module_dir "${source_file_name}")
    endif()
    set(thrift_python_output_base
      "${output_path}/gen-python/${thrift_python_module_dir}")
    set("${target_file_name}-${language}-SOURCES"
      ${thrift_python_output_base}/thrift_types.py
      ${thrift_python_output_base}/thrift_types.pyi
      ${thrift_python_output_base}/thrift_enums.py
      ${thrift_python_output_base}/thrift_abstract_types.py
      ${thrift_python_output_base}/thrift_mutable_types.py
      ${thrift_python_output_base}/thrift_mutable_types.pyi
      ${thrift_python_output_base}/thrift_uris.txt
      ${thrift_python_output_base}/thrift_reflection.py
    )
    if(NOT "no_metadata" IN_LIST thrift_codegen_option_list)
      list(APPEND "${target_file_name}-${language}-SOURCES"
        ${thrift_python_output_base}/thrift_metadata.py)
    endif()
    if(NOT "${services}" STREQUAL "")
      list(APPEND "${target_file_name}-${language}-SOURCES"
        ${thrift_python_output_base}/thrift_services_reflection.py
        ${thrift_python_output_base}/thrift_services.py
        ${thrift_python_output_base}/thrift_clients.py
        ${thrift_python_output_base}/thrift_mutable_services.py
        ${thrift_python_output_base}/thrift_mutable_clients.py
      )
    endif()
  endif()

  set(thrift_patch_codegen_commands)
  set(thrift_patch_codegen_outputs)
  if(thrift_generate_patch)
    set(patch_source_file_name "gen_patch_${source_file_name}")
    set(patch_thrift_file
      "${output_path}/gen-patch/${patch_source_file_name}.thrift")
    set(patch_traits_header
      "${output_path}/gen-patch/${patch_source_file_name}.h")
    set(patch_instantiations_source
      "${output_path}/gen-patch/${patch_source_file_name}.cpp")
    if("${include_prefix}" STREQUAL "")
      set(patch_source_include "${source_file_name}.thrift")
      set(patch_include_prefix_option "")
    else()
      set(patch_source_include
        "${include_prefix}/${source_file_name}.thrift")
      set(patch_include_prefix_option
        ",include_prefix=${include_prefix}")
    endif()

    set(thrift_patch_headers
      ${output_path}/gen-cpp2/${patch_source_file_name}_clients.h
      ${output_path}/gen-cpp2/${patch_source_file_name}_clients_fwd.h
      ${output_path}/gen-cpp2/${patch_source_file_name}_constants.h
      ${output_path}/gen-cpp2/${patch_source_file_name}_data.h
      ${output_path}/gen-cpp2/${patch_source_file_name}_handlers.h
      ${output_path}/gen-cpp2/${patch_source_file_name}_metadata.h
      ${output_path}/gen-cpp2/${patch_source_file_name}_types.h
      ${output_path}/gen-cpp2/${patch_source_file_name}_types.tcc
      ${output_path}/gen-cpp2/${patch_source_file_name}_types_custom_protocol.h
      ${output_path}/gen-cpp2/${patch_source_file_name}_types_fwd.h
    )
    set(thrift_patch_sources
      ${output_path}/gen-cpp2/${patch_source_file_name}_constants.cpp
      ${output_path}/gen-cpp2/${patch_source_file_name}_data.cpp
      ${output_path}/gen-cpp2/${patch_source_file_name}_metadata.cpp
      ${output_path}/gen-cpp2/${patch_source_file_name}_sinit.cpp
      ${output_path}/gen-cpp2/${patch_source_file_name}_types.cpp
      ${output_path}/gen-cpp2/${patch_source_file_name}_types_binary.cpp
      ${output_path}/gen-cpp2/${patch_source_file_name}_types_compact.cpp
      ${output_path}/gen-cpp2/${patch_source_file_name}_types_serialization.cpp
      ${patch_instantiations_source}
    )
    list(APPEND "${target_file_name}-${language}-HEADERS"
      ${thrift_patch_headers})
    list(APPEND "${target_file_name}-${language}-SOURCES"
      ${thrift_patch_sources})
    list(APPEND thrift_patch_codegen_outputs
      "${patch_thrift_file}"
      "${patch_traits_header}")
    list(APPEND thrift_patch_codegen_commands
      COMMAND ${thrift_compiler}
        --gen "cpp2_patch:source_include=${patch_source_include}"
        -o ${output_path}
        ${thrift_include_directories}
        "${file_path}/${source_file_name}.thrift"
      COMMAND ${thrift_compiler}
        --gen "mstch_cpp2:any${patch_include_prefix_option}"
        -o ${output_path}
        ${thrift_include_directories}
        "${patch_thrift_file}"
    )
    if(NOT THRIFT_GENERATE_NO_INSTALL)
      install(
        DIRECTORY "${output_path}/gen-patch"
        DESTINATION include/${include_prefix}
        FILES_MATCHING PATTERN "*.h")
    endif()
  endif()

  set(thrift_effective_option_list ${thrift_codegen_option_list})
  if(NOT "${include_prefix}" STREQUAL "" AND
     NOT "${language}" STREQUAL "py")
    foreach(thrift_codegen_option ${thrift_codegen_option_list})
      if(thrift_codegen_option MATCHES "^include_prefix=")
        message(FATAL_ERROR
          "Pass include_prefix only through thrift_generate's positional "
          "include_prefix argument, not in its generator option string")
      endif()
    endforeach()
    list(APPEND thrift_effective_option_list
      "include_prefix=${include_prefix}")
  endif()
  list(JOIN thrift_effective_option_list "," thrift_effective_options)
  set(thrift_generator_spec "${gen_language}")
  if(NOT "${thrift_effective_options}" STREQUAL "")
    string(APPEND thrift_generator_spec ":${thrift_effective_options}")
  endif()

  add_custom_command(
    OUTPUT ${thrift_patch_codegen_outputs}
      ${${target_file_name}-${language}-HEADERS}
      ${${target_file_name}-${language}-SOURCES}
    BYPRODUCTS ${thrift_codegen_byproducts}
    ${thrift_patch_codegen_commands}
    COMMAND ${thrift_compiler}
      ${thrift_schema_arguments}
      --gen "${thrift_generator_spec}"
      -o ${output_path}
      ${thrift_include_directories}
      "${file_path}/${source_file_name}.thrift"
    ${thrift_post_codegen_commands}
    DEPENDS
      ${thrift_compiler}
      "${file_path}/${source_file_name}.thrift"
    COMMENT
      "Generating ${target_file_name} ${language} files. Output: ${output_path}"
  )
  add_custom_target(
    ${target_file_name}-${language}-target ALL
    DEPENDS ${thrift_patch_codegen_outputs}
      ${${target_file_name}-${language}-HEADERS}
      ${${target_file_name}-${language}-SOURCES}
  )
  if(thrift_is_cpp AND NOT THRIFT_GENERATE_NO_INSTALL)
    install(
      DIRECTORY "${output_path}/${thrift_codegen_output_directory}"
      DESTINATION include/${include_prefix}
      FILES_MATCHING PATTERN "*.h")
    install(
      DIRECTORY "${output_path}/${thrift_codegen_output_directory}"
      DESTINATION include/${include_prefix}
      FILES_MATCHING PATTERN "*.tcc")
  endif()
endmacro()
