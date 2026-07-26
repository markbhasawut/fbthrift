# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0

find_path(sodium_INCLUDE_DIR NAMES sodium.h)
find_library(sodium_LIBRARY_RELEASE NAMES sodium libsodium)
find_library(sodium_LIBRARY_DEBUG NAMES sodiumd libsodiumd sodium libsodium)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  Sodium
  REQUIRED_VARS
    sodium_LIBRARY_RELEASE
    sodium_LIBRARY_DEBUG
    sodium_INCLUDE_DIR
)

if (Sodium_FOUND)
  set(
    sodium_LIBRARIES
    optimized "${sodium_LIBRARY_RELEASE}"
    debug "${sodium_LIBRARY_DEBUG}"
  )
  if (NOT TARGET sodium)
    add_library(sodium UNKNOWN IMPORTED)
    set_target_properties(
      sodium
      PROPERTIES
        IMPORTED_LOCATION "${sodium_LIBRARY_RELEASE}"
        IMPORTED_LOCATION_DEBUG "${sodium_LIBRARY_DEBUG}"
        INTERFACE_INCLUDE_DIRECTORIES "${sodium_INCLUDE_DIR}"
    )
  endif ()
endif ()

mark_as_advanced(
  sodium_INCLUDE_DIR
  sodium_LIBRARY_DEBUG
  sodium_LIBRARY_RELEASE
)
