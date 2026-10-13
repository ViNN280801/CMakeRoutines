# End-to-end check of deployment/ToolchainRuntimeRpath.cmake on a real Windows
# toolchain (MSVC, clang-cl, MinGW GCC or Clang). There is no ELF RUNPATH on
# Windows, so nothing may be added: get_toolchain_runtime_directories answers an
# empty list for every STDLIB, no target type gets BUILD_RPATH (by the explicit
# call or by the TOOLCHAIN_RUNTIME_RPATH parameter of configure_optimization_level),
# and the fixture of toolchain_runtime_rpath_build.cmake still configures,
# builds and starts in all four modes. The other platforms of the module are
# checked by simulation in toolchain_runtime_rpath.cmake (Apple has no host
# here). Runs before any case simulates another platform.

set(_trw_fixture "${CMAKE_CURRENT_LIST_DIR}/../fixtures/toolchain_runtime_rpath")
get_property(_trw_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

set(_trw_skip "")
if(NOT CMAKE_HOST_WIN32)
  set(_trw_skip "not a Windows host")
elseif(CMAKE_CROSSCOMPILING)
  set(_trw_skip "cross-compiling")
endif()

if(_trw_skip)
  message(STATUS "toolchain_runtime_rpath_windows: skipped (${_trw_skip})")
else()
  include("${_module_root}/optimizations/OptimizationLevelConfig.cmake")
  include("${_module_root}/deployment/ToolchainRuntimeRpath.cmake")
  message(STATUS "toolchain_runtime_rpath_windows: ${CMAKE_CXX_COMPILER_ID} "
    "${CMAKE_CXX_COMPILER_VERSION} (${CMAKE_CXX_COMPILER_FRONTEND_VARIANT}), "
    "generator ${CMAKE_GENERATOR}")

  # The answer is empty whatever the library asked for.
  foreach(_trw_args "" "STDLIB;libstdc++" "STDLIB;libc++" "STDLIB;libstdc++;libc++")
    get_toolchain_runtime_directories(_trw_dirs ${_trw_args})
    _ct_increment()
    if(_trw_dirs)
      _ct_fail("get_toolchain_runtime_directories(${_trw_args}) on Windows: expected nothing, got '${_trw_dirs}'")
    endif()
  endforeach()

  # No target type takes the property, by any of the three routes.
  function(_trw_expect_no_rpath target)
    _ct_increment()
    get_target_property(_trw_rpath ${target} BUILD_RPATH)
    if(_trw_rpath)
      _ct_fail("'${target}' got BUILD_RPATH '${_trw_rpath}' on Windows, expected none")
    endif()
  endfunction()

  foreach(_trw_type EXECUTABLE SHARED MODULE)
    new_linked_test_target(_trw_call_target ${_trw_type})
    configure_toolchain_runtime_rpath(${_trw_call_target})
    _trw_expect_no_rpath(${_trw_call_target})
    configure_toolchain_runtime_rpath(${_trw_call_target} STDLIB libstdc++ libc++)
    _trw_expect_no_rpath(${_trw_call_target})

    new_linked_test_target(_trw_param_target ${_trw_type})
    configure_optimization_level(${_trw_param_target} TOOLCHAIN_RUNTIME_RPATH ON)
    _trw_expect_no_rpath(${_trw_param_target})
  endforeach()
  new_test_target(_trw_static_target)
  configure_toolchain_runtime_rpath(${_trw_static_target})
  _trw_expect_no_rpath(${_trw_static_target})

  # The fixture: configure, build, start (the DLL sits next to the program).
  function(_trw_check_mode mode)
    set(_trw_dir "${CMAKE_CURRENT_BINARY_DIR}/_ct_toolchain_runtime_rpath_windows_${mode}")
    file(REMOVE_RECURSE "${_trw_dir}")
    execute_process(
      COMMAND ${CMAKE_COMMAND}
        -S "${_trw_fixture}" -B "${_trw_dir}"
        -G "${CMAKE_GENERATOR}"
        "-DCMAKE_BUILD_TYPE=Release"
        "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
        "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
        "-DMODULE_ROOT=${_module_root}"
        "-DFIXTURE_RPATH_MODE=${mode}"
      RESULT_VARIABLE _rc
      OUTPUT_VARIABLE _out
      ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0)
      _ct_fail("toolchain_runtime_rpath_windows fixture (${mode}): configure failed\n${_out}${_err}")
    endif()
    execute_process(
      COMMAND ${CMAKE_COMMAND} --build "${_trw_dir}" --config Release
      RESULT_VARIABLE _rc
      OUTPUT_VARIABLE _out
      ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0)
      _ct_fail("toolchain_runtime_rpath_windows fixture (${mode}): build failed\n${_out}${_err}")
    endif()

    if(_trw_multi_config)
      set(_trw_app "${_trw_dir}/Release/fixture_app.exe")
    else()
      set(_trw_app "${_trw_dir}/fixture_app.exe")
    endif()
    _ct_increment()
    if(NOT EXISTS "${_trw_app}")
      _ct_fail("toolchain_runtime_rpath_windows fixture (${mode}): '${_trw_app}' was not built")
    endif()
    _ct_increment()
    execute_process(
      COMMAND "${_trw_app}"
      RESULT_VARIABLE _rc
      OUTPUT_VARIABLE _out
      ERROR_VARIABLE _err)
    if(NOT _rc EQUAL 0)
      _ct_fail("fixture_app (${mode}) does not start on Windows (exit '${_rc}'): ${_out}${_err}")
    endif()
    message(STATUS "toolchain_runtime_rpath_windows: ${mode} ok")
  endfunction()

  foreach(_trw_mode CALL PARAMETER BOTH NONE)
    _trw_check_mode(${_trw_mode})
  endforeach()
endif()
