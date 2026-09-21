# Module coverage: sanitizer_profile_validate rejects an unknown profile.

include("${MODULE_ROOT}/testing/SanitizerProfile.cmake")

sanitizer_profile_validate("BOGUS" ASAN_UBSAN TSAN CFI NONE)
