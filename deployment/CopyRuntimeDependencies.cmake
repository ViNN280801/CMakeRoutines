# =============================================================================
# CopyRuntimeDependencies.cmake
# Universal cross-platform runtime dependency copy helper (cmake -P script mode)
# =============================================================================
#
# Copies compiler runtime shared libraries next to a built binary so that the
# binary is runnable without the user having to install the toolchain runtimes.
#
# This script runs in CMake SCRIPT mode (cmake -P). It is designed to be
# invoked as a POST_BUILD command from CMakeLists.txt:
#
# add_custom_command(TARGET MyTarget POST_BUILD
#   COMMAND ${CMAKE_COMMAND}
#     -Dtarget_file=$<TARGET_FILE:MyTarget>
#     [-Ddependency_name_regex=<regex>]
#     [-Dreport_unresolved=ON]
#     -P ${path}/CopyRuntimeDependencies.cmake
#   VERBATIM
# )
#
# Parameters (passed via -D on the cmake command line):
#   target_file            - REQUIRED. Full path to the built binary.
#   dependency_name_regex  - OPTIONAL. Regex against the dependency filename.
#                            If omitted, platform-specific defaults are used.
#   skip_compiler_runtime  - OPTIONAL. When ON, do not copy libstdc++/libgcc_s
#                            (shared libs built in-tree: avoids stale libstdc++
#                            in BUILD_RPATH dirs that breaks linking of
#                            dependent executables).
#   preferred_runtime_dir  - OPTIONAL (Linux/Unix). Directory of the toolchain
#                            runtime that was linked (from link_compiler_runtime
#                            property LCR_CXX_RUNTIME_DIR). When set, libstdc++,
#                            libgcc_s, libatomic, and libgomp are copied from
#                            this directory first. Required on hosts where
#                            LIBRARY_PATH / a stale $ORIGIN copy would make
#                            file(GET_RUNTIME_DEPENDENCIES) resolve an older
#                            libstdc++ (e.g. Astra SE gcc-astra 6.0.30 vs
#                            /usr/local/gcc-13.2).
#   report_unresolved      - OPTIONAL. When ON, log each unresolved dependency
#                            (informational; usually system/API-set DLLs).
#                            Default: OFF (keeps build output quiet).
#
# Platform defaults (when dependency_name_regex is not specified):
#   Windows  - msvcp140 / vcruntime140 (+ optional _* segments and/or trailing
#              Debug "d" before .dll). Examples: msvcp140.dll, msvcp140d.dll,
#              vcruntime140_1.dll, vcruntime140_1d.dll.
#              Excludes MFC, OpenMP, concrt, ucrtbase, api-ms-win-*.
#              Override via dependency_name_regex for a broader set, e.g.
#              "^(vcruntime|msvcp|concrt|ucrtbase|api-ms-win)".
#   macOS    - libc++, libc++abi, libunwind
#   Linux    - libstdc++, libgcc_s, libgomp, libatomic, libc++, libunwind
#   Other    - all resolved dependencies
#
# Notes:
# - Requires CMake 3.16+ (file(GET_RUNTIME_DEPENDENCIES) was added in 3.16).
# - Only already-resolved dependencies are copied; unresolved ones are optional
#   to log (see report_unresolved).
# - System DLLs (kernel32.dll, ntdll.dll, etc.) are intentionally excluded by
#   the default regex and are never copied.
# - On Windows, enable runtime-copy only for /MD (dynamic runtime); static /MT
#   builds do not require separate DLLs.
# =============================================================================

cmake_minimum_required(VERSION 3.16)

# CMP0207 (CMake 4.3): file(GET_RUNTIME_DEPENDENCIES) normalizes dependency
# paths to forward slashes before matching filters. Opt in so mixed-separator
# Windows paths (e.g. C:\Windows\system32/vcruntime140.dll) no longer emit a
# dev warning. This script matches on the dependency filename, not its path, so
# the normalization is safe. Guarded because CMP0207 does not exist before 4.3.
if(POLICY CMP0207)
  cmake_policy(SET CMP0207 NEW)
endif()

if(NOT target_file OR NOT EXISTS "${target_file}")
  message(WARNING
    "CopyRuntimeDependencies: target_file missing or not found: '${target_file}'. "
    "Ensure the target was built before this script runs.")
  return()
endif()

get_filename_component(output_dir "${target_file}" DIRECTORY)

# --- Platform-specific default regex ----------------------------------------
if(NOT DEFINED dependency_name_regex OR dependency_name_regex STREQUAL "")
  if(WIN32)
    # MSVC CRT redistributable subset.
    # Release: msvcp140.dll, vcruntime140.dll, vcruntime140_1.dll, msvcp140_*.dll
    # Debug:   msvcp140d.dll, vcruntime140d.dll, vcruntime140_1d.dll
    # The optional trailing "d" is required: Debug CRT uses a bare "d" suffix
    # (msvcp140d.dll), not only underscore forms (vcruntime140_1d.dll). A regex
    # of only "(_.*)?" matches the latter and silently skips the former - which
    # looks like "deploy stopped after the first DLL" on Debug /MDd builds.
    set(dependency_name_regex
      "^(msvcp140|vcruntime140)([_].*)?d?\\.dll$")
  elseif(APPLE)
    # libc++, libc++abi, libunwind shipped with Clang/libc++
    set(dependency_name_regex
      "^(libc\\+\\+|libc\\+\\+abi|libunwind)")
  elseif(UNIX)
    # libstdc++ / libgcc_s (GCC), libc++ / libunwind (Clang),
    # libgomp (OpenMP), libatomic (C++ atomics)
    if(skip_compiler_runtime)
      set(dependency_name_regex
        "^(libgomp|libatomic|libquadmath|libc\\+\\+|libc\\+\\+abi|libunwind)")
    else()
      set(dependency_name_regex
        "^(libstdc\\+\\+|libgcc_s|libgomp|libatomic|libquadmath|libc\\+\\+|libc\\+\\+abi|libunwind)")
    endif()
  else()
    # Unknown host: copy everything that was resolved
    set(dependency_name_regex ".*")
  endif()
endif()

# --- Prefer toolchain dir from link_compiler_runtime -------------------------
# file(GET_RUNTIME_DEPENDENCIES) follows ldd/$ORIGIN/LD_LIBRARY_PATH. A stale
# libstdc++.so.6 already next to the binary (or gcc-astra earlier in
# LIBRARY_PATH) wins over the GCC that actually linked the executable. Copy
# matching sonames from preferred_runtime_dir first when provided.
set(_copied_count 0)
set(_forced_names "")

if(UNIX AND NOT APPLE
   AND DEFINED preferred_runtime_dir
   AND preferred_runtime_dir
   AND IS_DIRECTORY "${preferred_runtime_dir}"
   AND NOT skip_compiler_runtime)
  foreach(_crt_name IN ITEMS
      "libstdc++.so.6"
      "libgcc_s.so.1"
      "libatomic.so.1"
      "libgomp.so.1"
      "libc++.so.1"
      "libc++abi.so.1"
      "libunwind.so.1")
    set(_crt_src "${preferred_runtime_dir}/${_crt_name}")
    if(NOT EXISTS "${_crt_src}")
      continue()
    endif()
    get_filename_component(_crt_real "${_crt_src}" REALPATH)
    if(NOT EXISTS "${_crt_real}")
      message(WARNING
        "CopyRuntimeDependencies: preferred path missing for '${_crt_name}': "
        "'${_crt_src}'")
      continue()
    endif()
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E copy_if_different
              "${_crt_real}" "${output_dir}/${_crt_name}"
      RESULT_VARIABLE _copy_rc
      ERROR_VARIABLE _copy_err
      OUTPUT_QUIET
    )
    if(_copy_rc EQUAL 0)
      message(STATUS
        "CopyRuntimeDependencies: preferred '${_crt_name}' ← '${_crt_real}'")
      list(APPEND _forced_names "${_crt_name}")
      math(EXPR _copied_count "${_copied_count} + 1")
    else()
      message(WARNING
        "CopyRuntimeDependencies: failed to copy preferred '${_crt_name}': "
        "${_copy_err}")
    endif()
  endforeach()
endif()

# --- Resolve runtime dependencies -------------------------------------------
# Use EXECUTABLES for executables (.exe or no .so/.dll/.dylib) so dependencies resolve correctly.
get_filename_component(_target_name "${target_file}" NAME)

if(WIN32 AND _target_name MATCHES "\\.exe$")
  set(_use_executables TRUE)
elseif(UNIX AND NOT _target_name MATCHES "\\.so")
  set(_use_executables TRUE)
else()
  set(_use_executables FALSE)
endif()

if(_use_executables)
  file(GET_RUNTIME_DEPENDENCIES
    EXECUTABLES "${target_file}"
    RESOLVED_DEPENDENCIES_VAR _resolved
    UNRESOLVED_DEPENDENCIES_VAR _unresolved
  )
else()
  file(GET_RUNTIME_DEPENDENCIES
    LIBRARIES "${target_file}"
    RESOLVED_DEPENDENCIES_VAR _resolved
    UNRESOLVED_DEPENDENCIES_VAR _unresolved
  )
endif()

# --- Copy matched dependencies ----------------------------------------------
# On Linux/macOS, GET_RUNTIME_DEPENDENCIES often returns a soname symlink
# (e.g. libstdc++.so.6 -> libstdc++.so.6.0.33). file(COPY) of a symlink alone
# leaves a dangling link in the output dir. Always copy the real file under the
# soname the loader looks for (regular file, same content).

foreach(dep ${_resolved})
  get_filename_component(dep_name "${dep}" NAME)

  if(NOT dep_name MATCHES "${dependency_name_regex}")
    continue()
  endif()

  if(dep_name IN_LIST _forced_names)
    continue()
  endif()

  get_filename_component(dep_real "${dep}" REALPATH)
  if(NOT EXISTS "${dep_real}")
    message(WARNING
      "CopyRuntimeDependencies: resolved path missing for '${dep_name}': '${dep}'")
    continue()
  endif()
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${dep_real}" "${output_dir}/${dep_name}"
    RESULT_VARIABLE _copy_rc
    ERROR_VARIABLE _copy_err
    OUTPUT_QUIET
  )
  if(_copy_rc EQUAL 0)
    message(STATUS "CopyRuntimeDependencies: copied '${dep_name}' → '${output_dir}'")
    math(EXPR _copied_count "${_copied_count} + 1")
  else()
    message(WARNING
      "CopyRuntimeDependencies: failed to copy '${dep_name}': ${_copy_err}")
  endif()
endforeach()

if(_copied_count EQUAL 0)
  message(STATUS "CopyRuntimeDependencies: no matching runtime dependencies found "
    "(regex='${dependency_name_regex}')")
endif()

# --- Report unresolved (optional; default OFF) ------------------------------
if(report_unresolved)
  foreach(dep ${_unresolved})
    message(STATUS "CopyRuntimeDependencies: unresolved dependency '${dep}' "
      "(expected for system libraries)")
  endforeach()
endif()
