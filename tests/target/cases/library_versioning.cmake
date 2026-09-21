# Branch coverage for utils/LibraryVersioning.cmake
include("${_module_root}/utils/LibraryVersioning.cmake")

# VERSION / SOVERSION / OUTPUT_NAME
new_test_target(t)
apply_library_versioning(${t} PROJECT_VERSION 1.2.3)
expect_target_property(${t} VERSION "1.2.3")
expect_target_property(${t} SOVERSION "1.2")
expect_target_property(${t} OUTPUT_NAME "${t}")

# INTERFACE library -> skipped (no VERSION)
add_library(_ct_iface INTERFACE)
apply_library_versioning(_ct_iface PROJECT_VERSION 1.2.3)
get_target_property(_v _ct_iface VERSION)
if(_v)
  message(FATAL_ERROR "INTERFACE library should skip versioning, got VERSION='${_v}'")
endif()
