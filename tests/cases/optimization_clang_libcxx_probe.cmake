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

# A failed probe must not be silent: the fallback reports, once per configure
# run, that libc++ was not taken and which library is kept. Without it a
# missing libc++ (runtime package installed, development package not) showed
# up only as libstdc++ in the deployed runtime.
# Search from the probe gate on: the GCC helper earlier in the file carries
# the same section marker.
string(SUBSTRING "${_src}" ${_gate_pos} -1 _after_gate)
string(FIND "${_after_gate}" "Clang libc++ not usable" _fallback_pos)
string(FIND "${_after_gate}" "# ---- Universal per-config flags" _flags_pos)
if(_fallback_pos EQUAL -1)
  message(FATAL_ERROR "the libc++ fallback does not report itself")
endif()
if(NOT _flags_pos EQUAL -1 AND _flags_pos LESS _fallback_pos)
  message(FATAL_ERROR
    "the libc++ fallback report is outside the probe branch")
endif()
string(SUBSTRING "${_after_gate}" 0 ${_fallback_pos} _branch)
if(NOT _branch MATCHES "_OPT_LVL_CLANG_LIBCXX_FALLBACK_REPORTED")
  message(FATAL_ERROR
    "the libc++ fallback report is not limited to once per configure run")
endif()
if(NOT _branch MATCHES "-print-file-name=libstdc\\+\\+\\.so")
  message(FATAL_ERROR
    "the libc++ fallback report does not name the library it keeps")
endif()
