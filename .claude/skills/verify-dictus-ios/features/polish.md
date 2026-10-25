# Polish (clean-up of the transcript)

- **ID:** `polish`
- **Tier:** Gratuit (Free) — needs Apple Intelligence
- **Targets:** DictusApp + DictusKeyboard + DictusCore
- **Screens:** `app.settings` — see [screens.md](screens.md)

## Sub-features

- `polish.toggle`: « Polir la transcription » switch in Réglages → Transcription.
- `polish.clean-up`: After transcription, fillers and punctuation are cleaned up without changing the meaning.
- `polish.in-keyboard`: The same clean-up runs for dictations made from the keyboard.
- `polish.debug`: A hidden debug screen (tap « Version » five times).

## How to get to it (user POV)

1. Turn on Apple Intelligence in the iPhone's Settings.
2. Dictus → Réglages → turn on « Polir la transcription».
3. Dictate as usual; the text arrives cleaned up.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
axe tap --label "Polir la transcription" --element-type CheckBox --wait-timeout 5 --udid <udid>   # the switch; a tap on the row's title does not flip it
.claude/skills/verify-dictus-ios/scripts/drive.sh tree | grep -A3 '"Polir la transcription"'   # AXValue flips
```

Debug builds show the toggle even without Apple Intelligence (`DICTUS_POLISH_DEBUG_VISIBLE`).

## Gotchas

- **Not drivable in the simulator:** the polish itself. Apple Intelligence is unavailable there (the keyboard's Smart Mode fan reads « Les modes exigent Apple Intelligence »), so toggling it changes a preference and nothing else.
- The explanatory text under the toggle and « Open iPhone Settings » are English on a French device (missing translations).
