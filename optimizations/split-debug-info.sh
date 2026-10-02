#!/bin/sh
# =============================================================================
# split-debug-info.sh
# Moves the DWARF of a freshly linked ELF binary into <output>.debug
# =============================================================================
#
# Set by configure_optimization_level (OptimizationLevelConfig.cmake) as the
# target's C/CXX_LINKER_LAUNCHER, so the link command follows the four
# arguments; run as a POST_BUILD command (CMake < 3.21) it gets none.
#
#   sh split-debug-info.sh <objcopy> <compress 0|1> <release 0|1> <output> \
#       [link command...]
#
# The link command runs first; its failure is returned as is. Unless
# <release> is 1 nothing else happens. In Release:
#
#   objcopy --only-keep-debug [--compress-debug-sections=zlib] <output> <output>.debug
#   objcopy --strip-all --add-gnu-debuglink=<output>.debug <output>
#
# The binary ends up stripped as -Wl,--strip-all would leave it (.dynsym
# stays), plus a .gnu_debuglink naming <output>.debug, which gdb and addr2line
# look for in the binary's directory.
# =============================================================================

if [ "$#" -lt 4 ]; then
    echo "split-debug-info.sh: usage: <objcopy> <compress 0|1> <release 0|1> <output> [link command...]" >&2
    exit 2
fi

objcopy=$1
compress=$2
release=$3
output=$4
shift 4

if [ "$#" -gt 0 ]; then
    "$@" || exit $?
fi

[ "$release" = "1" ] || exit 0

if [ "$compress" = "1" ]; then
    set -- --compress-debug-sections=zlib
else
    set --
fi

if ! "$objcopy" --only-keep-debug "$@" "$output" "$output.debug"; then
    echo "split-debug-info.sh: objcopy could not copy the debug info of $output into $output.debug" >&2
    exit 1
fi

if ! "$objcopy" --strip-all --add-gnu-debuglink="$output.debug" "$output"; then
    echo "split-debug-info.sh: objcopy could not strip $output or link it to $output.debug" >&2
    exit 1
fi
