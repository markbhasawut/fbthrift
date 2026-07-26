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

# Prefer an installed gflags package config, then fall back to raw headers and
# libraries while preserving the variable names used by fbthrift.
find_package(gflags CONFIG QUIET)
if (gflags_FOUND)
  set(LIBGFLAGS_LIBRARY ${gflags_LIBRARIES})
  set(LIBGFLAGS_INCLUDE_DIR ${gflags_INCLUDE_DIR})
  set(LIBGFLAGS_FOUND TRUE)
  set(GFLAGS_FOUND TRUE)
  set(Gflags_FOUND TRUE)
else ()
  find_path(LIBGFLAGS_INCLUDE_DIR gflags/gflags.h)
  find_library(LIBGFLAGS_LIBRARY_DEBUG NAMES gflagsd gflags_staticd)
  find_library(LIBGFLAGS_LIBRARY_RELEASE NAMES gflags gflags_static)
  include(SelectLibraryConfigurations)
  select_library_configurations(LIBGFLAGS)
  include(FindPackageHandleStandardArgs)
  find_package_handle_standard_args(
    Gflags DEFAULT_MSG LIBGFLAGS_LIBRARY LIBGFLAGS_INCLUDE_DIR)
  set(LIBGFLAGS_FOUND ${Gflags_FOUND})
  set(GFLAGS_FOUND ${Gflags_FOUND})
  set(gflags_FOUND ${Gflags_FOUND})
  set(gflags_INCLUDE_DIR ${LIBGFLAGS_INCLUDE_DIR})
  set(gflags_LIBRARIES ${LIBGFLAGS_LIBRARY})
endif ()

if (LIBGFLAGS_FOUND AND NOT TARGET gflags)
  add_library(gflags UNKNOWN IMPORTED)
  if (TARGET gflags-shared)
    target_link_libraries(gflags INTERFACE gflags-shared)
    set(LIBGFLAGS_LIBRARY gflags-shared)
  else ()
    set_target_properties(
      gflags
      PROPERTIES
        IMPORTED_LOCATION "${LIBGFLAGS_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${LIBGFLAGS_INCLUDE_DIR}"
    )
  endif ()
endif ()

mark_as_advanced(LIBGFLAGS_LIBRARY LIBGFLAGS_INCLUDE_DIR)
