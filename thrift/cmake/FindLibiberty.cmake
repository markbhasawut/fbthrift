# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0

find_path(LIBIBERTY_INCLUDE_DIR NAMES libiberty.h PATH_SUFFIXES libiberty)
find_library(LIBIBERTY_LIBRARY NAMES iberty)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  Libiberty
  REQUIRED_VARS LIBIBERTY_LIBRARY LIBIBERTY_INCLUDE_DIR
)

if (Libiberty_FOUND)
  set(LIBIBERTY_FOUND TRUE)
  set(LIBIBERTY_LIBRARIES ${LIBIBERTY_LIBRARY})
  set(LIBIBERTY_INCLUDE_DIRS ${LIBIBERTY_INCLUDE_DIR})
endif ()

mark_as_advanced(LIBIBERTY_INCLUDE_DIR LIBIBERTY_LIBRARY)
