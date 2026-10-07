# Branch coverage for deployment/ToolchainRuntimeRpath.cmake: which directories
# the runtime of a toolchain is found in, and which of them count as system.
# The compiler is a fake /bin/sh script that answers -print-file-name=<name>
# from a map and logs its arguments, so the case needs no toolchain outside
# the system paths and runs the same everywhere. POSIX hosts only.
if(CMAKE_HOST_WIN32 OR NOT EXISTS "/bin/sh")
  message(STATUS "toolchain_runtime_rpath_helpers: skipped (no /bin/sh)")
  return()
endif()

include("${MODULE_ROOT}/deployment/ToolchainRuntimeRpath.cmake")

set(_trp_root "${CMAKE_ROUTINES_TEST_TMP}/cmake_routines_toolchain_runtime_rpath")
file(REMOVE_RECURSE "${_trp_root}")

# A fake tree: GCC 13 under opt/gcc, LLVM under opt/llvm, and a symbolic link
# to the GCC directory.
set(_trp_gcc_lib "${_trp_root}/opt/gcc-13.2.0/lib64")
set(_trp_llvm_lib "${_trp_root}/opt/llvm-23.1.0/lib/x86_64-unknown-linux-gnu")
file(MAKE_DIRECTORY "${_trp_gcc_lib}" "${_trp_llvm_lib}")
foreach(_name libstdc++.so.6 libgcc_s.so.1)
  file(WRITE "${_trp_gcc_lib}/${_name}" "")
endforeach()
foreach(_name libc++.so.1 libc++abi.so.1 libunwind.so.1)
  file(WRITE "${_trp_llvm_lib}/${_name}" "")
endforeach()
file(CREATE_LINK "${_trp_gcc_lib}" "${_trp_root}/link-to-gcc" SYMBOLIC)

# Any existing file in a real system library directory (libc is everywhere on
# glibc); the answer "this library lives in /usr/lib" without writing there.
file(GLOB _trp_system_libs
  "/lib/*/libc.so.6" "/usr/lib/*/libc.so.6" "/lib64/libc.so.6" "/usr/lib64/libc.so.6"
  "/usr/lib/libc.so.6" "/lib/libc.so.6")
if(_trp_system_libs)
  list(GET _trp_system_libs 0 _trp_system_file)
else()
  set(_trp_system_file "")
endif()

# The fake compiler. <script>.map has "<name> <path>" lines, <script>.log gets
# the arguments of every call.
set(_trp_cxx "${_trp_root}/fake-cxx")
file(WRITE "${_trp_cxx}" [=[#!/bin/sh
self="$0"
echo "$*" >> "$self.log"
for arg in "$@"; do
  case "$arg" in
    -print-file-name=*)
      name="${arg#-print-file-name=}"
      while read -r key value; do
        if [ "$key" = "$name" ]; then echo "$value"; exit 0; fi
      done < "$self.map"
      echo "$name"
      exit 0 ;;
  esac
done
exit 1
]=])
execute_process(COMMAND chmod 755 "${_trp_cxx}" RESULT_VARIABLE _trp_rc)
if(NOT _trp_rc EQUAL 0)
  message(FATAL_ERROR "cannot make '${_trp_cxx}' executable")
endif()

# map(<name>=<path>...): what the fake compiler knows.
function(_trp_set_map)
  set(_text "")
  foreach(_pair IN LISTS ARGN)
    string(REGEX REPLACE "=" " " _line "${_pair}")
    string(APPEND _text "${_line}\n")
  endforeach()
  file(WRITE "${_trp_cxx}.map" "${_text}")
endfunction()

function(_trp_log_lines out_var)
  if(EXISTS "${_trp_cxx}.log")
    file(STRINGS "${_trp_cxx}.log" _lines)
    list(LENGTH _lines _count)
  else()
    set(_count 0)
  endif()
  set(${out_var} "${_count}" PARENT_SCOPE)
endfunction()

function(_trp_expect_list what actual)
  set(_expected "${ARGN}")
  if(NOT "${actual}" STREQUAL "${_expected}")
    message(FATAL_ERROR "${what}: expected '${_expected}', got '${actual}'")
  endif()
endfunction()

# What GCC 13 under /opt answers: -print-file-name gives a path with `..`.
_trp_set_map(
  "libstdc++.so.6=${_trp_gcc_lib}/../lib64/libstdc++.so.6"
  "libgcc_s.so.1=${_trp_gcc_lib}/libgcc_s.so.1"
  "libc++.so.1=${_trp_llvm_lib}/libc++.so.1"
  "libc++abi.so.1=${_trp_llvm_lib}/libc++abi.so.1"
  "libunwind.so.1=${_trp_llvm_lib}/libunwind.so.1")

# --- _trp_is_system_directory ------------------------------------------------
foreach(_dir /lib /lib32 /lib64 /libx32 /usr/lib /usr/lib32 /usr/lib64
             /usr/libx32 /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu
             /usr/lib/llvm-19/lib /usr/lib/gcc/x86_64-linux-gnu/8)
  _trp_is_system_directory("${_dir}" _system)
  if(NOT _system)
    message(FATAL_ERROR "'${_dir}' must be a system directory")
  endif()
endforeach()
foreach(_dir /usr/local/lib /usr/local/lib64 /opt/gcc-13.2.0/lib64
             /opt/llvm-23.1.0/lib/x86_64-unknown-linux-gnu /usr /usr/libexec
             /usr/libexec/gcc /home/user/usr/lib /library /opt/lib
             "${_trp_gcc_lib}")
  _trp_is_system_directory("${_dir}" _system)
  if(_system)
    message(FATAL_ERROR "'${_dir}' must not be a system directory")
  endif()
endforeach()

# --- GCC outside the system paths ---------------------------------------------
set(CMAKE_CXX_COMPILER "${_trp_cxx}")
set(CMAKE_CXX_COMPILER_ARG1 "")
set(CMAKE_CXX_COMPILER_ID "GNU")
set(CMAKE_CXX_FLAGS "")
set(CMAKE_CROSSCOMPILING FALSE)
set(UNIX TRUE)
set(WIN32 FALSE)
set(APPLE FALSE)
set(CYGWIN FALSE)
set(MSVC FALSE)
set(ENV{CXXFLAGS} "")
set(CMAKE_EXE_LINKER_FLAGS "")
set(CMAKE_SHARED_LINKER_FLAGS "")
set(CMAKE_MODULE_LINKER_FLAGS "")

# libstdc++ and libgcc_s share a directory: one entry, as a real path (the
# `..` is gone).
get_toolchain_runtime_directories(_dirs)
_trp_expect_list("GCC outside the system paths" "${_dirs}" "${_trp_gcc_lib}")

# GCC has no libc++, whatever a flag says.
get_toolchain_runtime_directories(_dirs STDLIB libc++)
_trp_expect_list("GCC and STDLIB libc++" "${_dirs}")
set(CMAKE_CXX_FLAGS "-stdlib=libc++")
get_toolchain_runtime_directories(_dirs)
_trp_expect_list("GCC and -stdlib=libc++ in the flags" "${_dirs}" "${_trp_gcc_lib}")
set(CMAKE_CXX_FLAGS "")

# --- the flags reach the compiler, the answer is cached ------------------------
file(REMOVE "${_trp_cxx}.log")
set(CMAKE_CXX_FLAGS "--gcc-toolchain=${_trp_gcc_lib}/.. -m32")
get_toolchain_runtime_directories(_dirs)
_trp_expect_list("flags change nothing in the answer" "${_dirs}" "${_trp_gcc_lib}")
file(STRINGS "${_trp_cxx}.log" _lines)
list(LENGTH _lines _first_count)
if(_first_count LESS 1)
  message(FATAL_ERROR "the compiler was never asked")
endif()
foreach(_line IN LISTS _lines)
  foreach(_flag "--gcc-toolchain=${_trp_gcc_lib}/.." "-m32" "-print-file-name=")
    string(FIND "${_line}" "${_flag}" _pos)
    if(_pos EQUAL -1)
      message(FATAL_ERROR "'${_line}' lacks '${_flag}': CMAKE_CXX_FLAGS must reach -print-file-name")
    endif()
  endforeach()
endforeach()
get_toolchain_runtime_directories(_dirs)
_trp_log_lines(_second_count)
if(NOT _second_count EQUAL _first_count)
  message(FATAL_ERROR
    "a second call asked the compiler again (${_first_count} -> ${_second_count} calls)")
endif()
set(CMAKE_CXX_FLAGS "-m32")
get_toolchain_runtime_directories(_dirs)
_trp_log_lines(_third_count)
if(_third_count EQUAL _second_count)
  message(FATAL_ERROR "another flag set must be asked again, not served from the cache")
endif()
set(CMAKE_CXX_FLAGS "")

# --- a wrapper in CMAKE_CXX_COMPILER_ARG1 comes first --------------------------
file(REMOVE "${_trp_cxx}.log")
set(CMAKE_CXX_COMPILER_ARG1 "--wrapped-arg")
get_toolchain_runtime_directories(_dirs STDLIB libstdc++)
file(STRINGS "${_trp_cxx}.log" _lines)
list(GET _lines 0 _line)
if(NOT _line MATCHES "^--wrapped-arg ")
  message(FATAL_ERROR "CMAKE_CXX_COMPILER_ARG1 is not the first argument: '${_line}'")
endif()
set(CMAKE_CXX_COMPILER_ARG1 "")

# --- a symbolic link to the directory gives the real directory -----------------
_trp_set_map(
  "libstdc++.so.6=${_trp_root}/link-to-gcc/libstdc++.so.6"
  "libgcc_s.so.1=${_trp_root}/link-to-gcc/libgcc_s.so.1")
set(CMAKE_CXX_FLAGS "-DLINK")
get_toolchain_runtime_directories(_dirs)
get_filename_component(_real_gcc_lib "${_trp_gcc_lib}" REALPATH)
_trp_expect_list("a link to the GCC directory" "${_dirs}" "${_real_gcc_lib}")
set(CMAKE_CXX_FLAGS "")

# --- a library that does not exist, or that the compiler does not know ---------
_trp_set_map(
  "libstdc++.so.6=${_trp_root}/missing/libstdc++.so.6"
  "libgcc_s.so.1=libgcc_s.so.1")
set(CMAKE_CXX_FLAGS "-DMISSING")
get_toolchain_runtime_directories(_dirs)
_trp_expect_list("missing and unknown libraries" "${_dirs}")
set(CMAKE_CXX_FLAGS "")

# --- a system compiler adds nothing --------------------------------------------
if(_trp_system_file)
  _trp_set_map(
    "libstdc++.so.6=${_trp_system_file}"
    "libgcc_s.so.1=${_trp_system_file}")
  set(CMAKE_CXX_FLAGS "-DSYSTEM")
  get_toolchain_runtime_directories(_dirs)
  _trp_expect_list("a runtime in a system directory (${_trp_system_file})" "${_dirs}")
  # One non-system library next to a system one: only the first is listed.
  _trp_set_map(
    "libstdc++.so.6=${_trp_system_file}"
    "libgcc_s.so.1=${_trp_gcc_lib}/libgcc_s.so.1")
  set(CMAKE_CXX_FLAGS "-DMIXED")
  get_toolchain_runtime_directories(_dirs)
  _trp_expect_list("a system and a non-system library" "${_dirs}" "${_trp_gcc_lib}")
  set(CMAKE_CXX_FLAGS "")
else()
  message(STATUS "toolchain_runtime_rpath_helpers: no system libc to point at, system cases skipped")
endif()

# --- Clang with libc++ and with libstdc++ ---------------------------------------
_trp_set_map(
  "libstdc++.so.6=${_trp_gcc_lib}/../lib64/libstdc++.so.6"
  "libgcc_s.so.1=${_trp_gcc_lib}/libgcc_s.so.1"
  "libc++.so.1=${_trp_llvm_lib}/../x86_64-unknown-linux-gnu/libc++.so.1"
  "libc++abi.so.1=${_trp_llvm_lib}/libc++abi.so.1"
  "libunwind.so.1=${_trp_llvm_lib}/libunwind.so.1")
set(CMAKE_CXX_COMPILER_ID "Clang")

# libc++: LLVM's directory first, then the GCC directory of libgcc_s.
get_toolchain_runtime_directories(_dirs STDLIB libc++)
_trp_expect_list("Clang with libc++" "${_dirs}" "${_trp_llvm_lib}" "${_trp_gcc_lib}")
get_toolchain_runtime_directories(_dirs STDLIB LIBC++)
_trp_expect_list("STDLIB is case-insensitive" "${_dirs}" "${_trp_llvm_lib}" "${_trp_gcc_lib}")
# libstdc++: the GCC directory only.
get_toolchain_runtime_directories(_dirs STDLIB libstdc++)
_trp_expect_list("Clang with libstdc++" "${_dirs}" "${_trp_gcc_lib}")
# Both, in the order given, without repeats.
get_toolchain_runtime_directories(_dirs STDLIB libstdc++ libc++)
_trp_expect_list("both libraries" "${_dirs}" "${_trp_gcc_lib}" "${_trp_llvm_lib}")
get_toolchain_runtime_directories(_dirs STDLIB libc++ libstdc++ libc++)
_trp_expect_list("both libraries, the other way round" "${_dirs}" "${_trp_llvm_lib}" "${_trp_gcc_lib}")

# Without STDLIB the global flags choose.
get_toolchain_runtime_directories(_dirs)
_trp_expect_list("Clang, no -stdlib in the flags" "${_dirs}" "${_trp_gcc_lib}")
set(CMAKE_CXX_FLAGS "-stdlib=libc++ -DCHOOSE")
get_toolchain_runtime_directories(_dirs)
_trp_expect_list("Clang, -stdlib=libc++ in CMAKE_CXX_FLAGS" "${_dirs}" "${_trp_llvm_lib}" "${_trp_gcc_lib}")
set(CMAKE_CXX_FLAGS "-stdlib=libstdc++ -DCHOOSE2")
get_toolchain_runtime_directories(_dirs)
_trp_expect_list("Clang, -stdlib=libstdc++ in CMAKE_CXX_FLAGS" "${_dirs}" "${_trp_gcc_lib}")
set(CMAKE_CXX_FLAGS "")

# --- platforms and compilers that get nothing ------------------------------------
function(_trp_expect_nothing what)
  get_toolchain_runtime_directories(_dirs STDLIB libstdc++ libc++)
  _trp_expect_list("${what}" "${_dirs}")
endfunction()

set(CMAKE_CXX_FLAGS "-DNOTHING")
set(CMAKE_CROSSCOMPILING TRUE)
_trp_expect_nothing("cross-compiling")
set(CMAKE_CROSSCOMPILING FALSE)
set(APPLE TRUE)
_trp_expect_nothing("Apple")
set(APPLE FALSE)
set(WIN32 TRUE)
_trp_expect_nothing("Windows (MinGW)")
set(WIN32 FALSE)
set(CYGWIN TRUE)
_trp_expect_nothing("Cygwin")
set(CYGWIN FALSE)
set(MSVC TRUE)
_trp_expect_nothing("MSVC / clang-cl")
set(MSVC FALSE)
set(UNIX FALSE)
_trp_expect_nothing("a non-UNIX host")
set(UNIX TRUE)
foreach(_id MSVC Intel IntelLLVM AppleClang NVIDIA "")
  set(CMAKE_CXX_COMPILER_ID "${_id}")
  _trp_expect_nothing("compiler '${_id}'")
endforeach()
set(CMAKE_CXX_COMPILER_ID "Clang")
set(CMAKE_CXX_COMPILER "")
_trp_expect_nothing("no C++ compiler")
set(CMAKE_CXX_COMPILER "${_trp_cxx}")

# And the same inputs give the answer again once everything is back.
set(CMAKE_CXX_FLAGS "-DBACK")
get_toolchain_runtime_directories(_dirs STDLIB libc++)
_trp_expect_list("everything back" "${_dirs}" "${_trp_llvm_lib}" "${_trp_gcc_lib}")

# The compiler failing is no answer.
file(WRITE "${_trp_root}/failing-cxx" "#!/bin/sh\nexit 1\n")
execute_process(COMMAND chmod 755 "${_trp_root}/failing-cxx")
set(CMAKE_CXX_COMPILER "${_trp_root}/failing-cxx")
set(CMAKE_CXX_FLAGS "-DFAILING")
get_toolchain_runtime_directories(_dirs STDLIB libstdc++ libc++)
_trp_expect_list("a compiler that fails" "${_dirs}")

file(REMOVE_RECURSE "${_trp_root}")
