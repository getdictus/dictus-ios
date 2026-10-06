#!/bin/bash
# Fetch the official Apple iPhone bezel used by screenshots.html (issue #643).
#
# The bezel comes from Apple Design Resources:
#   https://developer.apple.com/design/resources/#product-bezels
#   https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-17.dmg
#
# WHY it is fetched and never committed: the DMG carries the "Apple Design
# Resources" license. It allows using the bezels in mock-ups and in images of
# them, but forbids redistributing the resources themselves. This repository is
# public, so the PNG lives in assets/appstore/.bezels/ (git-ignored), and every
# machine that exports the screenshots fetches its own copy.
#
# The DMG asks for the license to be accepted when it is mounted. This script
# prints it and asks; set APPLE_DESIGN_RESOURCES_LICENSE=accept to answer yes
# without a prompt (only if you have read and accepted it).
#
# Usage: assets/appstore/tools/fetch-bezel.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$HERE/.bezels"
URL="https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-17.dmg"
MODEL="iPhone 17 Pro Max"
COLOURS=("Deep Blue" "Silver")

mkdir -p "$OUT"
missing=0
for colour in "${COLOURS[@]}"; do
  [ -f "$OUT/$MODEL - $colour - Portrait.png" ] || missing=1
done
if [ "$missing" = 0 ]; then
  echo "Bezels already present in $OUT"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'hdiutil detach -quiet "$TMP/mnt" 2>/dev/null || true; rm -rf "$TMP"' EXIT

echo "Downloading $URL"
curl -fL --progress-bar -o "$TMP/bezel.dmg" "$URL"

mkdir -p "$TMP/mnt"
if [ "${APPLE_DESIGN_RESOURCES_LICENSE:-}" = "accept" ]; then
  # `yes` dies of SIGPIPE once hdiutil stops reading, which pipefail would
  # report as a failure: judge the mount by its result instead.
  (yes | PAGER=cat hdiutil attach -nobrowse -noautoopen -readonly \
    -mountpoint "$TMP/mnt" "$TMP/bezel.dmg" >/dev/null) || true
  [ -d "$TMP/mnt/PNG" ] || { echo "Mounting the bezel DMG failed" >&2; exit 1; }
else
  # Interactive: hdiutil shows the license and asks Y/N itself.
  hdiutil attach -nobrowse -noautoopen -readonly -mountpoint "$TMP/mnt" "$TMP/bezel.dmg" >/dev/null
fi

for colour in "${COLOURS[@]}"; do
  cp "$TMP/mnt/PNG/$MODEL/$MODEL - $colour - Portrait.png" "$OUT/"
done
echo "Bezels copied to $OUT"
