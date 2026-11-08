# iPhone Duo: current-state audit

A snapshot of how Dictus (`develop` at `f6000edb`) runs on the iPhone Duo simulator, Apple's foldable iPhone. No app code was changed for this audit. Captured 2026-10-24.

A simulator run is not a device validation. The keyboard figures below come from a simulator, and the simulator does no real transcription: no model was downloaded and nothing was recorded.

## Environment

| Item | Value |
| --- | --- |
| Xcode | 27.1 (27A9275) |
| Simulator runtime | iOS 27.1 (24A94232), downloaded for this audit |
| Device type | `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`, model identifier `iPhone19,4` |
| Panels | cover panel 466×678 pt (1398×2034 px), inner panel 669×951 pt (2007×2853 px) |
| SDK used by the build | `iphonesimulator27.1`. The built `Info.plist` has `DTSDKName = iphonesimulator27.1`, `DTPlatformVersion = 27.1`, `DTSDKBuild = 24A94232`, `DTXcode = 2710` |
| App | Debug `DictusApp` 1.9.0 (36), `MinimumOSVersion = 17.0` |
| `UIDeviceFamily` | `[1]` (iPhone only; `TARGETED_DEVICE_FAMILY = 1`) |
| `UISupportedInterfaceOrientations` | Portrait, LandscapeLeft, LandscapeRight (`DictusApp/Info.plist:84`) |
| `UIRequiresFullScreen` | absent |
| `UIApplicationSupportsMultipleScenes` | `false` |

Because the build uses the iOS 27.1 SDK, the app fills the whole inner panel. No compatibility-mode frame was seen.

**How the simulator was driven.** Postures were set with Argent's `fold` tool (`closed` = 0°, `half-open` = 120°, `open` = 180°) and orientation with its `rotate` tool. On the unfolded device, `rotate Portrait` gives a landscape UI and `LandscapeLeft` gives a portrait UI.

`axe` 1.8.0 reads the accessibility tree on this device, but its taps do not land. Every tap went through Argent's `gesture-tap`, using the axe frame normalized by the app frame.

Onboarding was skipped with `dictus.hasCompletedOnboarding`, and Pro was forced with the Debug switch `dictus.debugProEntitlementForced`, both in the App Group. Full Access was granted in Réglages → Général → Clavier → Claviers → Dictus. The device was French, dark mode, with the status bar fixed at 09:41.

## Poses

| Pose | Meaning | File suffix |
| --- | --- | --- |
| Folded | cover panel, portrait | `__folded` |
| Folded, landscape | cover panel, device rotated | `__folded-landscape-…` |
| Open, portrait | inner panel, hinge 180°, portrait UI | `__open-portrait` |
| Open, landscape | inner panel, hinge 180°, landscape UI | `__open-landscape` |
| Partially folded | inner panel, hinge 120° (`half-open`), portrait UI | `__half-open` |
| Split View | inner panel, two apps side by side | not tested |
| Fold/unfold mid-task | posture change while a screen is open | `__fold-unfold`, `…-after-fold` |

## Screen × pose

| Screen | Folded | Open, portrait | Open, landscape | Partially folded | Split View | Fold/unfold mid-task |
| --- | --- | --- | --- | --- | --- | --- |
| Onboarding, intro | OK [png](onboarding__folded.png) | Not optimized [png](onboarding__open-portrait.png) | Not optimized [png](onboarding__open-landscape.png) | Not optimized [png](onboarding__half-open.png) | Not tested | Video [mp4](onboarding__open-portrait.mp4) |
| Onboarding, language step | Not optimized [png](onboarding-language__folded.png) | OK [png](onboarding-language__open-portrait.png) | Not optimized [png](onboarding-language__open-landscape.png) | OK [png](onboarding-language__half-open.png) | Not tested | OK, step 1 of 12 kept [png](onboarding-language__folded-landscape-after-fold.png) |
| Home (no model) | OK [png](home__folded.png) | OK [png](home__open-portrait.png) | OK [png](home__open-landscape.png) | OK [png](home__half-open.png) | Not tested | OK, tab kept on every posture change of the run |
| Models | OK [png](models__folded.png) | Not optimized [png](models__open-portrait.png) | Not optimized [png](models__open-landscape.png) | Not optimized [png](models__half-open.png) | Not tested | OK, tab kept |
| Settings | OK [png](settings__folded.png) | OK [png](settings__open-portrait.png) | Not optimized [png](settings__open-landscape.png) | OK [png](settings__half-open.png) | Not tested | OK, tab and scroll kept [mp4](settings__fold-unfold.mp4), [png](settings__folded-landscape-after-fold.png) |
| Recording | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested |
| History (empty) | OK [png](history__folded.png) | OK [png](history__open-portrait.png) | OK [png](history__open-landscape.png) | OK [png](history__half-open.png) | Not tested | OK, sheet kept |
| Pro hub (Debug-forced) | OK [png](pro-hub__folded.png) | OK [png](pro-hub__open-portrait.png) | OK [png](pro-hub__open-landscape.png) | OK [png](pro-hub__half-open.png) | Not tested | OK, sheet kept |
| Paywall | Not capturable | Not capturable | Not capturable | Not capturable | Not capturable | Not capturable |
| Keyboard (Safari address bar) | OK [png](keyboard__folded.png) | OK [png](keyboard__open-portrait.png) | **Broken** [png](keyboard__open-landscape.png), [number row](keyboard-number-row__open-landscape.png) | OK [png](keyboard__half-open.png) | Not tested | Keyboard dismissed by the fold (the field lost focus); came back on the next tap |
| Keyboard mic → app hand-off | Not tested | OK up to `No model downloaded` [png](keyboard-handoff__open-portrait.png), [mp4](keyboard-dictation__open-portrait.mp4) | Not tested | Not tested | Not tested | Not tested |

Why some rows are not tested or not capturable:

- **Recording.** In-app recording needs a downloaded model, and this audit downloaded none (the language step's `Continuer` starts a ~483 MB download). Without a model, Home shows « Télécharger un modèle pour commencer » and has no mic button.
- **Paywall.** It is hardcoded off: `PremiumFlags.paywallVisible = false`. Pro was reached through the Debug switch instead, and that is what the hub screenshots show.
- **Split View.** No multitasking control appeared on the inner panel, and no headless tool drives one. The app declares `UIApplicationSupportsMultipleScenes = false`.

## Videos

All are H.264 MP4 and under 30 seconds.

| File | Length | Content |
| --- | --- | --- |
| [onboarding__open-portrait.mp4](onboarding__open-portrait.mp4) | 23 s | Inner panel: intro → language step → layout switch → rotation to landscape and back → back to the intro. Recorded from the panel framebuffer, so the landscape part appears sideways. |
| [keyboard-dictation__open-portrait.mp4](keyboard-dictation__open-portrait.mp4) | 19 s | Dictus keyboard in Safari → mic tap → DictusApp cold start → swipe-back screen. No transcription: the chain ends in `No model downloaded`. |
| [settings__fold-unfold.mp4](settings__fold-unfold.mp4) | 17 s | Cover (left) and inner panel (right) side by side, built from paired screenshots at about 1 frame per second (the simulator records one display at a time). Settings is open while the device goes closed → 90° → open → closed → open. Tab and scroll position survive. |

## Broken

1. **The keyboard misreads orientation and screen on the inner panel.** On the inner panel, every `computeKbHeight` log line reads `screen=466x678 landscape=false`. That is the cover panel's size, whatever the panel or orientation. In inner landscape, `KeyboardLayouts.drawsDigitRow` therefore returns true, and with « Rangée de chiffres » on, the keyboard draws the number row in landscape. #331 drops that row in landscape by design.
   - Measured: `grid=270.0 total=322.0 screen=466x678 landscape=false numberRow=true`, keyboard 801 pt wide.
   - Screenshot: [keyboard-number-row__open-landscape.png](keyboard-number-row__open-landscape.png).
   - Cause, from the code: `DeviceContext.current` takes `isLandscape` from `UIScreen.main.isDeviceLandscape` (`DictusKeyboard/Vendored/Models/DeviceContext.swift:66`, `DictusKeyboard/Vendored/GiellaUtils.swift:89`). `UIScreen.main` stays on the cover panel.
2. **The keyboard was blank once, on the cover panel.** Right after Dictus was chosen from the globe menu, the input area stayed blank. The log showed the extension running: `keyboardDidAppear`, `keyboardFrame=466x216`, `running-active`. Refocusing the field drew the keyboard normally, and this was not reproduced afterwards. Simulator only, seen once.

## Not optimized

The app is a single-column iPhone layout stretched to the inner panel's width. Nothing is clipped or unreachable.

1. **Onboarding.** The primary button spans the full width: 621 pt on inner portrait, 819 pt on inner landscape.
   - `docs/agents/screens/iphone-duo/onboarding__open-portrait.png`
   - `docs/agents/screens/iphone-duo/onboarding__open-landscape.png`
2. **Onboarding language step.** The AZERTY/QWERTY/QWERTZ preview runs under the pinned `Continuer` button. The page scrolls, so nothing is unreachable.
   - `docs/agents/screens/iphone-duo/onboarding-language__folded.png`
   - `docs/agents/screens/iphone-duo/onboarding-language__open-landscape.png`
3. **Models.** One column of cards, each as wide as the panel (about 950 pt in landscape).
   - `docs/agents/screens/iphone-duo/models__open-portrait.png`
   - `docs/agents/screens/iphone-duo/models__open-landscape.png`
   - `docs/agents/screens/iphone-duo/models__half-open.png`
4. **Settings.** Form rows run the full landscape width.
   - `docs/agents/screens/iphone-duo/settings__open-landscape.png`
5. **Partially folded posture.** No posture-aware layout: at 120° the inner panel shows the open-portrait layout unchanged (no tabletop split).
   - `docs/agents/screens/iphone-duo/onboarding__half-open.png`

Seen on the cover panel, and not counted as issues because the system draws them: the status bar sits in a trailing column next to the camera, and `TabView` shows its tabs as a vertical rail on the trailing edge. Pro hub's close button lands in that column too.

## DeviceKit on the iPhone Duo

DeviceKit 5.9.0 (the version resolved in this build) has no iPhone Duo case, and its `mapToDevice` has no `iPhone19,4` entry.

- In the simulator, `Device.current` is `.simulator(.unknown("iPhone19,4"))`. Its `diagonal` is `-1`, so `KeyboardHeightProvider.height(forDiagonal:)` finds no `ScreenSize` (nearest-size tolerance 0.2).
- `deviceOverride` returns nil, so the height comes from `fallbackHeight`. `isPhone` is true through `UIDevice.current.userInterfaceIdiom == .phone && isCurrent`, which gives **216 pt portrait / 175 pt landscape**.
- Measured: `grid=216.0` on every panel and posture, `grid=270.0` with the number row.
- `DeviceContext.screenInches` falls back to 13.0 for the unknown diagonal. Only the iPad branches read it, and they are not taken because `isPad` is false.

## Static scan (read-only)

Duo-relevant patterns in `DictusApp`, `DictusKeyboard`, `DictusCore/Sources`, `DictusWidgets`, `DictusShare`.

**`UIScreen.main`.** Every hit is in the keyboard. On the Duo, it reported the cover panel (466×678) even on the inner panel.

- `DictusKeyboard/Vendored/Models/DeviceContext.swift:66`: `isLandscape: UIScreen.main.isDeviceLandscape`. This is the source of Broken 1.
- `DictusKeyboard/Vendored/GiellaUtils.swift:89`: `isDeviceLandscape` compares `bounds` width and height.
- `DictusKeyboard/Vendored/Models/KeyboardHeightProvider.swift:15`, `:27`: `portraitDeviceHeight` / `landscapeDeviceHeight` are `static let`, evaluated once per process from `UIScreen.main.bounds`. They are reached only from the `fallbackHeight` non-phone branch.
- `DictusKeyboard/KeyboardMetrics.swift:19`: `DeviceClass.current` is a `static let` built from `UIScreen.main.bounds.height` (≤667 compact, ≤852 standard, else large). The cover's 678 maps to `.standard` for the life of the process.
- `DictusKeyboard/KeyboardViewController.swift:968`: `UIScreen.main.bounds.size`, used in the diagnostic log only.

**Hardcoded screen-size thresholds.**

- `DictusKeyboard/KeyboardMetrics.swift:20`: `h <= 667`, `h <= 852`.
- `DictusKeyboard/Vendored/Models/KeyboardHeightProvider.swift`: `ScreenSize` diagonal table (4.7"–13"); the Duo has no entry. Heights per size are in `heightForScreenSize`; the fallback is `fallbackHeight`.

**Orientation from screen bounds, not traits.**

- `DictusKeyboard/KeyboardLayouts.swift:74`: `drawsDigitRow` reads `DeviceContext.current.isLandscape`.
- `DictusKeyboard/Vendored/Models/Theme.swift:198`, `:200`, `:207`, `:263`: key margins and font sizes switch on `device.isLandscape`.
- `DictusKeyboard/Vendored/Models/KeyboardHeightProvider.swift:45`–`56`: landscape height and the `rowCount > 4 && isLandscape` adjustment.

**`userInterfaceIdiom`.**

- `DictusKeyboard/Vendored/Models/DeviceContext.swift:54`, `:58`: iPad checks.
- The rest are comments explaining why the hardware identifier is used instead: `DictusApp/Extensions/ModelInfo+Localized.swift:87`, `DictusApp/Views/SettingsView.swift:402`, `DictusApp/Onboarding/KeyboardSetupPage.swift:313`.

**`horizontalSizeClass` / `verticalSizeClass`.**

- `DictusKeyboard/KeyboardViewController.swift:485`: log only. No size class is read to infer an iPad or a layout.

**Orientation locks.**

- `DictusApp/Info.plist:84`: `UISupportedInterfaceOrientations` with Portrait + both landscapes, no upside-down.
- No `supportedInterfaceOrientations` override, no `requiresFullScreen`, no `UIRequiresFullScreen`.

**Fixed frames that ignore the panel size.** Some caps keep text readable, which is fine.

- `DictusApp/Views/SwipeBackOverlayView.swift:40`: 180×390 phone drawing.
- `DictusApp/Onboarding/WelcomePage.swift:176`: `maxWidth: 330`.
- `DictusApp/Onboarding/FullAccessExplainerPage.swift:173`: `maxWidth: 280`.
- `DictusKeyboard/Views/MicButtonDisabled.swift:34`: `width: 250`.

Apple's resizability skill (`xcrun agent skills export`) was not used.

## Limitations

- **Simulator, not device.** Memory, timing, the declared height constraint (#166), dead zones and the warm hand-off still need a physical device. No physical iPhone Duo was available.
- **No transcription, no recording.** No model was downloaded, so the simulator transcribed nothing and recorded nothing. The keyboard mic tap only exercised the hand-off up to `No model downloaded`.
- **Keyboard.** The Xcode 27.1 release notes say that running and debugging most app extensions is unavailable in the iPhone Duo Simulator runtime (187708767). Here, the Dictus keyboard extension did run:
  - it registered with `pluginkit`, was selectable from the globe menu, rendered on both panels, took Full Access and drove the hand-off;
  - "OK" in the keyboard rows means it rendered and behaved, not that it was validated;
  - debugging the extension (attaching Xcode) was not tried.
- **Split View** was not tested (see above).
- **Paywall** is not capturable (`PremiumFlags.paywallVisible = false`). Pro screens are Debug-forced.
- **Tooling.**
  - `axe` taps do not land on this device; Argent `gesture-tap` does.
  - Quitting Device Hub shuts the simulator down, as quitting Simulator.app did on Xcode 26.
  - `simctl io recordVideo` records one display at a time, which is why the fold video is built from screenshots.
- The simulator `chore/iphone-duo-audit` is named after the branch, so `scripts/prune-worktrees.sh` deletes it with the worktree.
