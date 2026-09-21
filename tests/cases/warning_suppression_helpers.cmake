# Branch coverage for utils/WarningSuppression.cmake (pure helpers)
include("${MODULE_ROOT}/utils/WarningSuppression.cmake")

# --- _suppress_all_flags ---
_suppress_all_flags("MSVC" _r)
if(NOT _r STREQUAL "/w")
  message(FATAL_ERROR "MSVC all flags: '${_r}'")
endif()
_suppress_all_flags("GNU" _r)
if(NOT _r STREQUAL "-w")
  message(FATAL_ERROR "GNU all flags: '${_r}'")
endif()
_suppress_all_flags("Clang" _r)
if(NOT _r STREQUAL "-w")
  message(FATAL_ERROR "Clang all flags: '${_r}'")
endif()
_suppress_all_flags("Intel" _r)
if(NOT _r STREQUAL "-w")
  message(FATAL_ERROR "Intel all flags: '${_r}'")
endif()
_suppress_all_flags("Watcom" _r)
if(NOT _r STREQUAL "-w")
  message(FATAL_ERROR "Unknown all flags: '${_r}'")
endif()

# --- _suppress_specific_flags ---
_suppress_specific_flags("MSVC" "4251;4267" _r)
if(NOT _r STREQUAL "/wd4251;/wd4267")
  message(FATAL_ERROR "MSVC specific flags: '${_r}'")
endif()
_suppress_specific_flags("GNU" "global-constructors;documentation" _r)
if(NOT _r STREQUAL "-Wno-global-constructors;-Wno-documentation")
  message(FATAL_ERROR "GNU specific flags: '${_r}'")
endif()
_suppress_specific_flags("Clang" "global-constructors" _r)
if(NOT _r STREQUAL "-Wno-global-constructors")
  message(FATAL_ERROR "Clang specific flags: '${_r}'")
endif()
_suppress_specific_flags("Intel" "181;869" _r)
if(NOT _r STREQUAL "-diag-disable:181;-diag-disable:869")
  message(FATAL_ERROR "Intel specific flags: '${_r}'")
endif()
_suppress_specific_flags("Watcom" "anything" _r)
if(NOT _r STREQUAL "-w")
  message(FATAL_ERROR "Unknown specific flags: '${_r}'")
endif()

# --- _warning_suppress_match_sources ---
# folder substring match
_warning_suppress_match_sources("src/main.cpp;3rdparty/gtest/a.cpp;3rdparty/nlohmann/b.cpp" "3rdparty" _m)
if(NOT _m STREQUAL "3rdparty/gtest/a.cpp;3rdparty/nlohmann/b.cpp")
  message(FATAL_ERROR "folder match: '${_m}'")
endif()

# file path match
_warning_suppress_match_sources("src/main.cpp;3rdparty/nlohmann/json.hpp" "nlohmann/json.hpp" _m)
if(NOT _m STREQUAL "3rdparty/nlohmann/json.hpp")
  message(FATAL_ERROR "file match: '${_m}'")
endif()

# regex match
_warning_suppress_match_sources("src/main.cpp;third_party/x.cpp;src/other.cpp" "^.*third_party.*$" _m)
if(NOT _m STREQUAL "third_party/x.cpp")
  message(FATAL_ERROR "regex match: '${_m}'")
endif()

# Windows backslash normalization
_warning_suppress_match_sources("C:\\proj\\3rdparty\\x.cpp;C:\\proj\\src\\main.cpp" "3rdparty" _m)
if(NOT _m STREQUAL "C:\\proj\\3rdparty\\x.cpp")
  message(FATAL_ERROR "windows path match: '${_m}'")
endif()

# no match -> empty
_warning_suppress_match_sources("src/main.cpp" "3rdparty" _m)
if(_m)
  message(FATAL_ERROR "expected empty match, got '${_m}'")
endif()

# multiple patterns, OR semantics
_warning_suppress_match_sources("a.cpp;b.cpp;c.cpp" "a.cpp;c.cpp" _m)
if(NOT _m STREQUAL "a.cpp;c.cpp")
  message(FATAL_ERROR "multi pattern match: '${_m}'")
endif()
