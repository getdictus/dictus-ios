# #1083 — Home and the Models screen agree on the engine that dictates

Simulator: iPhone 17, iOS 26.5, slimmed (simslim), Debug build of `39e5092f`, created for the run
and deleted after it. French device, onboarding skipped, Pro trial.

Parakeet v3 was downloaded for real from the Models screen (483 MB). No iOS simulator ships
Apple's speech model, so Apple's card was made available through the Debug-simulator-only
`SimulatorHostRecognizer` (#1036): a throwaway helper on the Mac (not committed), on the port set
in `dictus.debugSimulatorHostPort`, answered `/locales` (de-DE, en-US, en-GB, es-ES, fr-FR) and
`/ready` (installed). No dictation was made.

| File | Step | Models screen | Home « Modèle actif » |
|---|---|---|---|
| `01-parakeet-models.png`, `02-parakeet-home.png` | Parakeet downloaded and selected | Parakeet highlighted | Parakeet v3 |
| `03-apple-models.png`, `04-apple-home.png` | Apple's card tapped, Parakeet still downloaded | Apple highlighted | Apple (sur l'appareil) |
| `05-parakeet-again-models.png`, `06-parakeet-again-home.png` | Parakeet's card tapped | Parakeet highlighted | Parakeet v3 |
| `1083-sequence.png` | The six side by side | | |

Before this fix, step 2's Home read « Parakeet v3 »: the card only showed Apple when no model
was downloaded (#1057).

Log of the run (`dictus_debug.log`, timestamps removed):

```
modelSelected name=parakeet-tdt-0.6b-v3
modelSelected name=apple-speechtranscriber
AppleEngine action=engineInstalled details=engine=simulator-host-speechanalyzer lang=fr
AppleEngine action=adopted details=engine=apple-speechtranscriber
modelSelected name=parakeet-tdt-0.6b-v3
```
