# Branch coverage for utils/BuildTiming.cmake
include("${_module_root}/utils/BuildTiming.cmake")

# ENABLE OFF -> no RULE_LAUNCH global property.
configure_build_timing(ENABLE OFF)
get_property(_launch GLOBAL PROPERTY RULE_LAUNCH_COMPILE)
if(_launch)
  message(FATAL_ERROR "ENABLE OFF should not set RULE_LAUNCH_COMPILE, got '${_launch}'")
endif()

# ENABLE ON -> RULE_LAUNCH_COMPILE and RULE_LAUNCH_LINK set.
configure_build_timing(ENABLE ON)
get_property(_launch GLOBAL PROPERTY RULE_LAUNCH_COMPILE)
if(NOT _launch)
  message(FATAL_ERROR "ENABLE ON should set RULE_LAUNCH_COMPILE")
endif()
get_property(_launch_link GLOBAL PROPERTY RULE_LAUNCH_LINK)
if(NOT _launch_link)
  message(FATAL_ERROR "ENABLE ON should set RULE_LAUNCH_LINK")
endif()
