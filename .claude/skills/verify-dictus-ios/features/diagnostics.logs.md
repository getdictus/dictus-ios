# Debug logs and diagnostics

- **ID:** `diagnostics.logs`
- **Tier:** Gratuit (Free)
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.settings.debug-logs`, `app.settings.diagnostic`, `app.settings.licences` — see [screens.md](screens.md)

## Sub-features

- `diagnostics.log-view`: « Debug Logs »: the shared app and keyboard log.
- `diagnostics.log-export`: « Exporter les logs » through the share sheet.
- `diagnostics.app-group-check`: « Diagnostic »: checks the storage shared by app and keyboard (App Group).
- `diagnostics.about`: Version, GitHub link, Licences.

## How to get to it (user POV)

1. Dictus → Réglages, scroll to À propos.
2. Tap « Exporter les logs » and send the file.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
axe swipe --start-x 201 --start-y 700 --end-x 201 --end-y 150 --duration 0.4 --udid <udid>
axe swipe --start-x 201 --start-y 700 --end-x 201 --end-y 150 --duration 0.4 --udid <udid>
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label Diagnostic
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-label "Read: OK"
```

The log file itself is readable from the host at `$LOG_FILE` (in `run.env`) and is copied out by `cleanup.sh`.

## Gotchas

- The share sheet's destinations are the simulator's, not the phone's; exporting proves the sheet opens, nothing more.
- An unsigned build (CI flags) has no App Group container: no log, Diagnostic fails. `launch.sh` builds signed ad hoc.
