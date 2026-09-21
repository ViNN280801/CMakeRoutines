# Feature: sanitizer runtime option strings.
# sanitizer_runtime_options maps enabled sanitizers to "<SAN>_OPTIONS=<opts>"
# entries. The constants carry the verbose diagnostics recommended to users.

include("${MODULE_ROOT}/testing/SanitizersConfig.cmake")

# ASan + UBSan only.
sanitizer_runtime_options(_opts ADDRESS ON UNDEFINED ON)
if(NOT _opts MATCHES "ASAN_OPTIONS=halt_on_error=1:abort_on_error=1")
  message(FATAL_ERROR "missing ASAN_OPTIONS entry: ${_opts}")
endif()
if(NOT _opts MATCHES "UBSAN_OPTIONS=print_stacktrace=1")
  message(FATAL_ERROR "missing UBSAN_OPTIONS entry: ${_opts}")
endif()
if(_opts MATCHES "TSAN_OPTIONS=|MSAN_OPTIONS=|LSAN_OPTIONS=")
  message(FATAL_ERROR "unexpected sanitizer entries for ASan+UBSan: ${_opts}")
endif()

# Every sanitizer enabled -> every entry present.
sanitizer_runtime_options(_all
  ADDRESS ON MEMORY ON THREAD ON UNDEFINED ON LEAK ON)
foreach(_need IN ITEMS ASAN_OPTIONS UBSAN_OPTIONS LSAN_OPTIONS MSAN_OPTIONS TSAN_OPTIONS)
  if(NOT _all MATCHES "${_need}=")
    message(FATAL_ERROR "missing ${_need} in all-sanitizers list: ${_all}")
  endif()
endforeach()

# Nothing enabled -> empty list.
sanitizer_runtime_options(_none)
if(_none)
  message(FATAL_ERROR "expected empty list for no sanitizers, got '${_none}'")
endif()

# The option strings must enable the diagnostic features the user asked for.
if(NOT SANITIZER_RUNTIME_ASAN_OPTIONS MATCHES "verbosity=1")
  message(FATAL_ERROR "ASan options missing verbosity=1")
endif()
if(NOT SANITIZER_RUNTIME_ASAN_OPTIONS MATCHES "detect_stack_use_after_return=1")
  message(FATAL_ERROR "ASan options missing detect_stack_use_after_return=1")
endif()
if(NOT SANITIZER_RUNTIME_UBSAN_OPTIONS MATCHES "print_stacktrace=1")
  message(FATAL_ERROR "UBSan options missing print_stacktrace=1")
endif()
if(NOT SANITIZER_RUNTIME_TSAN_OPTIONS MATCHES "history_size=7")
  message(FATAL_ERROR "TSan options missing history_size=7")
endif()
