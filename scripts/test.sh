#!/usr/bin/env bash
# Runs the headless sim test suite. Always refreshes Godot's class cache first
# so newly added class_name scripts resolve.
set -euo pipefail
cd "$(dirname "$0")/../game"
godot --headless --path . --import >/dev/null 2>&1 || true
exec godot --headless --path . -s tests/run_tests.gd "$@"
