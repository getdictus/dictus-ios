# #1084 PR 2: a voice note in automatic detection is read by the downloaded model, even with Apple's model chosen

Simulator: iPhone 17, iOS 26.5, slimmed (simslim), Debug build of this branch (`f2709e4d`), deleted after
the run (`verify-dictus-ios`). State: Pro forced (`dictus.debugProEntitlementForced`, Debug only), voice
notes on, voice-note language on automatic detection (the default), keyboard language `fr`, Apple's model
picked on the Models screen (`dictus.speechEngineChoice = apple`), and Parakeet v3 installed: the Mac's own
FluidAudio cache copied into the app's `Application Support/FluidAudio/Models`, then `activeModel`,
`downloadedModels` and `modelReady` set as a download sets them. No model was downloaded.

No iOS simulator ships Apple's speech model, so the Debug-simulator-only `SimulatorHostRecognizer`
(#1036) asks a throwaway helper on the Mac running macOS's own `SpeechTranscriber` (not committed), on
port 47814 (`dictus.debugSimulatorHostPort`). The keyboard dictation's audio is the Debug-simulator seam
`app-test-audio.wav` (a French `say -v Thomas` clip), so the room was not recorded.

The voice note is the same fictional **Spanish** clip as PR 1 (`say -v Paulina`, 10 s, as `.m4a`), put in
Files › On My iPhone and shared to Dictus from Files.

| File | What it shows |
|---|---|
| `01-card-es-parakeet.png` | The card: ES chip, the Spanish transcript, no "Transcribed in French…" line. With PR 1 alone this note read "Hla piercrio para confirmer la seena…" under FR. |
| `02-history-es.png` | The History entry reads ES. |
| `03-keyboard-reader-es.png` | The keyboard's voice-note reader offers it, ES. |
| `04-keyboard-dictation-on-apple.png` | The next keyboard dictation, in Safari, inserted in French by Apple's model. |
| `05-flow-note-then-dictation.mp4` | Files › long press › Share › Dictus with Dictus alive in the background, then Safari and a keyboard dictation, then Dictus. Built from screenshots at 2.6 per second (the simulator's recorder was stuck), 602 px wide, no audio. |

The History file on disk: `language: es`, `sttProvider: PK`, `source: sharedFile`, no `languageAssumed`.

The note, then the next keyboard dictation, from the run's `dictus_debug.log` (third note, the video):

```
<APP> VoiceNote accepted count=1 appState=2 activity=false
<APP> VoiceNote started id=4D12A1A2 seconds=10 chunks=1 mode=autoDetect activeModelEngine=PK engineChoice=downloadedModel reason=autoDetectUsesDownloadedModel
<APP> VoiceNote downloadedModelLoaded from=apple-speechtranscriber model=parakeet-tdt-0.6b-v3 loadMs=105
<APP> TranscriptionService languageResolution resolved mode=autoDetect keyboard=fr engine=PK stt=fr sttEffective=no
<APP> VoiceNote finished id=4D12A1A2 chars=153 engine=PK lang=es assumed=false savedToHistory=true elapsedMs=3272
<APP> VoiceNote dictationEngineRestored from=parakeet-tdt-0.6b-v3 to=apple-speechtranscriber elapsedMs=16
# the keyboard dictation, 15 s later
<APP> stopTiming step=engineAcquired sinceTapMs=335
<APP> stopTiming step=modelReady sinceTapMs=354
<APP> TranscriptionService languageResolution resolved mode=followKeyboard keyboard=fr engine=AP stt=fr sttEffective=yes
```

## What the swap costs (simulator, Mac silicon: not an iPhone figure)

| Step | Measured |
|---|---|
| Loading Parakeet for a note while Apple's model is loaded | 4639 ms (first load in a fresh process), 3790 ms (first load in another process), 105 ms (second load in the same process) |
| Putting Apple's back when the queue drains | 26, 19, 16 ms |
| Next keyboard dictation: engine acquired → engine ready | 19 ms, both times (335 → 354, 333 → 352 ms after the stop tap); no load |
| DictusApp footprint | 44 MB on Apple before the note; 56 MB with Parakeet, peak 111 MB while it transcribed; **still 56 MB after Apple is back** |

The 12 MB that stay after the swap back are not explained: the code drops its only reference to the
Parakeet engine (`TranscriptionService.prepare(engine:)`), and nothing else holds one. They may be Core ML
or allocator memory the process keeps; not measured further, and a simulator footprint carries no verdict
for the iPhone.

Not shown here: an iPhone, a real voice, WhatsApp, Whisper as the downloaded model, a fixed voice-note
language, a Core ML cache that is cold (after an install or an iOS update) and the share extension with
the app closed, which stays on Apple's model unchanged.
