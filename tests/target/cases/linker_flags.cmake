# Branch coverage for core/LinkerFlags.cmake
include("${_module_root}/core/LinkerFlags.cmake")

# ---------------------------------------------------------------------------
# MSVC linker: LTO ON -> /LTCG + /OPT:REF/ICF + /SUBSYSTEM:CONSOLE
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_linker_flags(${t} LTO ON)
expect_link_option(${t} "/LTCG")
expect_link_option(${t} "/OPT:REF")
expect_link_option(${t} "/SUBSYSTEM:CONSOLE")

# MSVC linker default (LTO off) -> no /LTCG, still /OPT:REF
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_linker_flags(${t})
expect_no_link_option(${t} "/LTCG")
expect_link_option(${t} "/OPT:REF")

# MSVC extra /SUBSYSTEM overrides the default
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_linker_flags(${t} MSVC_FLAGS /SUBSYSTEM:WINDOWS)
expect_link_option(${t} "/SUBSYSTEM:WINDOWS")

# ---------------------------------------------------------------------------
# GCC linker: LTO ON / THIN / default (-rdynamic)
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_linker_flags(${t} LTO ON)
expect_link_option(${t} "-flto")
expect_compile_option(${t} "-flto")

new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_linker_flags(${t} LTO THIN)
expect_link_option(${t} "-flto=auto")

new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_linker_flags(${t})
expect_link_option(${t} "-rdynamic")
expect_no_link_option(${t} "-flto")

# ---------------------------------------------------------------------------
# Clang linker: LTO ON / THIN / default
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
configure_linker_flags(${t} LTO ON)
expect_link_option(${t} "-flto")

new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
configure_linker_flags(${t} LTO THIN)
expect_link_option(${t} "-flto=thin")

new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
configure_linker_flags(${t})
expect_link_option(${t} "-rdynamic")

# ---------------------------------------------------------------------------
# Intel linker: IPO ON / default
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
configure_linker_flags(${t} LTO ON)
expect_link_option(${t} "-ipo")

new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
configure_linker_flags(${t})
expect_no_link_option(${t} "-ipo")

# ---------------------------------------------------------------------------
# Unsupported linker (else branch)
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Watcom" "Watcom")
configure_linker_flags(${t})
expect_no_link_option(${t} "-rdynamic")

# ---------------------------------------------------------------------------
# CUSTOM_FLAGS -> only custom, defaults skipped
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_linker_flags(${t} CUSTOM_FLAGS "-Wl,--myflag")
expect_link_option(${t} "-Wl,--myflag")
expect_no_link_option(${t} "-rdynamic")

# ---------------------------------------------------------------------------
# EXTRA_FLAGS
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_linker_flags(${t} EXTRA_FLAGS "-Wl,--extra")
expect_link_option(${t} "-Wl,--extra")

# NOTE: USE_DEFAULT_FLAGS OFF without CUSTOM_FLAGS hits the validation
# FATAL_ERROR (covered in validation_failures.cmake). The "user-specified flags
# only" else-branch is currently unreachable, as with CompilerFlags.
