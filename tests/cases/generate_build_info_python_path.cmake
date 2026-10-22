# Regression for utils/GenerateBuildInfo.cmake: _gbinfo_call_python looked for
# GenerateBuildInfo.py next to CMAKE_CURRENT_LIST_FILE, which inside a function
# is the list file of the CALLER. From any project's directory the script was
# never found: one warning per target, and the CMake-native text was written
# under the .json name of a json build. This case calls it from tests/cases/,
# where no GenerateBuildInfo.py lies, and requires the Python report.

include("${MODULE_ROOT}/utils/GenerateBuildInfo.cmake")

if(NOT GBINFO_PYTHON_EXECUTABLE)
  message(STATUS "generate_build_info_python_path: no Python 3.8+, nothing to check")
  return()
endif()
if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/GenerateBuildInfo.py")
  message(FATAL_ERROR "the case needs a directory without GenerateBuildInfo.py")
endif()

set(_dir "${CMAKE_ROUTINES_TEST_TMP}/cmr_gbinfo_python_path")
file(REMOVE_RECURSE "${_dir}")
file(MAKE_DIRECTORY "${_dir}")
file(WRITE "${_dir}/context.json" "{}\n")

_gbinfo_call_python(probe "${_dir}/probe-build-info.json" json
  "${_dir}/context.json" "" _ok)
if(NOT _ok)
  message(FATAL_ERROR "_gbinfo_call_python did not run GenerateBuildInfo.py")
endif()
file(READ "${_dir}/probe-build-info.json" _report)
if(NOT _report MATCHES "^{" OR NOT _report MATCHES "\"generator\": \"GenerateBuildInfo.py\"")
  message(FATAL_ERROR "not the JSON report of GenerateBuildInfo.py:\n${_report}")
endif()
file(REMOVE_RECURSE "${_dir}")
