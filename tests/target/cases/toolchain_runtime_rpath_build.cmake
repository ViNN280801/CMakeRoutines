# End-to-end check of deployment/ToolchainRuntimeRpath.cmake: builds
# fixtures/toolchain_runtime_rpath with the real compiler of this configure,
# reads the RUNPATH of its executable and shared library with readelf, and
# starts the executable with LD_LIBRARY_PATH removed from its environment. A
# toolchain outside the system paths (GCC or LLVM under /opt, a newer GCC in
# /usr/local) must find its own runtime without help; a distribution compiler
# must get no directory of the system. Runs where an ELF RUNPATH applies and
# can be observed (an ELF host, GCC or Clang, readelf, a single-config
# generator) and reports a skip elsewhere. Runs before any case simulates
# another platform.

set(_trb_fixture "${CMAKE_CURRENT_LIST_DIR}/../fixtures/toolchain_runtime_rpath")
find_program(_trb_readelf NAMES readelf llvm-readelf)
get_property(_trb_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

set(_trb_skip "")
if(NOT CMAKE_HOST_UNIX OR CMAKE_HOST_APPLE)
  set(_trb_skip "not an ELF host")
elseif(CMAKE_CROSSCOMPILING)
  set(_trb_skip "cross-compiling")
elseif(NOT CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang)$")
  set(_trb_skip "compiler is ${CMAKE_CXX_COMPILER_ID}")
elseif(NOT _trb_readelf)
  set(_trb_skip "no readelf")
elseif(_trb_multi_config)
  set(_trb_skip "multi-config generator ${CMAKE_GENERATOR}")
endif()

# readelf in the C locale (it translates its labels): the dynamic section.
function(_trb_dynamic file out_var)
  if(NOT EXISTS "${file}")
    _ct_fail("toolchain_runtime_rpath fixture: '${file}' was not built")
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env LC_ALL=C LANG=C LANGUAGE=C
      "${_trb_readelf}" -d -W "${file}"
    RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _out
    ERROR_VARIABLE _err)
  if(NOT _rc EQUAL 0)
    _ct_fail("readelf '${file}' failed: ${_err}")
  endif()
  set(${out_var} "${_out}" PARENT_SCOPE)
endfunction()

# The RUNPATH (or RPATH) entries of <file> as a list.
function(_trb_runpath file out_var)
  _trb_dynamic("${file}" _text)
  set(_entries "")
  if(_text MATCHES "\\((RUNPATH|RPATH)\\)[^\\[]*\\[([^]]*)\\]")
    string(REPLACE ":" ";" _entries "${CMAKE_MATCH_2}")
  endif()
  set(${out_var} "${_entries}" PARENT_SCOPE)
endfunction()

# The C++ standard library <file> needs: libc++ or libstdc++.
function(_trb_stdlib file out_var)
  _trb_dynamic("${file}" _text)
  if(_text MATCHES "\\(NEEDED\\)[^\\[]*\\[libc\\+\\+\\.so")
    set(${out_var} "libc++" PARENT_SCOPE)
  elseif(_text MATCHES "\\(NEEDED\\)[^\\[]*\\[libstdc\\+\\+\\.so")
    set(${out_var} "libstdc++" PARENT_SCOPE)
  else()
    _ct_fail("'${file}' needs neither libc++ nor libstdc++:\n${_text}")
  endif()
endfunction()

function(_trb_expect_binary file build_dir)
  _trb_stdlib("${file}" _stdlib)
  get_toolchain_runtime_directories(_expected STDLIB ${_stdlib})
  _trb_runpath("${file}" _entries)

  # Never a directory of the system, never anything but the build tree and
  # the toolchain's own directories.
  foreach(_entry IN LISTS _entries)
    _ct_increment()
    if(_entry MATCHES "^(/usr)?/lib(32|64|x32)?(/|$)")
      _ct_fail("'${file}' has the system directory '${_entry}' in its RUNPATH: ${_entries}")
    endif()
    string(FIND "${_entry}" "${build_dir}" _in_tree)
    if(NOT _in_tree EQUAL 0 AND NOT _entry IN_LIST _expected)
      _ct_fail("'${file}' has the unexpected RUNPATH entry '${_entry}': ${_entries} (toolchain: ${_expected})")
    endif()
  endforeach()

  # Every directory of a toolchain outside the system paths is there.
  foreach(_dir IN LISTS _expected)
    _ct_increment()
    if(NOT _dir IN_LIST _entries)
      _ct_fail("'${file}' (${_stdlib}) lacks '${_dir}' in its RUNPATH: ${_entries}")
    endif()
  endforeach()
  message(STATUS "toolchain_runtime_rpath_build: ${file} (${_stdlib}) RUNPATH=[${_entries}]")
endfunction()

if(_trb_skip)
  message(STATUS "toolchain_runtime_rpath_build: skipped (${_trb_skip})")
else()
  include("${_module_root}/deployment/ToolchainRuntimeRpath.cmake")

  set(_trb_dir "${CMAKE_CURRENT_BINARY_DIR}/_ct_toolchain_runtime_rpath_build")
  file(REMOVE_RECURSE "${_trb_dir}")
  execute_process(
    COMMAND ${CMAKE_COMMAND}
      -S "${_trb_fixture}" -B "${_trb_dir}"
      -G "${CMAKE_GENERATOR}"
      "-DCMAKE_BUILD_TYPE=Release"
      "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
      "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
      "-DMODULE_ROOT=${_module_root}"
    RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _out
    ERROR_VARIABLE _err)
  if(NOT _rc EQUAL 0)
    _ct_fail("toolchain_runtime_rpath fixture: configure failed\n${_out}${_err}")
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} --build "${_trb_dir}"
    RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _out
    ERROR_VARIABLE _err)
  if(NOT _rc EQUAL 0)
    _ct_fail("toolchain_runtime_rpath fixture: build failed\n${_out}${_err}")
  endif()

  get_filename_component(_trb_real_dir "${_trb_dir}" REALPATH)
  foreach(_trb_file "${_trb_dir}/fixture_app" "${_trb_dir}/lib/libfixture_lib.so")
    _trb_expect_binary("${_trb_file}" "${_trb_real_dir}")
  endforeach()

  # The program starts without LD_LIBRARY_PATH: with a toolchain outside the
  # system paths the loader finds the runtime through the RUNPATH alone.
  _ct_increment()
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env --unset=LD_LIBRARY_PATH "${_trb_dir}/fixture_app"
    RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _out
    ERROR_VARIABLE _err)
  if(NOT _rc EQUAL 0)
    _ct_fail("fixture_app does not start without LD_LIBRARY_PATH (exit '${_rc}'): ${_out}${_err}")
  endif()
endif()
