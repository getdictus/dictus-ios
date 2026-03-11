# Technology Stack — v1.2 Beta Ready

**Project:** Dictus v1.2 Beta Ready
**Researched:** 2026-03-11
**Scope:** Stack additions for production logging, Audio Bridge / cold start auto-return, CoreML pre-compilation, animation fixes, TestFlight deployment. Existing stack (WhisperKit 0.16.0+, FluidAudio/Parakeet, Swift 5.9+, SwiftUI, iOS 17.0, App Group, DictusCore, two-process Darwin + URL scheme architecture) is validated and unchanged.

---

## Critical Finding: Zero New SPM Dependencies Needed

All five v1.2 feature areas are served by built-in Apple frameworks and existing custom code. No new packages to install. This is excellent for a beta release -- no new integration risk, no dependency version conflicts.

---

## 1. Production Logging System

### Recommendation: Upgrade existing PersistentLog + os.Logger + OSLogStore for export

**Confidence:** HIGH -- all built-in Apple APIs, partially already in codebase

### Current State

The project has two logging systems already:
- `DictusLogger` (os.Logger) -- structured logging with subsystem/category, used throughout both targets
- `PersistentLog` -- file-based logger in App Group container, critical for cross-process debugging when Xcode debugger disconnects

### What Needs to Change

**PersistentLog has production-quality issues that must be fixed:**

| Issue | Current | Fix |
|-------|---------|-----|
| DateFormatter allocation | Creates `ISO8601DateFormatter()` on every `log()` call | Static cached formatter |
| Thread safety | Concurrent writes to FileHandle can corrupt | `NSLock` or dedicated serial `DispatchQueue` |
| Capacity | `maxLines = 200` too small for production debugging | Increase to `maxLines = 2000` with 500KB file size cap |
| Log levels | Everything is one level | Add `.debug`, `.info`, `.warning`, `.error` levels |
| Structured metadata | Only `[timestamp] function: message` | Add `[timestamp] [level] [subsystem] function: message` |
| Privacy | Logs could contain transcription text | Strip user transcription content; log only durations, byte counts, error codes |
| Export | No way for TestFlight users to share logs | Add "Export & Share" via `UIActivityViewController` |

**Add OSLogStore export for current-session structured logs:**

```swift
// iOS 15+ (well within iOS 17 minimum). Current process only.
let store = try OSLogStore(scope: .currentProcessIdentifier)
let position = store.position(date: Date().addingTimeInterval(-3600))
let entries = try store.getEntries(at: position)
    .compactMap { $0 as? OSLogEntryLog }
    .filter { $0.subsystem == "com.pivi.dictus" }
    .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }
```

**Critical limitation:** `OSLogStore(scope: .currentProcessIdentifier)` only sees logs from the current app session. It cannot access keyboard extension logs or previous session logs. This is why PersistentLog (file-based, App Group shared container) remains essential for cross-process debugging.

### Combined Log Strategy

| Need | Tool | Why |
|------|------|-----|
| Real-time debugging (Xcode attached) | `DictusLogger` (os.Logger) | Zero overhead, structured, filterable in Console.app |
| Cross-process debugging (keyboard + app) | `PersistentLog` (file in App Group) | Only mechanism that works across extension boundary and survives Signal 9 |
| TestFlight bug reports | OSLogStore + PersistentLog export | User taps "Export Logs" in Settings, shares combined log file |
| Privacy compliance | Log levels + content stripping | Never log transcription text, user input, or microphone audio |

### What NOT to Add

| Library | Why Not |
|---------|---------|
| CocoaLumberjack | Adds SPM dependency for no gain over os.Logger + PersistentLog |
| SwiftyBeaver | Cloud-based log destination contradicts offline/privacy identity |
| Bugfender | Remote logging service -- privacy violation, cloud dependency |
| OSLog (legacy function) | Use os.Logger (iOS 14+) instead -- better Swift integration |

### iOS 17 Cleanup Opportunity

Since Dictus targets iOS 17.0 minimum, **all `if #available(iOS 14.0, *)` guards around `DictusLogger` calls can be removed**. These guards appear throughout the codebase (DictationCoordinator, AudioRecorder, KeyboardState, etc.) and are unnecessary noise. This is a straightforward cleanup task for v1.2.

### Sources

- [Apple OSLogStore documentation](https://developer.apple.com/documentation/oslog/oslogstore) -- HIGH confidence
- [Apple OSLogPrivacy documentation](https://developer.apple.com/documentation/os/oslogprivacy) -- HIGH confidence
- [Exporting data from Unified Logging System (Swift with Majid)](https://swiftwithmajid.com/2022/04/19/exporting-data-from-unified-logging-system-in-swift/) -- MEDIUM confidence
- [Apple Developer Forums: OSLogStore limitations](https://developer.apple.com/forums/thread/691093) -- HIGH confidence

---

## 2. Cold Start Audio Bridge / Auto-Return

### Recommendation: Accept the limitation, optimize the cold-start UX path

**Confidence:** MEDIUM -- no public API solution exists. Pragmatic UX optimization is the path forward.

### The Hard Truth

**No public iOS API exists to programmatically return from the containing app to the previous (host) app.** This is confirmed by:

- [Swift Forums discussion (Jan 2026)](https://forums.swift.org/t/how-do-voice-dictation-keyboard-apps-like-wispr-flow-return-users-to-the-previous-app-automatically/83988) -- developer asked exactly this question, no solution found
- `_hostBundleID` private API -- blocked in iOS 18+
- `UIApplication.suspend()` -- goes to home screen, not previous app
- x-callback-url -- requires host app cooperation (Messages, WhatsApp do not support it)
- KeyboardKit Pro's "Audio Bridge" -- closed-source, proprietary, $129-599/year. Maintainer [explicitly refuses to share implementation details](https://github.com/KeyboardKit/KeyboardKit/issues/903)

### What KeyboardKit 10.2 Does (and Doesn't)

KeyboardKit 10.2 introduced `.keyboard` dictation that "navigates back to the keyboard" after opening the main app. However:
- This likely uses Apple's native `SFSpeechRecognizer` which has system-level privileges for mic access handoff
- The "audio bridge" concept = keyboard opens app once to establish mic session, then subsequent recordings happen without app switch
- This is functionally what Dictus already does with Darwin notifications + audio background mode (warm path)
- The cold start problem (iOS killed the app) is the unsolved part

### What NOT to Add

| Technology | Why Not |
|------------|---------|
| KeyboardKit Pro | $129-599/year, closed-source, proprietary Audio Bridge. Your existing Darwin + URL scheme architecture is functionally equivalent for the warm path |
| Private APIs | `_hostBundleID`, `LSApplicationWorkspace` -- App Review rejection risk |
| SFSpeechRecognizer | Apple's built-in speech recognizer. Dictus uses custom WhisperKit models for better French accuracy. Switching to Apple STT defeats the product purpose |

### Recommended Approach: Three-Prong Strategy

**Prong 1: Make cold starts rare (already mostly done)**
- Audio background mode keeps the app alive as long as the audio engine runs
- `collectSamples()` pattern keeps engine warm between recordings (already implemented)
- Key improvement: investigate extending background duration by playing an inaudible audio tone at ultra-low volume

**Prong 2: Make cold starts fast (the main engineering work)**
- Current cold start: URL scheme opens app -> WhisperKit init (3-4s) -> RawAudioCapture starts (<100ms)
- RawAudioCapture already provides instant recording on cold start (implemented in v1.1)
- Key improvement: verify CoreML compiled model cache persistence across app restarts. If the compiled model is cached, WhisperKit init drops from 4s to <2s

**Prong 3: Make the transition graceful (UX design)**
- On cold start URL open: show minimal branded overlay with recording waveform + "Recording... Swipe down to return"
- Auto-start recording immediately (already happens via `handleIncomingURL`)
- Consider adding a local notification after 1s: "Dictus is recording. Tap to return to [app name]" -- the notification shows the host app name in the "< Back" status bar area

### Stack Impact

**Zero new dependencies.** The existing two-process architecture handles everything. The work is:
1. UX design of the cold-start overlay (SwiftUI view)
2. Timing optimization (CoreML cache verification)
3. Optional: silent audio tone for extended background keep-alive

### Sources

- [Swift Forums: auto-return keyboard discussion](https://forums.swift.org/t/how-do-voice-dictation-keyboard-apps-like-wispr-flow-return-users-to-the-previous-app-automatically/83988) -- HIGH confidence
- [KeyboardKit 10.2 blog](https://keyboardkit.com/blog/2026/01/09/keyboardkit-10-2) -- MEDIUM confidence (marketing, no implementation details)
- [KeyboardKit issue #903](https://github.com/KeyboardKit/KeyboardKit/issues/903) -- HIGH confidence (maintainer confirms Pro-only)
- [KeyboardKit dictation feature page](https://keyboardkit.com/features/dictation) -- MEDIUM confidence

---

## 3. CoreML Pre-Compilation / Prewarming

### Recommendation: Use existing WhisperKit `prewarm: true` with better error handling and UX

**Confidence:** HIGH -- all within existing WhisperKit API. Work is error handling and UX, not new technology.

### How WhisperKit Handles CoreML Compilation

WhisperKit's `WhisperKitConfig` has three relevant flags:
- `prewarm: true` -- triggers CoreML compilation for the device's Neural Engine/GPU on first load. Minimizes peak memory but adds compile time
- `load: true` -- loads the compiled model into memory
- `download: true` -- downloads model from HuggingFace if not present locally

The existing `ModelManager.downloadWhisperKitModel()` already uses all three correctly. The existing `DictationCoordinator.ensureEngineReady()` uses `prewarm: true, load: true, download: true`.

### Current Issue: Large Turbo v3 Compilation Failure

The PROJECT.md mentions "Fix Large Turbo v3 CoreML compilation failure." Based on research:

| Finding | Detail |
|---------|--------|
| ANE first-run compilation | On first use, the ANE service optimizes the model for the specific device. Can take 2-4 minutes for large models |
| E5 bundle errors | Multiple simultaneous CoreML compilations crash the ANE. Already handled by `isPrewarming` serial lock in ModelManager |
| 4-minute uncached load penalty | Large Turbo v3 with encoder on ANE has a 4-minute uncached load time. Subsequent loads use cache |
| Device-specific compilation | CoreML compilation result is cached per-device. Moving a compiled model between devices does not work |

### Recommended Fixes (No New Dependencies)

1. **Timeout wrapper around prewarm:** Add `Task.withTimeout(seconds: 300)` around the `WhisperKit(config)` call during model download/prewarm. If compilation exceeds 5 minutes, cancel and show "This model may be too large for your device. Try a smaller model."

2. **ANE protection during compilation:** While a model is compiling (`.prewarming` state), disable UI interactions that could trigger another compilation. Show a non-dismissable modal with progress.

3. **Progress indication during prewarming:** Current code jumps from `.downloading` to `.prewarming` with no feedback. Add a timer-based simulated progress bar (0-100% over estimated compile time based on model size).

4. **Cache validation after prewarm:** After `WhisperKit(config)` returns, verify the compiled model directory exists before marking `.ready`. If files are missing (ANE failure), clean up and offer retry with a smaller model suggestion.

5. **Move prewarm into onboarding flow:** Currently download + prewarm are in ModelManager. For v1.2, add an explicit "Optimizing for your device..." step in onboarding after model download completes. User expects a wait during onboarding.

6. **Disk space pre-check:** Large Turbo v3 requires ~3GB total (download + compiled cache). Check `FileManager.default.attributesOfFileSystem(forPath:)[.systemFreeSize]` before download and show clear error if insufficient.

### What NOT to Add

| Technology | Why Not |
|------------|---------|
| Manual `MLModel.compileModel(at:)` | WhisperKit handles CoreML compilation internally via `prewarm`. Calling compileModel directly duplicates work and may conflict with WhisperKit's internal state |
| Pre-compiled model downloads | Device-specific ANE compilation means pre-compiled models from a server do not work. Each device must compile locally |
| Background NSURLSession for model download | Adds significant complexity. For v1.2 beta, foreground download with progress is sufficient |

### Sources

- [Apple compileModel(at:) documentation](https://developer.apple.com/documentation/coreml/mlmodel/compilemodel(at:)-6442s) -- HIGH confidence
- [WhisperKit Configurations.swift](https://github.com/argmaxinc/whisperkit/blob/main/Sources/WhisperKit/Core/Configurations.swift) -- HIGH confidence
- [WhisperKit issue #171: prewarmModels error](https://github.com/argmaxinc/WhisperKit/issues/171) -- MEDIUM confidence

---

## 4. TestFlight Deployment

### Recommendation: Manual Xcode archive + upload. No CI/CD tooling for first beta.

**Confidence:** HIGH -- standard Apple deployment process. Well-documented.

### Prerequisites

| Requirement | Status | Action |
|-------------|--------|--------|
| Apple Developer Program ($99/year) | Mentioned in PROJECT.md as pending | Enroll at developer.apple.com. Required for TestFlight distribution |
| Bundle ID registration | Needs migration from personal team | Register `com.pivi.dictus` (or `com.pivisolutions.dictus`) as explicit App ID |
| App Group registration | Already set: `group.com.pivi.dictus` | Verify App Group is registered under new developer account |
| Provisioning profiles | Need new profiles | Generate for both DictusApp and DictusKeyboard targets. Both need explicit App ID (not wildcard) due to App Group + Microphone entitlements |
| Xcode signing | Currently personal team | Switch to professional team in both targets' Signing & Capabilities |

### Keyboard Extension Specific Requirements

| Requirement | Detail |
|-------------|--------|
| `RequestsOpenAccess = true` | Already in DictusKeyboard Info.plist. Required for mic access |
| `NSMicrophoneUsageDescription` | Must be in DictusApp Info.plist (mic is used in app process, not extension) |
| App Group entitlement | Both targets need `com.apple.security.application-groups` with `group.com.pivi.dictus` |
| Full Access justification | Beta App Review will ask why Full Access is needed. Prepare: "Required for microphone access for voice dictation. No keystroke data is collected or transmitted." |

### TestFlight Process

1. **Archive:** Xcode > Product > Archive (both targets bundled automatically)
2. **Upload:** Xcode Organizer > Distribute App > App Store Connect
3. **App Store Connect setup:**
   - Create app record, primary language: French
   - Category: Utilities
   - Privacy nutrition label: Audio data (used on-device only, not collected)
   - Beta App Review information: testing instructions
4. **Testing instructions for reviewers and testers:**
   - "Enable Dictus keyboard: Settings > General > Keyboards > Add New Keyboard > Dictus"
   - "Grant Full Access: Settings > General > Keyboards > Dictus > Allow Full Access"
   - "Download a speech model in the app before using dictation"
5. **Beta App Review:** First build to external testers requires review. Expect 24-48h. Subsequent builds may not require re-review unless significant changes.
6. **Distribution:** Up to 10,000 external testers via public TestFlight link. Builds expire after 90 days.

### What NOT to Add

| Technology | Why Not |
|------------|---------|
| Fastlane | Overkill for solo developer's first TestFlight. Manual Xcode workflow is simpler and sufficient |
| GitHub Actions CI/CD | Add after first successful manual deployment when the process is understood |
| Firebase App Distribution | Apple's TestFlight is the standard for iOS beta testing, no reason to use a third-party |

### Sources

- [Apple TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) -- HIGH confidence
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) -- HIGH confidence
- [TestFlight test information requirements](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/) -- HIGH confidence

---

## 5. Animation State Management Fixes

### Recommendation: Fix state timing in Darwin notification handlers + use withAnimation completion callbacks

**Confidence:** MEDIUM -- the specific animation bug is intermittent and needs device testing to confirm root cause. Patterns below address the most common SwiftUI animation issues.

### Technologies Available (All Built-In)

| Technology | iOS Min | Purpose |
|------------|---------|---------|
| `withAnimation(_:completionCriteria:_:completion:)` | 17.0 | Animation completion callbacks -- coordinate state after animation finishes |
| `Transaction` | 13.0 | Control animation propagation, disable unwanted inherited animations |
| `PhaseAnimator` | 17.0 | Multi-phase animations without manual state management |

### Root Cause Analysis: Intermittent Recording/Transcription Animation Bug

The recording overlay transitions through states: `.idle` -> `.requested` -> `.recording` -> `.transcribing` -> `.ready` -> `.idle`. Based on code review, the likely causes of intermittent animation bugs are:

**Cause 1: @Published state changes without animation context**

In `KeyboardState.refreshFromDefaults()`, `dictationStatus` is set directly from a `DispatchQueue.main.async` block triggered by a Darwin notification. No `withAnimation` wrapper means SwiftUI applies the state change instantly (no transition animation) or with an inherited animation from a parent view.

```swift
// CURRENT (no animation context):
DarwinNotificationCenter.addObserver(for: .statusChanged) { [weak self] in
    DispatchQueue.main.async {
        self?.refreshFromDefaults()
    }
}

// FIX (explicit animation context):
DarwinNotificationCenter.addObserver(for: .statusChanged) { [weak self] in
    DispatchQueue.main.async {
        withAnimation(.easeInOut(duration: 0.25)) {
            self?.refreshFromDefaults()
        }
    }
}
```

**Cause 2: ProcessingAnimation onAppear restart**

`ProcessingAnimation` starts its repeating animation in `.onAppear`. If the view is conditionally shown/hidden (via `if isTranscribing` in RecordingOverlay), each show triggers a new `.onAppear`, potentially creating duplicate overlapping animations.

Fix: use `.task` modifier instead of `.onAppear`, or gate animation start with a `@State` flag that is only set once.

**Cause 3: Rapid state transitions collapse animations**

When recording stops and transcription completes quickly (<1s), the state goes `.recording` -> `.transcribing` -> `.ready` -> `.idle` in rapid succession. SwiftUI may collapse or skip intermediate animations.

Fix: Use `withAnimation` completion callbacks (iOS 17+) to gate state transitions:

```swift
withAnimation(.easeOut(duration: 0.3)) {
    status = .transcribing
} completion: {
    // Only proceed to next state after animation completes
    startTranscription()
}
```

**Cause 4: NavigationStack interference (iOS 17-18 known bug)**

iOS 17-18 have a [documented bug](https://medium.com/@talessilveira/ios-17-swiftui-animation-bugs-6b8d8951d029) where NavigationSplitView/NavigationStack interfere with all `withAnimation` and `.transition()` calls. If any view in the hierarchy uses NavigationStack, it can suppress animations in child views.

Fix: Verify whether MainTabView or any parent uses NavigationStack. If so, test wrapping animated content in a view that is not a NavigationStack descendant.

### What NOT to Add

| Library | Why Not |
|---------|---------|
| Lottie | Adds 2MB+ dependency for animations that SwiftUI handles natively |
| Spring (animation library) | Unnecessary -- SwiftUI `.spring()` animation is built-in |
| CADisplayLink for manual animation | UIKit approach that breaks SwiftUI's declarative model |

### Sources

- [Apple withAnimation completion documentation](https://developer.apple.com/documentation/swiftui/withanimation(_:completioncriteria:_:completion:)) -- HIGH confidence
- [iOS 17 SwiftUI animation bugs](https://medium.com/@talessilveira/ios-17-swiftui-animation-bugs-6b8d8951d029) -- MEDIUM confidence
- [Mastering SwiftUI Transactions (Fat Bob Man)](https://fatbobman.com/en/posts/mastering-transaction/) -- MEDIUM confidence
- [Animatable Protocol deep dive](https://fatbobman.com/en/posts/animatable-protocol-taming-unruly-swiftui-animation/) -- MEDIUM confidence

---

## Summary: No New Dependencies for v1.2

### Stack Unchanged

| Technology | Version | Status |
|------------|---------|--------|
| WhisperKit | 0.16.0+ via SPM | Unchanged |
| FluidAudio (Parakeet) | latest via SPM | Unchanged |
| Swift | 5.9+ | Unchanged |
| SwiftUI | - | Unchanged |
| DictusCore | local SPM package | Unchanged |
| App Group | `group.com.pivi.dictus` | Unchanged |
| Minimum iOS | 17.0 | Unchanged |

### New Built-In APIs to Use

| API | iOS Min | Purpose |
|-----|---------|---------|
| `OSLogStore` | 15.0 | Log export for TestFlight bug reports |
| `withAnimation(completion:)` | 17.0 | Animation state coordination |
| `PhaseAnimator` | 17.0 | Multi-phase animation (optional, for recording overlay) |
| `UIActivityViewController` | 6.0 | Share exported logs |

### Installation

```bash
# No new packages to install.
# Existing Package.swift (DictusCore) and Xcode SPM dependencies unchanged.
```

---

## Confidence Assessment

| Feature Area | Confidence | Reason |
|--------------|------------|--------|
| Production logging | HIGH | Built-in Apple APIs, existing code to upgrade |
| Cold start auto-return | MEDIUM | No public API for auto-return. UX optimization is pragmatic but not a full solution |
| CoreML pre-compilation | HIGH | WhisperKit handles compilation. Work is error handling and UX around existing API |
| TestFlight deployment | HIGH | Standard Apple process, well-documented |
| Animation fixes | MEDIUM | Root causes identified from code review, but intermittent bug needs device testing to confirm |
