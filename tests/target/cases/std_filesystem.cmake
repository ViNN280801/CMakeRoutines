# Branch coverage for dependencies/StdFilesystem.cmake. The probe compiles and
# links with the real compiler of this configure, so this case runs before any
# case simulates another platform, and the expected library follows the real
# toolchain: GCC before 9.1 keeps std::filesystem in stdc++fs, later GCC needs
# nothing. Other compilers are checked for consistency only.
include("${_module_root}/dependencies/StdFilesystem.cmake")

set(_sfs_expect_lib "")
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU"
   AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 9.1)
  set(_sfs_expect_lib "stdc++fs")
endif()

# Default scope is PRIVATE: LINK_LIBRARIES gets the library (if any).
new_test_target(_sfs_private)
link_std_filesystem(${_sfs_private})
get_target_property(_sfs_libs ${_sfs_private} LINK_LIBRARIES)
if(NOT _sfs_libs)
  set(_sfs_libs "")
endif()
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  if(_sfs_expect_lib AND NOT "${_sfs_expect_lib}" IN_LIST _sfs_libs)
    _ct_fail("GCC ${CMAKE_CXX_COMPILER_VERSION}: expected '${_sfs_expect_lib}' in LINK_LIBRARIES, got '${_sfs_libs}'")
  endif()
  if(NOT _sfs_expect_lib AND _sfs_libs MATCHES "(stdc|c)\\+\\+fs")
    _ct_fail("GCC ${CMAKE_CXX_COMPILER_VERSION}: expected no filesystem library, got '${_sfs_libs}'")
  endif()
endif()
_ct_increment()

# The answer is cached once per compiler and flags; the per-variant probe
# results are not left in the cache.
get_cmake_property(_sfs_cache CACHE_VARIABLES)
set(_sfs_answers 0)
foreach(_v IN LISTS _sfs_cache)
  if(_v MATCHES "^_CMAKE_ROUTINES_STD_FILESYSTEM_PROBE_")
    _ct_fail("probe result '${_v}' left in the cache")
  elseif(_v MATCHES "^_CMAKE_ROUTINES_STD_FILESYSTEM_")
    math(EXPR _sfs_answers "${_sfs_answers} + 1")
    get_property(_sfs_type CACHE "${_v}" PROPERTY TYPE)
    if(NOT _sfs_type STREQUAL "INTERNAL")
      _ct_fail("'${_v}' should be INTERNAL, is '${_sfs_type}'")
    endif()
  endif()
endforeach()
if(NOT _sfs_answers EQUAL 1)
  _ct_fail("expected one cached answer, found ${_sfs_answers}")
endif()
_ct_increment()

# INTERFACE scope: nothing in LINK_LIBRARIES, the same answer in
# INTERFACE_LINK_LIBRARIES.
new_test_target(_sfs_interface)
link_std_filesystem(${_sfs_interface} INTERFACE)
get_target_property(_sfs_libs ${_sfs_interface} LINK_LIBRARIES)
if(_sfs_libs MATCHES "(stdc|c)\\+\\+fs")
  _ct_fail("INTERFACE scope put '${_sfs_libs}' into LINK_LIBRARIES")
endif()
get_target_property(_sfs_ilibs ${_sfs_interface} INTERFACE_LINK_LIBRARIES)
if(_sfs_expect_lib AND NOT "${_sfs_expect_lib}" IN_LIST _sfs_ilibs)
  _ct_fail("INTERFACE scope: expected '${_sfs_expect_lib}' in INTERFACE_LINK_LIBRARIES, got '${_sfs_ilibs}'")
endif()
_ct_increment()

# MSVC needs nothing: the function returns before probing.
set(_sfs_saved_msvc "${MSVC}")
set(MSVC TRUE)
new_test_target(_sfs_msvc)
link_std_filesystem(${_sfs_msvc} PUBLIC)
get_target_property(_sfs_libs ${_sfs_msvc} LINK_LIBRARIES)
if(_sfs_libs)
  _ct_fail("MSVC: expected no link libraries, got '${_sfs_libs}'")
endif()
set(MSVC "${_sfs_saved_msvc}")
_ct_increment()

# Usage errors.
set(_sfs_body "
cmake_minimum_required(VERSION 3.16)
project(SFS LANGUAGES CXX)
include(\"${_module_root}/dependencies/StdFilesystem.cmake\")
add_library(sfs STATIC dummy.cpp)
link_std_filesystem(sfs PUBLIC PRIVATE)
")
expect_configure_fail(std_filesystem_two_scopes "${_sfs_body}"
  "give one of PUBLIC, PRIVATE, INTERFACE")
_ct_increment()

set(_sfs_body "
cmake_minimum_required(VERSION 3.16)
project(SFS LANGUAGES CXX)
include(\"${_module_root}/dependencies/StdFilesystem.cmake\")
link_std_filesystem(no_such_target)
")
expect_configure_fail(std_filesystem_missing_target "${_sfs_body}"
  "Target 'no_such_target' does not exist")
_ct_increment()

set(_sfs_body "
cmake_minimum_required(VERSION 3.16)
project(SFS LANGUAGES CXX)
include(\"${_module_root}/dependencies/StdFilesystem.cmake\")
add_library(sfs STATIC dummy.cpp)
link_std_filesystem(sfs BOGUS)
")
expect_configure_fail(std_filesystem_unknown_argument "${_sfs_body}"
  "unknown arguments 'BOGUS'")
_ct_increment()
