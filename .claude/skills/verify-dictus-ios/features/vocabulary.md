# Custom vocabulary

- **ID:** `vocabulary`
- **Tier:** Pro
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.pro.vocabulary`, `app.pro.vocabulary.term-editor`, `app.pro.vocabulary.suggestions`, `app.pro.vocabulary.pair-review`, `app.onboarding.vocabulary-scene` — see [screens.md](screens.md)

## Sub-features

- `vocabulary.add`: « Ajouter un terme »: the correct spelling and how Dictus mishears it.
- `vocabulary.edit`: Edit a term.
- `vocabulary.delete`: Delete a term.
- `vocabulary.reset`: « Réinitialiser le vocabulaire ».
- `vocabulary.suggestions`: « Analyser mes transcriptions » opens « Suggestions depuis l'historique »: words the user corrected, offered, never imposed.
- `vocabulary.term-variants`: the sheet's first section, « Variantes de vos termes » (#512 step 2): spans History wrote close to one of the user's terms (`cloud code` for `Claude Code`), seen in at least two dictations, at most 5 rows. Each row: « Accepter » opens « Avant l'ajout », which shows the term, its variants and the new one in green before « Ajouter » stores it; « Modifier » opens the term sheet with the variant filled in; « Ignorer » hides the row for good.
- `vocabulary.apply`: Terms are applied to every transcription.
- `vocabulary.toggle`: « Vocabulaire » on/off switch.

## How to get to it (user POV)

1. With Pro, Dictus → Réglages → Dictus Pro → Vocabulaire.
2. Tap « Ajouter un terme », type the word and how it comes out wrong, save.
3. Tap « Analyser mes transcriptions »: the suggestions from History, variants of your terms first.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.debugProEntitlementForced -bool YES
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Dictus Pro, Pro actif"
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Vocabulaire, Apprenez à Dictus vos termes techniques, Activé"
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Ajouter un terme"
.claude/skills/verify-dictus-ios/scripts/evidence.sh vocabulary-term-editor
```

Type into the focused field with `axe type 'Dr Nguyen' --udid <udid>`.

### Variants of your terms (`vocabulary.term-variants`)

Nothing records: the vocabulary and History are written into the App Group container with the app stopped, the way PR #814 was checked. `seed` takes the terms (`term=variant,variant;…`) and the dictations (`text|text|…`), clears the ignore list, then relaunches the app in French, which reads them. `open_suggestions` goes from the tab bar to the sheet. `expect_rows <n>` counts the « Accepter » buttons on screen and fails on any other count.

```bash
export DICTUS_VERIFY_RUN=<run dir from the READY line>
. "$DICTUS_VERIFY_RUN/run.env"
D=.claude/skills/verify-dictus-ios/scripts/drive.sh
E=.claude/skills/verify-dictus-ios/scripts/evidence.sh
$D set-default dictus.debugProEntitlementForced -bool YES

seed() {
  xcrun simctl terminate "$UDID" com.pivi.dictus >/dev/null 2>&1 || true
  python3 - "$GROUP_DIR" "$1" "$2" <<'PY'
import datetime, json, sys, uuid
group, terms, texts = sys.argv[1:]
now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
iso = lambda d: d.isoformat().replace("+00:00", "Z")
vocabulary = [{"id": str(uuid.uuid4()).upper(), "term": t.split("=")[0],
               "variants": t.split("=")[1].split(","), "isEnabled": True, "dateAdded": iso(now)}
              for t in terms.split(";")]
history = [{"id": str(uuid.uuid4()).upper(), "text": text, "language": "fr", "durationSeconds": 5,
            "createdAt": iso(now - datetime.timedelta(minutes=i)), "sttProvider": "PK"}
           for i, text in enumerate(texts.split("|"))]
json.dump(vocabulary, open(f"{group}/vocabulary.json", "w"), ensure_ascii=False)
json.dump(history, open(f"{group}/transcription_history.json", "w"), ensure_ascii=False)
PY
  xcrun simctl spawn "$UDID" defaults delete \
    "$GROUP_DIR/Library/Preferences/group.solutions.pivi.dictus.plist" dictus.vocabularySuggestionsIgnored 2>/dev/null || true
  $D relaunch -AppleLanguages '(fr)' -AppleLocale fr_FR   # French UI on any device
}
open_suggestions() {
  $D tab Réglages
  $D tap-label "Dictus Pro, Pro actif"
  $D tap-label "Vocabulaire, Apprenez à Dictus vos termes techniques, Activé"
  $D wait-label "Vos termes"
  # Below the terms: with several, the list renders the button only once scrolled to.
  axe swipe --start-x 200 --start-y 700 --end-x 200 --end-y 200 --udid "$UDID" >/dev/null; sleep 1
  $D tap-label "Analyser mes transcriptions"
  $D wait-label "Variantes de vos termes" 10
}
# The row's « Modifier » and « Ignorer » have no identifier, and the Vocabulaire screen
# under the sheet has its own « Modifier »: tap the one on the line of the row's
# `vocabulary.pair.accept` (one row on screen, so that identifier is unique).
tap_in_row() {
  local xy
  xy=$($D tree | python3 -c '
import json, sys
label = sys.argv[1]
nodes = []
def walk(n):
    nodes.append(n)
    for c in n.get("children") or []: walk(c)
for r in json.load(sys.stdin): walk(r)
accept = [n["frame"] for n in nodes if n.get("AXUniqueId") == "vocabulary.pair.accept"]
assert len(accept) == 1, "%d rows on screen, expected 1" % len(accept)
ay = accept[0]["y"] + accept[0]["height"] / 2
hits = [n["frame"] for n in nodes if n.get("AXLabel") == label and n.get("type") == "Button"
        and n["frame"]["y"] <= ay <= n["frame"]["y"] + n["frame"]["height"]]
assert len(hits) == 1, "%d %r buttons on the row" % (len(hits), label)
f = hits[0]
print(round(f["x"] + f["width"] / 2), round(f["y"] + f["height"] / 2))' "$1") || return 1
  axe tap -x "${xy% *}" -y "${xy#* }" --udid "$UDID" >/dev/null && echo "tapped row's $1 at $xy"
}
expect_rows() {
  local n
  n=$($D tree | python3 -c '
import json, sys
def walk(n):
    return (n.get("AXUniqueId") == "vocabulary.pair.accept") + sum(walk(c) for c in n.get("children") or [])
print(sum(walk(r) for r in json.load(sys.stdin)))')
  [ "$n" = "$1" ] && echo "rows $n" || { echo "error: $n rows, expected $1" >&2; return 1; }
}

# 1. At most 5 rows: seven terms, each misheard (last letter doubled) in two dictations.
T="" X=""
for n in Zorvalix Kentrabo Plimdora Quastemi Brunzeta Vothrami Dashkelo; do
  h=$(echo "$n" | tr '[:upper:]' '[:lower:]')${n: -1}
  T="$T;$n=${h}z" X="$X|$h est lent|$h encore"
done
seed "${T#;}" "${X#|}"
M=$($D log-mark)
open_suggestions
$D wait-log 'VocabularySuggestions .*termVariants=5' 10 "$M"
expect_rows 5
$E vocabulary-suggestions-cap

# 2. Accept: one term, `cloud code` in three dictations.
SEED_TERMS="Claude Code=clode code"
SEED_TEXTS="cloud code est lent|on parle de cloud code|cloud code encore|le reste est bon|rien à signaler"
seed "$SEED_TERMS" "$SEED_TEXTS"
M=$($D log-mark)
open_suggestions
$D wait-log 'VocabularySuggestions .*termVariants=1' 10 "$M"
$D wait-label "Écrit : cloud code"
expect_rows 1
$E vocabulary-suggestions
$D tap-id vocabulary.pair.accept
$D wait-label "Avant l’ajout"
$D wait-label "Désormais, quand Dictus écrit « cloud code », il écrit « Claude Code » à la place."
$E vocabulary-pair-review
$D tap-label Annuler                                  # stores nothing
$D gone-id vocabulary.pair.review.confirm
if grep -q 'cloud code' "$GROUP_DIR/vocabulary.json"; then echo "error: stored on Annuler" >&2; false; else echo "not stored"; fi
$D tap-id vocabulary.pair.accept
$D tap-id vocabulary.pair.review.confirm              # « Ajouter »
$D gone-id vocabulary.pair.accept                     # the row leaves the list
python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[0]["variants"])' "$GROUP_DIR/vocabulary.json"
# → ['clode code', 'cloud code']

# 3. Edit, then Ignore, on the same row (seeded again, ignore list cleared).
seed "$SEED_TERMS" "$SEED_TEXTS"
open_suggestions
tap_in_row Modifier
$D wait-label "Déjà dans votre vocabulaire. Cette variante y sera ajoutée."
$E vocabulary-pair-edit
$D tap-label Annuler                                  # the row stays
$D wait-id vocabulary.pair.accept
tap_in_row Ignorer
$D gone-id vocabulary.pair.accept
ignored=no                                            # the defaults flush takes a moment
for _ in 1 2 3 4 5 6 7 8 9 10; do
  xcrun simctl spawn "$UDID" defaults read "$GROUP_DIR/Library/Preferences/group.solutions.pivi.dictus.plist" \
    dictus.vocabularySuggestionsIgnored 2>/dev/null | grep -q 'pair:claude code|cloud code' && { ignored=yes; break; }
  sleep 1
done
if [ "$ignored" = yes ]; then echo "ignored: pair:claude code|cloud code"; else echo "error: ignore not stored" >&2; false; fi
$D tap-label OK                                       # close, open again: still hidden
sleep 1; $E vocabulary-list                          # once the sheet has slid away
$D tap-label "Analyser mes transcriptions"
$D wait-label "Suggestions depuis l’historique"; sleep 2; expect_rows 0
```

## Gotchas

- **Not drivable in the simulator:** whether a term actually fixes a transcription (needs a recording). FluidAudio's vocabulary boosting is English-only; the French correction path is the post-pass.
- Suggestions stay empty without history. A seeded History proves the screens and the store writes, not whether real dictations produce rows worth adding: that go/no-go is on Pierre's iPhone, on his own History.
- `vocabulary.pair.accept` is on **every** variant row, and « Modifier » / « Ignorer » have no identifier: `tap-id` refuses as soon as two rows are on screen. That is why steps 2 and 3 seed a single term; with several rows, only the cap is checked (by counting), and no row is tapped.
- `tap-label Modifier` refuses even with one row: the Vocabulaire screen under the sheet keeps its toolbar « Modifier » in the tree. `tap_in_row` taps the button with that label on the line of the row's `vocabulary.pair.accept`, by its frame. It is a coordinate tap anchored on an identifier, and the first thing to replace if the rows get their own identifiers (e.g. `vocabulary.pair.edit`, `vocabulary.pair.ignore`).
- The sheet still reads « Suggestions depuis l'historique »: only the Vocabulaire button was renamed « Analyser mes transcriptions ».
- « Modifier » on a variant opens « Nouveau terme » with both fields filled and the footer « Déjà dans votre vocabulaire. Cette variante y sera ajoutée. »: saving adds the variant to the existing term, it does not create a second one.
- In step 1, the sixth and seventh terms are past the cap: their spellings can come back lower down, in « Absents du dictionnaire, vus dans plusieurs dictées », which is step 1's miner and expected.
- `seed` overwrites `vocabulary.json` and `transcription_history.json` and deletes the ignore list. That is harmless on the device `launch.sh` created for the run. On any other device (e.g. `Dictus Smoke`), copy the two files out first and put them back afterwards.
