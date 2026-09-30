# CXX_STDLIB of configure_optimization_level (AUTO | LIBCXX | DEFAULT) and the
# target-level -stdlib detection of link_compiler_runtime.
include("${_module_root}/optimizations/OptimizationLevelConfig.cmake")
include("${_module_root}/deployment/LinkCompilerRuntime.cmake")

# The libc++ probe result is cached, so fixing the cache entry runs every
# branch on any host, whether libc++ is installed or not.
set(_opt_lvl_clang_libcxx_usable TRUE CACHE INTERNAL "libc++ probe (target tests)" FORCE)

function(_ct_expect_stdlib target expected)
  _ct_increment()
  _lcr_detect_stdlib_flag(_got ${target})
  if(NOT "${_got}" STREQUAL "${expected}")
    _ct_fail("link_compiler_runtime detects '${_got}' for '${target}', expected '${expected}'")
  endif()
endfunction()

# AUTO (the default) on a library: -stdlib=libc++ for the library and for its
# consumers, at compile and at link time.
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
configure_optimization_level(${t})
expect_compile_option(${t} "^-stdlib=libc\\+\\+$")
expect_link_option(${t} "^-stdlib=libc\\+\\+$")
expect_interface_compile_option(${t} "^-stdlib=libc\\+\\+$")
expect_interface_link_option(${t} "^-stdlib=libc\\+\\+$")

# link_compiler_runtime finds the flag on the library itself and, through the
# INTERFACE options, on an executable that only links the library.
_ct_expect_stdlib(${t} "libc++")
add_executable(_ct_stdlib_consumer "${_CT_DUMMY_SRC}")
target_link_libraries(_ct_stdlib_consumer PRIVATE ${t})
_ct_expect_stdlib(_ct_stdlib_consumer "libc++")

# AUTO on an executable: PRIVATE only, there is no consumer to hand it to.
add_executable(_ct_stdlib_exe "${_CT_DUMMY_SRC}")
configure_optimization_level(_ct_stdlib_exe CXX_STDLIB AUTO)
expect_compile_option(_ct_stdlib_exe "^-stdlib=libc\\+\\+$")
expect_link_option(_ct_stdlib_exe "^-stdlib=libc\\+\\+$")
expect_no_interface_compile_option(_ct_stdlib_exe "stdlib")
expect_no_interface_link_option(_ct_stdlib_exe "stdlib")

# LIBCXX with a usable libc++ behaves like AUTO; the value is case-insensitive.
new_test_target(t)
configure_optimization_level(${t} CXX_STDLIB libcxx)
expect_compile_option(${t} "^-stdlib=libc\\+\\+$")
expect_interface_compile_option(${t} "^-stdlib=libc\\+\\+$")

# DEFAULT adds no -stdlib even though libc++ is usable.
new_test_target(t)
configure_optimization_level(${t} CXX_STDLIB DEFAULT)
expect_no_compile_option(${t} "stdlib")
expect_no_link_option(${t} "stdlib")
expect_no_interface_compile_option(${t} "stdlib")
expect_no_interface_link_option(${t} "stdlib")

# AUTO without a usable libc++ keeps the compiler default (and reports it).
set(_opt_lvl_clang_libcxx_usable FALSE CACHE INTERNAL "libc++ probe (target tests)" FORCE)
new_test_target(t)
configure_optimization_level(${t})
expect_no_compile_option(${t} "stdlib")
expect_no_interface_compile_option(${t} "stdlib")

# GCC ignores CXX_STDLIB.
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_optimization_level(${t} CXX_STDLIB LIBCXX)
expect_no_compile_option(${t} "stdlib")
expect_no_interface_compile_option(${t} "stdlib")

# A later configure of this tree probes again.
unset(_opt_lvl_clang_libcxx_usable CACHE)

# FATAL_ERROR branches: an unknown value, and LIBCXX without a usable libc++.
set(_vf_body "
cmake_minimum_required(VERSION 3.16)
project(VF LANGUAGES CXX)
include(\"${_module_root}/optimizations/OptimizationLevelConfig.cmake\")
add_library(vf STATIC dummy.cpp)
configure_optimization_level(vf CXX_STDLIB LIBSTDCXX)
")
expect_configure_fail(optimization_cxx_stdlib_invalid "${_vf_body}"
  "CXX_STDLIB must be AUTO, LIBCXX or DEFAULT")

set(_vf_body "
cmake_minimum_required(VERSION 3.16)
project(VF LANGUAGES CXX)
include(\"${_module_root}/optimizations/OptimizationLevelConfig.cmake\")
set(_opt_lvl_clang_libcxx_usable FALSE CACHE INTERNAL \"\")
set(MSVC FALSE)
set(CMAKE_CXX_COMPILER_ID Clang)
add_library(vf STATIC dummy.cpp)
configure_optimization_level(vf CXX_STDLIB LIBCXX)
")
expect_configure_fail(optimization_cxx_stdlib_libcxx_missing "${_vf_body}"
  "CXX_STDLIB LIBCXX for 'vf'")
