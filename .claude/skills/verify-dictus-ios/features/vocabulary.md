# Custom vocabulary

- **ID:** `vocabulary`
- **Tier:** Pro
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.pro.vocabulary`, `app.pro.vocabulary.term-editor`, `app.pro.vocabulary.suggestions`, `app.pro.vocabulary.pair-review`, `app.onboarding.vocabulary-scene` — see [screens.md](screens.md)

## Sub-features

- `vocabulary.add`: « Ajouter un terme »: the correct spelling and the variant, if known (how Dictus mishears it). A term saved alone lists as « En attente d’erreurs à corriger » and replaces nothing (#819).
- `vocabulary.edit`: Edit a term.
- `vocabulary.delete`: Delete a term.
- `vocabulary.reset`: « Réinitialiser le vocabulaire ».
- `vocabulary.suggestions`: « Analyser mes transcriptions » opens « Suggestions depuis l’historique »: words the user corrected, offered, never imposed. The screen's « Comment ça marche » card explains it and names the button (#829).
- `vocabulary.term-variants`: the sheet's first section, « Vos orthographes, écrites autrement » (#512 step 2): spans History wrote close to a spelling the user wrote themselves (`cloud code` for the term `Claude Code`), seen in at least two dictations, one row per spelling, at most 10 rows. Terms come first, including a term saved without a variant (#819); then words the keyboard learned, marked « Tapé au clavier, pas encore un terme ». Each row has « Accepter » and « Ignorer », no « Modifier ». « Accepter » opens « Avant l’ajout »: one sentence saying the change, then the term and the new variant in two editable fields (the term's existing variants listed above the new one), « Annuler » / « Ajouter ». « Ajouter » adds the variant to the term (a pending term stops being pending), or creates a new term from a learned word. « Ignorer » hides the row for good.
- `vocabulary.apply`: Terms are applied to every transcription.
- `vocabulary.toggle`: « Vocabulaire » on/off switch.

## How to get to it (user POV)

1. With Pro, Dictus → Réglages → Dictus Pro → Vocabulaire.
2. Tap « Ajouter un terme », type the word and, if known, how it comes out wrong, save.
3. Tap « Analyser mes transcriptions »: the suggestions from History, your own spellings written differently first.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.debugProEntitlementForced -bool YES
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Dictus Pro, Pro actif"   # during the trial: "Dictus Pro, Pro · 14 jours restants"
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Vocabulaire, Apprenez à Dictus vos termes techniques, Activé"
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Ajouter un terme"
.claude/skills/verify-dictus-ios/scripts/evidence.sh vocabulary-term-editor
```

Type into the focused field with `axe type 'Dr Nguyen' --udid <udid>`.

### Variants of your terms (`vocabulary.term-variants`)

Nothing records: the vocabulary and History are written into the App Group container with the app stopped, the way PR #814 was checked. `seed` takes the terms (`term=variant,variant;…`, `term=` for a term without a variant) and the dictations (`text|text|…`), clears the ignore list, then relaunches the app in French, which reads them. `open_vocabulary` goes from the tab bar to Vocabulaire, `open_suggestions` on to the sheet. Each row's buttons carry its rank, from 1 down the first section: `vocabulary.pair.<rank>.accept` and `vocabulary.pair.<rank>.ignore`. `expect_rows <n>` counts the `.accept` identifiers on screen (only the rows that fit) and fails on any other count.

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
               "variants": [v for v in t.split("=")[1].split(",") if v], "isEnabled": True, "dateAdded": iso(now)}
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
open_vocabulary() {
  local pro
  $D tab Réglages; sleep 1
  # « Dictus Pro, Pro actif », or « Dictus Pro, Pro · 14 jours restants » while the trial runs.
  pro=$($D tree | python3 -c '
import json, sys
def walk(n):
    if n.get("type") == "Button" and (n.get("AXLabel") or "").startswith("Dictus Pro, "): print(n["AXLabel"]); sys.exit()
    for c in n.get("children") or []: walk(c)
for r in json.load(sys.stdin): walk(r)')
  $D tap-label "$pro"
  $D tap-label "Vocabulaire, Apprenez à Dictus vos termes techniques, Activé"
  $D wait-label "Vos termes"
}
open_suggestions() {
  # Below the terms: with several, the list renders the button only once scrolled to.
  axe swipe --start-x 200 --start-y 700 --end-x 200 --end-y 200 --udid "$UDID" >/dev/null; sleep 1
  $D tap-label "Analyser mes transcriptions"
  $D wait-label "Vos orthographes, écrites autrement" 10
}
expect_rows() {
  local n
  n=$($D tree | python3 -c '
import json, re, sys
def walk(n):
    own = bool(re.fullmatch(r"vocabulary\.pair\.\d+\.accept", n.get("AXUniqueId") or ""))
    return own + sum(walk(c) for c in n.get("children") or [])
print(sum(walk(r) for r in json.load(sys.stdin)))')
  [ "$n" = "$1" ] && echo "rows $n" || { echo "error: $n rows, expected $1" >&2; return 1; }
}
# Whether the review sheet's « Ajouter » is enabled: prints yes or no. The identifier is on
# a Group wrapper too, always enabled: read the Button.
add_enabled() {
  $D tree | python3 -c '
import json, sys
def find(n):
    if n.get("AXUniqueId") == "vocabulary.pair.review.confirm" and n.get("type") == "Button": return n
    for c in n.get("children") or []:
        f = find(c)
        if f: return f
hits = [f for f in (find(r) for r in json.load(sys.stdin)) if f]
print(("yes" if hits[0].get("enabled") else "no") if hits else "error: no confirm button")'
}
variants() {
  python3 -c 'import json,sys; print({e["term"]: e["variants"] for e in json.load(open(sys.argv[1]))})' "$GROUP_DIR/vocabulary.json"
}

# 1. At most 10 rows: twelve terms, each misheard (last letter doubled) in two dictations.
T="" X=""
for n in Zorvalix Kentrabo Plimdora Quastemi Brunzeta Vothrami Dashkelo Fenturak Glimsoda Hartvelo Joskarin Lunderfo; do
  h=$(echo "$n" | tr '[:upper:]' '[:lower:]')${n: -1}
  T="$T;$n=${h}z" X="$X|$h est lent|$h encore"
done
seed "${T#;}" "${X#|}"
M=$($D log-mark)
open_vocabulary; open_suggestions
$D wait-log 'VocabularySuggestions .*termVariants=10' 10 "$M"
$E vocabulary-suggestions-cap
# Ten rows do not fit on screen: scroll to the last one. No row 11 (rank 11 would be a
# step 1 row, which has no identifier).
axe swipe --start-x 200 --start-y 700 --end-x 200 --end-y 250 --udid "$UDID" >/dev/null; sleep 1
$D wait-id vocabulary.pair.10.accept
$D gone-id vocabulary.pair.11.accept

# 2. Accept, Annuler, an emptied variant, then Ajouter: one term, `cloud code` in three dictations.
SEED_TEXTS="cloud code est lent|on parle de cloud code|cloud code encore|le reste est bon|rien à signaler"
seed "Claude Code=clode code" "$SEED_TEXTS"
M=$($D log-mark)
open_vocabulary; open_suggestions
$D wait-log 'VocabularySuggestions .*termVariants=1' 10 "$M"
$D wait-label "Écrit : cloud code"
expect_rows 1
$E vocabulary-suggestions
$D tap-id vocabulary.pair.1.accept
$D wait-label "Avant l’ajout"
$D wait-label "Variante « cloud code » ajoutée à « Claude Code »."
$D wait-label "Désormais, quand Dictus écrit « cloud code », il écrit « Claude Code » à la place."
$E vocabulary-pair-review
$D tap-label Annuler                                  # stores nothing
$D gone-id vocabulary.pair.review.confirm
variants                                              # → {'Claude Code': ['clode code']}
$D tap-id vocabulary.pair.1.accept
$D tap-id vocabulary.pair.review.variant              # empty the variant (12 backspaces)
axe key-sequence --keycodes 42,42,42,42,42,42,42,42,42,42,42,42 --udid "$UDID" >/dev/null
$D wait-label "Rien ne changerait. Vérifiez le terme et la variante."
[ "$(add_enabled)" = no ] && echo "Ajouter disabled" || { echo "error: Ajouter not disabled on an empty variant" >&2; false; }
axe type 'cloud code' --udid "$UDID" >/dev/null       # back as suggested
$D wait-label "Variante « cloud code » ajoutée à « Claude Code »."
$D tap-id vocabulary.pair.review.confirm              # « Ajouter »
$D gone-id vocabulary.pair.1.accept                   # the row leaves the list
variants                                              # → {'Claude Code': ['clode code', 'cloud code']}

# 3. Ignore, on the same row (seeded again, ignore list cleared).
seed "Claude Code=clode code" "$SEED_TEXTS"
open_vocabulary; open_suggestions
$D tap-id vocabulary.pair.1.ignore
$D gone-id vocabulary.pair.1.accept
ignored=no                                            # the defaults flush takes a moment
for _ in 1 2 3 4 5 6 7 8 9 10; do
  xcrun simctl spawn "$UDID" defaults read "$GROUP_DIR/Library/Preferences/group.solutions.pivi.dictus.plist" \
    dictus.vocabularySuggestionsIgnored 2>/dev/null | grep -q 'pair:claude code|cloud code' && { ignored=yes; break; }
  sleep 1
done
if [ "$ignored" = yes ]; then echo "ignored: pair:claude code|cloud code"; else echo "error: ignore not stored" >&2; false; fi
$D tap-label OK                                       # close, open again: still hidden
sleep 1; $E vocabulary-list                           # once the sheet has slid away
$D tap-label "Analyser mes transcriptions"
$D wait-label "Suggestions depuis l’historique"; sleep 2; expect_rows 0

# 4. A term saved without a variant (#819) is pending; accepting its suggestion ends that.
seed "Claude Code=" "$SEED_TEXTS"
open_vocabulary
$D wait-label "En attente d’erreurs à corriger"
$E vocabulary-pending
open_suggestions
$D tap-id vocabulary.pair.1.accept
$D wait-label "Variante « cloud code » ajoutée à « Claude Code »."
$D tap-id vocabulary.pair.review.confirm
$D gone-id vocabulary.pair.1.accept
variants                                              # → {'Claude Code': ['cloud code']}
$D tap-label OK
$D wait-label "Remplace : cloud code"                 # no longer « En attente d’erreurs à corriger »
```

## Gotchas

- **Not drivable in the simulator:** whether a term actually fixes a transcription (needs a recording). FluidAudio's vocabulary boosting is English-only; the French correction path is the post-pass.
- Suggestions stay empty without history. A seeded History proves the screens and the store writes, not whether real dictations produce rows worth adding: that go/no-go is on Pierre's iPhone, on his own History.
- Row identifiers carry the rank (`vocabulary.pair.<rank>.accept`, `.ignore`), so rows on screen never share one and `tap-id` works with any number of rows. The numbering runs on through the two step 1 sections below, whose « Ajouter » / « Ignorer » have no identifier.
- No « Modifier » on a row: the review sheet is the edit path. Its two fields, `vocabulary.pair.review.term` and `vocabulary.pair.review.variant`, come filled in and editable, and the sentence on top (`vocabulary.pair.review.summary`) follows what they hold. When they would change nothing (empty variant, variant equal to the term, or one the term already has), it reads « Rien ne changerait. Vérifiez le terme et la variante. » and « Ajouter » is disabled.
- A term typed in the review sheet with other capitals than a stored one gains the variant; it does not create a second term.
- A term saved without a variant lists as « En attente d’erreurs à corriger » and replaces nothing. The generator still looks for its spelling, so it gets suggestions like any term, and accepting one makes it list as « Remplace : … ».
- Learned-word rows (« Tapé au clavier, pas encore un terme »; the review sheet then reads « Nouveau terme « … », avec la variante « … ». ») are not seeded here: they need words in the keyboard's learned dictionary. The recipe covers vocabulary terms only.
- The sheet's title is « Suggestions depuis l’historique » and the review sheet's « Avant l’ajout », both with a typographic apostrophe: `wait-label` needs it.
- In step 1, the eleventh and twelfth terms are past the cap: their spellings can come back lower down, in « Absents du dictionnaire, vus dans plusieurs dictées », which is step 1's miner and expected.
- `seed` overwrites `vocabulary.json` and `transcription_history.json` and deletes the ignore list. That is harmless on the device `launch.sh` created for the run. On any other device (e.g. `Dictus Smoke`), copy the two files out first and put them back afterwards.
