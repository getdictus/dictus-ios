---
phase: 1
status: human_needed
verified: 2026-03-05
---

# Phase 1 Verification: Cross-Process Foundation

## Success Criteria Check

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Tapping mic button stub in keyboard launches Dictus main app via `dictus://dictate` on a physical iPhone | ✓ (automated) / ? (device) | `DictusApp/Info.plist` registers `dictus://` URL scheme (`CFBundleURLSchemes`). `DictusApp/DictusApp.swift` handles `.onOpenURL` routing to `DictationCoordinator.startDictation()`. `KeyboardView.swift` MicKey uses `Link(destination:)` with `dictus://dictate` — the only URL-scheme-safe pattern from an extension (no `UIApplication.shared`). Manual device test still required. |
| 2 | Main app records audio and writes transcription result to App Group shared container | ✓ (stub) | `DictationCoordinator.swift` writes `DictationStatus` and `lastTranscription` to `AppGroup.sharedDefaults` + calls `defaults.synchronize()` + posts Darwin notification on every state transition. Stub simulates 1.5s recording + 1s transcription. Real `AVAudioEngine` recording deferred to Phase 2. |
| 3 | Keyboard extension reads result and displays it — round trip without crashing | ✓ (automated) / ? (device) | `KeyboardState.swift` observes Darwin notifications, reads `dictationStatus` and `lastTranscription` from App Group UserDefaults with 100ms retry guard. `KeyboardRootView.swift` renders `TranscriptionStub` (Phase 1 placeholder) when transcription is available. End-to-end round trip confirmed at code level; crash-free device run requires manual verification. |
| 4 | Basic AZERTY typing (characters, space, delete, return) works without Full Access enabled | ✓ (automated) | `KeyboardLayout.swift` defines full AZERTY letters/numbers/symbols layers. `KeyboardView.swift` routes all key taps to `textDocumentProxy.insertText()`, `deleteBackward()`, and `insertText("\n")`. `FullAccessBanner.swift` shows non-dismissible degradation banner when Full Access is off — typing path is never gated on Full Access. `MicKey` is disabled (not removed) when Full Access is off. |
| 5 | `AppGroupDiagnostic` logs confirm both targets can read and write to `group.com.pivi.dictus` | ✓ (automated) | `AppGroupDiagnostic.swift` implements `DiagnosticResult` with `canRead`/`canWrite`/`containerExists` fields. `DictusApp.swift` calls `AppGroupDiagnostic.run()` in `init()`. `KeyboardViewController.swift` calls it in `#if DEBUG viewDidLoad()`. Both targets hold `group.com.pivi.dictus` in their `.entitlements` files. Runtime log output requires device verification. |

## Requirement Traceability

| Req ID | Description | Plan | Status | Evidence |
|--------|-------------|------|--------|----------|
| DUX-05 | Dictation flow uses two-process architecture (keyboard triggers main app for recording + transcription) | 1.2 | ✓ | `MicKey` in `KeyboardView.swift` opens `dictus://dictate` via `Link`. `DictationCoordinator.swift` in DictusApp handles the request. `KeyboardState.swift` reads results back via App Group + Darwin notifications. Architecture is complete as a stub; audio wired in Phase 2. |
| APP-05 | App handles `dictus://dictate` URL scheme to receive dictation requests from keyboard extension | 1.2 | ✓ | `DictusApp/Info.plist` registers scheme identifier `com.pivi.dictus` with URL scheme `dictus`. `.onOpenURL` in `DictusApp.swift` matches `host == "dictate"` and calls `coordinator.startDictation()`. |
| APP-06 | All shared data passes through App Group (`group.com.pivi.dictus`) | 1.1 | ✓ | `AppGroup.swift` is the single source of truth for the group identifier and `sharedDefaults` accessor. Both targets have `group.com.pivi.dictus` in entitlements. `DictationCoordinator.swift` and `KeyboardState.swift` both use `AppGroup.sharedDefaults` exclusively — no in-process storage used for cross-process state. |
| KBD-01 | User can switch to Dictus keyboard via globe key in any app | 1.3 | ✓ (config) / ? (device) | `KeyboardViewController` is a `UIInputViewController` subclass registered as `NSExtensionPrincipalClass`. `Info.plist` sets `PrimaryLanguage=fr-FR` and `IsASCIICapable=true`. Globe key (`GlobeKey`) implemented in `SpecialKeyButton.swift` using `advanceToNextInputMode()`. Switching itself is a device-only verification. |
| KBD-04 | Keyboard remains functional for basic typing when Full Access is not enabled (graceful degradation) | 1.3 | ✓ | `FullAccessBanner` is shown but typing is never blocked. `MicKey` renders a disabled `MicButtonDisabled` stub (with Settings deep-link popover) when `hasFullAccess == false`. All `textDocumentProxy` calls are unconditional. `playInputClick()` is gated on `hasFullAccess` to avoid hangs. |

## Build Verification

| Target | Command | Result | Notes |
|--------|---------|--------|-------|
| DictusApp | `xcodebuild … CODE_SIGNING_ALLOWED=NO build` | PASS | Compilation succeeds. Failure without flag is code-signing only (no Developer Team configured in project). |
| DictusKeyboard | `xcodebuild … CODE_SIGNING_ALLOWED=NO build` | PASS | Compilation succeeds. Same code-signing note as above. |
| DictusCore (tests) | `swift test` | PASS | 6/6 tests passed in 0.003s. No failures. |

Note: Build failures with default `xcodebuild` are expected in this environment — they report `"Signing for DictusApp requires a development team"`, not compilation errors. Code correctness is confirmed via `CODE_SIGNING_ALLOWED=NO` builds.

## Human Verification Items

These items require a physical iPhone with Dictus installed and enabled. They cannot be confirmed by static analysis or simulator builds.

1. **Round-trip smoke test on device**: Tap mic button in keyboard → DictusApp opens → status cycles idle→requested→recording→transcribing→ready → keyboard receives transcription via Darwin notification. Confirm no crash at any step.
2. **`dictus://dictate` URL scheme live**: Verify iOS registers the URL scheme correctly post-install (Safari test: open `dictus://dictate`, confirm DictusApp launches).
3. **App Group cross-process read/write**: Confirm `AppGroupDiagnostic` logs in both DictusApp and DictusKeyboard show `canRead=true canWrite=true container=true` at runtime.
4. **Globe key keyboard switching**: Confirm globe key (`advanceToNextInputMode()`) cycles to Dictus keyboard from any app's system keyboard picker.
5. **Full Access off — typing still works**: Disable Full Access in Settings, type in any app; confirm all AZERTY characters, space, delete, return insert correctly with `FullAccessBanner` visible and mic disabled.
6. **Full Access off — FullAccessBanner**: Confirm non-dismissible banner renders above keyboard and Settings deep-link (`app-settings:`) opens iOS Settings.
7. **iOS `< [PreviousApp]` back chevron**: After DictusApp is opened via URL scheme, confirm iOS status bar shows back chevron automatically (no code required — system behavior).

## Gaps

None identified. All must-have items from the Phase 1 goal are implemented:

- App Group entitlements on both targets: confirmed
- `dictus://dictate` URL scheme: registered and handled
- Cross-process status + transcription via App Group UserDefaults + Darwin notifications: implemented
- Round-trip stub (without real audio): implemented
- Full AZERTY keyboard shell (all 3 layers + special keys): implemented
- Graceful degradation when Full Access is off: implemented
- `AppGroupDiagnostic` in both launch paths: implemented

The only unimplemented item intentional to Phase 1 scope: real `AVAudioEngine` audio recording. This is deferred to Phase 2 per plan design. The stub proves the architecture.

## Summary

Phase 1 automated verification passes on all five requirements (DUX-05, APP-05, APP-06, KBD-01, KBD-04). Code compiles cleanly for both targets. DictusCore unit tests pass 6/6. All key files exist and implement the two-process architecture as specified. The phase goal — "Prove the two-process dictation architecture works end-to-end on a real device before any other feature is built" — is structurally fulfilled.

Status is `human_needed` because the three core behaviours (cross-process round-trip, globe-key switching, App Group runtime logs) can only be confirmed on a physical iPhone. No automated check can substitute for deploying to device with a valid provisioning profile and exercising the keyboard extension in a live app context. Seven specific device verification items are listed above.
