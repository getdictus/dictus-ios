# #963: Parakeet on the A12X iPad, device protocol

Device: Pierre's iPad Pro 11" 2018, `iPad8,1`, A12X. Build: the Debug build of `chore/ipad-a12-parakeet-probe` (PR head sha in the PR). Only a Debug build carries the probe; a TestFlight build does not.

**Before you start.** Installing over a TestFlight or App Store build wipes Dictus's data (different signature), so onboarding runs again and installs Base. That is expected.

## 0. Setup (about 10 min, Wi-Fi)

1. Open Dictus. If onboarding appears, finish it (it installs Base and shows the "keyboard dictation unavailable" chip notice: expected, the probe leaves onboarding alone).
2. **Réglages → Exporter les logs** once now. The file must contain a `deviceCapabilitySnapshot model=iPad8,1 ramGB=…` line. **That line gives the iPad's real RAM**: 4 expected.
3. **Modèles** tab: the Parakeet v3 card is **not** greyed. Small, Small (quantifié), Medium, Nemotron and Turbo still are.
   - Fail: Parakeet greyed → wrong build; stop.
4. Tap Parakeet v3 and wait for the download and the preparation screen to finish. Note the time from tap to "ready" (rough, with a watch).
   - Pass: it ends on Parakeet ready, without a crash, and without being stuck on "Optimisation" past 10 minutes.
   - Fail: crash, app killed (back to the home screen), or stuck past 10 min. Export the logs and stop: Parakeet does not load on this chip.
5. Make sure Parakeet v3 is the **active** model (selected in Modèles).

## 1. In-app dictations, 5 of them (Dictus in the foreground)

Inside Dictus, use the mic button. Each one is about 10 s of plain French, a different sentence each time. For example: "Bonjour, je teste la dictée sur l'iPad Pro de 2018, il est quinze heures et il fait beau."

For each one, note: did text come back (yes/no), does it match what you said (ok, minor errors, wrong, English pseudo-words), and how long it took, roughly.

**Pass: 5/5 return text that reads as what you said** (a few word errors are fine, the bar is "usable").

## 2. Keyboard dictations, 5 of them (Dictus in the background)

This is the measurement that matters: Whisper failed here 7/7 (#635).

1. Open **Notes**, a new note, and switch to the Dictus keyboard (long-press the globe).
   - The mic must be **enabled**. If it is greyed with "Dictation unavailable on this device", the build is wrong: stop.
2. Tap the mic, say about 10 s of French, tap stop. Repeat 5 times, each in Notes, with a different sentence each time. If Dictus comes to the foreground to start the first one (cold start), go back to Notes; that is normal.

For each one, note: text inserted in Notes (yes/no), its quality as above, and any error shown on the keyboard.

**Pass: 5/5 insert text that reads as what you said.**
**Fail, the #635 failure: an instant error**, the kind Whisper gave ("Unable to compute the asynchronous prediction using ML Program"). Note which attempts did it.

## 3. Send back

1. **Réglages → Exporter les logs** and send the file. Do this right after the run, before anything else.
2. Send the 15 short notes (setup + 5 + 5).

What the log will show (no need to read it yourself):
- `ParakeetLoad computeUnits preprocessor=cpuOnly encoder=cpuAndNeuralEngine decoder=… joint=… loadMs=… footprintMB=… peakFootprintMB=…`: compute units requested at load, load time, memory.
- `TranscriptionService resources outcome=completed|failed appState=foreground|background elapsedMs=… footprintMB=… peakFootprintMB=…`: one per dictation. `appState=background` marks the keyboard ones.
- `transcriptionCompleted` / `transcriptionFailed` / `transcriptionPerformance`: the existing lines, with the error text on a failure.

## Reading the result

| In-app | Keyboard | Meaning |
|---|---|---|
| 5/5 | 5/5 | Parakeet works on the A12X in both modes. Open a follow-up to make it the real gate on `iPad8,*`. |
| 5/5 | instant errors | The ANE path is refused in the background too, or Core ML falls back to the GPU. #635 stays as it is. |
| 5/5 | slow or killed | It works, but memory or time is the limit; the `peakFootprintMB` numbers decide. |
| fails | n/a | Parakeet does not run on this chip; the #612 gate was right. |
