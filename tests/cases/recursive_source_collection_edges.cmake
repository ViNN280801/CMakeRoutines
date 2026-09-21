# Edge/branch coverage for utils/RecursiveSourceCollection.cmake
include("${MODULE_ROOT}/utils/RecursiveSourceCollection.cmake")

set(_tmp "$ENV{TEMP}/cmakeroutines-test-rsc-edges")
file(TO_CMAKE_PATH "${_tmp}" _tmp)
file(REMOVE_RECURSE "${_tmp}")
file(MAKE_DIRECTORY "${_tmp}/a/sub")
file(MAKE_DIRECTORY "${_tmp}/a/tests")
file(MAKE_DIRECTORY "${_tmp}/a/examples")
file(MAKE_DIRECTORY "${_tmp}/b")
file(WRITE "${_tmp}/a/x.cpp" "int x;")
file(WRITE "${_tmp}/a/x.h" "// header")
file(WRITE "${_tmp}/a/sub/y.cxx" "int y;")
file(WRITE "${_tmp}/a/tests/t.cpp" "int t;")
file(WRITE "${_tmp}/a/examples/e.cpp" "int e;")
file(WRITE "${_tmp}/b/z.cc" "int z;")

# collect_sources_recursive_multiple across two dirs (default excludes tests/examples).
collect_sources_recursive_multiple(_all DIRS "${_tmp}/a" "${_tmp}/b")
foreach(_need IN ITEMS "x\\.cpp" "y\\.cxx" "z\\.cc")
  if(NOT "${_all}" MATCHES "${_need}")
    message(FATAL_ERROR "multiple: missing ${_need}: ${_all}")
  endif()
endforeach()
if(NOT "${_all_HEADERS}" MATCHES "x\\.h")
  message(FATAL_ERROR "multiple: missing x.h header: ${_all_HEADERS}")
endif()

# INCLUDE_TESTS ON: the default EXCLUDE_DIRS ("tests","test") runs first, so it
# must be overridden to let the tests dir through.
collect_sources_recursive("${_tmp}/a" _src INCLUDE_TESTS ON EXCLUDE_DIRS 3rdparty EXTENSIONS cpp)
if(NOT "${_src}" MATCHES "t\\.cpp")
  message(FATAL_ERROR "INCLUDE_TESTS ON should include tests/t.cpp: ${_src}")
endif()

# INCLUDE_EXAMPLES ON -> examples dir included (examples is not in EXCLUDE_DIRS).
collect_sources_recursive("${_tmp}/a" _src INCLUDE_EXAMPLES ON EXTENSIONS cpp)
if(NOT "${_src}" MATCHES "e\\.cpp")
  message(FATAL_ERROR "INCLUDE_EXAMPLES ON should include examples/e.cpp: ${_src}")
endif()

# EXCLUDE_PATTERNS removes matching substrings.
collect_sources_recursive("${_tmp}/a" _src EXCLUDE_PATTERNS "sub" EXTENSIONS cpp)
if("${_src}" MATCHES "y\\.cxx")
  message(FATAL_ERROR "EXCLUDE_PATTERNS sub should exclude sub/y.cxx")
endif()
if(NOT "${_src}" MATCHES "x\\.cpp")
  message(FATAL_ERROR "EXCLUDE_PATTERNS should keep x.cpp: ${_src}")
endif()

# default extensions include .h (header list) and .cpp/.cxx/.cc.
collect_sources_recursive("${_tmp}/a" _src)
if(NOT "${_src_HEADERS}" MATCHES "x\\.h")
  message(FATAL_ERROR "default extensions should collect x.h as header: ${_src_HEADERS}")
endif()

# empty dir -> no files.
file(MAKE_DIRECTORY "${_tmp}/empty")
collect_sources_recursive("${_tmp}/empty" _src)
if(_src)
  message(FATAL_ERROR "empty dir should yield no files: ${_src}")
endif()

file(REMOVE_RECURSE "${_tmp}")
