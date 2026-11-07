#!/usr/bin/env bash
# Installs the Godot 4.5 Linux binary as /usr/local/bin/godot (with sudo when
# not root) and builds this project's script class cache so tests run
# immediately. Idempotent, and works from any working directory: the project
# is found relative to this script.
set -euo pipefail
GODOT_VERSION="4.5-stable"
GODOT_FILE="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_FILE}.zip"
if ! command -v godot >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  curl -sSL -o "$tmp/godot.zip" "$GODOT_URL"
  unzip -q -o "$tmp/godot.zip" -d "$tmp"
  if [ "$(id -u)" -eq 0 ]; then
    install -m 755 "$tmp/$GODOT_FILE" /usr/local/bin/godot
  else
    sudo install -m 755 "$tmp/$GODOT_FILE" /usr/local/bin/godot
  fi
  rm -rf "$tmp"
fi
godot --headless --version
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
proj="$here/../game"
if [ -f "$proj/project.godot" ] && [ -w "$proj" ]; then
  godot --headless --path "$proj" --import >/dev/null 2>&1 || true
  echo "class cache built for $proj"
fi
