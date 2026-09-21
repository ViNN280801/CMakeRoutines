# Branch coverage for utils/WarningSuppression.cmake
include("${_module_root}/utils/WarningSuppression.cmake")

# MSVC: no KEEP -> /w (all suppressed)
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
suppress_warnings(${t})
expect_compile_option(${t} "^/w$")

# MSVC: KEEP 4996 -> /W4 + /wd codes, but /wd4996 kept (absent)
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
suppress_warnings(${t} KEEP 4996)
expect_compile_option(${t} "^/W4$")
expect_no_compile_option(${t} "^/wd4996$")
expect_no_compile_option(${t} "^/w$")

# GNU: no KEEP -> -w
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
suppress_warnings(${t})
expect_compile_option(${t} "^-w$")

# GNU: KEEP unused-parameter
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
suppress_warnings(${t} KEEP unused-parameter)
expect_compile_option(${t} "-Wall")
expect_no_compile_option(${t} "^-Wno-unused-parameter$")
expect_compile_option(${t} "-Wno-unused-variable")

# Clang: no KEEP -> -w
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
suppress_warnings(${t})
expect_compile_option(${t} "^-w$")

# Clang: KEEP unused-parameter
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
suppress_warnings(${t} KEEP unused-parameter)
expect_no_compile_option(${t} "^-Wno-unused-parameter$")

# Intel: no KEEP -> -w
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
suppress_warnings(${t})
expect_compile_option(${t} "^-w$")

# Intel: KEEP 181 -> -w3 + diag-disable codes, but 181 kept (absent)
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
suppress_warnings(${t} KEEP 181)
expect_compile_option(${t} "^-w3$")
expect_no_compile_option(${t} "^-diag-disable:181$")
expect_compile_option(${t} "-diag-disable:182")

# Unsupported (Watcom) -> generic suppression (no flags)
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Watcom" "Watcom")
suppress_warnings(${t})
expect_no_compile_option(${t} "-w")

# =============================================================================
# suppress_warnings_for_sources (per-file suppression)
#
# Source-file properties (COMPILE_OPTIONS) are GLOBAL per path in CMake, so a
# source path shared across two targets would leak flags between them. Each
# test therefore builds its own unique source files.
# =============================================================================
function(_ws_target out_var)
  get_property(_j GLOBAL PROPERTY _WS_INDEX)
  if(NOT _j)
    set(_j 0)
  endif()
  math(EXPR _j "${_j} + 1")
  set_property(GLOBAL PROPERTY _WS_INDEX "${_j}")
  set(_dir "${CMAKE_CURRENT_BINARY_DIR}/_ws_sources_${_j}")
  file(MAKE_DIRECTORY "${_dir}/3rdparty/gtest")
  file(WRITE "${_dir}/3rdparty/gtest/a.cpp" "// vendored\n")
  file(WRITE "${_dir}/src_main.cpp" "// own\n")

  new_test_target(${out_var})
  target_sources(${${out_var}} PRIVATE
    "${_dir}/3rdparty/gtest/a.cpp"
    "${_dir}/src_main.cpp")
  set(${out_var} "${${out_var}}" PARENT_SCOPE)
endfunction()

# MSVC + ALL: 3rdparty source gets /w, own source gets nothing extra
_ws_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
suppress_warnings_for_sources(${t} MATCH "3rdparty" ALL)
expect_source_compile_option(${t} "3rdparty" "^/w$")
expect_no_source_compile_option(${t} "src_main" "/w")

# Clang + default (no ALL/SUPPRESS) -> -w on matched source only
_ws_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
suppress_warnings_for_sources(${t} MATCH "3rdparty")
expect_source_compile_option(${t} "3rdparty" "^-w$")
expect_no_source_compile_option(${t} "src_main" "-w")

# Clang + SUPPRESS specific groups
_ws_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
suppress_warnings_for_sources(${t} MATCH "3rdparty"
  SUPPRESS global-constructors documentation)
expect_source_compile_option(${t} "3rdparty" "^-Wno-global-constructors$")
expect_source_compile_option(${t} "3rdparty" "^-Wno-documentation$")
expect_no_source_compile_option(${t} "3rdparty" "^-w$")

# GNU + SUPPRESS names
_ws_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
suppress_warnings_for_sources(${t} MATCH "3rdparty" SUPPRESS unused-parameter)
expect_source_compile_option(${t} "3rdparty" "^-Wno-unused-parameter$")

# MSVC + SUPPRESS numeric codes
_ws_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
suppress_warnings_for_sources(${t} MATCH "3rdparty" SUPPRESS 4251 4267)
expect_source_compile_option(${t} "3rdparty" "^/wd4251$")
expect_source_compile_option(${t} "3rdparty" "^/wd4267$")

# Intel + SUPPRESS numeric codes
_ws_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
suppress_warnings_for_sources(${t} MATCH "3rdparty" SUPPRESS 181)
expect_source_compile_option(${t} "3rdparty" "^-diag-disable:181$")

# Regex pattern match (not just a literal folder)
_ws_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
suppress_warnings_for_sources(${t} MATCH "_ws_sources_[0-9]+/3rdparty/.*" ALL)
expect_source_compile_option(${t} "3rdparty" "^-w$")
expect_no_source_compile_option(${t} "src_main" "-w")

# MSVC + ALL: per-source /w only; never a bogus /wd9025 on the target (driver
# warnings D#### cannot be silenced with /wd, which only accepts C4xxx..C5xxx -
# cl.exe would emit D9014 "invalid value ... assuming '5999'").
_ws_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
suppress_warnings_for_sources(${t} MATCH "3rdparty" ALL)
expect_source_compile_option(${t} "3rdparty" "^/w$")
expect_no_compile_option(${t} "^/wd9025$")
