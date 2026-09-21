# Module coverage: collect_sources_recursive splits headers from sources and
# honours the default exclude directories (3rdparty/tests/test).

include("${MODULE_ROOT}/utils/RecursiveSourceCollection.cmake")

set(_tmp "$ENV{TEMP}/cmakeroutines-test-rsc")
file(TO_CMAKE_PATH "${_tmp}" _tmp)
file(REMOVE_RECURSE "${_tmp}")
file(MAKE_DIRECTORY "${_tmp}/src/sub")
file(MAKE_DIRECTORY "${_tmp}/src/tests")
file(WRITE "${_tmp}/src/a.cpp" "int a;")
file(WRITE "${_tmp}/src/b.hpp" "// header")
file(WRITE "${_tmp}/src/sub/c.cpp" "int c;")
file(WRITE "${_tmp}/src/tests/t.cpp" "int t;")

collect_sources_recursive("${_tmp}/src" _sources EXTENSIONS cpp hpp)

# a.cpp, b.hpp, sub/c.cpp are collected; b.hpp is also duplicated into the
# headers list; tests/ is excluded by default.
list(LENGTH _sources _n)
if(NOT _n EQUAL 3)
  message(FATAL_ERROR "expected 3 sources, got ${_n}: ${_sources}")
endif()
if(NOT "${_sources}" MATCHES "a\\.cpp")
  message(FATAL_ERROR "missing a.cpp: ${_sources}")
endif()
if(NOT "${_sources}" MATCHES "c\\.cpp")
  message(FATAL_ERROR "missing sub/c.cpp: ${_sources}")
endif()
if(NOT "${_sources}" MATCHES "b\\.hpp")
  message(FATAL_ERROR "missing b.hpp: ${_sources}")
endif()
if("${_sources}" MATCHES "t\\.cpp")
  message(FATAL_ERROR "tests/t.cpp should be excluded: ${_sources}")
endif()
if(NOT "${_sources_HEADERS}" MATCHES "b\\.hpp")
  message(FATAL_ERROR "missing b.hpp in headers: ${_sources_HEADERS}")
endif()

file(REMOVE_RECURSE "${_tmp}")
