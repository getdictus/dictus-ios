# #1057 PR 2 — the onboarding picks its route from the language

> Superseded in part: Apple's route now also downloads Parakeet behind Apple when it is the recommended model. See `../1057-parakeet-behind-apple/README.md`.

Simulator: iPhone 17 Pro, iOS 27.2, Debug, branch `feature/1057-onboarding-language-route`
(`a755fb01`), created for this run and deleted after it. Every run starts from an erased device
(the Dictus keyboard listed, Full Access granted in Settings, the microphone pre-granted with
`simctl privacy`, so the microphone step is passed over as on a second install).

No iOS simulator ships Apple's speech model. As in PR 1, the Debug-simulator-only
`SimulatorHostRecognizer` asks a throwaway helper on the Mac (127.0.0.1:47811, not committed),
which answers with macOS's own `SpeechTranscriber`: its locale list and the transcription. For
this PR the same harness also stands in for `AssetInventory`'s install (`/install`, Debug simulator
builds only): the helper starts with no locale installed, and decides how long the install takes
and whether it fails. Install times on the simulator are therefore the helper's, not Apple's.

The test audio is `app-test-audio.wav` at the App Group root (macOS `say`), which replaces the
simulator's silent microphone in Debug simulator builds only.

## Runs

| Run | Helper | Language | Route | What it shows |
|---|---|---|---|---|
| 1 | no locale installed, install 8 s | French | Apple | The video. No download, no popup, preparation step passed over, first dictation by Apple, Home « Apple seul » |
| 2 | no locale installed, install 90 s | English | Apple | The preparation step showing Apple's progress, then moving on by itself |
| 3 | every install fails after 2 s | French | Apple, then fallback | The download starts on its own, no popup, the preparation step shows it, onboarding continues |
| 4 | fr and en installed | Italian (no Dictus keyboard) | Download | Today's route, unchanged: the Parakeet line, the « Gardez Dictus ouvert » popup, the download |
| 5 | no locale installed, install 40 s | French | Apple, app killed mid-install | The app terminated on the keyboard step (what Full Access does on an iPhone), relaunched: the install resumes, the preparation step waits for it |

## Files

| File | Run | What it shows |
|---|---|---|
| `fr-apple-route-onboarding.mp4` | 1 | The whole onboarding, 3 min 14 s, from the intro to a dictation from Home's mic |
| `01-language-apple-route-fr.png`, `01-language-apple-route-en.png` | 1, EN | Language step: the line says Apple's recognition, Dictus downloads nothing |
| `02-keyboard-setup-no-popup-fr.png` | 1 | Right after Continue: the keyboard step, no popup |
| `03-preparation-apple-progress-en.png` | 2 | Preparation step on the Apple route: Apple's install at 26 % |
| `04-first-dictation-apple-fr.png`, `04-first-dictation-apple-en.png` | 1, 2 | First dictation from the Dictus keyboard, text inserted by Apple's engine |
| `05-home-apple-only-fr.png`, `05-home-apple-only-en.png` | 1, 2 | Home: « Modèle actif · Apple (sur l'appareil) », mic shown |
| `06-home-dictation-apple-fr.png` | 1 | A dictation from Home's mic |
| `07-uncovered-italian-language-fr.png`, `07-uncovered-italian-keep-open-fr.png` | 4 | Italian: the Parakeet line, then the keep-open popup, as today |
| `08-fallback-download-started-fr.png` | 3 | Apple's install failed: the Parakeet download runs (pill « Parakeet v3 · 20 % ») |
| `08-fallback-preparation-download-fr.png` | 3 | The preparation step shows today's download screen |
| `09-resume-after-kill-preparation-fr.png` | 5 | After the relaunch, the preparation step on Apple's route, waiting for the resumed install |

`01-language-apple-route-en.png` was taken on a separate fresh EN device after the language line
was fixed; runs 2 and 3 ran before that fix, which only changes the language step's line.

## Logs (App Group `dictus_debug.log`, timestamps and prefixes removed)

Run 1, French, Apple route:

```
AppleEngine action=onboardingRoute details=route=apple(languageCode: "fr", needsInstall: true) spoken=fr hasKeyboard=true preA14=false modelReady=false availability=needsAsset(notInstalled)
AppleEngine action=install details=lang=fr step=downloading host=simulator
AppleEngine action=install details=lang=fr step=done host=simulator
AppleEngine action=onboardingInstall details=lang=fr result=apple(languageCode: "fr", needsInstall: false) seconds=8.1
modelSelected name=apple-speechtranscriber
onboardingSceneSequenceSkipped from=smartModesScene to=firstDictation
transcriptionStarted model=apple-speechtranscriber
transcriptionCompleted duration=371ms words=11 language=fr
```

No `modelDownloadStarted` line in the whole run.

Run 2, English, the install still running when the preparation step comes:

```
AppleEngine action=onboardingRoute details=route=apple(languageCode: "en", needsInstall: true) spoken=en hasKeyboard=true preA14=false modelReady=false availability=needsAsset(notInstalled)
onboardingSceneSequenceSkipped from=smartModesScene to=modelPreparation
AppleEngine action=onboardingInstall details=lang=en result=apple(languageCode: "en", needsInstall: false) seconds=90.3
modelSelected name=apple-speechtranscriber
transcriptionCompleted duration=250ms words=9 language=en
```

Run 3, the install fails:

```
AppleEngine action=onboardingRoute details=route=apple(languageCode: "fr", needsInstall: true) ...
AppleEngine action=installFailed details=lang=fr context=onboarding error=domain=OnDeviceRecognizerError code=0
AppleEngine action=onboardingInstall details=lang=fr result=downloadedModel seconds=2.2
AppleEngine action=onboardingFallback details=model=parakeet-tdt-0.6b-v3 step=keyboardSetup
modelDownloadStarted name=parakeet-tdt-0.6b-v3 size=483MB
onboardingSceneSequenceSkipped from=smartModesScene to=modelPreparation
modelSelected name=parakeet-tdt-0.6b-v3
```

Run 4, Italian:

```
AppleEngine action=onboardingRoute details=route=downloadedModel spoken=it hasKeyboard=false preA14=false modelReady=false availability=unavailable(autoDetect)
modelDownloadStarted name=parakeet-tdt-0.6b-v3 size=483MB
```

Run 5, the app killed during Apple's install (`simctl terminate` on the keyboard step), then relaunched:

```
AppleEngine action=onboardingRoute details=route=apple(languageCode: "fr", needsInstall: true) ...
AppleEngine action=install details=lang=fr step=downloading host=simulator
appLaunched version=2.1.0 protectedData=true activePrewarm=false appGroup=healthy
AppleEngine action=onboardingRoute details=resumed lang=fr
AppleEngine action=install details=lang=fr step=downloading host=simulator
onboardingSceneSequenceSkipped from=smartModesScene to=modelPreparation
AppleEngine action=onboardingInstall details=lang=fr result=apple(languageCode: "fr", needsInstall: false) seconds=30.8
modelSelected name=apple-speechtranscriber
```

The helper kept its install running across the kill, so the resumed request finished it. Whether
iOS's own `AssetInventory` download survives the kill is an iPhone question.

## Not shown here

- Anything on an iPhone: Apple's real `AssetInventory` install, its duration on a fresh iPhone,
  and a real microphone.
- A pre-A14 iPhone (route rule unit-tested only).
