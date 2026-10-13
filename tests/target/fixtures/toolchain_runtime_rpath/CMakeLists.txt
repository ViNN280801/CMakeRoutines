# Fixture for cases/toolchain_runtime_rpath_build.cmake: an executable that
# uses the C++ standard library and a shared library that returns a
# std::string, both configured from the parent directory of the library.
# FIXTURE_RPATH_MODE says how the runtime directories reach the targets:
#   CALL      configure_optimization_level, then an explicit
#             configure_toolchain_runtime_rpath (the default)
#   PARAMETER configure_optimization_level(... TOOLCHAIN_RUNTIME_RPATH ON) only
#   BOTH      the parameter and the explicit call (nothing is added twice)
#   NONE      configure_optimization_level without the parameter (no RUNPATH
#             of the toolchain at all: the parameter is off by default)
cmake_minimum_required(VERSION 3.16)
project(ToolchainRuntimeRpathFixture C CXX)

include("${MODULE_ROOT}/optimizations/OptimizationLevelConfig.cmake")
include("${MODULE_ROOT}/deployment/ToolchainRuntimeRpath.cmake")

# Windows (cases/toolchain_runtime_rpath_windows.cmake): a DLL is found next to
# the executable and there is no RPATH, so both go into the build directory and
# the library exports what it defines. Neither setting does anything on ELF.
if(WIN32)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")
  set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

add_subdirectory(lib)
add_executable(fixture_app main.cpp)
target_link_libraries(fixture_app PRIVATE fixture_lib)

if(NOT FIXTURE_RPATH_MODE)
  set(FIXTURE_RPATH_MODE CALL)
endif()

foreach(_target fixture_app fixture_lib)
  if(FIXTURE_RPATH_MODE MATCHES "^(PARAMETER|BOTH)$")
    configure_optimization_level(${_target} TOOLCHAIN_RUNTIME_RPATH ON)
  else()
    configure_optimization_level(${_target})
  endif()
  if(FIXTURE_RPATH_MODE MATCHES "^(CALL|BOTH)$")
    configure_toolchain_runtime_rpath(${_target})
  endif()
endforeach()
