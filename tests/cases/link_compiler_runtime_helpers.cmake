# Branch coverage for deployment/LinkCompilerRuntime.cmake (pure helper)
include("${MODULE_ROOT}/deployment/LinkCompilerRuntime.cmake")

# No -stdlib flag -> empty
set(CMAKE_CXX_FLAGS "")
set(CMAKE_EXE_LINKER_FLAGS "")
set(CMAKE_SHARED_LINKER_FLAGS "")
set(CMAKE_MODULE_LINKER_FLAGS "")
set(ENV{CXXFLAGS} "")
_lcr_detect_stdlib_flag(_r)
if(_r)
  message(FATAL_ERROR "expected empty stdlib, got '${_r}'")
endif()

# -stdlib=libc++ in CMAKE_CXX_FLAGS
set(CMAKE_CXX_FLAGS "-stdlib=libc++")
_lcr_detect_stdlib_flag(_r)
if(NOT _r STREQUAL "libc++")
  message(FATAL_ERROR "expected libc++ from CXX_FLAGS, got '${_r}'")
endif()

# -stdlib=libstdc++ in CMAKE_EXE_LINKER_FLAGS
set(CMAKE_CXX_FLAGS "")
set(CMAKE_EXE_LINKER_FLAGS "-stdlib=libstdc++")
_lcr_detect_stdlib_flag(_r)
if(NOT _r STREQUAL "libstdc++")
  message(FATAL_ERROR "expected libstdc++ from EXE_LINKER_FLAGS, got '${_r}'")
endif()

# -stdlib in CMAKE_SHARED_LINKER_FLAGS
set(CMAKE_EXE_LINKER_FLAGS "")
set(CMAKE_SHARED_LINKER_FLAGS "-stdlib=libc++")
_lcr_detect_stdlib_flag(_r)
if(NOT _r STREQUAL "libc++")
  message(FATAL_ERROR "expected libc++ from SHARED_LINKER_FLAGS, got '${_r}'")
endif()

# -stdlib in ENV{CXXFLAGS}
set(CMAKE_SHARED_LINKER_FLAGS "")
set(ENV{CXXFLAGS} "-stdlib=libc++")
_lcr_detect_stdlib_flag(_r)
if(NOT _r STREQUAL "libc++")
  message(FATAL_ERROR "expected libc++ from CXXFLAGS env, got '${_r}'")
endif()

# A second argument that is not a target (script mode has none) falls back to
# the global flags; the target-level lookup is covered by
# tests/target/cases/optimization_cxx_stdlib.cmake.
_lcr_detect_stdlib_flag(_r no_such_target)
if(NOT _r STREQUAL "libc++")
  message(FATAL_ERROR "expected libc++ from CXXFLAGS env with a non-target, got '${_r}'")
endif()
set(ENV{CXXFLAGS} "")
_lcr_detect_stdlib_flag(_r no_such_target)
if(_r)
  message(FATAL_ERROR "expected empty stdlib with a non-target, got '${_r}'")
endif()
