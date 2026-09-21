# Module coverage: sanitizer_profile_validate accepts allowed profiles.

include("${MODULE_ROOT}/testing/SanitizerProfile.cmake")

sanitizer_profile_validate("ASAN_UBSAN" ASAN_UBSAN TSAN CFI NONE)
sanitizer_profile_validate("TSAN" ASAN_UBSAN TSAN CFI NONE)
sanitizer_profile_validate("CFI" ASAN_UBSAN TSAN CFI NONE)
sanitizer_profile_validate("NONE" ASAN_UBSAN TSAN CFI NONE)
