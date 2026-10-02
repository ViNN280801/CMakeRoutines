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

# --- Release debug symbols on ELF: split into <file>.debug, never stripped away --
# The split needs objcopy; a host without one (MSVC) still checks the wiring.
set(_ol_saved_objcopy "${CMAKE_OBJCOPY}")
if(NOT CMAKE_OBJCOPY)
  set(CMAKE_OBJCOPY "objcopy")
endif()
set(_ol_release_strip "CONFIG:Release>:-Wl,--strip-all")
set(_ol_build_id "CONFIG:Release>:-Wl,--build-id")
set(_ol_launcher "split-debug-info\\.sh")

# GNU, shared library, DEBUG_SYMBOLS ON (default): Build ID, split launcher,
# no Release strip (the launcher strips after saving the DWARF).
new_linked_test_target(t SHARED)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_optimization_level(${t})
expect_link_option(${t} "${_ol_build_id}")
expect_no_link_option(${t} "${_ol_release_strip}")
expect_link_option(${t} "CONFIG:MinSizeRel>:-Wl,--strip-all")
_ct_expect_property_match(${t} CXX_LINKER_LAUNCHER "${_ol_launcher}" TRUE)
_ct_expect_property_match(${t} C_LINKER_LAUNCHER "${_ol_launcher}" TRUE)
_ct_expect_property_match(${t} CXX_LINKER_LAUNCHER "^\\$<CONFIG:Release>$" TRUE)
_ct_expect_property_match(${t} CXX_LINKER_LAUNCHER "^\\$<TARGET_FILE:${t}>$" TRUE)

# GNU, executable: the same.
new_linked_test_target(t EXECUTABLE)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_optimization_level(${t} DEBUG_SYMBOLS ON)
expect_link_option(${t} "${_ol_build_id}")
expect_no_link_option(${t} "${_ol_release_strip}")
_ct_expect_property_match(${t} CXX_LINKER_LAUNCHER "${_ol_launcher}" TRUE)

# Clang takes the same path.
new_linked_test_target(t SHARED)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
configure_optimization_level(${t} CXX_STDLIB DEFAULT)
expect_link_option(${t} "${_ol_build_id}")
expect_no_link_option(${t} "${_ol_release_strip}")
_ct_expect_property_match(${t} CXX_LINKER_LAUNCHER "${_ol_launcher}" TRUE)

# DEBUG_SYMBOLS OFF: Release stripped at link, no Build ID, no launcher.
new_linked_test_target(t SHARED)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_optimization_level(${t} DEBUG_SYMBOLS OFF)
expect_link_option(${t} "${_ol_release_strip}")
expect_no_link_option(${t} "${_ol_build_id}")
_ct_expect_property_match(${t} CXX_LINKER_LAUNCHER "${_ol_launcher}" FALSE)

# A static library is not linked: no launcher.
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_optimization_level(${t})
_ct_expect_property_match(${t} CXX_LINKER_LAUNCHER "${_ol_launcher}" FALSE)

# MinGW (GNU on WIN32) is not ELF: Release stripped as before, no launcher.
new_linked_test_target(t SHARED)
simulate_platform(TRUE FALSE FALSE FALSE "GNU" "GNU")
configure_optimization_level(${t})
expect_link_option(${t} "${_ol_release_strip}")
_ct_expect_property_match(${t} CXX_LINKER_LAUNCHER "${_ol_launcher}" FALSE)

# A launcher of the consumer's own is kept, and the symbols stay inside (no strip).
new_linked_test_target(t SHARED)
set_target_properties(${t} PROPERTIES CXX_LINKER_LAUNCHER "consumer-launcher")
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_optimization_level(${t})
expect_target_property(${t} CXX_LINKER_LAUNCHER "consumer-launcher")
expect_no_link_option(${t} "${_ol_release_strip}")

# Configured twice: still one split launcher, still no Release strip.
new_linked_test_target(t SHARED)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_optimization_level(${t})
configure_optimization_level(${t})
_ct_expect_property_match(${t} CXX_LINKER_LAUNCHER "${_ol_launcher}" TRUE)
expect_no_link_option(${t} "${_ol_release_strip}")

# The ELF split never reaches another platform's branch, and the PDB path stays
# Windows-only: MSVC and clang-cl keep /Zi + /DEBUG (a PDB) and get no ELF launcher
# or Build ID; Apple keeps -dead_strip.
new_linked_test_target(t SHARED)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
configure_optimization_level(${t})
expect_link_option(${t} "^/DEBUG$")
expect_compile_option(${t} "/Zi")
expect_no_link_option(${t} "--build-id")
expect_no_link_option(${t} "--strip-all")
_ct_expect_property_match(${t} CXX_LINKER_LAUNCHER "${_ol_launcher}" FALSE)
_ct_expect_property_match(${t} C_LINKER_LAUNCHER "${_ol_launcher}" FALSE)

new_linked_test_target(t EXECUTABLE)
simulate_platform(TRUE FALSE FALSE TRUE "Clang" "Clang")
configure_optimization_level(${t})
expect_link_option(${t} "^/DEBUG$")
expect_no_link_option(${t} "--build-id")
_ct_expect_property_match(${t} CXX_LINKER_LAUNCHER "${_ol_launcher}" FALSE)

new_linked_test_target(t SHARED)
simulate_platform(FALSE TRUE TRUE FALSE "AppleClang" "AppleClang")
configure_optimization_level(${t} CXX_STDLIB DEFAULT)
expect_link_option(${t} "-dead_strip")
expect_no_link_option(${t} "--build-id")
_ct_expect_property_match(${t} CXX_LINKER_LAUNCHER "${_ol_launcher}" FALSE)

# And the other way round: an ELF target gets nothing of the PDB path.
new_linked_test_target(t SHARED)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_optimization_level(${t})
expect_no_compile_option(${t} "/Zi")
expect_no_link_option(${t} "/DEBUG")

set(CMAKE_OBJCOPY "${_ol_saved_objcopy}")
