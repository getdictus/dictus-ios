# Autocorrect and suggestions

- **ID:** `typing.autocorrect`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard + DictusCore
- **Screens:** `kbd.keys`, `kbd.suggestions` (not captured) — see [screens.md](screens.md)

## Sub-features

- Suggestion bar: predictions, corrections, undo of an autocorrection.
- Autocorrect on space; « Correction automatique » toggle in Réglages → Clavier.
- Auto full stop on double space; accents on long-press; dead keys.
- Files: `DictusKeyboard/TextPrediction/`, `DictusKeyboard/Views/SuggestionBarView.swift`, `DictusCore/Sources/DictusCore/AutoFullStop.swift`, `DictusKeyboard/Vendored/Controllers/LongPressController.swift`.

## How to get to it (user POV)

1. Type with the Dictus keyboard in Notes or Messages.
2. Suggestions appear above the keys; a mistyped word is corrected when you press space.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/drive.sh full-access && .claude/skills/verify-dictus-ios/scripts/drive.sh select-keyboard
# keys are not in the tree; on iPhone 17 with inputView at y=531, AZERTY rows sit at y≈611 / 663 / 718
axe tap -x 241 -y 718 --udid <udid>     # b
.claude/skills/verify-dictus-ios/scripts/evidence.sh typing
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log 'autocorrect' 10           # with « Autocorrect debug logs » on (Réglages → Developer)
```

Use a host field that allows correction (Rappels: `--keep com.apple.remindd` keeps it working under simslim).

## Gotchas

- Safari's address bar turns suggestions off: typing there shows no suggestion bar. Test in Rappels.
- Reset the user dictionary first (`typing.learned-words`): a learned word silently changes what autocorrect does.
- Key coordinates are measured, not read from the tree; re-measure on another device type.
- Host spell-check underlines are not a usable probe in the simulator (`docs/agents/simulator.md` §8).
