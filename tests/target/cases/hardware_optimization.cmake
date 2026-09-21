# Branch coverage for optimizations/HardwareOptimization.cmake
include("${_module_root}/optimizations/HardwareOptimization.cmake")

# MSVC NATIVE_ARCH -> /arch:AVX2
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_hardware_optimization(${t} OPTIMIZATIONS NATIVE_ARCH)
expect_compile_option(${t} "/arch:AVX2")

# MSVC AVX2 -> /arch:AVX2
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_hardware_optimization(${t} OPTIMIZATIONS AVX2)
expect_compile_option(${t} "/arch:AVX2")

# MSVC FAST_MATH -> /fp:fast
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_hardware_optimization(${t} OPTIMIZATIONS FAST_MATH)
expect_compile_option(${t} "/fp:fast")

# GCC NATIVE_ARCH -> -march=native
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_hardware_optimization(${t} OPTIMIZATIONS NATIVE_ARCH)
expect_compile_option(${t} "-march=native")

# GCC AVX2 -> -mavx2
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_hardware_optimization(${t} OPTIMIZATIONS AVX2)
expect_compile_option(${t} "-mavx2")

# GCC FAST_MATH -> -ffast-math
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_hardware_optimization(${t} OPTIMIZATIONS FAST_MATH)
expect_compile_option(${t} "-ffast-math")

# Clang AVX2 -> -mavx2
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
configure_hardware_optimization(${t} OPTIMIZATIONS AVX2)
expect_compile_option(${t} "-mavx2")

# Intel NATIVE_ARCH -> -xHost
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
configure_hardware_optimization(${t} OPTIMIZATIONS NATIVE_ARCH)
expect_compile_option(${t} "-xHost")

# Intel AVX2 -> -xCORE-AVX2
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
configure_hardware_optimization(${t} OPTIMIZATIONS AVX2)
expect_compile_option(${t} "-xCORE-AVX2")

# Intel FAST_MATH -> -fp-model fast=2
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
configure_hardware_optimization(${t} OPTIMIZATIONS FAST_MATH)
expect_compile_option(${t} "-fp-model")

# Legacy: GCC ARCH native -> -march=native
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_hardware_optimization(${t} ARCH native)
expect_compile_option(${t} "-march=native")

# Legacy: GCC TUNE native -> -mtune=native
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_hardware_optimization(${t} TUNE native)
expect_compile_option(${t} "-mtune=native")

# Legacy: MSVC FLOATING_POINT FAST -> /fp:fast
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_hardware_optimization(${t} FLOATING_POINT FAST)
expect_compile_option(${t} "/fp:fast")

# EXTRA_FLAGS
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_hardware_optimization(${t} EXTRA_FLAGS -fmyhw)
expect_compile_option(${t} "-fmyhw")
