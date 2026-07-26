# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0

find_path(Xxhash_INCLUDE_DIR NAMES xxhash.h)
find_library(Xxhash_LIBRARY_RELEASE NAMES xxhash)

include(SelectLibraryConfigurations)
select_library_configurations(Xxhash)
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  Xxhash DEFAULT_MSG Xxhash_LIBRARY Xxhash_INCLUDE_DIR)

if (Xxhash_FOUND)
  message(STATUS "Found xxhash: ${Xxhash_LIBRARY}")
endif ()

mark_as_advanced(Xxhash_INCLUDE_DIR Xxhash_LIBRARY)
