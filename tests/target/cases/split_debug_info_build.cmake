# End-to-end check of the Release debug-info split in
# optimizations/OptimizationLevelConfig.cmake: builds
# fixtures/split_debug_info with the real compiler of this configure, once in
# Release and once in Debug, and reads the outputs with readelf. The fixture's
# shared library is configured from its parent directory, as LumexLib
# configures its modules. Runs where the split applies and can be observed (an
# ELF host, GCC or Clang, objcopy, readelf, a single-config generator) and
# reports a skip elsewhere. Runs before any case simulates another platform.

set(_sdi_fixture "${CMAKE_CURRENT_LIST_DIR}/../fixtures/split_debug_info")
find_program(_sdi_readelf NAMES readelf llvm-readelf)
get_property(_sdi_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

set(_sdi_skip "")
if(NOT CMAKE_HOST_UNIX OR CMAKE_HOST_APPLE)
  set(_sdi_skip "not an ELF host")
elseif(NOT CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang)$")
  set(_sdi_skip "compiler is ${CMAKE_CXX_COMPILER_ID}")
elseif(NOT CMAKE_OBJCOPY)
  set(_sdi_skip "no objcopy")
elseif(NOT _sdi_readelf)
  set(_sdi_skip "no readelf")
elseif(_sdi_multi_config)
  set(_sdi_skip "multi-config generator ${CMAKE_GENERATOR}")
endif()

# Configures and builds the fixture in <config>; <out_var> is its build tree.
function(_sdi_build config out_var)
  set(_dir "${CMAKE_CURRENT_BINARY_DIR}/_ct_split_debug_info_${config}")
  file(REMOVE_RECURSE "${_dir}")
  execute_process(
    COMMAND ${CMAKE_COMMAND}
      -S "${_sdi_fixture}" -B "${_dir}"
      -G "${CMAKE_GENERATOR}"
      "-DCMAKE_BUILD_TYPE=${config}"
      "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
      "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
      "-DMODULE_ROOT=${_module_root}"
    RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _out
    ERROR_VARIABLE _err)
  if(NOT _rc EQUAL 0)
    _ct_fail("split_debug_info fixture: configure (${config}) failed\n${_out}${_err}")
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} --build "${_dir}"
    RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _out
    ERROR_VARIABLE _err)
  if(NOT _rc EQUAL 0)
    _ct_fail("split_debug_info fixture: build (${config}) failed\n${_out}${_err}")
  endif()
  set(${out_var} "${_dir}" PARENT_SCOPE)
endfunction()

# Section headers and notes of <file>, in the C locale (readelf translates
# its labels, "Build ID" included).
function(_sdi_readelf_text file out_var)
  if(NOT EXISTS "${file}")
    _ct_fail("split_debug_info fixture: '${file}' was not built")
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env LC_ALL=C LANG=C
      "${_sdi_readelf}" -S -W -n "${file}"
    RESULT_VARIABLE _rc
    OUTPUT_VARIABLE _out
    ERROR_VARIABLE _err)
  if(NOT _rc EQUAL 0)
    _ct_fail("readelf '${file}' failed: ${_err}")
  endif()
  set(${out_var} "${_out}" PARENT_SCOPE)
endfunction()

function(_sdi_expect file regex should_match what)
  _ct_increment()
  _sdi_readelf_text("${file}" _text)
  if(_text MATCHES "${regex}")
    set(_found TRUE)
  else()
    set(_found FALSE)
  endif()
  if(should_match AND NOT _found)
    _ct_fail("'${file}' lacks ${what}")
  elseif(NOT should_match AND _found)
    _ct_fail("'${file}' still has ${what}")
  endif()
endfunction()

function(_sdi_expect_exists path should_exist)
  _ct_increment()
  if(should_exist AND NOT EXISTS "${path}")
    _ct_fail("'${path}' was not written")
  elseif(NOT should_exist AND EXISTS "${path}")
    _ct_fail("'${path}' should not exist")
  endif()
endfunction()

set(_sdi_dwarf "[ \t]\\.debug_info[ \t]")
set(_sdi_symtab "[ \t]\\.symtab[ \t]")
set(_sdi_debuglink "[ \t]\\.gnu_debuglink[ \t]")
set(_sdi_build_id "Build ID:")

if(_sdi_skip)
  message(STATUS "split_debug_info_build: skipped (${_sdi_skip})")
else()
  # Release: both binaries stripped, with a Build ID and a debuglink; their
  # DWARF in <file>.debug. The library's split needs a linker launcher
  # (CMake 3.21+); older CMake keeps its symbols inside.
  _sdi_build(Release _sdi_release)
  set(_sdi_app "${_sdi_release}/fixture_app")
  set(_sdi_lib "${_sdi_release}/lib/libfixture_lib.so.1.2.3")

  _sdi_expect("${_sdi_app}" "${_sdi_debuglink}" TRUE ".gnu_debuglink")
  _sdi_expect("${_sdi_app}" "${_sdi_build_id}" TRUE "a Build ID")
  _sdi_expect("${_sdi_app}" "${_sdi_dwarf}" FALSE ".debug_info")
  _sdi_expect("${_sdi_app}" "${_sdi_symtab}" FALSE ".symtab")
  _sdi_expect_exists("${_sdi_app}.debug" TRUE)
  _sdi_expect("${_sdi_app}.debug" "${_sdi_dwarf}" TRUE ".debug_info")

  if(CMAKE_VERSION VERSION_LESS 3.21)
    _sdi_expect("${_sdi_lib}" "${_sdi_dwarf}" TRUE ".debug_info")
    _sdi_expect_exists("${_sdi_lib}.debug" FALSE)
  else()
    _sdi_expect("${_sdi_lib}" "${_sdi_debuglink}" TRUE ".gnu_debuglink")
    _sdi_expect("${_sdi_lib}" "${_sdi_build_id}" TRUE "a Build ID")
    _sdi_expect("${_sdi_lib}" "${_sdi_dwarf}" FALSE ".debug_info")
    _sdi_expect("${_sdi_lib}" "${_sdi_symtab}" FALSE ".symtab")
    _sdi_expect_exists("${_sdi_lib}.debug" TRUE)
    _sdi_expect("${_sdi_lib}.debug" "${_sdi_dwarf}" TRUE ".debug_info")
  endif()

  # The stripped executable still runs against the stripped library.
  _ct_increment()
  execute_process(COMMAND "${_sdi_app}" RESULT_VARIABLE _sdi_rc)
  if(NOT _sdi_rc EQUAL 0)
    _ct_fail("stripped '${_sdi_app}' exited with '${_sdi_rc}'")
  endif()

  # Debug: no split, the DWARF stays inside.
  _sdi_build(Debug _sdi_debug)
  _sdi_expect("${_sdi_debug}/fixture_app" "${_sdi_dwarf}" TRUE ".debug_info")
  _sdi_expect("${_sdi_debug}/fixture_app" "${_sdi_debuglink}" FALSE ".gnu_debuglink")
  _sdi_expect_exists("${_sdi_debug}/fixture_app.debug" FALSE)
endif()
