# CMakeRoutines test runner (script mode)
#
# Usage:
#   cmake -DCASE=<name> [-DMODULE_ROOT=<module-root>]
#         [-DCASE_EXPECT_FAIL=1] [-DCASE_FAIL_PATTERN=<regex>]
#         -P run_one.cmake
#
# MODULE_ROOT defaults to the parent of this file (the CMakeRoutines root), so
# case files can include the modules under test with a relative path.

cmake_minimum_required(VERSION 3.16)

if(NOT CASE)
  message(FATAL_ERROR "CASE is required")
endif()

if(NOT MODULE_ROOT)
  get_filename_component(MODULE_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
endif()

set(_case_file "${CMAKE_CURRENT_LIST_DIR}/cases/${CASE}.cmake")
if(NOT EXISTS "${_case_file}")
  message(FATAL_ERROR "missing case file: ${_case_file}")
endif()

if(CASE_EXPECT_FAIL)
  execute_process(
    COMMAND ${CMAKE_COMMAND}
      -DCASE=${CASE}
      -DMODULE_ROOT=${MODULE_ROOT}
      -P ${_case_file}
    RESULT_VARIABLE _rv
    OUTPUT_VARIABLE _out
    ERROR_VARIABLE _err)
  if(_rv EQUAL 0)
    message(FATAL_ERROR
      "case ${CASE} was expected to fail but returned 0\n${_out}${_err}")
  endif()
  if(CASE_FAIL_PATTERN AND NOT "${_err}${_out}" MATCHES "${CASE_FAIL_PATTERN}")
    message(FATAL_ERROR
      "case ${CASE} failed, but the output did not match '${CASE_FAIL_PATTERN}'\n"
      "stdout:\n${_out}\nstderr:\n${_err}")
  endif()
else()
  include("${_case_file}")
endif()
