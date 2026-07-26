# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0

include(FindPackageHandleStandardArgs)
include(SelectLibraryConfigurations)

find_library(GLOG_LIBRARY_RELEASE glog PATHS ${GLOG_LIBRARYDIR})
find_library(GLOG_LIBRARY_DEBUG glogd PATHS ${GLOG_LIBRARYDIR})
find_path(GLOG_INCLUDE_DIR glog/logging.h PATHS ${GLOG_INCLUDEDIR})
select_library_configurations(GLOG)
find_package_handle_standard_args(
  Glog DEFAULT_MSG GLOG_LIBRARY GLOG_INCLUDE_DIR)

set(GLOG_LIBRARIES ${GLOG_LIBRARY})
set(GLOG_INCLUDE_DIRS ${GLOG_INCLUDE_DIR})
mark_as_advanced(GLOG_LIBRARY GLOG_INCLUDE_DIR)

if (Glog_FOUND AND NOT TARGET glog::glog)
  add_library(glog::glog UNKNOWN IMPORTED)
  set_target_properties(
    glog::glog
    PROPERTIES
      IMPORTED_LOCATION "${GLOG_LIBRARIES}"
      INTERFACE_INCLUDE_DIRECTORIES "${GLOG_INCLUDE_DIRS}"
      INTERFACE_COMPILE_DEFINITIONS "GLOG_USE_GLOG_EXPORT"
  )
  find_package(Gflags QUIET)
  if (Gflags_FOUND)
    set_property(
      TARGET glog::glog APPEND
      PROPERTY INTERFACE_LINK_LIBRARIES "${LIBGFLAGS_LIBRARY}"
    )
  endif ()
endif ()
