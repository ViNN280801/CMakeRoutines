# Regression: CMP0207 policy opt-in in CopyRuntimeDependencies.cmake.
# file(GET_RUNTIME_DEPENDENCIES) under CMake 4.3 normalizes paths before
# matching filters. Opting into NEW removes the mixed-separator dev warning and
# is safe here because the script matches on the dependency filename, not path.

file(READ "${MODULE_ROOT}/deployment/CopyRuntimeDependencies.cmake" _src)

if(NOT _src MATCHES "cmake_policy\\(SET CMP0207 NEW\\)")
  message(FATAL_ERROR "missing cmake_policy(SET CMP0207 NEW)")
endif()
if(NOT _src MATCHES "if\\(POLICY CMP0207\\)")
  message(FATAL_ERROR "missing if(POLICY CMP0207) guard")
endif()
