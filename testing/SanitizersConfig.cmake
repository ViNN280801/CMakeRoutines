# =============================================================================
# SanitizersConfig.cmake
# Universal sanitizers configuration for all C/C++ compilers
# =============================================================================
#
# This module provides universal functions to configure sanitizers
# (AddressSanitizer, MemorySanitizer, ThreadSanitizer, UndefinedBehaviorSanitizer)
# for MSVC, GCC, Clang, and Intel ICC.
#
# Functions:
#   configure_sanitizers(<target>
#     [ADDRESS <ON|OFF>]
#     [MEMORY <ON|OFF>]
#     [THREAD <ON|OFF>]
#     [UNDEFINED <ON|OFF>]
#     [LEAK <ON|OFF>]
#     [CFI <ON|OFF>]  # Control Flow Integrity (Clang only; requires LTO)
#     [USE_DEFAULT_FLAGS <ON|OFF>]
#     [CUSTOM_FLAGS <flags...>]
#     [OPTIONS <options...>]
#     [EXTRA_FLAGS <flags...>]
#     [MSVC_FLAGS <flags...>]
#     [GCC_FLAGS <flags...>]
#     [CLANG_FLAGS <flags...>]
#     [ALLOW_UNSUPPORTED <ON|OFF>]  # Skip platform/combination checks. Default: OFF
#   )
#
# Sanitizer compatibility (enforced unless ALLOW_UNSUPPORTED):
#   ASan + TSan:   (conflict)
#   ASan + MSan:   (conflict)
#   TSan + MSan:   (conflict)
#   UBSan:         with any
#   LSan:          standalone or built into ASan
#
# Platform support (see gcc_clang_sanitizers.md):
#   ASan:  Linux, macOS, Windows (MSVC 16.9+)
#   LSan:  Linux, macOS; Windows limited
#   MSan:  Clang only, Linux (requires MSan-built deps)
#   TSan:  Linux, macOS; Windows limited
#   UBSan: All platforms (MSVC limited)
#   CFI:   Clang only; requires LTO (-flto=thin), -fvisibility=hidden
#
# Usage:
#   include(SanitizersConfig)
#   configure_sanitizers(MyApp ADDRESS ON UNDEFINED ON)
#
# =============================================================================

# =============================================================================
# Function: configure_sanitizers
#
# Configures sanitizers for a target.
#
# Parameters:
#   <target>               - Target name (required)
#   ADDRESS <on>           - Enable AddressSanitizer (ASan). Default: OFF
#   MEMORY <on>            - Enable MemorySanitizer (MSan, Clang-only). Default: OFF
#   THREAD <on>            - Enable ThreadSanitizer (TSan). Default: OFF
#   UNDEFINED <on>         - Enable UndefinedBehaviorSanitizer (UBSan). Default: OFF
#   LEAK <on>              - Enable LeakSanitizer (LSan). Default: OFF
#   CFI <on>               - Enable Control Flow Integrity (Clang only; requires LTO). Default: OFF
#   USE_DEFAULT_FLAGS <on> - Use default sanitizer flags. Default: ON
#                            If OFF, only user-specified flags are applied.
#                            If CUSTOM_FLAGS is specified, this option is ignored.
#   CUSTOM_FLAGS <...>     - Completely override all default sanitizer flags with custom ones.
#                            If specified, USE_DEFAULT_FLAGS is ignored.
#                            If not specified and USE_DEFAULT_FLAGS is OFF, error is raised.
#   OPTIONS <...>          - Sanitizer-specific options (e.g., ASAN_OPTIONS, TSAN_OPTIONS)
#   EXTRA_FLAGS <...>      - Extra sanitizer flags (added to defaults or custom)
#   MSVC_FLAGS <...>       - MSVC-specific sanitizer flags (added to defaults or custom)
#   GCC_FLAGS <...>        - GCC-specific sanitizer flags (added to defaults or custom)
#   CLANG_FLAGS <...>      - Clang-specific sanitizer flags (added to defaults or custom)
#   ALLOW_UNSUPPORTED <on> - Skip platform and combination checks. Default: OFF
#
# Usage:
#   # Use defaults
#   configure_sanitizers(MyApp ADDRESS ON UNDEFINED ON)
#
#   # Use only custom flags
#   configure_sanitizers(MyApp USE_DEFAULT_FLAGS OFF CUSTOM_FLAGS -fsanitize=address)
#
#   # Completely override with custom flags
#   configure_sanitizers(MyApp CUSTOM_FLAGS -fsanitize=address -fsanitize=undefined)
# =============================================================================
function(configure_sanitizers target)
  if(NOT TARGET ${target})
    message(FATAL_ERROR "SanitizersConfig: Target '${target}' does not exist")
  endif()

  # Parse arguments
  set(options "")
  set(oneValueArgs ADDRESS MEMORY THREAD UNDEFINED LEAK CFI USE_DEFAULT_FLAGS ALLOW_UNSUPPORTED)
  set(multiValueArgs CUSTOM_FLAGS OPTIONS EXTRA_FLAGS MSVC_FLAGS GCC_FLAGS CLANG_FLAGS)
  cmake_parse_arguments(SANITIZER "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Set default for USE_DEFAULT_FLAGS
  if(NOT DEFINED SANITIZER_USE_DEFAULT_FLAGS)
    set(SANITIZER_USE_DEFAULT_FLAGS ON)
  endif()
  if(NOT DEFINED SANITIZER_ALLOW_UNSUPPORTED)
    set(SANITIZER_ALLOW_UNSUPPORTED OFF)
  endif()

  # Validate: if USE_DEFAULT_FLAGS is OFF and CUSTOM_FLAGS is not specified, raise error
  if(NOT SANITIZER_USE_DEFAULT_FLAGS AND NOT SANITIZER_CUSTOM_FLAGS)
    message(FATAL_ERROR "SanitizersConfig: USE_DEFAULT_FLAGS is OFF but CUSTOM_FLAGS is not specified. "
      "Either set USE_DEFAULT_FLAGS ON or provide CUSTOM_FLAGS.")
  endif()

  # If CUSTOM_FLAGS specified, skip validation and use only them (ignore defaults)
  if(SANITIZER_CUSTOM_FLAGS)
    target_compile_options(${target} PRIVATE ${SANITIZER_CUSTOM_FLAGS})
    target_link_options(${target} PRIVATE ${SANITIZER_CUSTOM_FLAGS})
    message(STATUS "SanitizersConfig: Using custom sanitizer flags only for '${target}'")
    return()
  endif()

  # Set defaults
  if(NOT DEFINED SANITIZER_ADDRESS)
    set(SANITIZER_ADDRESS OFF)
  endif()
  if(NOT DEFINED SANITIZER_MEMORY)
    set(SANITIZER_MEMORY OFF)
  endif()
  if(NOT DEFINED SANITIZER_THREAD)
    set(SANITIZER_THREAD OFF)
  endif()
  if(NOT DEFINED SANITIZER_UNDEFINED)
    set(SANITIZER_UNDEFINED OFF)
  endif()
  if(NOT DEFINED SANITIZER_LEAK)
    set(SANITIZER_LEAK OFF)
  endif()
  if(NOT DEFINED SANITIZER_CFI)
    set(SANITIZER_CFI OFF)
  endif()

  # =========================================================================
  # Validation: invalid combinations and platform support (unless ALLOW_UNSUPPORTED)
  # See gcc_clang_sanitizers.md — shadow memory conflicts
  # =========================================================================
  if(NOT SANITIZER_ALLOW_UNSUPPORTED)
    # --- Invalid combinations (FATAL) ---
    if(SANITIZER_ADDRESS AND SANITIZER_THREAD)
      message(FATAL_ERROR "SanitizersConfig: ASan and TSan cannot be used together "
        "(shadow memory conflict). Use separate builds: one with ADDRESS, another with THREAD. "
        "Set ALLOW_UNSUPPORTED ON to override (not recommended).")
    endif()
    if(SANITIZER_ADDRESS AND SANITIZER_MEMORY)
      message(FATAL_ERROR "SanitizersConfig: ASan and MSan cannot be used together. "
        "Use separate builds. Set ALLOW_UNSUPPORTED ON to override (not recommended).")
    endif()
    if(SANITIZER_THREAD AND SANITIZER_MEMORY)
      message(FATAL_ERROR "SanitizersConfig: TSan and MSan cannot be used together. "
        "Use separate builds. Set ALLOW_UNSUPPORTED ON to override (not recommended).")
    endif()
    if(SANITIZER_CFI AND SANITIZER_MEMORY)
      message(FATAL_ERROR "SanitizersConfig: CFI and MSan cannot be used together. "
        "Use separate builds. Set ALLOW_UNSUPPORTED ON to override (not recommended).")
    endif()

    # --- Compiler-specific: MSan is Clang-only ---
    if(SANITIZER_MEMORY AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
      message(FATAL_ERROR "SanitizersConfig: MemorySanitizer (MSan) is supported only with Clang. "
        "Current compiler: ${CMAKE_CXX_COMPILER_ID}. Set ALLOW_UNSUPPORTED ON to override (will likely fail).")
    endif()

    # --- Platform warnings ---
    if(WIN32)
      if(SANITIZER_THREAD)
        message(WARNING "SanitizersConfig: TSan has limited support on Windows. "
          "Prefer Linux/macOS for thread sanitizer runs.")
      endif()
      if(SANITIZER_MEMORY)
        message(WARNING "SanitizersConfig: MSan is primarily supported on Linux. "
          "Windows support is experimental and may fail.")
      endif()
      if(SANITIZER_LEAK AND NOT SANITIZER_ADDRESS)
        message(WARNING "SanitizersConfig: Standalone LSan on Windows has limited support. "
          "Consider ADDRESS ON (includes LSan) or run on Linux.")
      endif()
    endif()

    # --- MSVC version for ASan ---
    if(MSVC AND SANITIZER_ADDRESS)
      if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "19.29")
        message(FATAL_ERROR "SanitizersConfig: MSVC AddressSanitizer requires Visual Studio 2019 16.9+ "
          "(version 19.29). Current: ${CMAKE_CXX_COMPILER_VERSION}. "
          "Use Clang/GCC or upgrade MSVC. Set ALLOW_UNSUPPORTED ON to override.")
      endif()
    endif()

    # --- MSan: all dependencies must be built with MSan (informational) ---
    if(SANITIZER_MEMORY)
      message(STATUS "SanitizersConfig: MSan requires all linked libraries to be built with MSan. "
        "Otherwise expect false positives. Consider using a pre-built MSan sysroot (e.g. LLVM/Google CI).")
    endif()

    # --- CFI: Clang only; requires LTO ---
    if(SANITIZER_CFI AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
      message(FATAL_ERROR "SanitizersConfig: CFI (Control Flow Integrity) is supported only with Clang. "
        "Current compiler: ${CMAKE_CXX_COMPILER_ID}. Set ALLOW_UNSUPPORTED ON to override (will likely fail).")
    endif()
  endif()

  # Configure based on compiler
  if(SANITIZER_USE_DEFAULT_FLAGS)
    if(MSVC)
      _configure_msvc_sanitizers(${target} "${SANITIZER_ADDRESS}" "${SANITIZER_UNDEFINED}" "${SANITIZER_OPTIONS}" "${SANITIZER_EXTRA_FLAGS}" "${SANITIZER_MSVC_FLAGS}")
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
      _configure_gcc_sanitizers(${target} "${SANITIZER_ADDRESS}" "${SANITIZER_THREAD}" "${SANITIZER_UNDEFINED}" "${SANITIZER_LEAK}" "${SANITIZER_OPTIONS}" "${SANITIZER_EXTRA_FLAGS}" "${SANITIZER_GCC_FLAGS}")
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
      _configure_clang_sanitizers(${target} "${SANITIZER_ADDRESS}" "${SANITIZER_MEMORY}"
        "${SANITIZER_THREAD}" "${SANITIZER_UNDEFINED}" "${SANITIZER_LEAK}" "${SANITIZER_CFI}"
        "${SANITIZER_OPTIONS}" "${SANITIZER_EXTRA_FLAGS}" "${SANITIZER_CLANG_FLAGS}")
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Intel")
      message(WARNING "SanitizersConfig: Intel ICC has limited sanitizer support")
    else()
      message(WARNING "SanitizersConfig: Sanitizers not supported for compiler '${CMAKE_CXX_COMPILER_ID}'")
    endif()
  else()
    # Only user-specified flags (already validated that CUSTOM_FLAGS or compiler-specific flags exist)
    if(SANITIZER_EXTRA_FLAGS)
      target_compile_options(${target} PRIVATE ${SANITIZER_EXTRA_FLAGS})
      target_link_options(${target} PRIVATE ${SANITIZER_EXTRA_FLAGS})
    endif()
    if(SANITIZER_MSVC_FLAGS)
      target_compile_options(${target} PRIVATE ${SANITIZER_MSVC_FLAGS})
      target_link_options(${target} PRIVATE ${SANITIZER_MSVC_FLAGS})
    endif()
    if(SANITIZER_GCC_FLAGS)
      target_compile_options(${target} PRIVATE ${SANITIZER_GCC_FLAGS})
      target_link_options(${target} PRIVATE ${SANITIZER_GCC_FLAGS})
    endif()
    if(SANITIZER_CLANG_FLAGS)
      target_compile_options(${target} PRIVATE ${SANITIZER_CLANG_FLAGS})
      target_link_options(${target} PRIVATE ${SANITIZER_CLANG_FLAGS})
    endif()
    message(STATUS "SanitizersConfig: Using user-specified flags only (no defaults) for '${target}'")
  endif()

  # Print the recommended sanitizer runtime option strings once per configure,
  # so the user can get maximum detail from the enabled sanitizers at runtime.
  get_property(_runtime_opts_hint GLOBAL PROPERTY _LUMEX_SANITIZER_RUNTIME_OPTS_HINT)
  if(NOT _runtime_opts_hint)
    set_property(GLOBAL PROPERTY _LUMEX_SANITIZER_RUNTIME_OPTS_HINT TRUE)
    print_sanitizer_runtime_options(
      ADDRESS ${SANITIZER_ADDRESS}
      MEMORY ${SANITIZER_MEMORY}
      THREAD ${SANITIZER_THREAD}
      UNDEFINED ${SANITIZER_UNDEFINED}
      LEAK ${SANITIZER_LEAK}
      CFI ${SANITIZER_CFI})
  endif()
endfunction()

# =============================================================================
# Internal function: _configure_msvc_sanitizers
# MSVC: /fsanitize=address (VS 2019 16.9+)
# =============================================================================
function(_configure_msvc_sanitizers target address undefined options)
  set(msvc_flags "")

  # AddressSanitizer
  if(address)
    # Check MSVC version (requires VS 2019 16.9+)
    if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "19.29")
      list(APPEND msvc_flags /fsanitize=address)
      message(STATUS "SanitizersConfig: MSVC AddressSanitizer enabled for '${target}'")
    else()
      message(WARNING "SanitizersConfig: MSVC AddressSanitizer requires Visual Studio 2019 16.9+ (current: ${CMAKE_CXX_COMPILER_VERSION})")
    endif()
  endif()

  # UndefinedBehaviorSanitizer (limited support in MSVC)
  if(undefined)
    message(WARNING "SanitizersConfig: MSVC has limited UBSan support. Consider using /analyze for static analysis")
  endif()

  # Apply flags. /fsanitize=address is a COMPILE-time flag: cl.exe embeds the
  # ASan runtime reference into the object, so link.exe picks the runtime up
  # automatically. Passing it on the link line only makes link.exe emit
  # LNK4044 ("unrecognized option '/fsanitize=address'; ignored").
  if(msvc_flags)
    target_compile_options(${target} PRIVATE ${msvc_flags})
  endif()
  # Apply extra flags
  if(extra_flags)
    target_compile_options(${target} PRIVATE ${extra_flags})
    target_link_options(${target} PRIVATE ${extra_flags})
  endif()
  # Apply compiler-specific flags
  if(compiler_flags)
    target_compile_options(${target} PRIVATE ${compiler_flags})
    target_link_options(${target} PRIVATE ${compiler_flags})
  endif()

  # ASan on Windows links a runtime DLL. Stage it next to the target so the
  # executable starts (and gtest_discover_tests can run it) without the
  # compiler bin directory being on PATH.
  if(address AND msvc_flags)
    stage_clang_sanitizer_runtime(${target} ADDRESS ON)
  endif()
endfunction()

# =============================================================================
# Internal function: _configure_gcc_sanitizers
# GCC: -fsanitize=address, -fsanitize=thread, -fsanitize=undefined, -fsanitize=leak
# =============================================================================
function(_configure_gcc_sanitizers target address thread undefined leak options)
  set(gcc_flags "")

  # Build sanitizer list
  set(sanitizers "")

  if(address)
    list(APPEND sanitizers "address")
  endif()

  if(thread)
    if(address)
      message(WARNING "SanitizersConfig: AddressSanitizer and ThreadSanitizer cannot be used together")
    else()
      list(APPEND sanitizers "thread")
    endif()
  endif()

  if(undefined)
    list(APPEND sanitizers "undefined")
  endif()

  if(leak)
    if(address)
      message(STATUS "SanitizersConfig: LeakSanitizer is included in AddressSanitizer")
    else()
      list(APPEND sanitizers "leak")
    endif()
  endif()

  # Apply sanitizer flags
  if(sanitizers)
    string(REPLACE ";" "," sanitizer_list "${sanitizers}")
    list(APPEND gcc_flags -fsanitize=${sanitizer_list})
    list(APPEND gcc_flags -fno-omit-frame-pointer)  # Required for proper stack traces
    list(APPEND gcc_flags -g)  # Debug symbols required

    target_compile_options(${target} PRIVATE ${gcc_flags})
    target_link_options(${target} PRIVATE ${gcc_flags})
    message(STATUS "SanitizersConfig: GCC sanitizers enabled for '${target}': ${sanitizer_list}")
  endif()
  # Apply extra flags
  if(extra_flags)
    target_compile_options(${target} PRIVATE ${extra_flags})
    target_link_options(${target} PRIVATE ${extra_flags})
  endif()
  # Apply compiler-specific flags
  if(compiler_flags)
    target_compile_options(${target} PRIVATE ${compiler_flags})
    target_link_options(${target} PRIVATE ${compiler_flags})
  endif()
endfunction()

# =============================================================================
# Internal function: _configure_clang_sanitizers
# Clang: -fsanitize=address, memory, thread, undefined, leak, cfi
# CFI requires LTO and -fvisibility=hidden (see gcc_clang_sanitizers.md)
# =============================================================================
function(_configure_clang_sanitizers target address memory thread undefined leak cfi options extra_flags compiler_flags)
  set(clangCompileFlags "")
  set(clangLinkFlags "")

  # Build sanitizer list
  set(sanitizers "")

  if(address)
    list(APPEND sanitizers "address")
  endif()

  if(memory)
    if(address OR thread)
      message(WARNING "SanitizersConfig: MemorySanitizer cannot be used with AddressSanitizer or ThreadSanitizer")
    else()
      list(APPEND sanitizers "memory")
    endif()
  endif()

  if(thread)
    if(address)
      message(WARNING "SanitizersConfig: AddressSanitizer and ThreadSanitizer cannot be used together")
    else()
      list(APPEND sanitizers "thread")
    endif()
  endif()

  if(undefined)
    list(APPEND sanitizers "undefined")
  endif()

  if(leak)
    if(address)
      message(STATUS "SanitizersConfig: LeakSanitizer is included in AddressSanitizer")
    else()
      list(APPEND sanitizers "leak")
    endif()
  endif()

  if(cfi)
    list(APPEND sanitizers "cfi")
  endif()

  # Apply sanitizer flags
  if(sanitizers)
    _lumex_sanitizer_is_clang_cl(_isClangCl)

    string(REPLACE ";" "," sanitizerList "${sanitizers}")
    list(APPEND clangCompileFlags -fsanitize=${sanitizerList})
    # Frame pointer for backtraces: clang-cl wants the MSVC spelling (/Oy-);
    # the GNU -fno-omit-frame-pointer is ignored by clang-cl and emits
    # -Wunknown-argument.
    if(_isClangCl)
      list(APPEND clangCompileFlags /Oy-)
    else()
      list(APPEND clangCompileFlags -fno-omit-frame-pointer)
    endif()
    list(APPEND clangCompileFlags -g)

    if(cfi)
      # CFI needs LTO + hidden visibility at compile time; link with -no-pie on Linux PIE defaults.
      # -fsplit-lto-unit: one thin-LTO unit per source file so static deps link consistently.
      list(APPEND clangCompileFlags -flto=thin -fsplit-lto-unit -fvisibility=hidden -fno-pie)
    endif()

    # MemorySanitizer requires special flags
    if(memory)
      list(APPEND clangCompileFlags -fno-optimize-sibling-calls)
      list(APPEND clangCompileFlags -fsanitize-memory-track-origins=2 -O1)
    endif()

    target_compile_options(${target} PRIVATE ${clangCompileFlags})

    # clang-cl (Clang frontend, MSVC-compatible interface) on Windows is normally
    # linked through link.exe, which ignores driver-only -fsanitize=... options.
    # Link the sanitizer runtime libraries explicitly so the __asan_* / __ubsan_*
    # symbols resolve. Native Clang keeps resolving the runtime from
    # -fsanitize=... at link time. (The dynamic ASan runtime DLL is staged next to
    # executables by stage_clang_sanitizer_runtime; that helper is called from the
    # target's own directory by lumex_test_use_gtest, since add_custom_command(TARGET)
    # requires the target to be defined in the current directory.)
    if(_isClangCl)
      _configure_clang_cl_sanitizer_link(${target} ${address} ${memory} ${thread} ${undefined} ${leak} ${cfi})
    else()
      list(APPEND clangLinkFlags -fsanitize=${sanitizerList})
      list(APPEND clangLinkFlags -fno-omit-frame-pointer)
      list(APPEND clangLinkFlags -g)

      if(cfi)
        list(APPEND clangLinkFlags -flto=thin -fsplit-lto-unit -no-pie)
      endif()
      if(memory)
        list(APPEND clangLinkFlags -fsanitize-memory-track-origins=2 -O1)
      endif()

      target_link_options(${target} PRIVATE ${clangLinkFlags})
    endif()

    message(STATUS "SanitizersConfig: Clang sanitizers enabled for '${target}': ${sanitizerList}")

    # Print the recommended sanitizer runtime option strings once per configure.
    # Done here too (not only in configure_sanitizers) because clang-cl consumers
    # often call _configure_clang_sanitizers directly to bypass the MSVC branch.
    get_property(_runtime_opts_hint GLOBAL PROPERTY _LUMEX_SANITIZER_RUNTIME_OPTS_HINT)
    if(NOT _runtime_opts_hint)
      set_property(GLOBAL PROPERTY _LUMEX_SANITIZER_RUNTIME_OPTS_HINT TRUE)
      print_sanitizer_runtime_options(
        ADDRESS ${address}
        MEMORY ${memory}
        THREAD ${thread}
        UNDEFINED ${undefined}
        LEAK ${leak}
        CFI ${cfi})
    endif()
  endif()
  # Apply extra flags
  if(extra_flags)
    target_compile_options(${target} PRIVATE ${extra_flags})
    target_link_options(${target} PRIVATE ${extra_flags})
  endif()
  # Apply compiler-specific flags
  if(compiler_flags)
    target_compile_options(${target} PRIVATE ${compiler_flags})
    target_link_options(${target} PRIVATE ${compiler_flags})
  endif()
endfunction()

# =============================================================================
# clang-cl sanitizer runtime helpers
#
# clang-cl on Windows is normally linked through link.exe, which ignores the
# driver-only -fsanitize=... options. The sanitizer runtime libraries must be
# linked explicitly, and the dynamic ASan runtime (clang_rt.asan_dynamic-*.dll)
# must sit next to every executable / shared library or the process fails to
# start with STATUS_DLL_NOT_FOUND (0xc0000135).
# =============================================================================

# True when the active compiler is clang-cl (Clang frontend with the
# MSVC-compatible interface). Distinguishes clang-cl from cl.exe
# (CMAKE_CXX_COMPILER_ID "MSVC") and from native clang++ (MSVC is FALSE).
function(_lumex_sanitizer_is_clang_cl out_var)
  set(_result FALSE)
  if(MSVC AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    set(_result TRUE)
  endif()
  set(${out_var} "${_result}" PARENT_SCOPE)
endfunction()

# Resolves the active Clang compiler's resource directory (e.g. .../lib/clang/22),
# which hosts lib/windows/clang_rt.*.{lib,dll}. Cached so the compiler is only
# interrogated once per configure run.
function(_lumex_sanitizer_resource_dir out_var)
  # Cache via a GLOBAL property (not a CACHE variable) so the helper also runs
  # under `cmake -P` script mode, which forbids `set(... CACHE ...)`.
  get_property(_cached GLOBAL PROPERTY _LUMEX_SANITIZER_CLANG_RESOURCE_DIR)
  if(_cached)
    set(${out_var} "${_cached}" PARENT_SCOPE)
    return()
  endif()

  set(_resource_dir "")
  execute_process(
    COMMAND "${CMAKE_CXX_COMPILER}" -print-resource-dir
    OUTPUT_VARIABLE _resource_dir
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
    RESULT_VARIABLE _print_result)
  if(NOT _print_result EQUAL 0 OR NOT _resource_dir OR NOT IS_DIRECTORY "${_resource_dir}")
    get_filename_component(_compiler_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
    file(GLOB _candidates "${_compiler_dir}/../lib/clang/*")
    set(_resource_dir "")
    foreach(_candidate ${_candidates})
      if(IS_DIRECTORY "${_candidate}")
        set(_resource_dir "${_candidate}")
      endif()
    endforeach()
  endif()

  set_property(GLOBAL PROPERTY _LUMEX_SANITIZER_CLANG_RESOURCE_DIR "${_resource_dir}")
  set(${out_var} "${_resource_dir}" PARENT_SCOPE)
endfunction()

# Maps the compiler architecture id to the suffix used in clang_rt.* library
# and DLL names (x86_64, i386, aarch64, arm).
function(_lumex_sanitizer_arch_suffix out_var)
  set(_suffix "")
  set(_arch_id "${CMAKE_CXX_COMPILER_ARCHITECTURE_ID}")
  if(_arch_id MATCHES "^(X64|x64|AMD64|amd64)$")
    set(_suffix "x86_64")
  elseif(_arch_id MATCHES "^(X86|x86|IA32|i386)$")
    set(_suffix "i386")
  elseif(_arch_id MATCHES "^(ARM64|arm64|AArch64|aarch64)$")
    set(_suffix "aarch64")
  elseif(_arch_id MATCHES "^(ARM|arm)$")
    set(_suffix "arm")
  endif()
  set(${out_var} "${_suffix}" PARENT_SCOPE)
endfunction()

# Explicitly links the clang-cl sanitizer runtime libraries. ASan uses the
# dynamic runtime (clang_rt.asan_dynamic + its thunk); UBSan uses the static
# standalone runtime. TSan/MSan are not supported on Windows.
function(_configure_clang_cl_sanitizer_link target address memory thread undefined leak cfi)
  _lumex_sanitizer_resource_dir(_resource_dir)
  _lumex_sanitizer_arch_suffix(_arch_suffix)
  if(NOT _resource_dir OR NOT _arch_suffix)
    message(WARNING
      "SanitizersConfig: clang-cl sanitizer runtime directory could not be "
      "determined for '${target}'. The linker may fail to resolve "
      "__asan_* / __ubsan_* symbols. Install LLVM/Clang runtime libraries or "
      "pass them via CMAKE_EXE_LINKER_FLAGS manually.")
    return()
  endif()
  set(_runtime_lib_dir "${_resource_dir}/lib/windows")
  if(NOT IS_DIRECTORY "${_runtime_lib_dir}")
    message(WARNING
      "SanitizersConfig: clang-cl sanitizer runtime directory "
      "'${_runtime_lib_dir}' does not exist; '${target}' may fail to link.")
    return()
  endif()
  set(_runtime_libs "")
  if(address)
    list(APPEND _runtime_libs
      "clang_rt.asan_dynamic_runtime_thunk-${_arch_suffix}.lib"
      "clang_rt.asan_dynamic-${_arch_suffix}.lib")
  endif()
  if(undefined)
    list(APPEND _runtime_libs
      "clang_rt.ubsan_standalone-${_arch_suffix}.lib"
      "clang_rt.ubsan_standalone_cxx-${_arch_suffix}.lib")
  endif()
  if(NOT _runtime_libs)
    return()
  endif()
  target_link_options(${target} PRIVATE "/LIBPATH:${_runtime_lib_dir}" ${_runtime_libs})
  message(STATUS
    "SanitizersConfig: clang-cl sanitizer runtime libraries for '${target}': ${_runtime_libs}")
endfunction()

# =============================================================================
# Function: stage_clang_sanitizer_runtime
#
# Copies the Windows AddressSanitizer runtime DLL next to a target so it can
# run. Handles both drivers:
#   clang-cl - clang_rt.asan_dynamic-<arch>.dll from the clang resource dir;
#   MSVC     - clang_rt.asan_dynamic-<arch>.dll (Release) or
#              clang_rt.asan_dbg_dynamic-<arch>.dll (Debug) from the directory
#              that holds cl.exe.
#
# The dynamic ASan runtime is a DLL on Windows; if it is missing beside the
# executable the process fails to start with STATUS_DLL_NOT_FOUND
# (0xc0000135), which also breaks gtest_discover_tests POST_BUILD discovery
# and CTest. Staging it means neither build nor test run needs the compiler
# bin directory on PATH (no vcvars import required).
#
# For test executables call this BEFORE gtest_discover_tests: POST_BUILD
# commands run in registration order, so the copy must be registered first.
# lumex_test_use_gtest does this automatically.
#
# Usage:
#   stage_clang_sanitizer_runtime(MyTest ADDRESS ON UNDEFINED ON)
# =============================================================================
function(stage_clang_sanitizer_runtime target)
  cmake_parse_arguments(ARG "" "ADDRESS;MEMORY;THREAD;UNDEFINED;LEAK;CFI" "" ${ARGN})

  # Only AddressSanitizer ships a runtime DLL on Windows; UBSan/TSan runtimes
  # are static libraries. Nothing to stage when ASan is off.
  if(NOT ARG_ADDRESS)
    return()
  endif()

  if(NOT TARGET ${target})
    return()
  endif()

  # Only executables and shared libraries load the DLL at runtime.
  get_target_property(_target_type ${target} TYPE)
  if(NOT (_target_type STREQUAL "EXECUTABLE" OR _target_type STREQUAL "SHARED_LIBRARY"))
    return()
  endif()

  # add_custom_command(TARGET ...) is directory-scoped: calling it for a target
  # created in another directory is a hard CMake error ("TARGET ... was not
  # created in this directory"). Staging only matters for the executables that
  # load the runtime DLL, and those call this helper from their own directory
  # (lumex_test_use_gtest, lumex_example_executable); a project-wide call from
  # the root for libraries is a no-op by design.
  get_target_property(_target_src_dir ${target} SOURCE_DIR)
  if(NOT _target_src_dir STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    return()
  endif()

  # Idempotency: test executables are staged early by lumex_test_use_gtest and
  # again (later) via _configure_clang_sanitizers; only add the copy once.
  get_target_property(_already_staged ${target} _LUMEX_SANITIZER_RUNTIME_STAGED)
  if(_already_staged)
    return()
  endif()

  _lumex_sanitizer_arch_suffix(_arch_suffix)
  if(NOT _arch_suffix)
    return()
  endif()

  set(_asan_runtime_dlls "")
  _lumex_sanitizer_is_clang_cl(_is_clang_cl)
  if(_is_clang_cl)
    _lumex_sanitizer_resource_dir(_resource_dir)
    if(_resource_dir)
      list(APPEND _asan_runtime_dlls
        "${_resource_dir}/lib/windows/clang_rt.asan_dynamic-${_arch_suffix}.dll")
    endif()
  elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    get_filename_component(_compiler_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
    foreach(_stem clang_rt.asan_dynamic clang_rt.asan_dbg_dynamic)
      list(APPEND _asan_runtime_dlls
        "${_compiler_dir}/${_stem}-${_arch_suffix}.dll")
    endforeach()
  else()
    return()
  endif()

  set(_staged_any FALSE)
  foreach(_asan_runtime_dll IN LISTS _asan_runtime_dlls)
    if(NOT EXISTS "${_asan_runtime_dll}")
      continue()
    endif()
    set(_staged_any TRUE)
    add_custom_command(TARGET ${target} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${_asan_runtime_dll}" "$<TARGET_FILE_DIR:${target}>"
      COMMENT "Staging sanitizer runtime DLL for ${target}"
      VERBATIM)
  endforeach()

  if(_staged_any)
    set_target_properties(${target} PROPERTIES _LUMEX_SANITIZER_RUNTIME_STAGED TRUE)
  else()
    message(WARNING
      "stage_clang_sanitizer_runtime: no ASan runtime DLL found in "
      "[${_asan_runtime_dlls}]; '${target}' may fail to start with "
      "STATUS_DLL_NOT_FOUND.")
  endif()
endfunction()

# =============================================================================
# Sanitizer runtime option strings
#
# Recommended values for the *_OPTIONS environment variables consumed by the
# sanitizer runtimes. They turn on verbose diagnostics (symbolization, stack
# traces, full thread history, allocation context) so reports carry the most
# detail. Consumers may export these as-is, e.g.:
#   set(ENV{ASAN_OPTIONS} "${SANITIZER_RUNTIME_ASAN_OPTIONS}")
# =============================================================================
set(SANITIZER_RUNTIME_ASAN_OPTIONS
  "halt_on_error=1:abort_on_error=1:detect_leaks=0:leak_check_at_exit=0:print_legend=1:print_summary=1:print_cmdline=1:print_full_thread_history=1:strict_string_checks=1:fast_unwind_on_malloc=0:fast_unwind_on_fatal=0:malloc_context_size=30:symbolize=1:symbolize_inline_frames=1:verbosity=1:detect_stack_use_after_return=1:alloc_dealloc_mismatch=1:dump_instruction_bytes=1")
set(SANITIZER_RUNTIME_UBSAN_OPTIONS
  "print_stacktrace=1:halt_on_error=1:abort_on_error=1:print_summary=1:symbolize=1:symbolize_inline_frames=1:verbosity=1:log_exe_name=1")
set(SANITIZER_RUNTIME_LSAN_OPTIONS
  "exitcode=0:print_suppressions=0")
set(SANITIZER_RUNTIME_MSAN_OPTIONS
  "halt_on_error=1:abort_on_error=1:print_stats=1:verbosity=1:symbolize=1:malloc_context_size=30:log_exe_name=1")
set(SANITIZER_RUNTIME_TSAN_OPTIONS
  "halt_on_error=1:abort_on_error=1:report_thread_leaks=0:history_size=7:report_destroy_locked=1:report_signal_unsafe=1:verbosity=1:symbolize=1:log_exe_name=1")

# Returns a list of "<SAN>_OPTIONS=<opts>" entries for the enabled sanitizers.
# Usage:
#   sanitizer_runtime_options(result ADDRESS ON UNDEFINED ON)
function(sanitizer_runtime_options out_var)
  cmake_parse_arguments(ARG "" "ADDRESS;MEMORY;THREAD;UNDEFINED;LEAK;CFI" "" ${ARGN})

  set(_entries "")
  if(ARG_ADDRESS)
    list(APPEND _entries "ASAN_OPTIONS=${SANITIZER_RUNTIME_ASAN_OPTIONS}")
  endif()
  if(ARG_UNDEFINED)
    list(APPEND _entries "UBSAN_OPTIONS=${SANITIZER_RUNTIME_UBSAN_OPTIONS}")
  endif()
  if(ARG_LEAK)
    list(APPEND _entries "LSAN_OPTIONS=${SANITIZER_RUNTIME_LSAN_OPTIONS}")
  endif()
  if(ARG_MEMORY)
    list(APPEND _entries "MSAN_OPTIONS=${SANITIZER_RUNTIME_MSAN_OPTIONS}")
  endif()
  if(ARG_THREAD)
    list(APPEND _entries "TSAN_OPTIONS=${SANITIZER_RUNTIME_TSAN_OPTIONS}")
  endif()

  set(${out_var} "${_entries}" PARENT_SCOPE)
endfunction()

# Prints the recommended *_OPTIONS strings for the enabled sanitizers.
# Usage:
#   print_sanitizer_runtime_options(ADDRESS ON UNDEFINED ON)
function(print_sanitizer_runtime_options)
  sanitizer_runtime_options(_hints ${ARGN})
  if(NOT _hints)
    return()
  endif()

  message(STATUS
    "SanitizersConfig: for verbose sanitizer diagnostics, run instrumented "
    "binaries with:")
  foreach(_hint IN LISTS _hints)
    message(STATUS "  ${_hint}")
  endforeach()
endfunction()

