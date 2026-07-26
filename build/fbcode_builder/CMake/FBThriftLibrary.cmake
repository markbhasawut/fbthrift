# Copyright (c) Facebook, Inc. and its affiliates.

include(FBCMakeParseArgs)
include(FBThriftPyLibrary)
include(FBThriftPy3Library)
include(FBThriftPythonLibrary)
include(FBThriftCppLibrary)

#
# add_fbthrift_library()
#
# This is a convenience function that generates thrift libraries for multiple
# languages.
#
# For example:
#   add_fbthrift_library(
#     foo foo.thrift
#     LANGUAGES cpp py python
#     SERVICES Foo
#     DEPENDS bar)
#
# will be expanded into three separate calls:
#
# add_fbthrift_cpp_library(foo_cpp foo.thrift SERVICES Foo DEPENDS bar_cpp)
# add_fbthrift_py_library(foo_py foo.thrift SERVICES Foo DEPENDS bar_py)
# add_fbthrift_python_library(
#   foo_python foo.thrift SERVICES Foo DEPENDS bar_python)
#
function(add_fbthrift_library LIB_NAME THRIFT_FILE)
  # Parse the arguments
  set(one_value_args
    PY_NAMESPACE
    PY3_NAMESPACE
    PYTHON_NAMESPACE
    INCLUDE_DIR
    THRIFT_INCLUDE_DIR
  )
  set(multi_value_args
    SERVICES
    DEPENDS
    LANGUAGES
    CPP_OPTIONS
    PY_OPTIONS
    PY3_OPTIONS
    PYTHON_OPTIONS
  )
  fb_cmake_parse_args(
    ARG "" "${one_value_args}" "${multi_value_args}" "${ARGN}"
  )

  if(NOT DEFINED ARG_INCLUDE_DIR)
    set(ARG_INCLUDE_DIR "include")
  endif()
  if(NOT DEFINED ARG_THRIFT_INCLUDE_DIR)
    set(ARG_THRIFT_INCLUDE_DIR "${ARG_INCLUDE_DIR}/thrift-files")
  endif()

  # CMake 3.12+ adds list(TRANSFORM) which would be nice to use here, but for
  # now we still want to support older versions of CMake.
  set(CPP_DEPENDS)
  set(PY_DEPENDS)
  set(PY3_DEPENDS)
  set(PYTHON_DEPENDS)
  foreach(dep IN LISTS ARG_DEPENDS)
    list(APPEND CPP_DEPENDS "${dep}_cpp")
    list(APPEND PY_DEPENDS "${dep}_py")
    list(APPEND PY3_DEPENDS "${dep}_py3")
    list(APPEND PYTHON_DEPENDS "${dep}_python")
  endforeach()

  if("cpp" IN_LIST ARG_LANGUAGES AND "cpp2" IN_LIST ARG_LANGUAGES)
    message(FATAL_ERROR
      "cpp and cpp2 select the same generator; request only one for "
      "thrift library ${LIB_NAME}")
  endif()

  foreach(lang IN LISTS ARG_LANGUAGES)
    if ("${lang}" STREQUAL "cpp" OR "${lang}" STREQUAL "cpp2")
      add_fbthrift_cpp_library(
        "${LIB_NAME}_cpp" "${THRIFT_FILE}"
        SERVICES ${ARG_SERVICES}
        DEPENDS ${CPP_DEPENDS}
        OPTIONS ${ARG_CPP_OPTIONS}
        INCLUDE_DIR "${ARG_INCLUDE_DIR}"
        THRIFT_INCLUDE_DIR "${ARG_THRIFT_INCLUDE_DIR}"
      )
    elseif ("${lang}" STREQUAL "py")
      unset(namespace_args)
      if (DEFINED ARG_PY_NAMESPACE)
        set(namespace_args NAMESPACE "${ARG_PY_NAMESPACE}")
      endif()
      add_fbthrift_py_library(
        "${LIB_NAME}_py" "${THRIFT_FILE}"
        SERVICES ${ARG_SERVICES}
        ${namespace_args}
        DEPENDS ${PY_DEPENDS}
        OPTIONS ${ARG_PY_OPTIONS}
        THRIFT_INCLUDE_DIR "${ARG_THRIFT_INCLUDE_DIR}"
      )
    elseif ("${lang}" STREQUAL "py3")
      unset(namespace_args)
      if (DEFINED ARG_PY3_NAMESPACE)
        set(namespace_args NAMESPACE "${ARG_PY3_NAMESPACE}")
      endif()
      add_fbthrift_py3_library(
        "${LIB_NAME}_py3" "${THRIFT_FILE}"
        SERVICES ${ARG_SERVICES}
        ${namespace_args}
        DEPENDS ${PY3_DEPENDS}
        OPTIONS ${ARG_PY3_OPTIONS}
        THRIFT_INCLUDE_DIR "${ARG_THRIFT_INCLUDE_DIR}"
      )
    elseif ("${lang}" STREQUAL "python")
      unset(namespace_args)
      if (DEFINED ARG_PYTHON_NAMESPACE)
        set(namespace_args NAMESPACE "${ARG_PYTHON_NAMESPACE}")
      endif()
      add_fbthrift_python_library(
        "${LIB_NAME}_python" "${THRIFT_FILE}"
        SERVICES ${ARG_SERVICES}
        ${namespace_args}
        DEPENDS ${PYTHON_DEPENDS}
        OPTIONS ${ARG_PYTHON_OPTIONS}
        THRIFT_INCLUDE_DIR "${ARG_THRIFT_INCLUDE_DIR}"
      )
    else()
      message(
        FATAL_ERROR "unknown language for thrift library ${LIB_NAME}: ${lang}"
      )
    endif()
  endforeach()
endfunction()
