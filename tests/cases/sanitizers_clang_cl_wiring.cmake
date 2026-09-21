# Regression: clang-cl sanitizer wiring in SanitizersConfig.cmake.
#
# clang-cl on Windows is linked through link.exe, which ignores driver-only
# -fsanitize=... options. The routine must link the clang_rt.* libraries
# explicitly (/LIBPATH + .lib files) and must expose DLL staging for the dynamic
# ASan runtime. These source assertions pin that behaviour so it cannot regress.

file(READ "${MODULE_ROOT}/testing/SanitizersConfig.cmake" _src)

# Explicit ASan runtime libraries (dynamic runtime + thunk).
if(NOT _src MATCHES "clang_rt\\.asan_dynamic_runtime_thunk-\\$\\{_arch_suffix\\}\\.lib")
  message(FATAL_ERROR "missing clang_rt.asan_dynamic_runtime_thunk lib")
endif()
if(NOT _src MATCHES "clang_rt\\.asan_dynamic-\\$\\{_arch_suffix\\}\\.lib")
  message(FATAL_ERROR "missing clang_rt.asan_dynamic lib")
endif()

# Explicit UBSan standalone runtime libraries.
if(NOT _src MATCHES "clang_rt\\.ubsan_standalone-\\$\\{_arch_suffix\\}\\.lib")
  message(FATAL_ERROR "missing clang_rt.ubsan_standalone lib")
endif()
if(NOT _src MATCHES "clang_rt\\.ubsan_standalone_cxx-\\$\\{_arch_suffix\\}\\.lib")
  message(FATAL_ERROR "missing clang_rt.ubsan_standalone_cxx lib")
endif()

# The runtime directory must be passed to the linker via /LIBPATH.
if(NOT _src MATCHES "/LIBPATH:\\$\\{_runtime_lib_dir\\}")
  message(FATAL_ERROR "missing /LIBPATH:${_runtime_lib_dir} link option")
endif()

# DLL staging for the dynamic ASan runtime.
if(NOT _src MATCHES "function\\(stage_clang_sanitizer_runtime")
  message(FATAL_ERROR "missing stage_clang_sanitizer_runtime function")
endif()
if(NOT _src MATCHES "clang_rt\\.asan_dynamic-\\$\\{_arch_suffix\\}\\.dll")
  message(FATAL_ERROR "missing clang_rt.asan_dynamic DLL reference")
endif()
if(NOT _src MATCHES "copy_if_different")
  message(FATAL_ERROR "missing copy_if_different for DLL staging")
endif()

# The clang-cl branch must NOT append -fsanitize to the linker flags (that is
# the driver-only flag link.exe ignores).
if(_src MATCHES "target_link_options\\(\\$\\{target\\} PRIVATE \\$\\{clangLinkFlags\\}\\)" AND
   NOT _src MATCHES "_isClangCl")
  message(FATAL_ERROR "clang link path is missing the clang-cl guard")
endif()
