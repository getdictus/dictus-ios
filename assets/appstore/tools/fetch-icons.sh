#!/bin/bash
# Fetch the app icons of the slide 1-2 ribbon (issue #643, V4).
#
# Real icons of apps where people write, at 1024 px, from Apple's public iTunes
# lookup API. They are third-party trademarks: like the Apple bezel they are
# NEVER committed. They land in assets/appstore/.icons/ (git-ignored), and each
# machine that exports the screenshots fetches its own copy.
#
# Apple's own apps (Messages, Mail, Notes) are left out on purpose: Apple's
# marketing guidelines restrict their icons in third-party marketing.
#
# Usage: assets/appstore/tools/fetch-icons.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$HERE/.icons"
mkdir -p "$OUT"

# slug:App Store id. Order = order on the ribbon.
APPS=(
  "whatsapp:310633997"
  "gmail:422689480"
  "slack:618783545"
  "instagram:389801252"
  "notion:1232780281"
  "messenger:454638411"
  "outlook:951937596"
  "linkedin:288429040"
  "telegram:686449807"
  "docs:842842640"
  "x:333903271"
  "chatgpt:6448311069"
)

for entry in "${APPS[@]}"; do
  slug="${entry%%:*}"; id="${entry##*:}"
  [ -s "$OUT/$slug.png" ] && continue
  json="$(curl -fsS "https://itunes.apple.com/lookup?id=$id&country=us")"
  name="$(printf '%s' "$json" | python3 -c 'import json,sys; r=json.load(sys.stdin)["results"]; print(r[0]["trackName"] if r else "")')"
  url="$(printf '%s' "$json" | python3 -c 'import json,sys; r=json.load(sys.stdin)["results"]; print(r[0]["artworkUrl512"] if r else "")')"
  [ -n "$url" ] || { echo "No artwork for $slug ($id)" >&2; exit 1; }
  # Same artwork path, larger rendition.
  curl -fsS -o "$OUT/$slug.png" "${url/512x512bb/1024x1024bb}"
  echo "$slug: $name"
done
echo "Icons in $OUT"
