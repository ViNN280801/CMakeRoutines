# Branch coverage for optimizations/PrecompiledHeadersConfig.cmake
include("${_module_root}/optimizations/PrecompiledHeadersConfig.cmake")

# HEADERS -> PRECOMPILE_HEADERS
new_test_target(t)
configure_precompiled_headers(${t} HEADERS stdafx.h)
get_target_property(_pch ${t} PRECOMPILE_HEADERS)
if(NOT "${_pch}" MATCHES "stdafx.h")
  message(FATAL_ERROR "PCH should contain stdafx.h: ${_pch}")
endif()

# STANDARD_HEADERS -> PRECOMPILE_HEADERS
new_test_target(t)
configure_precompiled_headers(${t} STANDARD_HEADERS "<vector>")
get_target_property(_pch ${t} PRECOMPILE_HEADERS)
if(NOT "${_pch}" MATCHES "vector")
  message(FATAL_ERROR "PCH should contain <vector>: ${_pch}")
endif()

# REUSE_FROM -> link to the other target
new_test_target(base)
configure_precompiled_headers(${base} HEADERS base.h)
new_test_target(t)
configure_precompiled_headers(${t} REUSE_FROM ${base})
get_target_property(_libs ${t} LINK_LIBRARIES)
if(NOT "${_libs}" MATCHES "${base}")
  message(FATAL_ERROR "REUSE_FROM should link ${base}: ${_libs}")
endif()
