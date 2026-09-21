# CMakeRoutines self-tests

Two layers, by what they need to run.

## Run everything

```sh
# Windows (from a Developer Command Prompt, or after importing vcvars):
./tests/run_all.ps1 -CxxCompiler clang-cl

# Linux / macOS:
CXX_COMPILER=g++ ./tests/run_all.sh
```

Or run the two layers manually:

## 1. Script-mode tests (`tests/`) - no compiler

Pure helpers and source-level regressions, run under `cmake -P`.

```sh
cmake -S tests -B build -G Ninja
ctest --test-dir build --output-on-failure
```

Cases live in `tests/cases/*.cmake` and are driven by `run_one.cmake`.
`CASE_EXPECT_FAIL` + `CASE_FAIL_PATTERN` cover `message(FATAL_ERROR)` branches.

## 2. Target-level tests (`tests/target/`) - needs a C/C++ compiler

Exercises the `configure_*` routines against every branch of their
conditionals, then asserts the resulting `COMPILE_OPTIONS` / `LINK_OPTIONS` /
`COMPILE_DEFINITIONS` / properties. No build is run; every check is a
`message(FATAL_ERROR)` during configure. It prints the total assertion count.

```sh
cmake -S tests/target -B build-target -G Ninja \
  -DCMAKE_C_COMPILER=<cc> -DCMAKE_CXX_COMPILER=<cxx>
```

- The compiler only enables `project(LANGUAGES C CXX)`.
- MSVC / GCC / Clang / Intel / Windows / macOS / Linux branches are
  **simulated** by overriding `MSVC`, `WIN32`, `UNIX`, `APPLE`,
  `CMAKE_CXX_COMPILER_ID` in the caller scope (`simulate_platform` in
  `helpers.cmake`), so one configure covers all compiler paths.
- FATAL_ERROR validation branches are tested via `expect_configure_fail`,
  which runs a nested configure that must fail.

## Adding a case

1. Pure helper: add `tests/cases/<name>.cmake` and register it in
   `tests/CMakeLists.txt`.
2. `configure_*` routine: add `tests/target/cases/<name>.cmake` and
   `include()` it from `tests/target/CMakeLists.txt`.

