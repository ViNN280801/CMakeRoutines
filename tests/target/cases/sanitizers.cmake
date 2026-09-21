# Branch coverage for testing/SanitizersConfig.cmake (clang-cl frame pointer)
include("${_module_root}/testing/SanitizersConfig.cmake")

# clang-cl: frame pointer via /Oy- (the GNU -fno-omit-frame-pointer is ignored
# by clang-cl and emits -Wunknown-argument).
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "Clang" "Clang")
_configure_clang_sanitizers(${t} ON OFF OFF ON OFF OFF "" "" "")
expect_compile_option(${t} "/Oy-")
expect_no_compile_option(${t} "-fno-omit-frame-pointer")

# native Clang: frame pointer via -fno-omit-frame-pointer.
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "Clang" "Clang")
_configure_clang_sanitizers(${t} ON OFF OFF ON OFF OFF "" "" "")
expect_compile_option(${t} "-fno-omit-frame-pointer")
expect_no_compile_option(${t} "/Oy-")

# MSVC ASan: /fsanitize=address is COMPILE-only. cl.exe embeds the runtime
# reference into the object, so link.exe picks it up automatically; passing it
# to link.exe only produces LNK4044 ("unrecognized option; ignored").
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
set(CMAKE_CXX_COMPILER_VERSION "19.40")
_configure_msvc_sanitizers(${t} ON OFF "")
expect_compile_option(${t} "/fsanitize=address")
expect_no_link_option(${t} "/fsanitize=address")

# MSVC ASan on an unsupported toolchain (< VS 2019 16.9 / 19.29): no flag.
new_test_target(t)
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")
set(CMAKE_CXX_COMPILER_VERSION "19.20")
_configure_msvc_sanitizers(${t} ON OFF "")
expect_no_compile_option(${t} "/fsanitize=address")
