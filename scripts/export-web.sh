#!/usr/bin/env bash
# Exports the prototype to ring-giver/web (single-threaded Godot web build,
# which runs on GitHub Pages without special headers). Needs the Godot web
# export templates; setup-web-templates.sh installs them.
set -euo pipefail
cd "$(dirname "$0")/../game"
godot --headless --path . --import >/dev/null 2>&1 || true
mkdir -p ../web
godot --headless --path . --export-release "Web" ../web/index.html
ls -la ../web
