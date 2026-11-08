# iPad current-state audit (2026-10-23)

What DictusApp and the Dictus keyboard look like on iPad today, before any iPad work. Captured on `develop` at `a25d2dd3` (version 1.9.0, build 36), Debug build, headless simulators.

| Device | Runtime | App window Dictus gets |
| --- | --- | --- |
| `pro13`: iPad Pro 13-inch (M5), 1032×1376 pt | iOS 26.5 | 390×844 pt iPhone canvas, scaled ×1.62 |
| `mini`: iPad mini (A17 Pro), 744×1133 pt | iOS 26.5 | 375×667 pt iPhone canvas (iPhone SE size), scaled ×1.70 |

Device language French, dark appearance, status bar fixed at 09:41. No personal data on screen: no account, no dictation transcript, empty History.

## Why everything looks like an iPhone

All targets ship `TARGETED_DEVICE_FAMILY = 1` (iPhone only). On iPadOS 26 an iPhone-only app runs in a compatibility window: an iPhone-sized canvas scaled to the screen height. The app declares portrait and both landscapes (`UISupportedInterfaceOrientations`) and `UIApplicationSupportsMultipleScenes = false`; there is no `UIRequiresFullScreen` key. Consequences visible in the captures:

- Rotating the iPad does not give the app a landscape layout. The window stays a portrait iPhone canvas in the middle of a landscape screen.
- Landscape left and landscape right render the same layout. Every pair was compared pixel by pixel (ImageMagick `compare -fuzz 3%`): 0.2 % to 0.5 % of pixels differ (status bar, wallpaper), up to 7 % where a looping onboarding animation was caught on a different frame. **Only `landscape-left` is kept**; read it as "landscape (left and right identical)".
- The keyboard extension is not boxed in. In a native iPad app (Reminders) it gets the full iPad width.

## What looks broken or not optimized

1. **App uses about 60 % of the screen width in portrait and 35 % in landscape.** The rest is wallpaper. [`pro13-app-home-portrait`](pro13-app-home-portrait.png), [`pro13-app-home-landscape-left`](pro13-app-home-landscape-left.png), [`pro13-onb-11b-try-it-dictus-kbd-no-full-access-landscape-left`](pro13-onb-11b-try-it-dictus-kbd-no-full-access-landscape-left.png).
2. **Keyboard in iPad apps is the iPhone layout stretched to 1032 pt.** Ten ~100 pt-wide keys per row, keys touching the screen edges, no iPad keys (tab, caps lock, second shift, hide keyboard, return on the second row). The declared height is 436 pt in portrait (`heightConst=436`, `keyboardFrame=1032x384` plus the 52 pt toolbar, read from the extension's `diagnosticProbe`) and the same height in landscape, where it covers about half of the 1032 pt screen. The emoji grid spreads 8 columns over the full width. [`pro13-kbd-reminders-portrait`](pro13-kbd-reminders-portrait.png), [`pro13-kbd-reminders-landscape-left`](pro13-kbd-reminders-landscape-left.png), [`pro13-kbd-reminders-numbers-portrait`](pro13-kbd-reminders-numbers-portrait.png), [`pro13-kbd-reminders-emoji-portrait`](pro13-kbd-reminders-emoji-portrait.png), [`mini-kbd-reminders-no-full-access-portrait`](mini-kbd-reminders-no-full-access-portrait.png).
3. **The recording panel stretches the same way.** The waveform runs edge to edge with cancel and confirm at the far corners. [`pro13-kbd-reminders-recording-portrait`](pro13-kbd-reminders-recording-portrait.png), [`pro13-kbd-reminders-recording-landscape-left`](pro13-kbd-reminders-recording-landscape-left.png).
4. **Split tiling breaks the window, and rotation makes it stick.** In the "fill and arrange" split, Dictus keeps its iPhone aspect ratio and is wider than its tile, so the neighbour app covers part of it ([`pro13-multitask-split-reminders-focused-portrait`](pro13-multitask-split-reminders-focused-portrait.png)). After rotating to landscape and back, Dictus disappeared from the split ([`pro13-multitask-split-after-rotation-landscape-left`](pro13-multitask-split-after-rotation-landscape-left.png)), then came back with its left edge off screen, window controls unreachable, and stayed that way after a terminate and relaunch ([`pro13-multitask-split-after-rotation-back-portrait`](pro13-multitask-split-after-rotation-back-portrait.png)). Dragging the window's top edge recovered it.
5. **Keyboard dictation from another app: the recording UI was not visible on return.** Tapping the keyboard mic in Reminders opened Dictus, recording started and the app returned to Reminders on its own (`hostReturn outcome=returned`). Reminders had discarded the empty reminder meanwhile, so the keyboard was gone and nothing on screen said a recording was running. Re-focusing a reminder showed the recording panel at 00:26. Possibly Reminders-specific; to check on a device with Notes and Messages. Video: `videos/ipad-pro13-kbd-dictation-reminders-x2.mp4`.
6. **"Skip" is hidden under the Dictus keyboard in the onboarding try-it step.** Inside the compatibility window the Dictus keyboard is taller than the system one and covers « Passer »; only its top few points take a tap. [`pro13-onb-11b-try-it-dictus-kbd-no-full-access-portrait`](pro13-onb-11b-try-it-dictus-kbd-no-full-access-portrait.png), [`pro13-kbd-onboarding-full-access-portrait`](pro13-kbd-onboarding-full-access-portrait.png).
7. **Copy says iPhone on an iPad.** « Tout se passe sur votre iPhone » (welcome), « Celle de votre iPhone » and « le meilleur pour votre langue sur cet iPhone » (language), « Optimisation pour cet iPhone » (model preparation), and the polish notice « Apple Intelligence is required for polish. Enable it in iPhone Settings… / Open iPhone Settings », which is also English in the French UI. [`pro13-onb-02-language-portrait`](pro13-onb-02-language-portrait.png), [`pro13-app-model-preparing-portrait`](pro13-app-model-preparing-portrait.png), [`pro13-app-settings-portrait`](pro13-app-settings-portrait.png).
8. **iPad mini gets the iPhone SE layout.** 375×667 pt, so the small-screen variants and tighter spacing, on a device whose screen is larger than any iPhone. [`mini-app-home-no-model-portrait`](mini-app-home-no-model-portrait.png), [`mini-app-settings-portrait`](mini-app-settings-portrait.png).
9. **Minor:** in portrait the system status bar date overlaps the window controls (« ••• ») of the full-height Dictus window ([`pro13-onb-05-smart-modes-scene-portrait`](pro13-onb-05-smart-modes-scene-portrait.png)); the hint « Appui long : langues et réglages » in the stretched keyboard toolbar is very small for its width ([`pro13-kbd-reminders-numbers-portrait`](pro13-kbd-reminders-numbers-portrait.png)).

What works: every screen renders without clipping inside its window; sheets (languages, History, Pro hub) open inside the window; the keyboard → app → host return chain runs; the window can be resized (scale only, aspect ratio locked), tiled and put in Slide Over.

## Captures

File names: `<device>-<screen>-<orientation>.png`. `portrait` and `landscape-left` unless noted. PNG, 1200 px on the long side, 256-colour palette.

### Onboarding (pro13)

| Step | Portrait | Landscape |
| --- | --- | --- |
| 1 Welcome (carousel, page differs per shot) | `pro13-onb-01-welcome-portrait.png` | `pro13-onb-01-welcome-landscape-left.png` |
| 2 Language | `pro13-onb-02-language-portrait.png` | `pro13-onb-02-language-landscape-left.png` |
| 2b « Gardez Dictus ouvert » download alert | not shown on the second pass (model already present) | `pro13-onb-02b-keep-open-alert-landscape-left.png` |
| 3 Keyboard setup | `pro13-onb-03-keyboard-setup-portrait.png` | `pro13-onb-03-keyboard-setup-landscape-left.png` |
| 4 Siri language / Apple Intelligence | `pro13-onb-04-apple-intelligence-portrait.png` | `pro13-onb-04-apple-intelligence-landscape-left.png` |
| 5 Smart Mode scene | `pro13-onb-05-smart-modes-scene-portrait.png` | `pro13-onb-05-smart-modes-scene-landscape-left.png` |
| 6 Pick three Smart Modes | `pro13-onb-06-smart-mode-pick-portrait.png` | `pro13-onb-06-smart-mode-pick-landscape-left.png` |
| 7 Voice notes scene | `pro13-onb-07-voice-notes-scene-portrait.png` | `pro13-onb-07-voice-notes-scene-landscape-left.png` |
| 8 Vocabulary scene | `pro13-onb-08-vocabulary-scene-portrait.png` | `pro13-onb-08-vocabulary-scene-landscape-left.png` |
| 9 History scene | `pro13-onb-09-history-scene-portrait.png` | `pro13-onb-09-history-scene-landscape-left.png` |
| 10 Microphone | skipped on the second pass (permission granted) | `pro13-onb-10-microphone-landscape-left.png` |
| 10b System microphone alert | `pro13-onb-10b-mic-permission-portrait.png` | — |
| 11 Try it (system keyboard) | `pro13-onb-11-first-dictation-portrait.png` | `pro13-onb-11-first-dictation-landscape-left.png` |
| 11b Try it, Dictus keyboard, no Full Access | `pro13-onb-11b-try-it-dictus-kbd-no-full-access-portrait.png` | `pro13-onb-11b-try-it-dictus-kbd-no-full-access-landscape-left.png` |
| 12 Completion | `pro13-onb-12-completion-portrait.png` | `pro13-onb-12-completion-landscape-left.png` |

### App screens (pro13)

| Screen | Portrait | Landscape |
| --- | --- | --- |
| Home (no Pro) | `pro13-app-home-portrait.png` | `pro13-app-home-landscape-left.png` |
| Home (Pro forced, History entry) | `pro13-app-home-pro-portrait.png` | `pro13-app-home-pro-landscape-left.png` |
| Recording (« Nouvelle dictée », cancelled) | `pro13-app-recording-portrait.png` | `pro13-app-recording-landscape-left.png` |
| History (empty) | `pro13-app-history-portrait.png` | `pro13-app-history-landscape-left.png` |
| Models list | `pro13-app-models-portrait.png` | `pro13-app-models-landscape-left.png` |
| Model preparation (download 0 %) | `pro13-app-model-preparing-portrait.png` | `pro13-app-model-preparing-landscape-left.png` |
| Models list, optimizing | `pro13-app-models-optimizing-portrait.png` | `pro13-app-models-optimizing-landscape-left.png` |
| Supported languages sheet | `pro13-app-models-languages-sheet-portrait.png` | `pro13-app-models-languages-sheet-landscape-left.png` |
| Settings, top | `pro13-app-settings-portrait.png` | `pro13-app-settings-landscape-left.png` |
| Settings, scrolled (incl. Developer and Reverse trial #593 sections) | `pro13-app-settings-part2-portrait.png` … `part7` | — |
| Settings, Developer with « Force Pro entitlement » on | `pro13-app-settings-debug-pro-forced-portrait.png` | — |
| Settings › keyboard language menu | `pro13-app-settings-keyboard-language-menu-portrait.png` | — |
| Settings › Sons | `pro13-app-settings-sounds-portrait.png` | `pro13-app-settings-sounds-landscape-left.png` |
| Settings › Licences | `pro13-app-settings-licences-portrait.png` | `pro13-app-settings-licences-landscape-left.png` |
| Settings › Diagnostic | `pro13-app-settings-diagnostic-portrait.png` | `pro13-app-settings-diagnostic-landscape-left.png` |
| Settings › Debug Logs | `pro13-app-settings-debug-logs-portrait.png` | `pro13-app-settings-debug-logs-landscape-left.png` |
| Dictus Pro hub (Debug-forced) | `pro13-app-pro-hub-portrait.png` | `pro13-app-pro-hub-landscape-left.png` |
| Paywall | not reachable, see Limitations | — |

### Keyboard (pro13)

| State | Portrait | Landscape |
| --- | --- | --- |
| Globe long-press picker | `pro13-kbd-globe-picker-portrait.png` | — |
| In Dictus onboarding, Full Access on | `pro13-kbd-onboarding-full-access-portrait.png` | `pro13-kbd-onboarding-full-access-landscape-left.png` |
| In Dictus onboarding, recording | `pro13-kbd-recording-portrait.png` | `pro13-kbd-recording-landscape-left.png` |
| In Reminders (native iPad app), letters | `pro13-kbd-reminders-portrait.png` | `pro13-kbd-reminders-landscape-left.png` |
| In Reminders, numbers | `pro13-kbd-reminders-numbers-portrait.png` | — |
| In Reminders, emoji | `pro13-kbd-reminders-emoji-portrait.png` | — |
| In Reminders, voice notes panel (hamburger) | `pro13-kbd-reminders-voice-notes-panel-portrait.png` | — |
| In Reminders, recording | `pro13-kbd-reminders-recording-portrait.png` | `pro13-kbd-reminders-recording-landscape-left.png` |

### Multitasking (pro13)

| State | File |
| --- | --- |
| Dictus window over Reminders | `pro13-multitask-dictus-over-reminders-portrait.png` |
| Window resized by its corner grip (scales, does not reflow) | `pro13-multitask-resized-smaller-portrait.png` |
| Window controls expanded | `pro13-multitask-window-menu-portrait.png` |
| Arrange menu (tiles, « Accéder à Slide Over ») | `pro13-multitask-tiling-menu-portrait.png` |
| Split tile, Dictus focused | `pro13-multitask-split-portrait.png` |
| Split tile, Reminders focused | `pro13-multitask-split-reminders-focused-portrait.png` |
| Split, after rotating to landscape | `pro13-multitask-split-after-rotation-landscape-left.png` |
| Split, after rotating back to portrait | `pro13-multitask-split-after-rotation-back-portrait.png` |
| Slide Over | `pro13-multitask-slide-over-portrait.png`, `pro13-multitask-slide-over-landscape-left.png` |

### iPad mini (subset)

| Screen | Portrait | Landscape |
| --- | --- | --- |
| Welcome | `mini-onb-01-welcome-portrait.png` | `mini-onb-01-welcome-landscape-left.png` |
| Home, no model | `mini-app-home-no-model-portrait.png` | `mini-app-home-no-model-landscape-left.png` |
| Models | `mini-app-models-portrait.png` | `mini-app-models-landscape-left.png` |
| Settings | `mini-app-settings-portrait.png` | `mini-app-settings-landscape-left.png` |
| Keyboard in Reminders, no Full Access | `mini-kbd-reminders-no-full-access-portrait.png` | `mini-kbd-reminders-no-full-access-landscape-left.png` |

## Videos

H.264, 1080 px high, no audio, each under 30 s. Recorded with `simctl io recordVideo`, so the frame is the panel in its native portrait orientation (rotated content appears sideways).

| File | Content |
| --- | --- |
| `videos/ipad-pro13-onboarding-x3.5.mp4` | Full onboarding walkthrough, 3.5× speed |
| `videos/ipad-pro13-kbd-dictation-onboarding.mp4` | Dictus keyboard in the onboarding try-it step: mic tap, recording, rotation, cancel |
| `videos/ipad-pro13-kbd-dictation-reminders-x2.mp4` | Keyboard mic in Reminders → Dictus opens → auto-return → keyboard gone, 2× speed |
| `videos/ipad-pro13-multitasking-x3.5.mp4` | Resize grip, window menu, split tiling, 3.5× speed |

## Limitations

- **Audio.** A simulator records the Mac's microphone. To keep the room out of the repository every recording was cancelled before transcription: no transcript, no History entry, no Smart Mode output was captured. Recording UI and state changes were captured; transcription quality and timing were not.
- **Paywall.** `PremiumFlags.paywallVisible` is a compile-time `false` (`DictusCore/Sources/DictusCore/PremiumFlags.swift`), so no build, Debug included, can present the paywall or the trial screens. The Pro hub shown is the Debug-forced one (Settings › Developer › « Force Pro entitlement »). StoreKit is not configured in the simulator either.
- **Rotation.** Xcode 27 has no Simulator.app menu. Rotation was driven by a throwaway UI-test bundle, kept outside the repository, that sets `XCUIDevice.shared.orientation`.
- **Multitasking.** iPadOS 26 replaces Split View and Slide Over with window tiling and a Slide Over mode; both were driven by touch through the window controls. External display and keyboard shortcuts were not tested.
- **iPad mini.** Subset only: no Full Access, no model downloaded.
- **Not measured.** Keyboard memory and the declared-height constraint on a physical iPad; the keyboard in Notes, Messages and Safari; Live Activities (disabled in this simulator, `systemActivitiesDisabled`).
