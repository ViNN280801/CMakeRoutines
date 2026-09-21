# FATAL_ERROR validation branches for CompilerFlags / LinkerFlags.
# Each body is a mini-project that is expected to fail configure.

set(_vf_body "
cmake_minimum_required(VERSION 3.16)
project(VF LANGUAGES CXX)
include(\"${_module_root}/core/CompilerFlags.cmake\")
add_library(vf STATIC dummy.cpp)
configure_compiler_flags(vf USE_DEFAULT_FLAGS OFF)
")
expect_configure_fail(compiler_flags_no_custom "${_vf_body}"
  "USE_DEFAULT_FLAGS is OFF but CUSTOM_FLAGS is not specified")

set(_vf_body "
cmake_minimum_required(VERSION 3.16)
project(VF LANGUAGES CXX)
include(\"${_module_root}/core/LinkerFlags.cmake\")
add_library(vf STATIC dummy.cpp)
configure_linker_flags(vf USE_DEFAULT_FLAGS OFF)
")
expect_configure_fail(linker_flags_no_custom "${_vf_body}"
  "USE_DEFAULT_FLAGS is OFF but CUSTOM_FLAGS is not specified")

# apply_library_versioning with < 3-part version -> FATAL
set(_vf_body "
cmake_minimum_required(VERSION 3.16)
project(VF LANGUAGES CXX)
include(\"${_module_root}/utils/LibraryVersioning.cmake\")
add_library(vf STATIC dummy.cpp)
apply_library_versioning(vf PROJECT_VERSION 1.2)
")
expect_configure_fail(library_versioning_short_version "${_vf_body}"
  "major.minor.patch")

# configure_install_rules on a missing target -> FATAL
set(_vf_body "
cmake_minimum_required(VERSION 3.16)
project(VF LANGUAGES CXX)
include(\"${_module_root}/deployment/InstallConfig.cmake\")
configure_install_rules(no_such_target)
")
expect_configure_fail(install_rules_no_target "${_vf_body}" "does not exist")
