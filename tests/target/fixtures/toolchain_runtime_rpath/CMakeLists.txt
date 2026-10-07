# Fixture for cases/toolchain_runtime_rpath_build.cmake: an executable that
# uses the C++ standard library and a shared library that returns a
# std::string, both configured the way LumexLib configures its targets
# (configure_optimization_level, then configure_toolchain_runtime_rpath), from
# the parent directory of the library.
cmake_minimum_required(VERSION 3.16)
project(ToolchainRuntimeRpathFixture C CXX)

include("${MODULE_ROOT}/optimizations/OptimizationLevelConfig.cmake")
include("${MODULE_ROOT}/deployment/ToolchainRuntimeRpath.cmake")

add_subdirectory(lib)
add_executable(fixture_app main.cpp)
target_link_libraries(fixture_app PRIVATE fixture_lib)

foreach(_target fixture_app fixture_lib)
  configure_optimization_level(${_target})
  configure_toolchain_runtime_rpath(${_target})
endforeach()
