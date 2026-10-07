# get_toolchain_runtime_directories rejects a library name it does not know,
# on every platform (here a host that gets no RPATH at all).
include("${MODULE_ROOT}/deployment/ToolchainRuntimeRpath.cmake")

set(MSVC TRUE)
get_toolchain_runtime_directories(_dirs STDLIB libstdcxx)
