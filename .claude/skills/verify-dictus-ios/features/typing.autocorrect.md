# Autocorrect and suggestions

- **ID:** `typing.autocorrect`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard + DictusCore
- **Screens:** `kbd.keys`, `kbd.suggestions` (not captured) — see [screens.md](screens.md)

## Sub-features

- `typing.suggestions`: Suggestion bar with predictions and corrections.
- `typing.autocorrect-on-space`: A mistyped word is corrected when space is pressed.
- `typing.undo-correction`: The suggestion bar offers to undo the last correction.
- `typing.auto-full-stop`: Double space inserts a full stop.
- `typing.accents`: Long-press a letter for its accents.
- `typing.dead-keys`: Dead keys compose accented letters.
- `typing.autocorrect-toggle`: « Correction automatique » switch in Réglages → Clavier.

## How to get to it (user POV)

1. Type with the Dictus keyboard in Notes or Messages.
2. Suggestions appear above the keys; a mistyped word is corrected when you press space.

## Driving it with axe + Argent

Measured 2026-10-20 (iPhone 17, iOS 26.5): a misspelling followed by space, typed through the Dictus keys in a Rappels field, is corrected.

```bash
D=.claude/skills/verify-dictus-ios/scripts/drive.sh
E=.claude/skills/verify-dictus-ios/scripts/evidence.sh
$D set-default dictus.autocorrectDebugLogging -bool YES   # Debug builds: logs each decision
$D full-access && $D select-keyboard                     # makes Dictus the current keyboard
xcrun simctl launch <udid> com.apple.reminders
$D tap-label Continuer                                   # first-run splash
$D tap-label "Plus tard"                                 # iCloud sync prompt
$D tap-label Rappel                                      # new reminder, title field focused
$D wait-id inputView 10
M=$($D log-mark)
$D type bonjoru                                          # the misspelling, key by key
$E typed-misspelling
$D space                                                 # autocorrect runs on space
$D wait-log 'APPLIED orig="Bonjoru" → "Bonjour"' 10 "$M"
$E after-space
argent run describe --udid <udid>                        # AXTextField "Titre" value="Bonjour "
```

The proof is two facts together: the field's value becomes `Bonjour ` and the log carries `APPLIED orig="Bonjoru" → "Bonjour"` after the mark. After the space the suggestion bar shows the undo chip `↶ Bonjoru` (`kbd.suggestions`); tapping it is `typing.undo-correction`. The first letter is capitalised by the host field, hence `Bonjoru`.

## Gotchas

- Safari's address bar turns suggestions off: typing there shows no suggestion bar. Test in Rappels.
- Reset the user dictionary first (`typing.learned-words`): a learned word silently changes what autocorrect does.
- `axe type` does not exercise autocorrect: it sends hardware keyboard events that reach the field without going through the extension. `drive.sh type` taps the Dictus keys instead (lowercase a–z, AZERTY letters page, offsets measured on iPhone 17).
- Host spell-check underlines are not a usable probe in the simulator (`docs/agents/simulator.md` §8).
