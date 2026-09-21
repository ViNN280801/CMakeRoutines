# Branch coverage for core/CompilerFlags.cmake
include("${_module_root}/core/CompilerFlags.cmake")

# ---------------------------------------------------------------------------
# Dispatch branches (MSVC / GNU / Clang / Intel / unsupported)
# ---------------------------------------------------------------------------

# MSVC cl.exe (MSVC=TRUE, id=MSVC) -> /MP is emitted, no clang-only -Wno flags.
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_compiler_flags(${t} WARNINGS HIGH)
expect_compile_option(${t} "/permissive-")
expect_compile_option(${t} "/W4")
expect_compile_option(${t} "/MP")
expect_no_compile_option(${t} "98-compat")

# MSVC clang-cl (MSVC=TRUE, id=Clang) -> no /MP, and c++98-compat noise suppressed.
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "Clang" "Clang")
configure_compiler_flags(${t} WARNINGS HIGH)
expect_compile_option(${t} "/permissive-")
expect_compile_option(${t} "/W4")
expect_no_compile_option(${t} "^/MP$")
expect_compile_option(${t} "98-compat")
expect_compile_option(${t} "98-compat-pedantic")
expect_compile_option(${t} "14-compat")
expect_compile_option(${t} "17-compat")

# GNU
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_compiler_flags(${t} WARNINGS HIGH)
expect_compile_option(${t} "-Wall")
expect_compile_option(${t} "-Wpedantic")
expect_compile_option(${t} "-g")

# Clang (native)
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
configure_compiler_flags(${t} WARNINGS HIGH)
expect_compile_option(${t} "-Wall")
expect_compile_option(${t} "-Wpedantic")

# Intel
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
configure_compiler_flags(${t} WARNINGS HIGH)
expect_compile_option(${t} "-w3")

# Unsupported compiler (else branch): no flags, must not crash.
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Watcom" "Watcom")
configure_compiler_flags(${t})
expect_no_compile_option(${t} "-Wall")
expect_no_compile_option(${t} "/W")

# ---------------------------------------------------------------------------
# Warning levels (MSVC): OFF /w, LOW /W1, MEDIUM /W3, HIGH /W4, PEDANTIC /Wall
# ---------------------------------------------------------------------------
foreach(_kv IN ITEMS "OFF:/w" "LOW:/W1" "MEDIUM:/W3" "HIGH:/W4" "PEDANTIC:/Wall")
  string(REPLACE ":" ";" _pair "${_kv}")
  list(GET _pair 0 _lvl)
  list(GET _pair 1 _flag)
  new_test_target(t)
  simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
  configure_compiler_flags(${t} WARNINGS ${_lvl})
  expect_compile_option(${t} "${_flag}")
endforeach()

# MSVC default (no WARNINGS -> /W3)
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_compiler_flags(${t})
expect_compile_option(${t} "/W3")

# ---------------------------------------------------------------------------
# Warning levels (GCC)
# ---------------------------------------------------------------------------
foreach(_kv IN ITEMS "OFF:-w" "LOW:-Wall" "MEDIUM:-Wextra" "HIGH:-Wpedantic" "PEDANTIC:-Wstrict-null-sentinel")
  string(REPLACE ":" ";" _pair "${_kv}")
  list(GET _pair 0 _lvl)
  list(GET _pair 1 _flag)
  new_test_target(t)
  simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
  configure_compiler_flags(${t} WARNINGS ${_lvl})
  expect_compile_option(${t} "${_flag}")
endforeach()

# GCC default (no WARNINGS -> -Wextra)
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_compiler_flags(${t})
expect_compile_option(${t} "-Wextra")

# ---------------------------------------------------------------------------
# Warning levels (Clang)
# ---------------------------------------------------------------------------
foreach(_kv IN ITEMS "OFF:-w" "LOW:-Wall" "MEDIUM:-Wextra" "HIGH:-Wpedantic" "PEDANTIC:-Wstrict-null-sentinel")
  string(REPLACE ":" ";" _pair "${_kv}")
  list(GET _pair 0 _lvl)
  list(GET _pair 1 _flag)
  new_test_target(t)
  simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
  configure_compiler_flags(${t} WARNINGS ${_lvl})
  expect_compile_option(${t} "${_flag}")
endforeach()

# ---------------------------------------------------------------------------
# Warning levels (Intel)
# ---------------------------------------------------------------------------
foreach(_kv IN ITEMS "OFF:-w" "LOW:-w1" "MEDIUM:-w2" "HIGH:-w3" "PEDANTIC:-Wall")
  string(REPLACE ":" ";" _pair "${_kv}")
  list(GET _pair 0 _lvl)
  list(GET _pair 1 _flag)
  new_test_target(t)
  simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
  configure_compiler_flags(${t} WARNINGS ${_lvl})
  expect_compile_option(${t} "${_flag}")
endforeach()

# ---------------------------------------------------------------------------
# STANDARD -> CXX_STANDARD / CXX_STANDARD_REQUIRED / CXX_EXTENSIONS
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_compiler_flags(${t} STANDARD 20)
expect_target_property(${t} CXX_STANDARD 20)
expect_target_property(${t} CXX_STANDARD_REQUIRED ON)
expect_target_property(${t} CXX_EXTENSIONS OFF)

# ---------------------------------------------------------------------------
# CUSTOM_DEFINITIONS
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_compiler_flags(${t} CUSTOM_DEFINITIONS MY_DEF "VAL=42")
expect_compile_definition(${t} MY_DEF)
expect_compile_definition(${t} "VAL=42")

# ---------------------------------------------------------------------------
# Default MSVC definitions only when USE_DEFAULT_FLAGS AND MSVC
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_compiler_flags(${t})
expect_compile_definition(${t} _CRT_SECURE_NO_WARNINGS)
expect_compile_definition(${t} NOMINMAX)

new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_compiler_flags(${t})
expect_no_compile_definition(${t} NOMINMAX)

# ---------------------------------------------------------------------------
# CUSTOM_FLAGS -> only custom, defaults skipped (early return)
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_compiler_flags(${t} CUSTOM_FLAGS -fmyflag)
expect_compile_option(${t} "-fmyflag")
expect_no_compile_option(${t} "-Wall")

# ---------------------------------------------------------------------------
# EXTRA_FLAGS (applied for all compilers)
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_compiler_flags(${t} EXTRA_FLAGS -fextra)
expect_compile_option(${t} "-fextra")

# ---------------------------------------------------------------------------
# Compiler-specific extra flags with defaults ON (MSVC_FLAGS / GCC_FLAGS)
# ---------------------------------------------------------------------------
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_compiler_flags(${t} MSVC_FLAGS /fmsvcextra)
expect_compile_option(${t} "/fmsvcextra")

new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_compiler_flags(${t} GCC_FLAGS -fgccextra)
expect_compile_option(${t} "-fgccextra")

# NOTE: USE_DEFAULT_FLAGS OFF without CUSTOM_FLAGS hits the validation
# FATAL_ERROR (covered in validation_failures.cmake). The "user-specified flags
# only" else-branch is currently unreachable: the validation requires
# CUSTOM_FLAGS when USE_DEFAULT_FLAGS is OFF, and CUSTOM_FLAGS returns early.
