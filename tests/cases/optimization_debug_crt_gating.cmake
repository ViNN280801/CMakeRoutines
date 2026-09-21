# Regression: debug-CRT flag gating in OptimizationLevelConfig.cmake.
#
# clang-cl ASan forces the release CRT (/MD) in a Debug build. The MSVC routine
# must then skip /RTC1 and /D_DEBUG (debug-CRT-only flags); emitting them makes
# the STL reference _calloc_dbg/_CrtDbgReport, which are absent from /MD and
# fail the link with LNK2019.

file(READ "${MODULE_ROOT}/optimizations/OptimizationLevelConfig.cmake" _src)

if(NOT _src MATCHES "_opt_lvl_debug_crt")
  message(FATAL_ERROR "missing _opt_lvl_debug_crt gating variable")
endif()
if(NOT _src MATCHES "CMAKE_MSVC_RUNTIME_LIBRARY MATCHES \"\\^\\(MultiThreaded\\|MultiThreadedDLL\\)\\$\"")
  message(FATAL_ERROR "missing release-CRT detection")
endif()
if(NOT _src MATCHES "if\\(_opt_lvl_debug_crt\\)")
  message(FATAL_ERROR "missing conditional debug-CRT block")
endif()

# /RTC1 and /D_DEBUG must live after the debug-CRT branch opens (i.e. inside the
# conditional block), not only in the unconditional Debug flag list. CMake's
# regex has no non-greedy or \s support, so locate the branch by position.
string(FIND "${_src}" "if(_opt_lvl_debug_crt)" _branch_pos)
if(_branch_pos EQUAL -1)
  message(FATAL_ERROR "missing if(_opt_lvl_debug_crt) branch")
endif()
string(SUBSTRING "${_src}" ${_branch_pos} -1 _tail)
if(NOT _tail MATCHES "/RTC1")
  message(FATAL_ERROR "debug-CRT branch does not emit /RTC1")
endif()
if(NOT _tail MATCHES "/D_DEBUG")
  message(FATAL_ERROR "debug-CRT branch does not emit /D_DEBUG")
endif()
