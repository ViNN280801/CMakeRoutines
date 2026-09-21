# Branch coverage for optimizations/UnityBuildConfig.cmake
include("${_module_root}/optimizations/UnityBuildConfig.cmake")

# ENABLE default (ON) -> UNITY_BUILD ON
new_test_target(t)
configure_unity_build(${t})
expect_target_property(${t} UNITY_BUILD ON)

# BATCH_SIZE + MODE
new_test_target(t)
configure_unity_build(${t} BATCH_SIZE 16 MODE GROUP)
expect_target_property(${t} UNITY_BUILD_BATCH_SIZE 16)
expect_target_property(${t} UNITY_BUILD_MODE GROUP)

# ENABLE OFF -> UNITY_BUILD OFF
new_test_target(t)
configure_unity_build(${t} ENABLE OFF)
expect_target_property(${t} UNITY_BUILD OFF)
