# Live Activity and Dynamic Island

- **ID:** `live-activity`
- **Tier:** Gratuit (Free)
- **Targets:** DictusWidgets + DictusApp
- **Screens:** `widget.live-activity` (not captured) — see [screens.md](screens.md)

## Sub-features

- Standby activity « On » while Dictus is ready, then Rec, Transcribing, Ready, Error; buttons stop standby (`StopStandbyIntent`), dictate (`dictus://dictate`), stop (`dictus://stop`).
- A voice-note activity.
- « Live Activity » toggle in Réglages → Clavier.
- Files: `DictusWidgets/DictusLiveActivity.swift`, `DictusWidgets/StopStandbyIntent.swift`, `DictusApp/LiveActivityManager.swift`.

## How to get to it (user POV)

1. Open Dictus once: the orange « On » pill appears in the Dynamic Island.
2. Long-press the island to stop Dictus between dictations.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
axe button home --udid <udid>
.claude/skills/verify-dictus-ios/scripts/evidence.sh island
```

## Gotchas

- Not reproduced in this skill's runs: with no model installed and the device slimmed, the Home screen showed no island after leaving Dictus. CLAUDE.md notes (unmeasured) that a Live Activity test needs `simslim on <udid> --except widgets`; `launch.sh` does not pass it.
- A dev install kills running Live Activities; Focus modes drop their alerts. Device only.
