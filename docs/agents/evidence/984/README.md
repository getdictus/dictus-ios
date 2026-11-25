# #984 captures: the device's own name in the copy

The four texts from the iPad audit (#783, item 7), in French and English, on an iPad and an iPhone simulator. 16 images, one text per screen pair.

| Text | iPhone | iPad |
| --- | --- | --- |
| « Tout se passe sur votre … » (welcome, second slide) | `iphone-welcome-{fr,en}.png` | `ipad-welcome-{fr,en}.png` |
| « Celle de votre … » (language step; the model line « sur cet … » too) | `iphone-language-{fr,en}.png` | `ipad-language-{fr,en}.png` |
| « Optimisation pour cet … » (model preparation; the subtitle « et cet … » too) | `iphone-model-preparation-{fr,en}.png` | `ipad-model-preparation-{fr,en}.png` |
| Polish notice and « Ouvrir les Réglages » / « Open … Settings » (Settings) | `iphone-settings-{fr,en}.png` | `ipad-settings-{fr,en}.png` |

## How they were taken

- 2026-11-24, Xcode 27.2, iOS 26.5 runtime, Debug build of this branch. Simulators « iPhone 17 » and « iPad Pro 13-inch (M5) », created for the run and deleted after it. Device in French; English through `-AppleLanguages '(en)'`.
- The iPad runs Dictus in iPhone compatibility mode, like a real iPad, so these captures exercise the hardware-identifier path of `DeviceNoun` (the simulator's `SIMULATOR_MODEL_IDENTIFIER`, an `iPad…` identifier).
- iPad images are quantized to 256 colours to keep them small; the text is unaffected.

## The Settings captures come from a modified build

The polish notice only shows when Apple Intelligence is unavailable. On this Mac's simulators it reported available on 2026-11-24, with and without simslim, and with Siri in another language than the device, so the real build shows no notice there (on 2026-11-05, #908, it did). The four `*-settings-*` images come from a local build where `polishStateFooter` read `.appleIntelligenceNotEnabled` instead of `PolishAvailability.state`. That one-line change was never committed. Every other image is from the branch as committed.
