#!/usr/bin/env bash
# Runs the headless sim test suite. Always refreshes Godot's class cache first
# so newly added class_name scripts resolve. Fails if any test fails OR if
# Godot printed a script error (parse or runtime), which the runner itself
# cannot always count.
set -uo pipefail
cd "$(dirname "$0")/../game"
godot --headless --path . --import >/dev/null 2>&1 || true
out="$(mktemp)"
godot --headless --path . -s tests/run_tests.gd "$@" 2>&1 | grep -v '^Godot Engine v' | tee "$out"
status=${PIPESTATUS[0]}
if grep -q 'SCRIPT ERROR\|ERROR: Failed to load script' "$out"; then
  echo "script errors found in output; failing" >&2
  status=1
fi
rm -f "$out"
exit "$status"
