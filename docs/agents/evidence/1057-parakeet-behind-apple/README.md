# #1057 — Parakeet downloads behind Apple's model during the onboarding

Simulator: iPhone 17, iOS 26.5, Debug, commit `1bda8955`, created for this run by
`verify-dictus-ios` and deleted after it. Fresh install, French device, Full Access granted and
the microphone pre-granted with `simctl privacy`.

No iOS simulator ships Apple's speech model. As in the earlier runs (`../1057-pr2/README.md`),
the Debug-simulator-only `SimulatorHostRecognizer` asked a throwaway helper on the Mac
(127.0.0.1, not committed), answering with macOS's own `SpeechTranscriber`. The helper started
with no French model installed and took 10 s to "install" it. The dictated audio is a macOS
`say` clip placed as `app-test-audio.wav` at the App Group root (Debug simulator builds only).

## Files

| File | What it shows |
|---|---|
| `01-language-apple-parakeet-fr.png` | Language step: Apple's recognition, you can dictate at once, Parakeet (~483 Mo) downloads in the background |
| `02-popup-dictate-now-fr.png` | Right after Continuer: the popup titled « Vous pouvez déjà dicter », text « Dictus télécharge Parakeet (~483 Mo), plus précis, en arrière-plan. Ça va plus vite si Dictus reste ouvert. » (second run, commit `d683707b`) |
| `03-first-dictation-apple-fr.png` | First dictation step: the text from the Dictus keyboard, transcribed by Apple's engine |
| `04-models-apple-selected-parakeet-downloaded-fr.png` | Models after the download: Parakeet downloaded, Apple still the selected engine |
| `05-home-active-model-card-fr.png` | Home: its card reads « Modèle actif · Parakeet v3 » while Apple dictates: the bug of #1083, fixed by PR #1087 |

**Not captured: the Models page with the download in progress.** On this Mac the 483 MB
arrived in 11 s (10 % → 100 %, 21:57:42 → 21:57:53), before any screen past the popup could be
reached. The progression is in the log below; on an iPhone the transfer is far slower.

## Log (App Group `dictus_debug.log`, prefixes trimmed)

```
21:57:42 AppleEngine action=onboardingRoute route=apple(languageCode: "fr", needsInstall: true) spoken=fr hasKeyboard=true preA14=false modelReady=false
21:57:42 AppleEngine action=onboardingDownload plan=parakeetBehindApple("parakeet-tdt-0.6b-v3") handoff=true
21:57:42 modelDownloadStarted name=parakeet-tdt-0.6b-v3 size=483MB
21:57:49 modelDownloadProgress name=parakeet-tdt-0.6b-v3 percent=50
21:57:52 AppleEngine action=onboardingInstall lang=fr result=apple(languageCode: "fr", needsInstall: false) seconds=10.3
21:57:52 modelSelected name=apple-speechtranscriber
21:57:53 modelDownloadCompleted name=parakeet-tdt-0.6b-v3
21:57:55 modelCompilationCompleted name=parakeet-tdt-0.6b-v3 duration=2512ms
21:57:55 modelSelected name=parakeet-tdt-0.6b-v3        (activeModel recorded, as before)
21:59:46 AppleEngine action=onboardingRoute resumed lang=fr        (relaunch mid-onboarding)
22:00:04 transcriptionStarted model=apple-speechtranscriber
22:00:05 transcriptionCompleted duration=484ms words=10 language=fr
```

App Group after the download: `speechEngineChoice = apple`, `parakeetHandoffPending = true`,
`activeModel = parakeet-tdt-0.6b-v3`. No Parakeet load or compile line during the dictation.

The Models capture needs the onboarding out of the way: the run marked it complete and
relaunched right after the popup, then resumed it at the first dictation step. That relaunch is
also the resume path (`resumed lang=fr`), here with Parakeet already ready, which the handoff
marker lets through.

## Home's card

With Parakeet downloaded behind Apple, Home's « Modèle actif » card names Parakeet while
dictations run on Apple. This is the bug of #1083, fixed by PR #1087 (one source of truth for the
engine that dictates); this run predates that fix. Not changed here.
