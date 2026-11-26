# #1056 PR 3: a voice note transcribed in the share extension with Apple's model

Simulator: iPhone 17, iOS 27.2, slimmed (simslim), Debug build of this branch, deleted after the run.
State: onboarding done, Pro forced (`dictus.debugProEntitlementForced`, Debug only), voice notes on,
voice-note language on automatic detection (the default), keyboard language `fr`, **no Dictus model
downloaded**. Dictus is **killed** before every share (`simctl terminate`, then the share).

No iOS simulator ships Apple's speech model, so the Debug-simulator-only `SimulatorHostRecognizer`
(#1036) asks a throwaway helper on the Mac running macOS's own `SpeechTranscriber` (not committed).
Another agent's helper held the usual port 47811 on this Mac, so this run's helper listened on 47812,
set through `dictus.debugSimulatorHostPort` (read only in Debug simulator builds). "Apple not ready"
is the helper refusing to answer, which reads as an iPhone without `SpeechTranscriber`.

The audio is fictional, synthesised on the Mac with `say -v Thomas` (French, 13 s), copied into
Files › On My iPhone. The over-5-minute file is the same note looped to 5 min 28 s with ffmpeg.

| File | What it shows |
|---|---|
| `01-flow-app-killed-fr.mp4` | Dictus killed. Files › long press › Share › Dictus: "Envoi vers Dictus…", then "Transcription de votre message vocal" with the language line, then "Message vocal transcrit". Dictus is opened afterwards: the entry is in History. Two idle stretches (the context menu and the share sheet left open while the UI was read) are cut; nothing else is edited. |
| `02-transcribing-fr.png`, `02-transcribing-en.png` | The extension transcribing: title, and "Avec le modèle d'Apple, sur l'appareil, en français, votre langue de dictée." |
| `03-done-fr.png`, `03-done-en.png` | Done: "Le texte est dans le clavier Dictus." and "Transcrit en français, votre langue de dictée." The sheet closes by itself after 2 s. |
| `04-over-5-min-fr.png`, `04-over-5-min-en.png` | Over 5 minutes: today's "Open Dictus" screen with its own line, held 2.5 s, then Dictus opens on the note as today. |
| `05-apple-not-ready-fr.png`, `05-apple-not-ready-en.png` | Apple not ready: three frames, "Sending to Dictus…" then Dictus opens on the note, exactly as on develop (the "waiting" screen only shows if opening fails). |
| `06-history-after-opening-fr.png` | Dictus opened after the extension's transcription: the note is in History (FR, 13 s). |
| `log.txt` | `dictus_debug.log` lines of the run, timestamps removed, test-host lines dropped. |

After "Apple not ready" and "over 5 min", the app takes the note as today and fails with "no model
downloaded": this simulator has no Dictus model. On an iPhone with a model it transcribes it.

Main run, from `log.txt`:

```
<SHARE> VoiceNoteShare route route=shareExtension lang=fr source=dictationLanguage engine=simulator-host-speechanalyzer voiceNoteLanguage=auto keyboard=fr ios=27 speechTranscriberAvailable=true installed=true count=1 longestKnownSeconds=13 cap=300 footprintKB=20034 liveKB=5720 availableKB=0
<SHARE> VoiceNoteShare claim id=D90B4CE9 owner=shareExtension
<SHARE> VoiceNoteShare decoded id=D90B4CE9 seconds=12 ms=817 footprintKB=25026 liveKB=8847 availableKB=0
<SHARE> VoiceNoteShare finished id=D90B4CE9 seconds=12 chars=213 lang=fr engine=simulator-host-speechanalyzer savedToHistory=true decodeMs=817 transcribeMs=413 totalMs=1231 peakFootprintKB=25282 minAvailableKB=0 samples=3
<APP> VoiceNote launch pending=true
<APP> VoiceNote adopted id=D90B4CE9 chars=213 engine=simulator-host-speechanalyzer lang=fr savedToHistory=true queueCommitted=true
```

Not shown here: an iPhone (memory, time, whether the extension sees the model the app reserved),
WhatsApp, the keyboard's reader (unchanged; it reads the delivery the extension publishes), and
the paths a simulator cannot provoke (a killed extension, a failed result write).
