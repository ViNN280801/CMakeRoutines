# Exit statuses of optimizations/split-debug-info.sh, the linker launcher
# configure_optimization_level sets for Release debug symbols on ELF. A launcher
# that hid a failed link would let the build go on with a stale or missing
# binary. POSIX hosts only (the script runs through /bin/sh); objcopy is never
# reached in the cases below, so none is needed.
if(CMAKE_HOST_WIN32 OR NOT EXISTS "/bin/sh")
  message(STATUS "split_debug_info_launcher: skipped (no /bin/sh)")
  return()
endif()

set(_sdl_script "${MODULE_ROOT}/optimizations/split-debug-info.sh")
set(_sdl_out "${CMAKE_ROUTINES_TEST_TMP}/cmake_routines_split_debug_info_launcher")
file(REMOVE "${_sdl_out}" "${_sdl_out}.debug")

function(_sdl_run expected_rc)
  execute_process(
    COMMAND /bin/sh "${_sdl_script}" ${ARGN}
    RESULT_VARIABLE _rc
    OUTPUT_QUIET
    ERROR_VARIABLE _err)
  if(NOT "${_rc}" STREQUAL "${expected_rc}")
    message(FATAL_ERROR
      "split-debug-info.sh ${ARGN}: expected exit ${expected_rc}, got '${_rc}' (${_err})")
  endif()
endfunction()

# Too few arguments: usage error.
_sdl_run(2 objcopy 1 1)

# The link command's failure comes back as is, in Release too, and nothing
# is split.
_sdl_run(3 objcopy 1 1 "${_sdl_out}" /bin/sh -c "exit 3")
if(EXISTS "${_sdl_out}.debug")
  message(FATAL_ERROR "a failed link still produced '${_sdl_out}.debug'")
endif()

# Outside Release a successful link is all: objcopy is not run (it does not
# exist here).
_sdl_run(0 /nonexistent/objcopy 1 0 "${_sdl_out}" /bin/sh -c "exit 0")

# In Release a failed objcopy fails the build.
_sdl_run(1 /nonexistent/objcopy 1 1 "${_sdl_out}" /bin/sh -c "exit 0")
