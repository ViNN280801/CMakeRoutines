# CMakeRoutines full test runner (Windows PowerShell).
# Usage:
#   .\tests\run_all.ps1 -CxxCompiler clang-cl
#
# Layer 1 (script-mode) needs no compiler. Layer 2 (target-level) needs a
# C/C++ compiler; on Windows with MSVC/clang-cl, run this from a Developer
# Command Prompt or import vcvars first (Layer 2 must detect the compiler).

param(
  [string]$CCompiler = "",
  [string]$CxxCompiler = ""
)

$ErrorActionPreference = "Stop"

Write-Host "=== CMakeRoutines tests: layer 1 (script-mode, no compiler) ==="
cmake -S $PSScriptRoot -B "$PSScriptRoot/build-tests" -G Ninja
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
ctest --test-dir "$PSScriptRoot/build-tests" --output-on-failure
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== CMakeRoutines tests: layer 2 (target-level, needs compiler) ==="
$targetArgs = @("-S", "$PSScriptRoot/target", "-B", "$PSScriptRoot/build-target", "-G", "Ninja")
if ($CCompiler) { $targetArgs += "-DCMAKE_C_COMPILER=$CCompiler" }
if ($CxxCompiler) { $targetArgs += "-DCMAKE_CXX_COMPILER=$CxxCompiler" }
cmake @targetArgs
exit $LASTEXITCODE
