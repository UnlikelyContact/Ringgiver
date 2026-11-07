#!/usr/bin/env bash
# Installs only the Godot 4.5 web export templates (from the 1.3 GB bundle).
set -euo pipefail
V="4.5.stable"
DEST="$HOME/.local/share/godot/export_templates/$V"
if [ -f "$DEST/web_nothreads_release.zip" ]; then
  echo "web templates present"; exit 0
fi
tmp="$(mktemp -d)"
for i in 1 2 3 4 5; do
  curl -sSL -C - -o "$tmp/templates.tpz" "https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_export_templates.tpz" && break
  sleep 5
done
mkdir -p "$DEST"
unzip -q -o "$tmp/templates.tpz" 'templates/web_nothreads_release.zip' 'templates/web_nothreads_debug.zip' -d "$tmp"
mv "$tmp"/templates/* "$DEST"/
rm -rf "$tmp"
ls -la "$DEST"
