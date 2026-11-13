# Debug logs and diagnostics

- **ID:** `diagnostics.logs`
- **Tier:** Gratuit (Free)
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.settings.debug-logs`, `app.settings.diagnostic`, `app.settings.licences`, `app.settings.feedback`, `app.settings.feedback.log`, `app.settings.feedback.failed`, `app.settings.feedback.sent` — see [screens.md](screens.md)

## Sub-features

- `diagnostics.log-view`: « Debug Logs »: the shared app and keyboard log.
- `diagnostics.log-export`: « Exporter les logs » through the share sheet.
- `diagnostics.app-group-check`: « Diagnostic »: checks the storage shared by app and keyboard (App Group).
- `diagnostics.about`: Version, GitHub link (getdictus/dictus-ios), Licences.
- `diagnostics.feedback`: « Envoyer un retour » (#565): name, optional email, Bug / Idée / Autre, message, « Joindre le journal technique » with « Voir ce qui sera envoyé », sent to `POST /api/feedback` on getdictus.com. On failure: one sentence, « Réessayer », « Partager à la place ».

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

### Send feedback

A Debug build reads `-DictusFeedbackEndpoint <url>` from the launch command line, so a run never posts to getdictus.com. Point it at a stub on the Mac (the simulator reaches `http://127.0.0.1`), started through Portly; one that runs the website's own handler is described in PR #565's body.

```bash
.claude/skills/verify-dictus-ios/scripts/drive.sh relaunch -DictusFeedbackEndpoint http://127.0.0.1:8765/api/feedback
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
# scroll to À propos as above
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-id settings.sendFeedback
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-id feedback.name
```

Fields: `feedback.name`, `feedback.email`, `feedback.type`, `feedback.message`, `feedback.attachLog`, `feedback.seeLog`, `feedback.send`. After a failure: `feedback.failure`, `feedback.retry`, `feedback.share`. After a 200: `feedback.sent`.

## Gotchas

- The share sheet's destinations are the simulator's, not the phone's; exporting proves the sheet opens, nothing more.
- `axe type` sends US key codes and the French device keyboard is AZERTY, so typed text comes out wrong. Put the text on the pasteboard (`xcrun simctl pbcopy <udid>`), tap the field, then `axe key-combo --modifiers 227 --key 25` (⌘V). ⌘A is `--key 20` on AZERTY; `--key 4` is ⌘Q and sends the app to the background.
- A swipe down on the form closes the sheet. The draft survives that, by design, until the app is killed.
- A Vercel preview behind deployment protection answers `302` to `vercel.com/sso-api`; the app follows it, gets a login page with `200`, and shows « Dictus n’a pas pu joindre le serveur ».
- An unsigned build (CI flags) has no App Group container: no log, Diagnostic fails. `launch.sh` builds signed ad hoc.
