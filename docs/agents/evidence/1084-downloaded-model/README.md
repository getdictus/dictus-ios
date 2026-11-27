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

## Cold Core ML cache (second commit)

A second simulator, Debug build `9539af03`, same state, deleted after the run. Parakeet copied in has
no `dictus.modelWarmth` entry, so `ModelWarmth` reads it cold, as after a fresh install or an iOS
update; no record was edited. (To force cold on a device that is warm:
`defaults delete <App Group plist> dictus.modelWarmth` with DictusApp stopped. A process that has
already warmed the model would not warm it again, so restart it.)

Order: a keyboard dictation to wake DictusApp, Dictus in the background, the Spanish note shared from
Files, a keyboard dictation at once, Dictus opened and left in front, the same note shared again.

| File | What it shows |
|---|---|
| `06-cold-card-apple-fr-assumed.png` | The cold note: read by Apple's model, FR, PR 1's line. |
| `07-warm-card-parakeet-es.png` | The same note shared after the compile: Parakeet, ES, no line. |
| `08-history-cold-then-warm.png` | History: the Parakeet note (ES), the cold one (FR, voice-note icon), and the keyboard dictations. |
| `09-flow-cold-then-compile-then-warm.mp4` | The whole run, from screenshots at 2.6 per second played at twice the speed (97 s), 602 px wide, no audio. |

The cold note's transcript is the French test clip, not the Spanish note read in French: the
Debug-simulator seam `app-test-audio.wav`, there for the keyboard dictations, replaces the audio
Apple's engine is given, a voice note's included. What the screen proves is the engine, the language
and the line; PR 1's evidence shows the Spanish note read in French.

```
# cold: the note stays on Apple's model, the compile is scheduled and refused in the background
<APP> VoiceNote voiceNoteEngine choice=apple reason=coldCache id=FDF9A8DC
<APP> VoiceNote compile scheduled model=parakeet-tdt-0.6b-v3
<APP> VoiceNote started id=FDF9A8DC … engineChoice=dictationEngine reason=coldCache
<APP> TranscriptionService languageResolution resolved mode=autoDetect keyboard=fr engine=AP stt=fr sttEffective=yes
<APP> VoiceNote finished id=FDF9A8DC chars=57 engine=AP lang=fr assumed=true savedToHistory=true elapsedMs=277
<APP> VoiceNote compile deferred context=queueDrained model=parakeet-tdt-0.6b-v3 reason=appNotActive
# keyboard dictation right after: no wait
<APP> stopTiming step=engineAcquired sinceTapMs=403
<APP> stopTiming step=modelReady sinceTapMs=421
<APP> TranscriptionService languageResolution resolved mode=followKeyboard keyboard=fr engine=AP …
# Dictus opened and left in front: the compile runs aside, Apple's engine stays installed
<APP> VoiceNote compile started context=didBecomeActive model=parakeet-tdt-0.6b-v3
<APP> modelCompilationCompleted name=parakeet-tdt-0.6b-v3 duration=3663ms
<APP> WarmInference completed ms=1140 engine=Parakeet samples=32000 warmthRecorded=true
<APP> VoiceNote compile finished model=parakeet-tdt-0.6b-v3 ms=4816 warm=true
# the same note again: warm, Parakeet
<APP> VoiceNote voiceNoteEngine choice=downloadedModel reason=autoDetectUsesDownloadedModel id=3F24CB5F
<APP> VoiceNote downloadedModelLoaded from=apple-speechtranscriber model=parakeet-tdt-0.6b-v3 loadMs=109
<APP> VoiceNote finished id=3F24CB5F chars=153 engine=PK lang=es assumed=false savedToHistory=true elapsedMs=1669
<APP> VoiceNote dictationEngineRestored from=parakeet-tdt-0.6b-v3 to=apple-speechtranscriber elapsedMs=35
```

The simulator's compile takes 4.8 s; on an iPhone with a cold cache it is a Core ML compile on the
Neural Engine, minutes in the past, not measured here.
