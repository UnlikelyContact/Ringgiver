#!/usr/bin/env bash
# Runs the headless sim test suite. Builds the class cache first if missing.
set -euo pipefail
cd "$(dirname "$0")/../game"
if [ ! -f .godot/global_script_class_cache.cfg ]; then
  godot --headless --path . --import >/dev/null 2>&1 || true
fi
exec godot --headless --path . -s tests/run_tests.gd "$@"
