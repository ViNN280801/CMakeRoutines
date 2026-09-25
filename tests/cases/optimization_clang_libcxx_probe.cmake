# Regression: libc++ detection in OptimizationLevelConfig.cmake.
#
# Clang accepts -stdlib=libc++ even where libc++ is not installed, so a plain
# check_cxx_compiler_flag passed on a stock Ubuntu (libstdc++ only) and every
# target then failed with "'cmath' file not found". The routine must compile
# and link a program that includes a standard header before it switches to
# libc++.

file(READ "${MODULE_ROOT}/optimizations/OptimizationLevelConfig.cmake" _src)

if(_src MATCHES "check_cxx_compiler_flag\\(\"-stdlib=libc\\+\\+\"")
  message(FATAL_ERROR
    "libc++ is still detected with a flag check only")
endif()
if(NOT _src MATCHES "include\\(CheckCXXSourceCompiles\\)")
  message(FATAL_ERROR "missing include(CheckCXXSourceCompiles)")
endif()

string(FIND "${_src}" "check_cxx_source_compiles(" _probe_pos)
if(_probe_pos EQUAL -1)
  message(FATAL_ERROR "missing check_cxx_source_compiles libc++ probe")
endif()
string(SUBSTRING "${_src}" ${_probe_pos} 400 _probe)
if(NOT _probe MATCHES "#include <")
  message(FATAL_ERROR "libc++ probe does not include a standard header")
endif()
if(NOT _probe MATCHES "_opt_lvl_clang_libcxx_usable")
  message(FATAL_ERROR "libc++ probe result variable renamed or missing")
endif()

# The probe must compile and link with the flag.
string(SUBSTRING "${_src}" 0 ${_probe_pos} _head)
if(NOT _head MATCHES "CMAKE_REQUIRED_FLAGS \"-stdlib=libc\\+\\+\"")
  message(FATAL_ERROR "libc++ probe does not compile with -stdlib=libc++")
endif()
if(NOT _head MATCHES "CMAKE_REQUIRED_LINK_OPTIONS \"-stdlib=libc\\+\\+\"")
  message(FATAL_ERROR "libc++ probe does not link with -stdlib=libc++")
endif()

# -stdlib=libc++ lands on the target only behind the probe result.
string(FIND "${_src}" "if(_opt_lvl_clang_libcxx_usable)" _gate_pos)
string(FIND "${_src}" "target_compile_options(\${target} PRIVATE -stdlib=libc++)"
  _flag_pos)
if(_gate_pos EQUAL -1 OR _flag_pos EQUAL -1 OR _flag_pos LESS _gate_pos)
  message(FATAL_ERROR "-stdlib=libc++ is not gated by the probe result")
endif()
