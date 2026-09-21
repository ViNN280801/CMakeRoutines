# Branch coverage for optimizations/PGOConfig.cmake
include("${_module_root}/optimizations/PGOConfig.cmake")

# MSVC GENERATE -> /GL (compile) + /LTCG /GENPROFILE (link)
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_pgo(${t} MODE GENERATE)
expect_compile_option(${t} "/GL")
expect_link_option(${t} "/GENPROFILE")

# MSVC USE -> /USEPROFILE
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_pgo(${t} MODE USE)
expect_link_option(${t} "/USEPROFILE")

# GCC GENERATE -> -fprofile-arcs
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_pgo(${t} MODE GENERATE)
expect_compile_option(${t} "-fprofile-arcs")

# GCC USE -> -fprofile-use
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_pgo(${t} MODE USE)
expect_compile_option(${t} "-fprofile-use=")

# Clang GENERATE -> -fprofile-arcs
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
configure_pgo(${t} MODE GENERATE)
expect_compile_option(${t} "-fprofile-arcs")

# Intel GENERATE -> -prof-gen=dir=
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
configure_pgo(${t} MODE GENERATE)
expect_compile_option(${t} "-prof-gen=dir=")

# Intel USE -> -prof-use=
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
configure_pgo(${t} MODE USE)
expect_compile_option(${t} "-prof-use=")
