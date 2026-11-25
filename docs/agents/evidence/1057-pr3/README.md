# #1057 PR 3 — Home presents the other models when dictating with Apple's model

Simulators: iPhone 17 Pro and iPad Air 11-inch (M4), iOS 27.2, slimmed (simslim), Debug build of
this branch, each deleted after the run, one at a time. Starting state for the card shots:
onboarding done, `dictus.speechEngineChoice = apple`, `dictus.appleEngineReadyLanguage = fr`, **no
downloaded model** (`modelReady`, `activeModel`, `downloadedModels` absent), card never closed.

No iOS simulator ships Apple's speech model, so the Debug-simulator-only `SimulatorHostRecognizer`
(#1036) asks a throwaway helper on the Mac (127.0.0.1:47811, not committed). For these screens the
helper only had to answer `/locales` (de-DE, en-US, en-GB, es-ES, fr-FR) and `/ready` (installed):
no dictation was made, so it did not run macOS's `SpeechTranscriber` as #1065's did.

| File | What it shows |
|---|---|
| `01-home-apple-only-card-fr-iphone.png` | FR, iPhone: the card under « Modèle actif · Apple (sur l'appareil) », « déjà sur votre iPhone », « comme Parakeet v3 », « (483 Mo) » |
| `02-models-tab-after-see-models-fr.png` | After « Voir les modèles »: the Models tab. Nothing downloads. |
| `03-home-card-closed-fr.png` | Back on Home, after the cross: the card is gone |
| `04-home-after-relaunch-still-closed-fr.png` | App terminated and relaunched: still closed (`dictus.otherModelsCardDismissed = true` in the App Group) |
| `05-video-card-see-models-close-relaunch-fr.mp4` | The whole sequence 01 → 04 in one take (30 s) |
| `06-home-apple-only-card-en-iphone.png` | EN, iPhone: « already on your iPhone », « (483 MB) » |
| `07-home-model-downloaded-no-card-en.png` | After downloading Small (Quantized) from the Models tab: active model Small (Quantized), no card |
| `08-home-model-downloaded-no-card-fr.png` | Same state, FR, after a relaunch: no card |
| `09-home-apple-only-card-fr-ipad.png`, `10-home-apple-only-card-en-ipad.png` | iPad (iPhone app in compatibility mode): « votre iPad » / « your iPad » |

For 07 and 08 the card had not been closed (the key was absent): it went away because a downloaded
model became ready. `speechEngineChoice` stayed `apple`: switching engines is PR 4.

Log of the FR run (`dictus_debug.log`, timestamps removed):

```
AppleEngine action=appleOnlyGate details=context=init-preload modelReady=false canDictate=true
OtherModelsCard action=seeModels details=recommended=parakeet-tdt-0.6b-v3
OtherModelsCard action=closed details=recommended=parakeet-tdt-0.6b-v3
modelSelected name=openai_whisper-small_216MB
```

Not shown here: anything on an iPhone, the 4 GB iPhone 12 case (Small recommended: the simulator
reads the Mac's RAM, so it always recommends Parakeet), de and es.
