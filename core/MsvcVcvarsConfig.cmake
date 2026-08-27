# =============================================================================
# MsvcVcvarsConfig.cmake
# Universal MSVC developer-environment import for C/C++ projects
# =============================================================================
#
# Locates Visual Studio (vswhere, VS 2019+) and imports vcvarsall.bat into
# the current CMake process so Ninja/Makefile generators can compile without
# a Developer Command Prompt.
#
# Call configure_msvc_vcvars() BEFORE project(). After project() this module
# raises FATAL_ERROR: compiler detection has already run.
#
# Functions:
#   configure_msvc_vcvars(
#     [ARCH <arch>]
#     [VCVARSALL <path>]
#     [INSTALLATION_PATH <path>]
#     [VSWHERE <path>]
#     [PRERELEASE]
#   )
#
# Usage:
#   cmake_minimum_required(VERSION 3.16)
#   list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
#   include(core/MsvcVcvarsConfig)
#   configure_msvc_vcvars()
#   project(MyProject LANGUAGES C CXX)
#
# Cache / -D overrides (function arguments win when both are set):
#   MSVC_VCVARSALL              path to vcvarsall.bat
#   MSVC_VS_INSTALLATION_PATH   Visual Studio installation root
#   MSVC_VCVARS_ARCH            target arch or raw vcvarsall token
#   MSVC_VSWHERE                path to vswhere.exe
#   MSVC_VCVARS_PRERELEASE      ON to include Preview in the first vswhere pass
#
# =============================================================================

include_guard(GLOBAL)

# =============================================================================
# Internal helpers
# =============================================================================

function(_msvc_vcvars_first_line text out_var)
  string(REPLACE "\r\n" "\n" _t "${text}")
  string(REPLACE "\r" "\n" _t "${_t}")
  string(REGEX REPLACE "\n.*" "" _t "${_t}")
  string(STRIP "${_t}" _t)
  set(${out_var} "${_t}" PARENT_SCOPE)
endfunction()

function(_msvc_vcvars_abbrev_env name out_var)
  if(NOT DEFINED ENV{${name}} OR "$ENV{${name}}" STREQUAL "")
    set(${out_var} "(unset)" PARENT_SCOPE)
    return()
  endif()
  set(_raw "$ENV{${name}}")
  list(LENGTH _raw _n)
  list(GET _raw 0 _first)
  if(_n GREATER 1)
    set(${out_var} "${_first} ... (${_n} entries)" PARENT_SCOPE)
  else()
    set(${out_var} "${_raw}" PARENT_SCOPE)
  endif()
endfunction()

function(_msvc_vcvars_find_vswhere explicit_vswhere out_var)
  if(explicit_vswhere AND EXISTS "${explicit_vswhere}")
    set(${out_var} "${explicit_vswhere}" PARENT_SCOPE)
    return()
  endif()
  if(MSVC_VSWHERE AND EXISTS "${MSVC_VSWHERE}")
    set(${out_var} "${MSVC_VSWHERE}" PARENT_SCOPE)
    return()
  endif()

  set(_vswhere "$ENV{ProgramFiles\(x86\)}/Microsoft Visual Studio/Installer/vswhere.exe")
  if(NOT EXISTS "${_vswhere}")
    set(_vswhere "$ENV{ProgramFiles}/Microsoft Visual Studio/Installer/vswhere.exe")
  endif()
  if(EXISTS "${_vswhere}")
    set(${out_var} "${_vswhere}" PARENT_SCOPE)
  else()
    set(${out_var} "" PARENT_SCOPE)
  endif()
endfunction()

function(_msvc_vcvars_detect_host_arch out_var)
  set(_wow "$ENV{PROCESSOR_ARCHITEW6432}")
  if(_wow)
    set(_raw "${_wow}")
  else()
    set(_raw "$ENV{PROCESSOR_ARCHITECTURE}")
    if(NOT _raw)
      set(_raw "${CMAKE_HOST_SYSTEM_PROCESSOR}")
    endif()
  endif()
  string(TOUPPER "${_raw}" _u)
  if(_u STREQUAL "AMD64" OR _u STREQUAL "X86_64" OR _u STREQUAL "X64")
    set(${out_var} "x64" PARENT_SCOPE)
  elseif(_u STREQUAL "ARM64" OR _u STREQUAL "AARCH64")
    set(${out_var} "arm64" PARENT_SCOPE)
  elseif(_u STREQUAL "X86" OR _u STREQUAL "I386" OR _u STREQUAL "I686")
    set(${out_var} "x86" PARENT_SCOPE)
  else()
    message(FATAL_ERROR
      "MsvcVcvarsConfig: unsupported host architecture '${_raw}'. "
      "Set ARCH / MSVC_VCVARS_ARCH explicitly (x86, x64, arm64, or a vcvarsall token).")
  endif()
endfunction()

function(_msvc_vcvars_normalize_target requested host_arch out_target out_is_raw)
  string(TOLOWER "${requested}" _req)
  string(STRIP "${_req}" _req)
  if(_req MATCHES "_")
    set(${out_target} "${_req}" PARENT_SCOPE)
    set(${out_is_raw} TRUE PARENT_SCOPE)
    return()
  endif()
  if(_req STREQUAL "x64" OR _req STREQUAL "amd64" OR _req STREQUAL "x86_64")
    set(${out_target} "x64" PARENT_SCOPE)
  elseif(_req STREQUAL "x86" OR _req STREQUAL "win32" OR _req STREQUAL "i386")
    set(${out_target} "x86" PARENT_SCOPE)
  elseif(_req STREQUAL "arm64" OR _req STREQUAL "aarch64")
    set(${out_target} "arm64" PARENT_SCOPE)
  elseif(_req STREQUAL "")
    set(${out_target} "${host_arch}" PARENT_SCOPE)
  else()
    message(FATAL_ERROR
      "MsvcVcvarsConfig: unknown ARCH '${requested}'. "
      "Use x86, x64, arm64, or a raw vcvarsall token (amd64, amd64_x86, arm64, ...).")
  endif()
  set(${out_is_raw} FALSE PARENT_SCOPE)
endfunction()

function(_msvc_vcvars_compute_arg host_arch target_arch is_raw out_var)
  if(is_raw)
    set(${out_var} "${target_arch}" PARENT_SCOPE)
    return()
  endif()
  if(host_arch STREQUAL "x64")
    if(target_arch STREQUAL "x64")
      set(${out_var} "amd64" PARENT_SCOPE)
    elseif(target_arch STREQUAL "x86")
      set(${out_var} "amd64_x86" PARENT_SCOPE)
    elseif(target_arch STREQUAL "arm64")
      set(${out_var} "amd64_arm64" PARENT_SCOPE)
    endif()
  elseif(host_arch STREQUAL "arm64")
    if(target_arch STREQUAL "arm64")
      set(${out_var} "arm64" PARENT_SCOPE)
    elseif(target_arch STREQUAL "x64")
      set(${out_var} "arm64_amd64" PARENT_SCOPE)
    elseif(target_arch STREQUAL "x86")
      set(${out_var} "arm64_x86" PARENT_SCOPE)
    endif()
  elseif(host_arch STREQUAL "x86")
    if(target_arch STREQUAL "x86")
      set(${out_var} "x86" PARENT_SCOPE)
    else()
      set(${out_var} "" PARENT_SCOPE)
    endif()
  else()
    set(${out_var} "" PARENT_SCOPE)
  endif()
endfunction()

function(_msvc_vcvars_check_host_can_run host_arch vcvars_arg)
  if(NOT host_arch STREQUAL "x86")
    return()
  endif()
  if(vcvars_arg STREQUAL "x86")
    return()
  endif()
  message(FATAL_ERROR
    "MsvcVcvarsConfig: a 32-bit Windows host cannot run the 64-bit MSVC toolset "
    "(requested vcvarsall argument '${vcvars_arg}'). Use ARCH x86, or configure "
    "on a 64-bit host.")
endfunction()

function(_msvc_vcvars_vswhere_find vswhere out_var)
  execute_process(
    COMMAND "${vswhere}" -latest -products "*" ${ARGN} -find "**/vcvarsall.bat"
    OUTPUT_VARIABLE _out
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  _msvc_vcvars_first_line("${_out}" _line)
  if(_line AND EXISTS "${_line}")
    set(${out_var} "${_line}" PARENT_SCOPE)
  else()
    set(${out_var} "" PARENT_SCOPE)
  endif()
endfunction()

function(_msvc_vcvars_locate_vcvarsall vswhere installation_path use_prerelease_first explicit_vcvarsall out_vcvars out_pass)
  if(explicit_vcvarsall)
    if(NOT EXISTS "${explicit_vcvarsall}")
      message(FATAL_ERROR
        "MsvcVcvarsConfig: VCVARSALL does not exist: '${explicit_vcvarsall}'")
    endif()
    set(${out_vcvars} "${explicit_vcvarsall}" PARENT_SCOPE)
    set(${out_pass} "argument VCVARSALL" PARENT_SCOPE)
    return()
  endif()
  if(MSVC_VCVARSALL)
    if(NOT EXISTS "${MSVC_VCVARSALL}")
      message(FATAL_ERROR
        "MsvcVcvarsConfig: MSVC_VCVARSALL does not exist: '${MSVC_VCVARSALL}'")
    endif()
    set(${out_vcvars} "${MSVC_VCVARSALL}" PARENT_SCOPE)
    set(${out_pass} "cache MSVC_VCVARSALL" PARENT_SCOPE)
    return()
  endif()

  set(_root "${installation_path}")
  if(_root)
    set(_candidate "${_root}/VC/Auxiliary/Build/vcvarsall.bat")
    if(EXISTS "${_candidate}")
      set(${out_vcvars} "${_candidate}" PARENT_SCOPE)
      set(${out_pass} "INSTALLATION_PATH" PARENT_SCOPE)
      return()
    endif()
    if(vswhere)
      execute_process(
        COMMAND "${vswhere}" -path "${_root}" -find "**/vcvarsall.bat"
        OUTPUT_VARIABLE _out
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
      )
      _msvc_vcvars_first_line("${_out}" _line)
      if(_line AND EXISTS "${_line}")
        set(${out_vcvars} "${_line}" PARENT_SCOPE)
        set(${out_pass} "vswhere -path INSTALLATION_PATH" PARENT_SCOPE)
        return()
      endif()
    endif()
    message(FATAL_ERROR
      "MsvcVcvarsConfig: vcvarsall.bat not found under installation path '${_root}'. "
      "Expected VC/Auxiliary/Build/vcvarsall.bat (Visual Studio 2017+ layout).")
  endif()

  if(NOT vswhere)
    message(FATAL_ERROR
      "MsvcVcvarsConfig: vswhere.exe not found and no VCVARSALL / "
      "MSVC_VS_INSTALLATION_PATH given. Install Visual Studio 2019+ (or Build Tools) "
      "or pass -DMSVC_VCVARSALL=<path-to-vcvarsall.bat>.")
  endif()

  set(_vc_tools -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64)

  if(use_prerelease_first)
    _msvc_vcvars_vswhere_find("${vswhere}" _found -prerelease ${_vc_tools})
    if(_found)
      set(${out_vcvars} "${_found}" PARENT_SCOPE)
      set(${out_pass} "vswhere -latest -prerelease" PARENT_SCOPE)
      return()
    endif()
    _msvc_vcvars_vswhere_find("${vswhere}" _found -prerelease)
    if(_found)
      set(${out_vcvars} "${_found}" PARENT_SCOPE)
      set(${out_pass} "vswhere -latest -prerelease (any product)" PARENT_SCOPE)
      return()
    endif()
    _msvc_vcvars_vswhere_find("${vswhere}" _found ${_vc_tools})
    if(_found)
      set(${out_vcvars} "${_found}" PARENT_SCOPE)
      set(${out_pass} "vswhere -latest (stable, after Preview miss)" PARENT_SCOPE)
      return()
    endif()
    _msvc_vcvars_vswhere_find("${vswhere}" _found)
    if(_found)
      set(${out_vcvars} "${_found}" PARENT_SCOPE)
      set(${out_pass} "vswhere -find vcvarsall.bat (any product)" PARENT_SCOPE)
      return()
    endif()
  else()
    _msvc_vcvars_vswhere_find("${vswhere}" _found ${_vc_tools})
    if(_found)
      set(${out_vcvars} "${_found}" PARENT_SCOPE)
      set(${out_pass} "vswhere -latest (stable)" PARENT_SCOPE)
      return()
    endif()
    _msvc_vcvars_vswhere_find("${vswhere}" _found -prerelease ${_vc_tools})
    if(_found)
      set(${out_vcvars} "${_found}" PARENT_SCOPE)
      set(${out_pass} "vswhere -latest -prerelease (fallback)" PARENT_SCOPE)
      return()
    endif()
    _msvc_vcvars_vswhere_find("${vswhere}" _found -prerelease)
    if(_found)
      set(${out_vcvars} "${_found}" PARENT_SCOPE)
      set(${out_pass} "vswhere -find vcvarsall.bat (Preview, any product)" PARENT_SCOPE)
      return()
    endif()
    _msvc_vcvars_vswhere_find("${vswhere}" _found)
    if(_found)
      set(${out_vcvars} "${_found}" PARENT_SCOPE)
      set(${out_pass} "vswhere -find vcvarsall.bat (any product)" PARENT_SCOPE)
      return()
    endif()
  endif()

  message(FATAL_ERROR
    "MsvcVcvarsConfig: vcvarsall.bat not found via vswhere ('${vswhere}'). "
    "Install the VC++ toolset (Desktop development with C++) or set "
    "-DMSVC_VCVARSALL=<path-to-vcvarsall.bat>.")
endfunction()

function(_msvc_vcvars_install_root_from_vcvarsall vcvarsall out_var)
  get_filename_component(_d "${vcvarsall}" DIRECTORY)
  get_filename_component(_d "${_d}" DIRECTORY)
  get_filename_component(_d "${_d}" DIRECTORY)
  get_filename_component(_d "${_d}" DIRECTORY)
  set(${out_var} "${_d}" PARENT_SCOPE)
endfunction()

function(_msvc_vcvars_import_env vcvarsall vcvars_arg out_count)
  file(TO_NATIVE_PATH "${vcvarsall}" _native)
  string(RANDOM LENGTH 8 _tok)
  set(_helper "$ENV{TEMP}/msvc_vcvars_capture_${_tok}.bat")
  file(WRITE "${_helper}"
    "@echo off\r\n"
    "call \"${_native}\" ${vcvars_arg} >nul\r\n"
    "if errorlevel 1 exit /b 1\r\n"
    "set\r\n"
  )
  execute_process(
    COMMAND "${_helper}"
    OUTPUT_VARIABLE _env_block
    ERROR_VARIABLE _env_err
    RESULT_VARIABLE _env_rc
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  file(REMOVE "${_helper}")
  if(NOT _env_rc EQUAL 0)
    message(FATAL_ERROR
      "MsvcVcvarsConfig: vcvarsall.bat failed (rc=${_env_rc}) for "
      "'${vcvarsall}' ${vcvars_arg}. ${_env_err}")
  endif()

  string(REPLACE "\r\n" "\n" _remaining "${_env_block}")
  string(REPLACE "\r" "\n" _remaining "${_remaining}")
  set(_imported 0)
  while(NOT _remaining STREQUAL "")
    string(FIND "${_remaining}" "\n" _nl)
    if(_nl EQUAL -1)
      set(_line "${_remaining}")
      set(_remaining "")
    else()
      string(SUBSTRING "${_remaining}" 0 ${_nl} _line)
      math(EXPR _next "${_nl}+1")
      string(SUBSTRING "${_remaining}" ${_next} -1 _remaining)
    endif()
    if(_line MATCHES "^([^=]+)=(.*)$")
      set(_key "${CMAKE_MATCH_1}")
      set(_val "${CMAKE_MATCH_2}")
      if(NOT _key STREQUAL "")
        set(ENV{${_key}} "${_val}")
        math(EXPR _imported "${_imported}+1")
      endif()
    endif()
  endwhile()
  set(${out_count} "${_imported}" PARENT_SCOPE)
endfunction()

function(_msvc_vcvars_bind_tools)
  find_program(_msvc_cl NAMES cl cl.exe)
  find_program(_msvc_link NAMES link link.exe)
  find_program(_msvc_rc NAMES rc rc.exe)
  find_program(_msvc_mt NAMES mt mt.exe)
  if(_msvc_cl)
    if(NOT CMAKE_C_COMPILER)
      set(CMAKE_C_COMPILER "${_msvc_cl}" CACHE FILEPATH "C compiler")
    endif()
    if(NOT CMAKE_CXX_COMPILER)
      set(CMAKE_CXX_COMPILER "${_msvc_cl}" CACHE FILEPATH "C++ compiler")
    endif()
  elseif(NOT CMAKE_C_COMPILER OR NOT CMAKE_CXX_COMPILER)
    message(FATAL_ERROR
      "MsvcVcvarsConfig: cl.exe not found after importing vcvars. "
      "Install the MSVC C++ toolset or set CMAKE_C_COMPILER / CMAKE_CXX_COMPILER.")
  endif()
  if(_msvc_link AND NOT CMAKE_LINKER)
    set(CMAKE_LINKER "${_msvc_link}" CACHE FILEPATH "Linker")
  endif()
  if(_msvc_rc AND NOT CMAKE_RC_COMPILER)
    set(CMAKE_RC_COMPILER "${_msvc_rc}" CACHE FILEPATH "RC compiler")
  endif()
  if(_msvc_mt AND NOT CMAKE_MT)
    set(CMAKE_MT "${_msvc_mt}" CACHE FILEPATH "MSVC mt.exe")
  endif()
endfunction()

function(_msvc_vcvars_print_report)
  set(options ALREADY_ACTIVE)
  set(oneValueArgs VCVARSALL ARCH HOST_ARCH VSWHERE INSTALLATION_PATH PASS IMPORTED MANUAL)
  cmake_parse_arguments(REP "${options}" "${oneValueArgs}" "" ${ARGN})

  _msvc_vcvars_abbrev_env(INCLUDE _inc)
  _msvc_vcvars_abbrev_env(LIB _lib)
  _msvc_vcvars_abbrev_env(LIBPATH _libpath)

  message(STATUS "MsvcVcvarsConfig: preparing MSVC development environment")
  message(STATUS "  hint           : call configure_msvc_vcvars() BEFORE project()")
  if(REP_ALREADY_ACTIVE)
    message(STATUS "  source         : already active Developer Prompt (VSCMD_ARG_TGT_ARCH=$ENV{VSCMD_ARG_TGT_ARCH})")
  else()
    message(STATUS "  source         : ${REP_PASS}")
  endif()
  message(STATUS "  vcvarsall      : ${REP_VCVARSALL}")
  message(STATUS "  vcvarsall arg  : ${REP_ARCH} (host ${REP_HOST_ARCH})")
  if(REP_VSWHERE)
    message(STATUS "  vswhere        : ${REP_VSWHERE}")
  endif()
  message(STATUS "  installation   : ${REP_INSTALLATION_PATH}")
  message(STATUS "  action         : import INCLUDE, LIB, LIBPATH, PATH, Windows SDK into this CMake process")
  if(DEFINED ENV{VCToolsVersion})
    message(STATUS "  VCToolsVersion : $ENV{VCToolsVersion}")
  endif()
  if(DEFINED ENV{WindowsSDKVersion})
    message(STATUS "  WindowsSDK     : $ENV{WindowsSDKVersion}")
  endif()
  if(DEFINED ENV{VSCMD_VER})
    message(STATUS "  VSCMD_VER      : $ENV{VSCMD_VER}")
  endif()
  if(DEFINED ENV{VSCMD_ARG_HOST_ARCH})
    message(STATUS "  host/target    : $ENV{VSCMD_ARG_HOST_ARCH} -> $ENV{VSCMD_ARG_TGT_ARCH}")
  endif()
  message(STATUS "  INCLUDE        : ${_inc}")
  message(STATUS "  LIB            : ${_lib}")
  message(STATUS "  LIBPATH        : ${_libpath}")
  if(REP_IMPORTED)
    message(STATUS "  imported vars  : ${REP_IMPORTED}")
  endif()
  if(CMAKE_C_COMPILER)
    message(STATUS "  CMAKE_C_COMPILER   : ${CMAKE_C_COMPILER}")
  endif()
  if(CMAKE_CXX_COMPILER)
    message(STATUS "  CMAKE_CXX_COMPILER : ${CMAKE_CXX_COMPILER}")
  endif()
  if(CMAKE_RC_COMPILER)
    message(STATUS "  CMAKE_RC_COMPILER  : ${CMAKE_RC_COMPILER}")
  endif()
  if(CMAKE_MT)
    message(STATUS "  CMAKE_MT           : ${CMAKE_MT}")
  endif()
  message(STATUS "  manual         : ${REP_MANUAL}")
endfunction()

# =============================================================================
# Function: configure_msvc_vcvars
#
# Discovers vcvarsall.bat, imports its environment into this CMake process,
# and points unset CMAKE_*_COMPILER cache entries at cl.exe / rc.exe / mt.exe.
# Must run before project().
#
# Parameters:
#   ARCH <arch>                 Target ISA (x86|x64|arm64) or raw vcvarsall token.
#                               Default: host architecture.
#   VCVARSALL <path>            Explicit vcvarsall.bat (highest priority).
#   INSTALLATION_PATH <path>    Visual Studio root; vcvarsall is resolved under it.
#   VSWHERE <path>              Explicit vswhere.exe.
#   PRERELEASE                  Include Preview builds in the first vswhere query.
# =============================================================================
function(configure_msvc_vcvars)
  if(NOT CMAKE_HOST_WIN32)
    message(STATUS "MsvcVcvarsConfig: not a Windows host, skipping")
    return()
  endif()

  if(CMAKE_PROJECT_NAME)
    message(FATAL_ERROR
      "MsvcVcvarsConfig: configure_msvc_vcvars() must be called BEFORE project(). "
      "Compiler detection already ran for '${CMAKE_PROJECT_NAME}'. Example:\n"
      "  cmake_minimum_required(VERSION 3.16)\n"
      "  list(APPEND CMAKE_MODULE_PATH \"\${CMAKE_CURRENT_SOURCE_DIR}/cmake\")\n"
      "  include(core/MsvcVcvarsConfig)\n"
      "  configure_msvc_vcvars()\n"
      "  project(MyProject LANGUAGES C CXX)")
  endif()

  set(options PRERELEASE)
  set(oneValueArgs ARCH VCVARSALL INSTALLATION_PATH VSWHERE)
  cmake_parse_arguments(MSVC_VCVARS_PARSE "${options}" "${oneValueArgs}" "" ${ARGN})

  set(MSVC_VCVARSALL "${MSVC_VCVARSALL}" CACHE FILEPATH
    "Path to vcvarsall.bat (overrides vswhere)")
  set(MSVC_VS_INSTALLATION_PATH "${MSVC_VS_INSTALLATION_PATH}" CACHE PATH
    "Visual Studio installation root (overrides vswhere -latest)")
  set(MSVC_VCVARS_ARCH "${MSVC_VCVARS_ARCH}" CACHE STRING
    "vcvarsall architecture: x86, x64, arm64, or a raw token (amd64_x86, ...)")
  set(MSVC_VSWHERE "${MSVC_VSWHERE}" CACHE FILEPATH
    "Path to vswhere.exe")
  set(MSVC_VCVARS_PRERELEASE "${MSVC_VCVARS_PRERELEASE}" CACHE BOOL
    "Query Visual Studio Preview installs in the first vswhere pass")

  _msvc_vcvars_detect_host_arch(_host_arch)

  set(_requested "${MSVC_VCVARS_PARSE_ARCH}")
  if(NOT _requested)
    set(_requested "${MSVC_VCVARS_ARCH}")
  endif()
  _msvc_vcvars_normalize_target("${_requested}" "${_host_arch}" _target_arch _is_raw)
  _msvc_vcvars_compute_arg("${_host_arch}" "${_target_arch}" "${_is_raw}" _vcvars_arg)
  if(NOT _vcvars_arg)
    message(FATAL_ERROR
      "MsvcVcvarsConfig: cannot map host '${_host_arch}' + ARCH '${_requested}' "
      "to a vcvarsall argument.")
  endif()
  _msvc_vcvars_check_host_can_run("${_host_arch}" "${_vcvars_arg}")

  _msvc_vcvars_find_vswhere("${MSVC_VCVARS_PARSE_VSWHERE}" _vswhere)

  set(_use_pre FALSE)
  if(MSVC_VCVARS_PARSE_PRERELEASE OR MSVC_VCVARS_PRERELEASE)
    set(_use_pre TRUE)
  endif()

  set(_install_hint "${MSVC_VCVARS_PARSE_INSTALLATION_PATH}")
  if(NOT _install_hint)
    set(_install_hint "${MSVC_VS_INSTALLATION_PATH}")
  endif()

  _msvc_vcvars_locate_vcvarsall(
    "${_vswhere}"
    "${_install_hint}"
    "${_use_pre}"
    "${MSVC_VCVARS_PARSE_VCVARSALL}"
    _vcvarsall
    _pass)

  _msvc_vcvars_install_root_from_vcvarsall("${_vcvarsall}" _install_root)

  file(TO_NATIVE_PATH "${_vcvarsall}" _vcvars_native)
  set(_manual "cmd /c \"call \"${_vcvars_native}\" ${_vcvars_arg}\"")

  if(DEFINED ENV{VSCMD_ARG_TGT_ARCH} AND NOT "$ENV{VSCMD_ARG_TGT_ARCH}" STREQUAL "")
    _msvc_vcvars_bind_tools()
    _msvc_vcvars_print_report(
      ALREADY_ACTIVE
      VCVARSALL "${_vcvarsall}"
      ARCH "${_vcvars_arg}"
      HOST_ARCH "${_host_arch}"
      VSWHERE "${_vswhere}"
      INSTALLATION_PATH "${_install_root}"
      PASS "${_pass}"
      MANUAL "${_manual}")
  else()
    _msvc_vcvars_import_env("${_vcvarsall}" "${_vcvars_arg}" _imported)
    _msvc_vcvars_bind_tools()
    _msvc_vcvars_print_report(
      VCVARSALL "${_vcvarsall}"
      ARCH "${_vcvars_arg}"
      HOST_ARCH "${_host_arch}"
      VSWHERE "${_vswhere}"
      INSTALLATION_PATH "${_install_root}"
      PASS "${_pass}"
      IMPORTED "${_imported}"
      MANUAL "${_manual}")
  endif()

  set(MSVC_VCVARSALL "${_vcvarsall}" PARENT_SCOPE)
  set(MSVC_VCVARS_ARCH "${_vcvars_arg}" PARENT_SCOPE)
  set(MSVC_VS_INSTALLATION_PATH "${_install_root}" PARENT_SCOPE)
endfunction()
