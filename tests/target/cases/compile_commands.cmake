# Branch coverage for utils/CompileCommandsConfig.cmake
include("${_module_root}/utils/CompileCommandsConfig.cmake")

# ENABLE OFF -> export disabled
configure_compile_commands(ENABLE OFF)
if(CMAKE_EXPORT_COMPILE_COMMANDS)
  message(FATAL_ERROR "ENABLE OFF should set CMAKE_EXPORT_COMPILE_COMMANDS OFF")
endif()

# ENABLE ON -> export enabled (no symlink)
configure_compile_commands(ENABLE ON CREATE_SYMLINK OFF)
if(NOT CMAKE_EXPORT_COMPILE_COMMANDS)
  message(FATAL_ERROR "ENABLE ON should set CMAKE_EXPORT_COMPILE_COMMANDS ON")
endif()
