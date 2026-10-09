# configure_toolchain_runtime_rpath (deployment/ToolchainRuntimeRpath.cmake):
# which targets get BUILD_RPATH, from which toolchain, on which platform.
# The compiler that answers -print-file-name is a fake /bin/sh script, so the
# directories are known and the case runs the same on any host; the real
# toolchain is covered by cases/toolchain_runtime_rpath_build.cmake. The
# TOOLCHAIN_RUNTIME_RPATH parameter of configure_optimization_level is covered
# here too (off by default, idempotent with the explicit call). POSIX
# hosts only. Everything that overrides the compiler variables runs inside a
# function, so the cases after this one see the real ones.
include("${_module_root}/deployment/ToolchainRuntimeRpath.cmake")
include("${_module_root}/optimizations/OptimizationLevelConfig.cmake")

if(CMAKE_HOST_WIN32 OR NOT EXISTS "/bin/sh")
  message(STATUS "toolchain_runtime_rpath: skipped (no /bin/sh)")
  return()
endif()

set(_trp_root "${CMAKE_CURRENT_BINARY_DIR}/_ct_toolchain_runtime_rpath")
file(REMOVE_RECURSE "${_trp_root}")
set(_trp_gcc_lib "${_trp_root}/opt/gcc-13.2.0/lib64")
set(_trp_llvm_lib "${_trp_root}/opt/llvm-23.1.0/lib/x86_64-unknown-linux-gnu")
file(MAKE_DIRECTORY "${_trp_gcc_lib}" "${_trp_llvm_lib}")
foreach(_name libstdc++.so.6 libgcc_s.so.1)
  file(WRITE "${_trp_gcc_lib}/${_name}" "")
endforeach()
foreach(_name libc++.so.1 libc++abi.so.1 libunwind.so.1)
  file(WRITE "${_trp_llvm_lib}/${_name}" "")
endforeach()

# A real file in a system library directory: libc, to say "in /usr/lib".
file(GLOB _trp_system_libs
  "/lib/*/libc.so.6" "/usr/lib/*/libc.so.6" "/lib64/libc.so.6" "/usr/lib64/libc.so.6"
  "/usr/lib/libc.so.6" "/lib/libc.so.6")
if(_trp_system_libs)
  list(GET _trp_system_libs 0 _trp_system_file)
else()
  set(_trp_system_file "")
endif()

# <script>.map: "<name> <path>" lines.
set(_trp_cxx "${_trp_root}/fake-cxx")
file(WRITE "${_trp_cxx}" [=[#!/bin/sh
self="$0"
for arg in "$@"; do
  case "$arg" in
    -print-file-name=*)
      name="${arg#-print-file-name=}"
      while read -r key value; do
        if [ "$key" = "$name" ]; then echo "$value"; exit 0; fi
      done < "$self.map"
      echo "$name"
      exit 0 ;;
  esac
done
exit 1
]=])
execute_process(COMMAND chmod 755 "${_trp_cxx}")

function(_trp_set_map)
  set(_text "")
  foreach(_pair IN LISTS ARGN)
    string(REGEX REPLACE "=" " " _line "${_pair}")
    string(APPEND _text "${_line}\n")
  endforeach()
  file(WRITE "${_trp_cxx}.map" "${_text}")
endfunction()

# expect_build_rpath(<target> <dir>...): BUILD_RPATH is exactly this list
# (no argument: not set at all).
function(expect_build_rpath target)
  _ct_increment()
  get_target_property(_got ${target} BUILD_RPATH)
  if(NOT _got)
    set(_got "")
  endif()
  set(_expected "${ARGN}")
  if(NOT "${_got}" STREQUAL "${_expected}")
    _ct_fail("'${target}' BUILD_RPATH: expected '${_expected}', got '${_got}'")
  endif()
endfunction()

function(_ct_toolchain_runtime_rpath_cases)
  set(CMAKE_CXX_COMPILER "${_trp_cxx}")
  set(CMAKE_CXX_COMPILER_ARG1 "")
  set(CMAKE_CXX_FLAGS "")
  set(CMAKE_CROSSCOMPILING FALSE)
  set(CYGWIN FALSE)
  set(ENV{CXXFLAGS} "")
  set(CMAKE_EXE_LINKER_FLAGS "")
  set(CMAKE_SHARED_LINKER_FLAGS "")
  set(CMAKE_MODULE_LINKER_FLAGS "")

  _trp_set_map(
    "libstdc++.so.6=${_trp_gcc_lib}/libstdc++.so.6"
    "libgcc_s.so.1=${_trp_gcc_lib}/libgcc_s.so.1"
    "libc++.so.1=${_trp_llvm_lib}/libc++.so.1"
    "libc++abi.so.1=${_trp_llvm_lib}/libc++abi.so.1"
    "libunwind.so.1=${_trp_llvm_lib}/libunwind.so.1")

  # --- GCC outside the system paths: executable, shared and module libraries
  # get the GCC directory; a static library, an object library and an
  # interface library have nothing to link, so nothing to find.
  simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
  new_linked_test_target(exe EXECUTABLE)
  new_linked_test_target(shared SHARED)
  new_linked_test_target(module MODULE)
  new_test_target(static)
  add_library(_ct_trp_object OBJECT "${_CT_DUMMY_SRC}")
  add_library(_ct_trp_interface INTERFACE)
  foreach(_t ${exe} ${shared} ${module})
    configure_toolchain_runtime_rpath(${_t})
    expect_build_rpath(${_t} "${_trp_gcc_lib}")
  endforeach()
  foreach(_t ${static} _ct_trp_object)
    configure_toolchain_runtime_rpath(${_t})
    expect_build_rpath(${_t})
  endforeach()
  configure_toolchain_runtime_rpath(_ct_trp_interface)

  # An alias and an imported library cannot take the property.
  add_library(_ct_trp_alias ALIAS ${shared})
  configure_toolchain_runtime_rpath(_ct_trp_alias)
  add_library(_ct_trp_imported SHARED IMPORTED)
  configure_toolchain_runtime_rpath(_ct_trp_imported)

  # Twice is once; what the project set before stays, in front.
  configure_toolchain_runtime_rpath(${exe})
  expect_build_rpath(${exe} "${_trp_gcc_lib}")
  new_linked_test_target(own EXECUTABLE)
  set_property(TARGET ${own} PROPERTY BUILD_RPATH "/project/own/dir")
  configure_toolchain_runtime_rpath(${own})
  configure_toolchain_runtime_rpath(${own})
  expect_build_rpath(${own} "/project/own/dir" "${_trp_gcc_lib}")

  # Not a target, an unknown argument: see the FATAL_ERROR cases below.

  # GCC takes libstdc++ whatever a -stdlib= option on the target says.
  new_linked_test_target(odd EXECUTABLE)
  target_compile_options(${odd} PRIVATE -stdlib=libc++)
  configure_toolchain_runtime_rpath(${odd})
  expect_build_rpath(${odd} "${_trp_gcc_lib}")

  # --- Clang -------------------------------------------------------------------
  simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")

  # No -stdlib=: the compiler default, libstdc++ of the GCC it was given.
  new_linked_test_target(plain EXECUTABLE)
  configure_toolchain_runtime_rpath(${plain})
  expect_build_rpath(${plain} "${_trp_gcc_lib}")

  # -stdlib=libc++ on the target (what configure_optimization_level adds):
  # LLVM's directory, then the GCC directory of libgcc_s.
  new_linked_test_target(libcxx EXECUTABLE)
  target_compile_options(${libcxx} PRIVATE -stdlib=libc++)
  configure_toolchain_runtime_rpath(${libcxx})
  expect_build_rpath(${libcxx} "${_trp_llvm_lib}" "${_trp_gcc_lib}")

  # An executable that only links a library built with -stdlib=libc++ gets the
  # flag through the library's INTERFACE options, and the directories with it.
  new_linked_test_target(libcxx_lib SHARED)
  target_compile_options(${libcxx_lib} PUBLIC -stdlib=libc++)
  new_linked_test_target(user EXECUTABLE)
  target_link_libraries(${user} PRIVATE ${libcxx_lib})
  configure_toolchain_runtime_rpath(${user})
  expect_build_rpath(${user} "${_trp_llvm_lib}" "${_trp_gcc_lib}")

  # -stdlib=libstdc++ on the target: no LLVM directory.
  new_linked_test_target(stdcxx EXECUTABLE)
  target_compile_options(${stdcxx} PRIVATE -stdlib=libstdc++)
  configure_toolchain_runtime_rpath(${stdcxx})
  expect_build_rpath(${stdcxx} "${_trp_gcc_lib}")

  # STDLIB names the library (and wins over what the target says).
  new_linked_test_target(forced EXECUTABLE)
  target_compile_options(${forced} PRIVATE -stdlib=libc++)
  configure_toolchain_runtime_rpath(${forced} STDLIB libstdc++)
  expect_build_rpath(${forced} "${_trp_gcc_lib}")
  new_linked_test_target(both EXECUTABLE)
  configure_toolchain_runtime_rpath(${both} STDLIB libstdc++ libc++)
  expect_build_rpath(${both} "${_trp_gcc_lib}" "${_trp_llvm_lib}")

  # --- a toolchain in the system paths adds nothing -----------------------------
  if(_trp_system_file)
    _trp_set_map(
      "libstdc++.so.6=${_trp_system_file}"
      "libgcc_s.so.1=${_trp_system_file}"
      "libc++.so.1=${_trp_system_file}"
      "libc++abi.so.1=${_trp_system_file}"
      "libunwind.so.1=${_trp_system_file}")
    set(CMAKE_CXX_FLAGS "-DSYSTEM")
    new_linked_test_target(system EXECUTABLE)
    target_compile_options(${system} PRIVATE -stdlib=libc++)
    configure_toolchain_runtime_rpath(${system})
    expect_build_rpath(${system})
    configure_toolchain_runtime_rpath(${system} STDLIB libstdc++ libc++)
    expect_build_rpath(${system})
    _trp_set_map(
      "libstdc++.so.6=${_trp_gcc_lib}/libstdc++.so.6"
      "libgcc_s.so.1=${_trp_gcc_lib}/libgcc_s.so.1"
      "libc++.so.1=${_trp_llvm_lib}/libc++.so.1"
      "libc++abi.so.1=${_trp_llvm_lib}/libc++abi.so.1"
      "libunwind.so.1=${_trp_llvm_lib}/libunwind.so.1")
    set(CMAKE_CXX_FLAGS "")
  endif()

  # --- configure_optimization_level(... TOOLCHAIN_RUNTIME_RPATH) ------------------
  # The libc++ probe is cached, so -stdlib=libc++ is decided here, not by the host.
  set(_opt_lvl_clang_libcxx_usable TRUE CACHE INTERNAL "libc++ probe (target tests)" FORCE)
  simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")

  # Off by default: the same call without the parameter, with it OFF or empty,
  # leaves BUILD_RPATH alone.
  new_linked_test_target(p_default EXECUTABLE)
  configure_optimization_level(${p_default})
  expect_build_rpath(${p_default})
  new_linked_test_target(p_off EXECUTABLE)
  configure_optimization_level(${p_off} TOOLCHAIN_RUNTIME_RPATH OFF)
  expect_build_rpath(${p_off})
  new_linked_test_target(p_empty EXECUTABLE)
  configure_optimization_level(${p_empty} TOOLCHAIN_RUNTIME_RPATH "")
  expect_build_rpath(${p_empty})
  foreach(_value no NO false 0)
    new_linked_test_target(p_false EXECUTABLE)
    configure_optimization_level(${p_false} TOOLCHAIN_RUNTIME_RPATH ${_value})
    expect_build_rpath(${p_false})
  endforeach()

  # On: an executable, a shared and a module library get the directories; a
  # static library has no RPATH. The value is any CMake boolean.
  foreach(_value ON on TRUE yes 1)
    new_linked_test_target(p_exe EXECUTABLE)
    configure_optimization_level(${p_exe} TOOLCHAIN_RUNTIME_RPATH ${_value})
    expect_build_rpath(${p_exe} "${_trp_gcc_lib}")
  endforeach()
  new_linked_test_target(p_shared SHARED)
  configure_optimization_level(${p_shared} TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${p_shared} "${_trp_gcc_lib}")
  new_linked_test_target(p_module MODULE)
  configure_optimization_level(${p_module} TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${p_module} "${_trp_gcc_lib}")
  new_test_target(p_static)
  configure_optimization_level(${p_static} TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${p_static})

  # Only the target that is passed: another target configured without the
  # parameter in the same tree stays empty.
  expect_build_rpath(${p_default})

  # Idempotent: the parameter and the explicit call, in either order and
  # repeated, leave one entry, behind what the project set itself.
  new_linked_test_target(p_after EXECUTABLE)
  configure_optimization_level(${p_after} TOOLCHAIN_RUNTIME_RPATH ON)
  configure_toolchain_runtime_rpath(${p_after})
  expect_build_rpath(${p_after} "${_trp_gcc_lib}")
  new_linked_test_target(p_before EXECUTABLE)
  configure_toolchain_runtime_rpath(${p_before})
  configure_optimization_level(${p_before} TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${p_before} "${_trp_gcc_lib}")
  new_linked_test_target(p_twice EXECUTABLE)
  set_property(TARGET ${p_twice} PROPERTY BUILD_RPATH "/project/own/dir")
  configure_optimization_level(${p_twice} TOOLCHAIN_RUNTIME_RPATH ON)
  configure_optimization_level(${p_twice} TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${p_twice} "/project/own/dir" "${_trp_gcc_lib}")

  # Clang: the -stdlib=libc++ that the same call puts on the target decides the
  # directories (LLVM first, then the GCC one of libgcc_s).
  simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
  new_linked_test_target(pc_libcxx EXECUTABLE)
  configure_optimization_level(${pc_libcxx} TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${pc_libcxx} "${_trp_llvm_lib}" "${_trp_gcc_lib}")
  new_linked_test_target(pc_libcxx_off EXECUTABLE)
  configure_optimization_level(${pc_libcxx_off})
  expect_build_rpath(${pc_libcxx_off})
  new_linked_test_target(pc_default_stdlib EXECUTABLE)
  configure_optimization_level(${pc_default_stdlib} CXX_STDLIB DEFAULT
    TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${pc_default_stdlib} "${_trp_gcc_lib}")
  # An executable without its own -stdlib= takes the one of the library it
  # links, which handed it on through its INTERFACE options.
  new_linked_test_target(pc_lib SHARED)
  configure_optimization_level(${pc_lib} TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${pc_lib} "${_trp_llvm_lib}" "${_trp_gcc_lib}")
  new_linked_test_target(pc_user EXECUTABLE)
  target_link_libraries(${pc_user} PRIVATE ${pc_lib})
  configure_optimization_level(${pc_user} CXX_STDLIB DEFAULT TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${pc_user} "${_trp_llvm_lib}" "${_trp_gcc_lib}")
  # No usable libc++: the compiler default, GCC's libstdc++ only.
  set(_opt_lvl_clang_libcxx_usable FALSE CACHE INTERNAL "libc++ probe (target tests)" FORCE)
  new_linked_test_target(pc_no_libcxx EXECUTABLE)
  configure_optimization_level(${pc_no_libcxx} TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${pc_no_libcxx} "${_trp_gcc_lib}")
  set(_opt_lvl_clang_libcxx_usable TRUE CACHE INTERNAL "libc++ probe (target tests)" FORCE)

  # Platforms with no ELF RUNPATH, a cross build and other compilers: the
  # parameter is accepted and does nothing.
  simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
  set(CMAKE_CROSSCOMPILING TRUE)
  new_linked_test_target(pp_cross EXECUTABLE)
  configure_optimization_level(${pp_cross} TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${pp_cross})
  set(CMAKE_CROSSCOMPILING FALSE)
  simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
  new_linked_test_target(pp_msvc EXECUTABLE)
  configure_optimization_level(${pp_msvc} TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${pp_msvc})
  simulate_platform(FALSE TRUE TRUE FALSE "AppleClang" "AppleClang")
  new_linked_test_target(pp_apple EXECUTABLE)
  configure_optimization_level(${pp_apple} TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${pp_apple})
  simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
  new_linked_test_target(pp_intel EXECUTABLE)
  configure_optimization_level(${pp_intel} TOOLCHAIN_RUNTIME_RPATH ON)
  expect_build_rpath(${pp_intel})
  unset(_opt_lvl_clang_libcxx_usable CACHE)

  # --- platforms the RPATH does not exist or does not apply on --------------------
  # (the GCC toolchain from above is still the one that would answer)
  simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
  set(CMAKE_CROSSCOMPILING TRUE)
  new_linked_test_target(cross EXECUTABLE)
  configure_toolchain_runtime_rpath(${cross})
  expect_build_rpath(${cross})
  set(CMAKE_CROSSCOMPILING FALSE)

  simulate_platform(TRUE FALSE FALSE FALSE "GNU" "GNU")   # MinGW
  new_linked_test_target(mingw EXECUTABLE)
  configure_toolchain_runtime_rpath(${mingw})
  expect_build_rpath(${mingw})
  configure_toolchain_runtime_rpath(${mingw} STDLIB libstdc++)
  expect_build_rpath(${mingw})

  simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
  new_linked_test_target(msvc EXECUTABLE)
  configure_toolchain_runtime_rpath(${msvc})
  expect_build_rpath(${msvc})

  simulate_platform(TRUE FALSE FALSE TRUE "Clang" "Clang")   # clang-cl
  new_linked_test_target(clang_cl EXECUTABLE)
  configure_toolchain_runtime_rpath(${clang_cl})
  expect_build_rpath(${clang_cl})

  simulate_platform(FALSE TRUE TRUE FALSE "AppleClang" "AppleClang")
  new_linked_test_target(apple EXECUTABLE)
  configure_toolchain_runtime_rpath(${apple})
  expect_build_rpath(${apple})
  simulate_platform(FALSE TRUE TRUE FALSE "Clang" "Clang")   # LLVM on macOS
  configure_toolchain_runtime_rpath(${apple})
  expect_build_rpath(${apple})

  simulate_platform(FALSE FALSE TRUE FALSE "Intel" "Intel")
  new_linked_test_target(intel EXECUTABLE)
  configure_toolchain_runtime_rpath(${intel})
  expect_build_rpath(${intel})

  # And back on Linux with GCC the same call works again.
  simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
  new_linked_test_target(back EXECUTABLE)
  configure_toolchain_runtime_rpath(${back})
  expect_build_rpath(${back} "${_trp_gcc_lib}")
endfunction()

_ct_toolchain_runtime_rpath_cases()

# --- get_toolchain_runtime_directories needs no target ---------------------------
# (its branches are covered by tests/cases/toolchain_runtime_rpath_helpers.cmake)

# --- FATAL_ERROR branches ---------------------------------------------------------
set(_vf_body "
cmake_minimum_required(VERSION 3.16)
project(VF LANGUAGES CXX)
include(\"${_module_root}/deployment/ToolchainRuntimeRpath.cmake\")
configure_toolchain_runtime_rpath(no_such_target)
")
expect_configure_fail(toolchain_runtime_rpath_no_target "${_vf_body}"
  "'no_such_target' is not a known CMake[ \n]+target")

set(_vf_body "
cmake_minimum_required(VERSION 3.16)
project(VF LANGUAGES CXX)
include(\"${_module_root}/deployment/ToolchainRuntimeRpath.cmake\")
add_executable(vf dummy.cpp)
configure_toolchain_runtime_rpath(vf BOGUS)
")
expect_configure_fail(toolchain_runtime_rpath_unknown_argument "${_vf_body}"
  "unknown[ \n]+argument\\(s\\)[ \n]+'BOGUS'")

set(_vf_body "
cmake_minimum_required(VERSION 3.16)
project(VF LANGUAGES CXX)
include(\"${_module_root}/deployment/ToolchainRuntimeRpath.cmake\")
add_executable(vf dummy.cpp)
configure_toolchain_runtime_rpath(vf STDLIB libgcc)
")
expect_configure_fail(toolchain_runtime_rpath_bad_stdlib "${_vf_body}"
  "STDLIB must be libstdc\\+\\+ or[ \n]+libc\\+\\+")

set(_vf_body "
cmake_minimum_required(VERSION 3.16)
project(VF LANGUAGES CXX)
include(\"${_module_root}/deployment/ToolchainRuntimeRpath.cmake\")
get_toolchain_runtime_directories(_dirs EXTRA)
")
expect_configure_fail(toolchain_runtime_rpath_directories_unknown_argument "${_vf_body}"
  "get_toolchain_runtime_directories: unknown[ \n]+argument\\(s\\)[ \n]+'EXTRA'")

# The parameter takes ON or OFF (any CMake boolean spelling) and nothing else.
set(_vf_body "
cmake_minimum_required(VERSION 3.16)
project(VF LANGUAGES CXX)
include(\"${_module_root}/optimizations/OptimizationLevelConfig.cmake\")
add_executable(vf dummy.cpp)
configure_optimization_level(vf TOOLCHAIN_RUNTIME_RPATH MAYBE)
")
expect_configure_fail(optimization_toolchain_runtime_rpath_invalid "${_vf_body}"
  "TOOLCHAIN_RUNTIME_RPATH must be ON or[ \n]+OFF[ \n]+\\(got[ \n]+'MAYBE'\\)")
