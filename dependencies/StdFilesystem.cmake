cmake_minimum_required(VERSION 3.16)
include_guard(GLOBAL)

#[=======================================================================[.rst:
StdFilesystem
-------------

Provides :command:`link_std_filesystem` - links the library that
``std::filesystem`` needs with the active toolchain, if it needs one.

Before GCC 9 (libstdc++) and LLVM 9 (libc++), ``std::filesystem`` is not in
the shared standard library: libstdc++ keeps it in the static
``libstdc++fs.a``, libc++ in ``libc++fs.a``. A target that uses
``std::filesystem`` still compiles, but it fails to link, and a shared
library links with undefined symbols that break every executable linked
against it. Clang uses whichever standard library it is given, so the answer
depends on the library, not only on the compiler.

The function links a small C++17 program that calls into ``std::filesystem``,
first without an extra library, then with ``stdc++fs``, then with ``c++fs``,
and links the first variant that works to the target. The result is cached
per compiler and flag set. MSVC and current toolchains need nothing and get
nothing.

.. command:: link_std_filesystem

  .. code-block:: cmake

    link_std_filesystem(<target> [PUBLIC|PRIVATE|INTERFACE]
                        [COMPILE_OPTIONS <option>...])

  ``PRIVATE`` (the default) is enough for a shared library, which absorbs
  the static archive; CMake still passes a ``PRIVATE`` library of a static
  library on to its users.

  ``COMPILE_OPTIONS`` are flags the target gets outside ``CMAKE_CXX_FLAGS``
  that change the standard library, such as ``-stdlib=libc++``. The probe
  uses them for both compiling and linking.

  When no variant links (no C++17, or no ``std::filesystem`` at all), the
  function warns and links nothing.

Minimum CMake version: 3.16
#]=======================================================================]

include(CheckCXXSourceCompiles)
include(CMakePushCheckState)

# -----------------------------------------------------------------------------
# _stdfs_find_library(<out_var> <options>)
#
# Sets <out_var> to "" (no extra library), "stdc++fs", "c++fs", or
# "NOTFOUND". <options> is a list of compile-and-link options for the probe.
# The answer is cached for the compiler, CMAKE_CXX_FLAGS and <options>.
# -----------------------------------------------------------------------------
function(_stdfs_find_library out_var options)
  string(MD5 _key
    "${CMAKE_CXX_COMPILER}|${CMAKE_CXX_COMPILER_VERSION}|${CMAKE_CXX_FLAGS}|${options}")
  set(_cache_var "_CMAKE_ROUTINES_STD_FILESYSTEM_${_key}")

  if(NOT DEFINED "${_cache_var}")
    set(_source [=[
#include <filesystem>
#include <system_error>

int
main (int argc, char **argv)
{
  std::filesystem::path const base (argc > 0 ? argv[0] : ".");
  std::error_code error;
  return std::filesystem::exists (base / "probe", error) ? 1 : 0;
}
]=])

    # std::filesystem is C++17; the probe asks for it whatever the caller's
    # default standard is.
    set(CMAKE_CXX_STANDARD 17)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
    set(CMAKE_CXX_EXTENSIONS OFF)

    set(_result "NOTFOUND")
    set(_index 0)
    foreach(_lib IN ITEMS "" "stdc++fs" "c++fs")
      math(EXPR _index "${_index} + 1")
      set(_probe_var "_CMAKE_ROUTINES_STD_FILESYSTEM_PROBE_${_key}_${_index}")
      cmake_push_check_state(RESET)
      set(CMAKE_REQUIRED_QUIET ON)
      string(REPLACE ";" " " CMAKE_REQUIRED_FLAGS "${options}")
      set(CMAKE_REQUIRED_LINK_OPTIONS ${options})
      if(_lib)
        set(CMAKE_REQUIRED_LIBRARIES "${_lib}")
      endif()
      check_cxx_source_compiles("${_source}" "${_probe_var}")
      set(_linked "${${_probe_var}}")
      cmake_pop_check_state()
      # The per-variant results are scratch; only the final answer is kept.
      unset("${_probe_var}" CACHE)
      if(_linked)
        set(_result "${_lib}")
        break()
      endif()
    endforeach()

    if(_result STREQUAL "NOTFOUND")
      message(WARNING
        "StdFilesystem: no variant of a C++17 std::filesystem program links "
        "with ${CMAKE_CXX_COMPILER} (tried no library, stdc++fs, c++fs).")
    elseif(_result)
      message(STATUS
        "StdFilesystem: std::filesystem needs '${_result}' with "
        "${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
    endif()
    set("${_cache_var}" "${_result}" CACHE INTERNAL
      "Library std::filesystem needs (empty: none)")
  endif()

  set(${out_var} "${${_cache_var}}" PARENT_SCOPE)
endfunction()

# =============================================================================
# Public API
# =============================================================================

# -----------------------------------------------------------------------------
# link_std_filesystem(<target> [PUBLIC|PRIVATE|INTERFACE]
#                     [COMPILE_OPTIONS <option>...])
#
# Links the library std::filesystem needs with this toolchain (stdc++fs for
# libstdc++ before GCC 9, c++fs for libc++ before LLVM 9), or nothing.
# -----------------------------------------------------------------------------
function(link_std_filesystem target)
  if(NOT TARGET "${target}")
    message(FATAL_ERROR "Target '${target}' does not exist")
  endif()

  cmake_parse_arguments(PARSE_ARGV 1 _LSF
    "PUBLIC;PRIVATE;INTERFACE" "" "COMPILE_OPTIONS")
  if(_LSF_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR
      "link_std_filesystem: unknown arguments '${_LSF_UNPARSED_ARGUMENTS}'")
  endif()

  set(_scope "")
  foreach(_candidate IN ITEMS PUBLIC PRIVATE INTERFACE)
    if(_LSF_${_candidate})
      if(_scope)
        message(FATAL_ERROR
          "link_std_filesystem: give one of PUBLIC, PRIVATE, INTERFACE")
      endif()
      set(_scope "${_candidate}")
    endif()
  endforeach()
  if(NOT _scope)
    set(_scope PRIVATE)
  endif()

  if(MSVC)
    return()
  endif()

  _stdfs_find_library(_library "${_LSF_COMPILE_OPTIONS}")
  if(_library AND NOT _library STREQUAL "NOTFOUND")
    target_link_libraries("${target}" ${_scope} "${_library}")
  endif()
endfunction()
