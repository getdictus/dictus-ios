#!/bin/sh
# release-notes.sh — App Store Connect "What's New" from ReleaseNotes/<version>/ (#974).
#
# ReleaseNotes/<version>/<locale>.txt is the one source for a version's notes: the app shows
# the same file once after the update and from Settings (a symbol, a title and a sentence per
# change). This script turns it into the store's plain text and sends that to the App Store
# version's localizations, so the store and the app say the same words:
#
#   Nouveautés de la 2.0.2
#   • Écrivez-nous depuis l'app : Réglages > À propos > Envoyer un retour…
#
# The title line, then one `• <title><sep><sentence>` line per change; <sep> is " : " in
# French and ": " elsewhere. The symbol lines are the app's only.
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

# The store text of one file: blocks separated by blank lines, the first one the title, every
# other one "symbol / title / sentence" (the format ReleaseNotes.swift reads).
store_text() {
  awk -v sep="$2" 'BEGIN { RS = ""; FS = "\n" }
    NR == 1 { print $1; next }
    { print "• " $2 sep $3 }' "$1"
}

for PAIR in fr-FR:fr en-US:en en-GB:en de-DE:de es-ES:es; do
  ASC_LOCALE=${PAIR%%:*}
  FILE=${PAIR#*:}
  if [ "$FILE" = fr ]; then SEP=" : "; else SEP=": "; fi
  TEXT=$(store_text "$DIR/$FILE.txt" "$SEP")
  if [ "$MODE" = "--apply" ]; then
    asc localizations update --app "$ASC_APP_ID" --version "$VERSION" --platform IOS \
      --locale "$ASC_LOCALE" --whats-new "$TEXT"
    echo "✓ $ASC_LOCALE"
  else
    printf '── %s (%s.txt)\n%s\n\n' "$ASC_LOCALE" "$FILE" "$TEXT"
  fi
done

[ "$MODE" = "--apply" ] || echo "Nothing sent. Run again with --apply to set What's New on $VERSION."
