#!/usr/bin/env bash
# Exports the game and puts the hub beside it, because a pack cannot hold a program to run.
# tools/package_build.sh linux [folder]    tools/package_build.sh windows [folder]
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${1:-linux}"
ELECTRON_VERSION="$(node -p "require('./hub/node_modules/electron/package.json').version")"
case "$TARGET" in
  linux)   OUT="${2:-build/test}";    PRESET="Linux";           BINARY="NEH-School.x86_64" ;;
  windows) OUT="${2:-build/windows}"; PRESET="Windows Desktop"; BINARY="NEH-School.exe" ;;
  *) echo "linux hoặc windows"; exit 1 ;;
esac
mkdir -p "$OUT"
godot --headless --path . --export-release "$PRESET" "$OUT/$BINARY"
rm -rf "$OUT/hub" "$OUT/data" "$OUT/docs"
mkdir -p "$OUT/hub" "$OUT/data" "$OUT/docs"
for item in main.js desktop.js profiles.js realweb.js package.json assets shell web node_modules; do
  cp -a "hub/$item" "$OUT/hub/"
done
# The web stack reads these from the project root.
cp data/social_posts.json "$OUT/data/"
cp docs/town-school.png "$OUT/docs/"
grep -o "photo: '[^']*'" hub/web/news-data.js | cut -d"'" -f2 | sort -u | while read -r photo; do
  cp "docs/$photo" "$OUT/docs/"
done
if [ "$TARGET" = windows ]; then
  ARCHIVE="electron-v$ELECTRON_VERSION-win32-x64.zip"
  CACHE="$(mktemp -d)"
  curl -fsSL -o "$CACHE/$ARCHIVE" "https://github.com/electron/electron/releases/download/v$ELECTRON_VERSION/$ARCHIVE"
  rm -rf "$OUT/hub/node_modules/electron/dist"
  mkdir -p "$OUT/hub/node_modules/electron/dist"
  unzip -q "$CACHE/$ARCHIVE" -d "$OUT/hub/node_modules/electron/dist"
  rm -rf "$CACHE"
fi
du -sh "$OUT"
