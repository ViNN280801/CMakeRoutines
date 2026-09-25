# CMakeRoutines self-test suite.
#
# Standalone: configure this directory with no language and run ctest:
#   cmake -S tests -B build -G Ninja
#   ctest --test-dir build
#
# Each case is a `cmake -P` script under cases/ driven by run_one.cmake. The
# tests do not need a compiler: they either exercise pure helpers in script
# mode or assert on the source of a routine (regression pinning).

cmake_minimum_required(VERSION 3.16)
project(CMakeRoutinesTests NONE)

enable_testing()

function(_cmake_routines_add_case name)
  add_test(NAME ${name}
    COMMAND ${CMAKE_COMMAND}
      -DCASE=${name}
      -DMODULE_ROOT=${CMAKE_CURRENT_LIST_DIR}/..
      -P ${CMAKE_CURRENT_LIST_DIR}/run_one.cmake)
  set_tests_properties(${name} PROPERTIES
    LABELS "cmake_routines"
    TIMEOUT 60)
endfunction()

function(_cmake_routines_add_fail_case name pattern)
  add_test(NAME ${name}
    COMMAND ${CMAKE_COMMAND}
      -DCASE=${name}
      -DCASE_EXPECT_FAIL=1
      -DCASE_FAIL_PATTERN=${pattern}
      -DMODULE_ROOT=${CMAKE_CURRENT_LIST_DIR}/..
      -P ${CMAKE_CURRENT_LIST_DIR}/run_one.cmake)
  set_tests_properties(${name} PROPERTIES
    LABELS "cmake_routines"
    TIMEOUT 60)
endfunction()

# --- Sanitizer regressions (clang-cl runtime linking + DLL staging) ---
_cmake_routines_add_case(sanitizers_clang_cl_detection)
_cmake_routines_add_case(sanitizers_arch_suffix)
_cmake_routines_add_case(sanitizers_resource_dir)
_cmake_routines_add_case(sanitizers_runtime_options)
_cmake_routines_add_case(sanitizers_clang_cl_wiring)

# --- Optimization regression (debug CRT gating for clang-cl ASan) ---
_cmake_routines_add_case(optimization_debug_crt_gating)
# --- Optimization regression (libc++ probe must compile a header) ---
_cmake_routines_add_case(optimization_clang_libcxx_probe)

# --- Module coverage ---
_cmake_routines_add_case(sanitizer_profile_validate)
_cmake_routines_add_fail_case(sanitizer_profile_validate_invalid
  "Invalid sanitizer profile 'BOGUS'")
_cmake_routines_add_case(recursive_source_collection)
_cmake_routines_add_case(recursive_source_collection_edges)
_cmake_routines_add_case(deployment_copy_runtime_dependencies_policy)
_cmake_routines_add_case(version_config)
_cmake_routines_add_case(static_analysis)
_cmake_routines_add_case(link_compiler_runtime_helpers)
_cmake_routines_add_case(warning_suppression_helpers)

# --- MsvcVcvarsConfig pure helpers ---
_cmake_routines_add_case(msvc_vcvars_helpers)
_cmake_routines_add_fail_case(msvc_vcvars_fail_unknown_arch "unknown ARCH 'mips'")
_cmake_routines_add_fail_case(msvc_vcvars_fail_host_cant_run "32-bit Windows host")
_cmake_routines_add_fail_case(msvc_vcvars_fail_unsupported_host "unsupported host architecture")
