#!/usr/bin/env bash
# Installs the Godot 4.5 headless-capable Linux binary as /usr/local/bin/godot
# and builds the project's script class cache so tests run immediately.
# Idempotent. Run from the directory that contains the Modding checkout, or
# from anywhere if the project is not present (install only).
set -euo pipefail
GODOT_VERSION="4.5-stable"
GODOT_FILE="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_FILE}.zip"
if ! command -v godot >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  curl -sSL -o "$tmp/godot.zip" "$GODOT_URL"
  unzip -q -o "$tmp/godot.zip" -d "$tmp"
  install -m 755 "$tmp/$GODOT_FILE" /usr/local/bin/godot
  rm -rf "$tmp"
fi
godot --headless --version
for p in Modding/ring-giver/game ring-giver/game game; do
  if [ -f "$p/project.godot" ]; then
    godot --headless --path "$p" --import >/dev/null 2>&1 || true
    echo "class cache built for $p"
    break
  fi
done
