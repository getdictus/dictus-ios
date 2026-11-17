#!/bin/sh
# release-notes.sh — App Store Connect "What's New" from ReleaseNotes/<version>/ (#974).
#
# ReleaseNotes/<version>/<locale>.txt is the one source for a version's notes: the app shows
# the same file once after the update and from Settings. This script sends it to the App
# Store version's localizations, so the store and the app say the same words.
#
#   ASC locale   file
#   fr-FR        fr.txt
#   en-US        en.txt
#   en-GB        en.txt   (en-GB reads the en-US text)
#   de-DE        de.txt
#   es-ES        es.txt
#
# Usage:
#   scripts/release-notes.sh 2.0.2            # print what would be sent (nothing is sent)
#   scripts/release-notes.sh 2.0.2 --apply    # set What's New on the 2.0.2 App Store version
#
# --apply needs `asc` authenticated and the App Store version already created in App Store
# Connect. See docs/release-notes.md.
set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
ASC_APP_ID="6761262378"

VERSION="${1:-}"
MODE="${2:-}"
case "$VERSION" in
  ''|-*) echo "usage: scripts/release-notes.sh <version> [--apply]" >&2; exit 1 ;;
esac
case "$MODE" in
  ''|--apply) : ;;
  *) echo "usage: scripts/release-notes.sh <version> [--apply]" >&2; exit 1 ;;
esac

DIR="$REPO_ROOT/ReleaseNotes/$VERSION"
for FILE in fr en de es; do
  [ -s "$DIR/$FILE.txt" ] || { echo "error: $DIR/$FILE.txt is missing or empty." >&2; exit 1; }
done

for PAIR in fr-FR:fr en-US:en en-GB:en de-DE:de es-ES:es; do
  ASC_LOCALE=${PAIR%%:*}
  TEXT=$(cat "$DIR/${PAIR#*:}.txt")
  if [ "$MODE" = "--apply" ]; then
    asc localizations update --app "$ASC_APP_ID" --version "$VERSION" --platform IOS \
      --locale "$ASC_LOCALE" --whats-new "$TEXT"
    echo "✓ $ASC_LOCALE"
  else
    printf '── %s (%s.txt)\n%s\n\n' "$ASC_LOCALE" "${PAIR#*:}" "$TEXT"
  fi
done

[ "$MODE" = "--apply" ] || echo "Nothing sent. Run again with --apply to set What's New on $VERSION."
