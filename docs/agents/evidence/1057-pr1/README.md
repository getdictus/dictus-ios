# #1057 PR 1 — dictate with Apple's model, no Dictus model downloaded

Simulator: iPhone 17 Pro, iOS 27.2, slimmed (simslim), Debug, deleted after the run.
State for every shot: onboarding done, `dictus.speechEngineChoice = apple`, **no downloaded model**
(`modelReady`, `activeModel`, `downloadedModels` absent).

No iOS simulator ships Apple's speech model, so the Debug-simulator-only `SimulatorHostRecognizer`
(#1036) asks a throwaway helper on the Mac (127.0.0.1:47811, not committed). The helper answers
with macOS's own `SpeechTranscriber`: its locale list, whether the locale is installed, and the
transcription. With the helper stopped, Apple reads as an iPhone without `SpeechTranscriber`.

| File | Build | What it shows |
|---|---|---|
| `01-home-apple-only-before-fr.png`, `01-home-apple-only-before-en.png` | develop `d34ec0ea` | Home: no mic, « Télécharger un modèle pour commencer » |
| `01b-models-apple-picked-before-en.png` | develop `d34ec0ea` | Same state: Apple is picked and ready on the Models screen |
| `02-home-apple-only-after-fr.png`, `02-home-apple-only-after-en.png` | this branch `115833ba` | Home: mic shown, active model « Apple (sur l'appareil) » |
| `03-dictation-apple-only-after-fr.png` | this branch | A dictation from Home's mic, transcribed by Apple's engine |
| `04-home-apple-unavailable-after-en.png` | this branch | Helper stopped (Apple unavailable): back to the download block, no mic |

The EN « after » shot was taken after switching the dictation language from fr to en: the App
Group record still said `fr`, and the launch's fresh reading moved it to `en`.

Log of the « after » FR run (`dictus_debug.log`, timestamps removed). The test audio is
`app-test-audio.wav` at the App Group root (macOS `say -v Thomas`), which replaces the
simulator's silent microphone in Debug simulator builds only:

```
AppleEngine action=appleOnlyGate details=context=init-preload modelReady=false canDictate=true
modelLoadStateChanged from=idle to=loading reason=init-preload
AppleEngine action=appleOnlyGate details=context=didBecomeActive modelReady=false canDictate=true
AppleEngine action=engineInstalled details=engine=simulator-host-speechanalyzer lang=fr
engineWarmUpAttempt context=init-preload
modelLoadStateChanged from=loading to=ready reason=init-preload-success
AppleEngine action=appleOnlyGate details=context=startDictation modelReady=false canDictate=true
transcriptionStarted model=apple-speechtranscriber
transcriptionCompleted duration=375ms words=14 language=fr
```

Not shown here: the keyboard (needs Full Access and the globe menu; its start answer is
unchanged by this PR, see the PR body), voice notes, and anything on an iPhone.
