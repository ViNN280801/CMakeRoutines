# Branch coverage for testing/CoverageConfig.cmake
include("${_module_root}/testing/CoverageConfig.cmake")

# gcov -> --coverage
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_coverage(${t} TOOL gcov)
expect_compile_option(${t} "--coverage")

# llvm-cov -> -fprofile-instr-generate
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
configure_coverage(${t} TOOL llvm-cov)
expect_compile_option(${t} "-fprofile-instr-generate")

# msvc -> /ZI
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_coverage(${t} TOOL msvc)
expect_compile_option(${t} "/ZI")
