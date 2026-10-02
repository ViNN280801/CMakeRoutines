# Fixture for cases/split_debug_info_build.cmake: an executable and a shared
# library that the parent directory configures (the shape LumexLib uses, where
# every module is configured from the project root).
cmake_minimum_required(VERSION 3.16)
project(SplitDebugInfoFixture C CXX)

include("${MODULE_ROOT}/optimizations/OptimizationLevelConfig.cmake")

add_subdirectory(lib)
add_executable(fixture_app main.cpp)
target_link_libraries(fixture_app PRIVATE fixture_lib)

configure_optimization_level(fixture_app CXX_STDLIB DEFAULT)
configure_optimization_level(fixture_lib CXX_STDLIB DEFAULT)
