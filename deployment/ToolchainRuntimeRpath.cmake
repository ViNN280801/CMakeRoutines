cmake_minimum_required(VERSION 3.16)
include_guard(GLOBAL)

#[=======================================================================[.rst:
ToolchainRuntimeRpath
---------------------

Provides :command:`configure_toolchain_runtime_rpath` and
:command:`get_toolchain_runtime_directories`: they let the binaries of a
**build tree** find the C++ runtime of the compiler that built them when that
runtime is not in the system library directories.

A GCC installed under ``/opt`` or ``/usr/local``, or a Clang built from source,
brings its own ``libstdc++.so.6`` / ``libgcc_s.so.1`` (GCC) or ``libc++.so.1`` /
``libc++abi.so.1`` / ``libunwind.so.1`` (Clang with ``-stdlib=libc++``). The
linker finds them at link time, but the program does not: the dynamic loader
looks only in the system directories, and loads an older ``libstdc++`` or
``libc++`` there. The program then stops at start-up (``GLIBCXX_3.4.32 not
found``) or at its first call of a newer symbol (``undefined symbol:
std::__1::__hash_memory``). CMake does not help: the directories the compiler
searches anyway (``CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES``) are never put into a
build RPATH.

The runtime directories are asked from the compiler itself, with
``-print-file-name=<soname>`` and the flags of ``CMAKE_CXX_FLAGS`` (so a
``--gcc-toolchain=`` or ``--gcc-install-dir=`` of a Clang is honored), and
only those outside the system directories are used. The system directories
are ``/lib``, ``/lib32``, ``/lib64``, ``/libx32``, ``/usr/lib``, ``/usr/lib32``,
``/usr/lib64`` and ``/usr/libx32`` with everything below them (multiarch
directories, ``/usr/lib/gcc/<triplet>/<N>``, ``/usr/lib/llvm-<N>/lib``);
``/usr/local`` is not one of them. A distribution compiler therefore adds
nothing. The test is on the path, not on the loader's configuration: a runtime
that lies below these directories but that the loader does not search (the
``/usr/lib/gcc-astra/lib64`` of Astra Linux) gets no RUNPATH either.

The directories go into the ``BUILD_RPATH`` target property, which CMake keeps
out of the installed binary: ``cmake --install`` replaces the whole RPATH with
the ``INSTALL_RPATH`` of the target, which this module never touches. Nothing
is done for MSVC, on Windows (also MinGW), Cygwin and Apple (no ELF RUNPATH
there), when cross-compiling (the runtime of the target is not the host's),
and for compilers other than GCC and Clang. ``CMAKE_SKIP_BUILD_RPATH`` ON
switches the property off in CMake itself.

A project does not have to call :command:`configure_toolchain_runtime_rpath`
for each target: ``configure_optimization_level(<target>
TOOLCHAIN_RUNTIME_RPATH ON)`` (``optimizations/OptimizationLevelConfig.cmake``)
makes it the last step of that call, for that target. The parameter is off by
default. Both ways can be mixed on one target: a directory already in
``BUILD_RPATH`` is not added again.

.. command:: configure_toolchain_runtime_rpath

  .. code-block:: cmake

    configure_toolchain_runtime_rpath(<target> [STDLIB <libstdc++|libc++>...])

  Appends the runtime directories of the compiler to ``BUILD_RPATH`` of an
  executable, shared or module library (other target types, imported and
  alias targets are left alone; a directory already listed is not added
  again). A static library is not linked, so it has no RPATH; its users call
  this function themselves.

  ``STDLIB`` names the C++ standard library to find (a list is allowed).
  Without it the library is detected like :command:`link_compiler_runtime`
  does: the ``-stdlib=`` option of the target itself, then of the targets it
  links directly (a library built with ``-stdlib=libc++`` hands the flag to
  its users), then the global flags, and ``libstdc++`` when there is none.
  GCC always uses ``libstdc++``.

.. command:: get_toolchain_runtime_directories

  .. code-block:: cmake

    get_toolchain_runtime_directories(<out_var> [STDLIB <libstdc++|libc++>...])

  Sets ``<out_var>`` to the list of the real directories that hold the
  runtime of the compiler outside the system directories, empty when there
  are none or the platform is not covered. ``STDLIB`` as above, detected from
  the global flags when omitted. The answer is computed once per compiler,
  flag set and library and kept for the rest of the configure run. Use it to
  hand the directories to a project that is configured separately
  (``-DCMAKE_BUILD_RPATH=<dirs>``).

Minimum CMake version: 3.16
#]=======================================================================]

include("${CMAKE_CURRENT_LIST_DIR}/LinkCompilerRuntime.cmake")

# -----------------------------------------------------------------------------
# _trp_applicable(<out_var>)
#
# TRUE when the build can carry an ELF RUNPATH to the toolchain's runtime:
# a native build on an ELF host (not MSVC, Windows, Cygwin, Apple) with a
# GCC or Clang C++ compiler.
# -----------------------------------------------------------------------------
function(_trp_applicable out_var)
  set(_trp_ok FALSE)
  if(UNIX AND NOT APPLE AND NOT WIN32 AND NOT CYGWIN AND NOT MSVC
     AND NOT CMAKE_CROSSCOMPILING
     AND CMAKE_CXX_COMPILER
     AND CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang)$")
    set(_trp_ok TRUE)
  endif()
  set(${out_var} ${_trp_ok} PARENT_SCOPE)
endfunction()

# -----------------------------------------------------------------------------
# _trp_is_system_directory(<dir> <out_var>)
#
# TRUE when the real path of <dir> is one of the distribution's library
# directories or below one (see the module description).
# -----------------------------------------------------------------------------
function(_trp_is_system_directory dir out_var)
  get_filename_component(_trp_real "${dir}" REALPATH)
  if(_trp_real MATCHES "^(/usr)?/lib(32|64|x32)?(/|$)")
    set(${out_var} TRUE PARENT_SCOPE)
  else()
    set(${out_var} FALSE PARENT_SCOPE)
  endif()
endfunction()

# -----------------------------------------------------------------------------
# _trp_probe_directory(<soname> <out_var> [<compiler flag>...])
#
# Asks the C++ compiler where <soname> is. Sets <out_var> to the real
# directory of that file, or to the empty string when the compiler does not
# know the name (it then echoes the bare name) or the file is missing.
# -----------------------------------------------------------------------------
function(_trp_probe_directory soname out_var)
  set(_trp_launcher "")
  if(CMAKE_CXX_COMPILER_ARG1)
    separate_arguments(_trp_launcher UNIX_COMMAND "${CMAKE_CXX_COMPILER_ARG1}")
  endif()
  execute_process(
    COMMAND "${CMAKE_CXX_COMPILER}" ${_trp_launcher} ${ARGN}
            "-print-file-name=${soname}"
    OUTPUT_VARIABLE _trp_path
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE _trp_rc
    ERROR_QUIET
  )
  if(_trp_rc EQUAL 0 AND _trp_path AND NOT _trp_path STREQUAL "${soname}"
     AND EXISTS "${_trp_path}")
    get_filename_component(_trp_dir "${_trp_path}" DIRECTORY)
    get_filename_component(_trp_dir "${_trp_dir}" REALPATH)
    set(${out_var} "${_trp_dir}" PARENT_SCOPE)
  else()
    set(${out_var} "" PARENT_SCOPE)
  endif()
endfunction()

# -----------------------------------------------------------------------------
# _trp_default_stdlib(<out_var> [<target>])
#
# The C++ standard library a program is built with when the caller names none:
# libstdc++ for GCC; for Clang the -stdlib= option of <target> (its own, or
# one a library it links hands to its users) or of the global flags, as
# link_compiler_runtime sees it, where libc++ is libc++ and anything else, or
# no option, is the compiler's default libstdc++.
# -----------------------------------------------------------------------------
function(_trp_default_stdlib out_var)
  set(_trp_name "")
  if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    _lcr_detect_stdlib_flag(_trp_name ${ARGN})
  endif()
  if("${_trp_name}" STREQUAL "libc++")
    set(${out_var} "libc++" PARENT_SCOPE)
  else()
    set(${out_var} "libstdc++" PARENT_SCOPE)
  endif()
endfunction()

# -----------------------------------------------------------------------------
# _trp_find_directories(<stdlib> <out_var>)
#
# Runtime directories of the compiler for one standard library, outside the
# system directories, one per library that lives there (_trp_collect removes
# the repeats); cached for the rest of the configure run per compiler, flags
# and library. GCC has no libc++: the answer for it is empty.
# -----------------------------------------------------------------------------
function(_trp_find_directories stdlib out_var)
  string(MD5 _trp_key
    "${CMAKE_CXX_COMPILER}|${CMAKE_CXX_COMPILER_ID}|${CMAKE_CXX_COMPILER_ARG1}|${CMAKE_CXX_FLAGS}|${stdlib}")
  set(_trp_property "_TRP_DIRECTORIES_${_trp_key}")
  get_property(_trp_known GLOBAL PROPERTY "${_trp_property}" SET)
  if(_trp_known)
    get_property(_trp_cached GLOBAL PROPERTY "${_trp_property}")
    set(${out_var} "${_trp_cached}" PARENT_SCOPE)
    return()
  endif()

  set(_trp_found "")
  if(stdlib STREQUAL "libc++")
    # What a program linked with -stdlib=libc++ needs at run time: the three
    # libraries of LLVM's runtime and the GCC support library the driver adds.
    set(_trp_sonames libc++.so.1 libc++abi.so.1 libunwind.so.1 libgcc_s.so.1)
  else()
    set(_trp_sonames libstdc++.so.6 libgcc_s.so.1)
  endif()

  if(NOT (stdlib STREQUAL "libc++" AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU"))
    separate_arguments(_trp_flags UNIX_COMMAND "${CMAKE_CXX_FLAGS}")
    foreach(_trp_soname IN LISTS _trp_sonames)
      _trp_probe_directory("${_trp_soname}" _trp_dir ${_trp_flags})
      if(_trp_dir)
        _trp_is_system_directory("${_trp_dir}" _trp_system)
        if(NOT _trp_system)
          list(APPEND _trp_found "${_trp_dir}")
        endif()
      endif()
    endforeach()
  endif()

  set_property(GLOBAL PROPERTY "${_trp_property}" "${_trp_found}")
  set(${out_var} "${_trp_found}" PARENT_SCOPE)
endfunction()

# -----------------------------------------------------------------------------
# _trp_collect(<out_var> <stdlib>...)
#
# Union, in order, of the directories of every named library; "" for a
# platform the module does not cover. An empty <stdlib> list means the one
# the global flags select. Validates the names.
# -----------------------------------------------------------------------------
function(_trp_collect out_var)
  # The names are checked on every platform, so a typo fails the same way
  # everywhere.
  set(_trp_libs "")
  foreach(_trp_name IN LISTS ARGN)
    string(TOLOWER "${_trp_name}" _trp_lower)
    if(NOT _trp_lower MATCHES "^(libstdc\\+\\+|libc\\+\\+)$")
      message(FATAL_ERROR
        "ToolchainRuntimeRpath: STDLIB must be libstdc++ or libc++ "
        "(got '${_trp_name}')")
    endif()
    list(APPEND _trp_libs "${_trp_lower}")
  endforeach()

  set(_trp_all "")
  _trp_applicable(_trp_ok)
  if(_trp_ok)
    if(NOT _trp_libs)
      _trp_default_stdlib(_trp_libs)
    endif()
    foreach(_trp_lib IN LISTS _trp_libs)
      _trp_find_directories("${_trp_lib}" _trp_dirs)
      list(APPEND _trp_all ${_trp_dirs})
    endforeach()
    list(REMOVE_DUPLICATES _trp_all)
  endif()
  set(${out_var} "${_trp_all}" PARENT_SCOPE)
endfunction()

# =============================================================================
# Public API
# =============================================================================

function(get_toolchain_runtime_directories out_var)
  cmake_parse_arguments(_TRP "" "" "STDLIB" ${ARGN})
  if(_TRP_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR
      "get_toolchain_runtime_directories: unknown argument(s) "
      "'${_TRP_UNPARSED_ARGUMENTS}'")
  endif()
  _trp_collect(_trp_dirs ${_TRP_STDLIB})
  set(${out_var} "${_trp_dirs}" PARENT_SCOPE)
endfunction()

function(configure_toolchain_runtime_rpath target)
  cmake_parse_arguments(_TRP "" "" "STDLIB" ${ARGN})
  if(_TRP_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR
      "configure_toolchain_runtime_rpath: unknown argument(s) "
      "'${_TRP_UNPARSED_ARGUMENTS}'")
  endif()
  if(NOT TARGET "${target}")
    message(FATAL_ERROR
      "configure_toolchain_runtime_rpath: '${target}' is not a known CMake target")
  endif()

  get_target_property(_trp_alias "${target}" ALIASED_TARGET)
  get_target_property(_trp_imported "${target}" IMPORTED)
  get_target_property(_trp_type "${target}" TYPE)
  if(_trp_alias OR _trp_imported
     OR NOT _trp_type MATCHES "^(EXECUTABLE|SHARED_LIBRARY|MODULE_LIBRARY)$")
    return()
  endif()

  # Without STDLIB the library is the one this target is built with: its own
  # -stdlib= option, or one a library it links hands to its users.
  set(_trp_libs ${_TRP_STDLIB})
  if(NOT _trp_libs)
    _trp_applicable(_trp_ok)
    if(NOT _trp_ok)
      return()
    endif()
    _trp_default_stdlib(_trp_libs "${target}")
  endif()

  _trp_collect(_trp_dirs ${_trp_libs})
  if(NOT _trp_dirs)
    return()
  endif()

  get_target_property(_trp_present "${target}" BUILD_RPATH)
  set(_trp_new "")
  foreach(_trp_dir IN LISTS _trp_dirs)
    if(NOT _trp_present OR NOT "${_trp_dir}" IN_LIST _trp_present)
      list(APPEND _trp_new "${_trp_dir}")
    endif()
  endforeach()
  if(_trp_new)
    set_property(TARGET "${target}" APPEND PROPERTY BUILD_RPATH ${_trp_new})
  endif()
endfunction()
