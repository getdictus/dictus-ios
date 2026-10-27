# Dictation from the keyboard

- **ID:** `dictation.keyboard`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard + DictusApp + DictusCore
- **Screens:** `kbd.keys`, `kbd.no-full-access`, `kbd.recording`, `kbd.transcribing`, `kbd.dictation-undo`, `kbd.dictation-error` — see [screens.md](screens.md), which also maps the top bar's states

## Sub-features

- `dictation.start`: Tap the mic in the keyboard toolbar to start a dictation.
- `dictation.stop`: Stop with ✓: the transcript is inserted at the cursor.
- `dictation.cancel`: Cancel with ✕: nothing is inserted.
- `dictation.status`: Recording overlay states: starting, listening, transcribing, processing.
- `dictation.undo-insert`: « ↶ Annuler » in the bar for eight seconds after an insertion removes the inserted text; a keystroke or a caret move withdraws it (`kbd.dictation-undo`).
- `dictation.handoff`: The keyboard hands the recording to the app (warm through a notification, cold through the `dictus://dictate` URL after 500 ms), because the extension's memory limit keeps audio out of it.
- `dictation.requires-full-access`: Without Full Access the mic is disabled and the bar reads « Accès complet requis ».
- `dictation.device-gating`: Refused on devices too old to transcribe (A12/A13 iPhones: « Dictation unavailable on this device »).
- `dictation.onboarding-gate`: Before onboarding is finished (#827), the mic (and the long-press mode rows) in another app only opens Dictus on onboarding: no recording, no error, no return to the host. Long-press → Dictus Pro opens onboarding, not the paywall. Inside Dictus (the onboarding practice field) dictation is allowed. Log: `<KBD> … micTapOpensOnboarding` / `micTapAllowedBeforeOnboarding reason=…`.

## How to get to it (user POV)

1. Install Dictus, add the keyboard in Réglages → Général → Clavier → Claviers, turn on Accès complet.
2. In any text field, long-press the globe and choose Dictus.
3. Tap the blue mic pill at the top right of the keyboard, speak, tap ✓.

## Driving it with axe + Argent

This is the recipe the skill was proven on (no model installed, so the chain must end in the expected failure). It needs onboarding finished — `launch.sh --skip-onboarding` — or, since #827, the mic only opens onboarding:

```bash
.claude/skills/verify-dictus-ios/scripts/drive.sh full-access
.claude/skills/verify-dictus-ios/scripts/drive.sh select-keyboard
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<KBD> .*fullAccess=true' 15
xcrun simctl terminate <udid> com.pivi.dictus   # force the cold-start path
M=$(.claude/skills/verify-dictus-ios/scripts/drive.sh log-mark)
.claude/skills/verify-dictus-ios/scripts/drive.sh kbd mic
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<KBD> keyboardMicTapped' 15 "$M"
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<APP> coldStartURLReceived isColdStart=true' 20 "$M"
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<APP> dictationFailed error=No model downloaded' 20 "$M"
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<KBD> statusChanged from=requested to=failed' 15 "$M"
```

The mic is not in the accessibility tree: `kbd mic` taps `inputView`'s trailing edge, 28 pt below its top. The four log lines are the proof, in that order (except the last, which may be written before `dictationFailed`: two processes, two write queues). `scripts/simulator-smoke-test.sh` runs the same chain as a pass/fail test.

**With a model, end to end** (run on 2026-10-20 for the screen map; only when the task asks for a recording, since it records the room). Install a model first (`models.transcription`), grant the simulator's microphone with `xcrun simctl privacy <udid> grant microphone com.pivi.dictus`, then `full-access` and `select-keyboard`. Warm the app with one take first: the first mic tap after Full Access is a cold start that brings DictusApp forward on « Dictée en cours »; tap the « ◀ Safari » breadcrumb at (35, 39) pt to go back, then ✕ to cancel that take.

```bash
M=$(.claude/skills/verify-dictus-ios/scripts/drive.sh log-mark)
.claude/skills/verify-dictus-ios/scripts/drive.sh kbd mic
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<KBD> statusChanged .*to=recording' 20 "$M"
say -v Eddy -r 150 "Bonjour, ceci est un test de dictée sur le simulateur."   # the Mac's speakers, heard by its mic
axe tap -x 357 -y 559 --udid <udid>     # ✓: the overlay's right pill, same place as the mic (inputView at y=531)
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log '<KBD> keyboardTextInserted' 30 "$M"
xcrun simctl io <udid> screenshot <run>/undo.png    # at once: « Annuler » lasts 8 s
```

The proof is the sequence `<KBD> statusChanged … to=recording`, `<APP> transcriptionStarted`, `<APP> transcriptionCompleted … words=N`, `<KBD> keyboardTextInserted`, `<APP> polishHandoff step=finished outcome=inserted chars=N`. The log never prints the text; `dictus.lastPolishedTranscription` in the App Group plist holds it (`plutil -p "$GROUP_DIR/Library/Preferences/group.solutions.pivi.dictus.plist"`). Screenshot `kbd.transcribing` with `simctl io … screenshot` in a loop right after ✓: `evidence.sh` is too slow for a state that lasts a few seconds.

This recipe proves the insertion and captures the undo **state** only: it does not tap « Annuler », so `dictation.undo-insert` itself (the inserted text removed) is not verified by it. « Annuler » sits in the bar's left slot, where ☰ is (`kbd menu` taps that spot); a run that wants the proof taps it within the 8 s and checks the field is back to what it held before the dictation.

## Gotchas

- **A recording is the room.** A simulator records the Mac's microphone: what `say` plays through the speakers, and whatever else is said nearby, which ends up in the transcript. Do not start one unless the task asks, keep takes short, and never publish a transcript without reading it. Transcript quality is not a measurement: through speakers and a built-in mic, Small (quantifié) heard « Bonjour, si c'est un test de tes aiselles, c'est mieux le teur. » for the sentence above, after a sentence picked up from the room, and « *MUSIQUE*. » at the Mac's default input volume (34). Transcription timing is Mac silicon (~10 s for 9 s of audio here).
- **Not drivable:** the warm hand-off as a deterministic test (it depends on iOS keeping the app alive), auto-return to the host app, the keyboard's memory ceiling and the declared-height constraint (#166). Physical iPhone only.
- The A12/A13 refusal renders on a device created as `iPhone-11` (identifier-based); anything gated on RAM never fires (the simulator reports the Mac's RAM).
- `simctl openurl dictus://dictate…` raises an « Ouvrir dans « Dictus » ? » alert that needs a tap.
- Granting Full Access kills DictusApp (`domain:tcc(11)`); Doctor then warns "DictusApp not running", which is expected.
