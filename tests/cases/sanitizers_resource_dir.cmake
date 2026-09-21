# Regression: clang resource-directory fallback.
# When `-print-resource-dir` is unavailable the helper must fall back to globbing
# <compiler_dir>/../lib/clang/<version>. A non-existent compiler exercises that
# path without requiring a real Clang install.

include("${MODULE_ROOT}/testing/SanitizersConfig.cmake")

set(_tmp "${CMAKE_CURRENT_LIST_DIR}/../.test-tmp-resource-dir")
file(REMOVE_RECURSE "${_tmp}")
file(MAKE_DIRECTORY "${_tmp}/bin")
file(MAKE_DIRECTORY "${_tmp}/lib/clang/99")

# A compiler path that does not exist: -print-resource-dir fails, so the
# fallback glob must resolve <compiler_dir>/../lib/clang/* -> lib/clang/99.
set(CMAKE_CXX_COMPILER "${_tmp}/bin/does-not-exist")
_lumex_sanitizer_resource_dir(_got)

if(NOT _got MATCHES "lib/clang/99$")
  message(FATAL_ERROR
    "fallback resource dir: expected '.../lib/clang/99', got '${_got}'")
endif()

file(REMOVE_RECURSE "${_tmp}")
