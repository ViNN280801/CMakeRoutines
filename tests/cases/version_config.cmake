# Branch coverage for core/VersionConfig.cmake
include("${MODULE_ROOT}/core/VersionConfig.cmake")

function(_expect_eq got expected label)
  if(NOT "${got}" STREQUAL "${expected}")
    message(FATAL_ERROR "${label}: expected '${expected}', got '${got}'")
  endif()
endfunction()

# 3-component version
configure_version(VERSION 1.2.3)
_expect_eq("${PROJECT_VERSION_MAJOR}" "1" "major 1.2.3")
_expect_eq("${PROJECT_VERSION_MINOR}" "2" "minor 1.2.3")
_expect_eq("${PROJECT_VERSION_PATCH}" "3" "patch 1.2.3")
_expect_eq("${PROJECT_VERSION_TWEAK}" "0" "tweak 1.2.3")

# 4-component version
configure_version(VERSION 1.2.3.4)
_expect_eq("${PROJECT_VERSION_TWEAK}" "4" "tweak 1.2.3.4")

# 1-component version
configure_version(VERSION 1)
_expect_eq("${PROJECT_VERSION_MAJOR}" "1" "major 1")
_expect_eq("${PROJECT_VERSION_MINOR}" "0" "minor 1")
_expect_eq("${PROJECT_VERSION_PATCH}" "0" "patch 1")

# 2-component version
configure_version(VERSION 1.2)
_expect_eq("${PROJECT_VERSION_MAJOR}" "1" "major 1.2")
_expect_eq("${PROJECT_VERSION_MINOR}" "2" "minor 1.2")
_expect_eq("${PROJECT_VERSION_PATCH}" "0" "patch 1.2")

# PROJECT_VERSION fallback
set(PROJECT_VERSION "2.5.1")
configure_version()
_expect_eq("${PROJECT_VERSION_MAJOR}" "2" "major project fallback")
_expect_eq("${PROJECT_VERSION_MINOR}" "5" "minor project fallback")

# default 1.0.0 (no VERSION, no PROJECT_VERSION)
set(PROJECT_VERSION "")
configure_version()
_expect_eq("${PROJECT_VERSION}" "1.0.0" "default version")

# _generate_version_header content (tweak = 0)
set(_tmp "$ENV{TEMP}/cmakeroutines-test-ver.h")
file(TO_CMAKE_PATH "${_tmp}" _tmp)
_generate_version_header("${_tmp}" 1 2 3 0)
file(READ "${_tmp}" _content)
if(NOT _content MATCHES "#define PROJECT_VERSION_MAJOR 1")
  message(FATAL_ERROR "header missing MAJOR")
endif()
if(NOT _content MATCHES "PROJECT_VERSION \"1.2.3\"")
  message(FATAL_ERROR "header missing version string (tweak=0)")
endif()

# tweak != 0 -> version string includes tweak
_generate_version_header("${_tmp}" 1 2 3 4)
file(READ "${_tmp}" _content)
if(NOT _content MATCHES "PROJECT_VERSION \"1.2.3.4\"")
  message(FATAL_ERROR "header missing tweak version string")
endif()

file(REMOVE "${_tmp}")
