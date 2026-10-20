# Debug logs and diagnostics

- **ID:** `diagnostics.logs`
- **Tier:** Gratuit (Free)
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.settings.debug-logs`, `app.settings.diagnostic`, `app.settings.licences` — see [screens.md](screens.md)

## Sub-features

- « Debug Logs »: the App Group `dictus_debug.log`, shared by app and keyboard (tags `<APP>`, `<KBD>`).
- « Exporter les logs »: share sheet with the log.
- « Diagnostic »: App Group reachability (read/write).
- Version row, GitHub link, Licences.
- Files: `DictusApp/Views/DebugLogView.swift`, `DictusApp/Views/SettingsView.swift`, `DictusCore/Sources/DictusCore/PersistentLog.swift`.

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
