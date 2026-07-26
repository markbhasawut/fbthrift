# Copyright (c) Meta Platforms, Inc. and affiliates.

include(FBCMakeParseArgs)

# Generate thrift.py3 Cython and native-wrapper sources from a Thrift file.
#
# This function intentionally creates a code-generation target, not a C++ or
# Python archive. thrift.py3 requires a separately generated cpp/cpp2 target
# and a Cython extension build. Consumers can read the THRIFT_PY3_HEADERS and
# THRIFT_PY3_SOURCES target properties to build that extension without adding
# an implicit py3 -> cpp2 dependency edge here.
function(add_fbthrift_py3_library LIB_NAME THRIFT_FILE)
  set(one_value_args NAMESPACE THRIFT_INCLUDE_DIR)
  set(multi_value_args SERVICES DEPENDS OPTIONS)
  fb_cmake_parse_args(
    ARG "" "${one_value_args}" "${multi_value_args}" "${ARGN}"
  )

  if(NOT DEFINED ARG_THRIFT_INCLUDE_DIR)
    set(ARG_THRIFT_INCLUDE_DIR "include/thrift-files")
  endif()

  get_filename_component(base "${THRIFT_FILE}" NAME_WE)
  set(output_dir "${CMAKE_CURRENT_BINARY_DIR}/${THRIFT_FILE}-py3")

  if(DEFINED ARG_NAMESPACE AND NOT ARG_NAMESPACE STREQUAL "")
    string(REPLACE "." "/" namespace_dir "${ARG_NAMESPACE}")
    set(module_dir "${namespace_dir}/${base}")
  else()
    set(module_dir "${base}")
  endif()
  set(python_output_dir "${output_dir}/gen-py3/${module_dir}")
  set(cpp_output_dir "${output_dir}/gen-py3/${base}")

  set(generated_byproducts)
  if(DEFINED ARG_NAMESPACE AND NOT ARG_NAMESPACE STREQUAL "")
    set(namespace_path "${output_dir}/gen-py3")
    string(REPLACE "." ";" namespace_parts "${ARG_NAMESPACE}")
    foreach(namespace_part IN LISTS namespace_parts)
      string(APPEND namespace_path "/${namespace_part}")
      list(APPEND generated_byproducts "${namespace_path}/__init__.py")
    endforeach()
  endif()

  set(generated_headers
    "${python_output_dir}/cbindings.pxd"
    "${python_output_dir}/converter.pxd"
    "${python_output_dir}/metadata.pxd"
    "${python_output_dir}/metadata.pyi"
    "${python_output_dir}/types.pxd"
    "${python_output_dir}/types.pyi"
    "${python_output_dir}/types_fields.pxd"
    "${cpp_output_dir}/metadata.h"
    "${cpp_output_dir}/types.h"
  )
  set(generated_sources
    "${python_output_dir}/__init__.py"
    "${python_output_dir}/builders.py"
    "${python_output_dir}/constants_FBTHRIFT_ONLY_DO_NOT_USE.py"
    "${python_output_dir}/containers_FBTHRIFT_ONLY_DO_NOT_USE.py"
    "${python_output_dir}/converter.pyx"
    "${python_output_dir}/metadata.py"
    "${python_output_dir}/metadata.pyx"
    "${python_output_dir}/types.py"
    "${python_output_dir}/types.pyx"
    "${python_output_dir}/types_auto_FBTHRIFT_ONLY_DO_NOT_USE.py"
    "${python_output_dir}/types_auto_migrated.py"
    "${python_output_dir}/types_empty.pyx"
    "${python_output_dir}/types_fields.pyx"
    "${python_output_dir}/types_impl_FBTHRIFT_ONLY_DO_NOT_USE.py"
    "${python_output_dir}/types_reflection.py"
    "${cpp_output_dir}/metadata.cpp"
  )

  if("inplace_migrate" IN_LIST ARG_OPTIONS)
    list(APPEND generated_sources
      "${python_output_dir}/types_inplace_FBTHRIFT_ONLY_DO_NOT_USE.py")
  endif()
  if(ARG_SERVICES OR "single_file_service" IN_LIST ARG_OPTIONS)
    list(APPEND generated_headers
      "${python_output_dir}/clients.pxd"
      "${python_output_dir}/clients.pyi"
      "${python_output_dir}/clients_wrapper.pxd"
      "${python_output_dir}/services.pxd"
      "${python_output_dir}/services.pyi"
      "${python_output_dir}/services_interface.pxd"
      "${python_output_dir}/services_wrapper.pxd"
      "${cpp_output_dir}/clients_wrapper.h"
      "${cpp_output_dir}/services_wrapper.h"
    )
    list(APPEND generated_sources
      "${python_output_dir}/clients.py"
      "${python_output_dir}/clients.pyx"
      "${python_output_dir}/services.py"
      "${python_output_dir}/services.pyx"
      "${cpp_output_dir}/clients_wrapper.cpp"
      "${cpp_output_dir}/services_wrapper.cpp"
    )
  endif()

  add_library("${LIB_NAME}.thrift_includes" INTERFACE)
  target_include_directories(
    "${LIB_NAME}.thrift_includes"
    INTERFACE
      "$<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}>"
      "$<INSTALL_INTERFACE:${ARG_THRIFT_INCLUDE_DIR}>"
  )
  foreach(dep IN LISTS ARG_DEPENDS)
    target_link_libraries(
      "${LIB_NAME}.thrift_includes"
      INTERFACE "${dep}.thrift_includes"
    )
  endforeach()

  set(thrift_include_options
    "-I;$<JOIN:$<TARGET_PROPERTY:${LIB_NAME}.thrift_includes,INTERFACE_INCLUDE_DIRECTORIES>,;-I;>"
  )

  foreach(option IN LISTS ARG_OPTIONS)
    if(option MATCHES "^include_prefix=")
      message(FATAL_ERROR
        "add_fbthrift_py3_library() computes include_prefix; do not pass it "
        "in OPTIONS")
    endif()
  endforeach()
  file(RELATIVE_PATH include_prefix
    "${PROJECT_SOURCE_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/${THRIFT_FILE}")
  get_filename_component(include_prefix "${include_prefix}" DIRECTORY)
  if(NOT include_prefix STREQUAL "")
    list(APPEND ARG_OPTIONS "include_prefix=${include_prefix}")
  endif()
  string(REPLACE ";" "," generator_options "${ARG_OPTIONS}")
  set(generator_spec "py3")
  if(NOT generator_options STREQUAL "")
    string(APPEND generator_spec ":${generator_options}")
  endif()

  add_custom_command(
    OUTPUT ${generated_headers} ${generated_sources}
    BYPRODUCTS ${generated_byproducts}
    COMMAND_EXPAND_LISTS
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${output_dir}"
    COMMAND
      "${FBTHRIFT_COMPILER}"
      --legacy-strict
      --gen "${generator_spec}"
      "${thrift_include_options}"
      -I "${FBTHRIFT_INCLUDE_DIR}"
      -o "${output_dir}"
      "${CMAKE_CURRENT_SOURCE_DIR}/${THRIFT_FILE}"
    COMMAND
      "${CMAKE_COMMAND}" -E touch "${python_output_dir}/__init__.py"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    MAIN_DEPENDENCY "${THRIFT_FILE}"
    DEPENDS ${ARG_DEPENDS} "${FBTHRIFT_COMPILER}"
    VERBATIM
  )

  add_custom_target(
    "${LIB_NAME}" ALL DEPENDS ${generated_headers} ${generated_sources})
  set_target_properties(
    "${LIB_NAME}"
    PROPERTIES
      THRIFT_PY3_HEADERS "${generated_headers}"
      THRIFT_PY3_SOURCES "${generated_sources}"
      THRIFT_PY3_OUTPUT_DIR "${output_dir}/gen-py3"
  )
endfunction()
