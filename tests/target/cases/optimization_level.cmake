# Branch coverage for optimizations/OptimizationLevelConfig.cmake
include("${_module_root}/optimizations/OptimizationLevelConfig.cmake")

# MSVC MAXIMUM -> /fp:fast + /arch:AVX2 (non-portable)
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_optimization_level(${t} LEVEL MAXIMUM)
expect_compile_option(${t} "/fp:fast")
expect_compile_option(${t} "/arch:AVX2")

# MSVC MINSIZE -> /Os
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_optimization_level(${t} LEVEL MINSIZE)
expect_compile_option(${t} "/Os")

# MSVC STANDARD -> /O1
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_optimization_level(${t} LEVEL STANDARD)
expect_compile_option(${t} "/O1")

# MSVC default (PORTABLE) -> /O2, no /fp:fast
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_optimization_level(${t})
expect_compile_option(${t} "/O2")
expect_no_compile_option(${t} "/fp:fast")

# GNU MAXIMUM -> -ffast-math (aggressive FP)
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_optimization_level(${t} LEVEL MAXIMUM)
expect_compile_option(${t} "-ffast-math")

# GNU default (PORTABLE) -> -O2, no -ffast-math
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_optimization_level(${t})
expect_compile_option(${t} "-O2")
expect_no_compile_option(${t} "-ffast-math")

# Clang dispatch
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
configure_optimization_level(${t})
expect_compile_option(${t} "-O2")

# Intel dispatch
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
configure_optimization_level(${t})
expect_no_compile_option(${t} "/fp:fast")
