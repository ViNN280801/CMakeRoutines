# CMakeRoutines target-level self-test harness.
#
# Configures a real project (needs a C/C++ compiler only to enable the
# language) and exercises the `configure_*` routines against every branch of
# their conditionals, checking the resulting target properties. No build is
# run; every assertion is a message(FATAL_ERROR) during configure.
#
# Usage:
#   cmake -S tests/target -B <build> -G Ninja
#     [-DCMAKE_C_COMPILER=<cc> -DCMAKE_CXX_COMPILER=<cxx>]
#
# The platform/compiler branches are simulated by overriding WIN32 / UNIX /
# APPLE / MSVC / CMAKE_CXX_COMPILER_ID in the caller scope (see helpers.cmake),
# so a single configure can cover MSVC, GCC, Clang, and Intel code paths.

cmake_minimum_required(VERSION 3.16)
project(CMakeRoutinesTargetTests LANGUAGES C CXX)

set(_module_root "${CMAKE_CURRENT_LIST_DIR}/../..")

include("${CMAKE_CURRENT_LIST_DIR}/helpers.cmake")

# Each case runs its tests immediately when included.
include("${CMAKE_CURRENT_LIST_DIR}/cases/compiler_flags.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/linker_flags.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/warning_suppression.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/hardware_optimization.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/optimization_level.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/windows_version.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/build_timing.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/pgo.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/precompiled_headers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/unity_build.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/coverage.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/library_versioning.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/compile_commands.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/sanitizers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cases/validation_failures.cmake")

get_property(_total GLOBAL PROPERTY _CT_ASSERT_COUNT)
if(NOT _total)
  set(_total 0)
endif()
message(STATUS "CMakeRoutinesTargetTests: ALL PASSED (${_total} assertions)")
