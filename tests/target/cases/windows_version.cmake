# Branch coverage for core/WindowsVersionConfig.cmake
include("${_module_root}/core/WindowsVersionConfig.cmake")

# Reset to a Windows + MSVC platform (earlier cases simulate non-Windows via
# simulate_platform, which overwrites WIN32 in the shared top-level scope).
simulate_platform(TRUE FALSE FALSE TRUE "MSVC" "MSVC")

# Predefined version -> WIN32_WINNT hex (WINDOWS_VERSION is a sticky cache var,
# so clear it between VERSION calls to exercise each branch).
foreach(_kv IN ITEMS "XP:0x0501" "VISTA:0x0600" "SEVEN:0x0601" "EIGHT:0x0602" "EIGHTDOTONE:0x0603" "TENELEVEN:0x0A00")
  string(REPLACE ":" ";" _pair "${_kv}")
  list(GET _pair 0 _ver)
  list(GET _pair 1 _hex)
  unset(WINDOWS_VERSION CACHE)
  new_test_target(t)
  configure_windows_version(VERSION ${_ver} TARGET ${t})
  expect_compile_definition(${t} "WIN32_WINNT=${_hex}")
  expect_compile_definition(${t} "_WIN32_WINNT=${_hex}")
endforeach()

# Unknown version -> fallback 0x0A00
unset(WINDOWS_VERSION CACHE)
new_test_target(t)
configure_windows_version(VERSION BOGUS TARGET ${t})
expect_compile_definition(${t} "WIN32_WINNT=0x0A00")

# Custom hex
new_test_target(t)
configure_windows_version(CUSTOM_WIN32_WINNT 0x0B00 TARGET ${t})
expect_compile_definition(${t} "WIN32_WINNT=0x0B00")

# Non-Windows platform -> no definition applied
new_test_target(t)
simulate_platform(FALSE FALSE TRUE FALSE "GNU" "GNU")
configure_windows_version(VERSION SEVEN TARGET ${t})
expect_no_compile_definition(${t} "WIN32_WINNT=0x0601")
