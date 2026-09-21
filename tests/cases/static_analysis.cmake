# Branch coverage for analysis/StaticAnalysisConfig.cmake (pure helper)
include("${MODULE_ROOT}/analysis/StaticAnalysisConfig.cmake")

# Defaults: DETECT_LEAKS ON, default ASAN/UBSAN options.
get_sanitizer_env_recommendations(_r)
if(NOT "${_r}" MATCHES "ASAN_OPTIONS=symbolize=1:abort_on_error=1:print_stats=0:detect_leaks=1")
  message(FATAL_ERROR "default ASAN options: ${_r}")
endif()
if(NOT "${_r}" MATCHES "UBSAN_OPTIONS=print_stacktrace=1:abort_on_error=1")
  message(FATAL_ERROR "default UBSAN options: ${_r}")
endif()
if("${_r}" MATCHES "LSAN_OPTIONS=")
  message(FATAL_ERROR "no LSAN_OPTIONS entry expected by default: ${_r}")
endif()

# DETECT_LEAKS OFF -> no detect_leaks=1
get_sanitizer_env_recommendations(_r DETECT_LEAKS OFF)
if("${_r}" MATCHES "detect_leaks=1")
  message(FATAL_ERROR "DETECT_LEAKS OFF should omit detect_leaks=1: ${_r}")
endif()

# DETECT_LEAKS 0 -> OFF
get_sanitizer_env_recommendations(_r DETECT_LEAKS 0)
if("${_r}" MATCHES "detect_leaks=1")
  message(FATAL_ERROR "DETECT_LEAKS 0 should omit detect_leaks=1: ${_r}")
endif()

# DETECT_LEAKS FALSE -> OFF
get_sanitizer_env_recommendations(_r DETECT_LEAKS FALSE)
if("${_r}" MATCHES "detect_leaks=1")
  message(FATAL_ERROR "DETECT_LEAKS FALSE should omit detect_leaks=1: ${_r}")
endif()

# Custom ASAN_OPTS / UBSAN_OPTS / LSAN_OPTS
get_sanitizer_env_recommendations(_r ASAN_OPTS foo=1 UBSAN_OPTS bar=2 LSAN_OPTS baz=3)
if(NOT "${_r}" MATCHES "ASAN_OPTIONS=foo=1")
  message(FATAL_ERROR "custom ASAN: ${_r}")
endif()
if(NOT "${_r}" MATCHES "UBSAN_OPTIONS=bar=2")
  message(FATAL_ERROR "custom UBSAN: ${_r}")
endif()
if(NOT "${_r}" MATCHES "LSAN_OPTIONS=baz=3")
  message(FATAL_ERROR "custom LSAN: ${_r}")
endif()
