# Regression: clang_rt.* arch suffix mapping.
# The runtime library/DLL names embed a lower-case arch token that differs from
# CMAKE_CXX_COMPILER_ARCHITECTURE_ID.

include("${MODULE_ROOT}/testing/SanitizersConfig.cmake")

function(_expect_suffix expect arch label)
  set(CMAKE_CXX_COMPILER_ARCHITECTURE_ID "${arch}")
  _lumex_sanitizer_arch_suffix(_got)
  if(NOT _got STREQUAL "${expect}")
    message(FATAL_ERROR
      "${label}: expected '${expect}', got '${_got}' (arch=${arch})")
  endif()
endfunction()

_expect_suffix(x86_64  X64    "X64")
_expect_suffix(x86_64  AMD64  "AMD64")
_expect_suffix(i386    X86    "X86")
_expect_suffix(i386    IA32   "IA32")
_expect_suffix(aarch64 ARM64  "ARM64")
_expect_suffix(arm     ARM    "ARM")
_expect_suffix(""      RISC_V "unknown arch -> empty")
