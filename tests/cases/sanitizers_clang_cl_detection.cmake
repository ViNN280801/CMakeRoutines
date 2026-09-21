# Regression: clang-cl detection.
# clang-cl is MSVC-true AND Clang-id. cl.exe is MSVC-true but MSVC-id. Native
# clang++ is Clang-id but not MSVC. The helper must distinguish all three.

include("${MODULE_ROOT}/testing/SanitizersConfig.cmake")

function(_expect_is_clang_cl expect msvc compiler_id label)
  set(MSVC ${msvc})
  set(CMAKE_CXX_COMPILER_ID "${compiler_id}")
  _lumex_sanitizer_is_clang_cl(_got)
  if(NOT _got STREQUAL "${expect}")
    message(FATAL_ERROR
      "${label}: expected '${expect}', got '${_got}' "
      "(MSVC=${msvc} ID=${compiler_id})")
  endif()
endfunction()

_expect_is_clang_cl(TRUE  TRUE  Clang "clang-cl (MSVC + Clang)")
_expect_is_clang_cl(FALSE TRUE  MSVC  "cl.exe (MSVC + MSVC)")
_expect_is_clang_cl(FALSE FALSE Clang "native clang++ (Clang, not MSVC)")
_expect_is_clang_cl(FALSE FALSE GNU   "gcc")
