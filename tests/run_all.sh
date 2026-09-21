#!/usr/bin/env bash
# CMakeRoutines full test runner (Linux/macOS).
# Usage: CXX_COMPILER=g++ ./tests/run_all.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== CMakeRoutines tests: layer 1 (script-mode, no compiler) ==="
cmake -S "$SCRIPT_DIR" -B "$SCRIPT_DIR/build-tests" -G Ninja
ctest --test-dir "$SCRIPT_DIR/build-tests" --output-on-failure

echo "=== CMakeRoutines tests: layer 2 (target-level, needs compiler) ==="
ARGS=(-S "$SCRIPT_DIR/target" -B "$SCRIPT_DIR/build-target" -G Ninja)
[[ -n "${CXX_COMPILER:-}" ]] && ARGS+=("-DCMAKE_CXX_COMPILER=$CXX_COMPILER")
[[ -n "${C_COMPILER:-}" ]] && ARGS+=("-DCMAKE_C_COMPILER=$C_COMPILER")
cmake "${ARGS[@]}"
echo "CMakeRoutines tests: OK"
