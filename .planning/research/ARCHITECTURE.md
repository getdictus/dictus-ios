# Architecture Research: v1.2 Beta Ready Integration

**Domain:** iOS keyboard extension with on-device speech-to-text
**Researched:** 2026-03-11
**Focus:** How v1.2 features integrate with existing two-process architecture
**Overall Confidence:** MEDIUM-HIGH

---

## Existing Architecture (v1.1 Baseline)

```
+--------------------------------------+     +----------------------------------+
|  DictusApp (Main Process)            |     |  DictusKeyboard (Extension)      |
|                                      |     |  Memory ceiling: ~50MB           |
|  DictationCoordinator (singleton)    |     |                                  |
|  +-- AudioRecorder (WhisperKit)      |     |  KeyboardViewController          |
|  +-- RawAudioCapture (cold start)    |     |  +-- KeyboardRootView            |
|  +-- TranscriptionService            |     |  |   +-- ToolbarView (mic btn)   |
|  +-- ModelManager                    |     |  |   +-- SuggestionBarView       |
|                                      |     |  |   +-- KeyboardView (4 rows)   |
|  WhisperKit loaded here (~50-200MB)  |     |  |   +-- RecordingOverlay        |
|  AVAudioEngine kept warm (bg audio)  |     |  +-- KeyboardState (observer)    |
|                                      |     |  +-- TextPredictionEngine        |
|  DictusCore (shared SPM package)     |     |                                  |
|  +-- SharedKeys, DarwinNotifications |     |  DictusCore (same SPM package)   |
|  +-- PersistentLog, DictusLogger     |     |  +-- SharedKeys, DarwinNotifs    |
|  +-- ModelInfo, DictationStatus      |     |  +-- PersistentLog, DictusLogger |
|  +-- Design (colors, typography)     |     |  +-- Design (colors, typography) |
+------------------+-------------------+     +------------------+---------------+
                   |                                            |
                   |  Darwin Notifications (ping-only, CFString)|
                   |  App Group UserDefaults (data payload)     |
                   |  App Group Container (file system)         |
                   |  URL Scheme: dictus://dictate (cold start) |
                   <--------------------------------------------+
```

**IPC contract:** Keyboard writes flags to App Group UserDefaults, posts Darwin notification. App reads flags, acts, writes results back. Keyboard reads on notification. File system in App Group container used for PersistentLog and model storage.

---

## Feature 1: PersistentLog Production Upgrade

### Current State

PersistentLog already exists in DictusCore (`DictusCore/Sources/DictusCore/PersistentLog.swift`). It writes to `dictus_debug.log` in the App Group container. Both processes can write to it. It uses `FileHandle.seekToEndOfFile()` on a `DispatchQueue.global(qos: .utility)` with a 200-line trim cap.

### What Needs to Change

The current implementation has three problems for production use:

1. **No cross-process file safety.** Both DictusApp and DictusKeyboard can write simultaneously. `FileHandle` without coordination can cause interleaved or corrupted entries. The existing serial queue protects against intra-process races but not inter-process races.

2. **No log levels.** Everything is a flat log line. Production needs severity filtering (debug vs info vs error) and the ability to suppress verbose output in release builds.

3. **No privacy safeguards.** Log messages could contain transcribed text (user dictation). Production logs must never include user speech content.

### Architecture Decision: Keep in DictusCore, Add File Coordination

PersistentLog stays in DictusCore because both processes need it. The fix for cross-process safety is to use **atomic write operations** (not NSFileCoordinator).

**Why NOT NSFileCoordinator:** Apple's documentation for App Group containers states that file coordination between app and extension is supported from iOS 8.2+, but it adds complexity and potential deadlocks. For an append-only log file, a simpler approach works.

**Why atomic appends:** Each log entry is a single line written via `FileHandle.write()`. On Apple platforms, writes smaller than `PIPE_BUF` (4096 bytes on iOS) to a file opened in append mode are atomic at the filesystem level. A single log line will never exceed 4096 bytes. This means interleaved writes produce correctly-ordered complete lines, never partial corruption.

**Confidence:** MEDIUM. The POSIX atomicity guarantee applies to pipes and FIFOs explicitly; for regular files on APFS, small appends are de facto atomic but not guaranteed by spec. For a debug log (not financial data), this is acceptable. If corruption is observed in testing, upgrade to NSFileCoordinator.

### Component Changes

| Component | Change Type | Details |
|-----------|-------------|---------|
| `PersistentLog` (DictusCore) | MODIFY | Add log levels (debug/info/warning/error), privacy filter, process identifier tag, configurable max lines for production (500) vs debug (200) |
| `DictusLogger` (DictusCore) | MODIFY | Add convenience methods that forward to PersistentLog for dual output (os.log + file) |
| `DebugLogView` (DictusApp) | MODIFY | Add level filtering, search, export-to-pasteboard with device info header |

### Data Flow

```
Keyboard extension:
  PersistentLog.info("mic tapped")
  --> "[2026-03-11T10:00:00Z] [KB] [INFO] startRecording(): mic tapped\n"
  --> FileHandle.seekToEndOfFile() + write() on utility queue
  --> dictus_debug.log in App Group container

App process:
  PersistentLog.info("recording started")
  --> "[2026-03-11T10:00:00Z] [APP] [INFO] startDictation(): recording started\n"
  --> same file, same pattern

DebugLogView:
  PersistentLog.read() --> display with level filters
```

### Privacy Rule

Add a `PersistentLog.logSafe()` method that strips any text longer than 20 characters (potential transcription content). Use `logSafe` in all paths that touch transcription results. The main `log()` method is fine for lifecycle events.

---

## Feature 2: Audio Bridge (Cold Start Auto-Return)

### Problem Statement

When iOS kills DictusApp (common after 2-3 app switches), the keyboard must open `dictus://dictate` URL to relaunch it. This brings DictusApp to the foreground. The user must manually tap "< Back" in the status bar to return to their previous app. Competitors (Wispr Flow) handle this automatically.

### Research Finding: No Public API for Auto-Return

**Confidence:** HIGH. Verified across:
- [Swift Forums discussion](https://forums.swift.org/t/how-do-voice-dictation-keyboard-apps-like-wispr-flow-return-users-to-the-previous-app-automatically/83988): "No public API exists"
- Apple Developer Forums: `suspend()` goes to home screen, not previous app
- Private APIs (`_hostBundleID`, `LSApplicationWorkspace`) blocked in iOS 18+

Wispr Flow uses "Flow Sessions" where the app stays alive with background audio. On true cold start, they also open their main app. Their FAQ: "Not all apps allow the app to reopen" -- suggesting they use a technique that works for most but not all host apps. Most likely: they use an undocumented behavior or have special App Store review consideration.

### Recommended Strategy: Audio Bridge Pattern

Instead of solving the unsolvable (programmatic auto-return), make cold starts **invisible** by bridging the audio session so the app returns to background almost instantly.

```
CURRENT FLOW (cold start):
  1. User taps mic in keyboard
  2. Keyboard posts Darwin notification (no response -- app dead)
  3. After 500ms, keyboard opens dictus://dictate
  4. iOS launches DictusApp in FOREGROUND
  5. DictusApp configures audio session + starts RawAudioCapture
  6. User sees DictusApp, must manually tap "< Back"
  7. Recording continues in background

PROPOSED AUDIO BRIDGE FLOW (cold start):
  1. User taps mic in keyboard
  2. Keyboard posts Darwin notification (no response -- app dead)
  3. After 500ms, keyboard opens dictus://dictate
  4. iOS launches DictusApp in FOREGROUND
  5. DictusApp shows minimal ColdStartOverlay ("Recording...")
  6. DictusApp configures audio session + starts RawAudioCapture (<100ms)
  7. DictusApp schedules auto-background after 1.0s delay
  8. Auto-background: open a neutral URL that triggers iOS to go back
     --> Option A: Open a universal link that resolves to nothing
     --> Option B: Use performSelector on UIApplication to suspend
     --> Option C: Post a local notification, then suspend
  9. User is back in previous app within ~1.5s total
  10. Recording continues in background (audio mode)
```

### Critical Technical Analysis of Auto-Background Options

**Option A: Open a "bounce" URL.** Open `App-prefs:` or another URL that briefly opens Settings then the user is back where keyboard is. REJECTED -- unreliable, shows Settings flash, may be blocked.

**Option B: UIApplication.suspend() via selector.** `UIApplication.shared.perform(Selector("suspend"))` sends the app to the home screen, NOT the previous app. REJECTED -- wrong destination.

**Option C: Do nothing, optimize for speed.** Accept that cold start shows the app briefly. Minimize the time the app is visible by starting recording in <100ms (already done via RawAudioCapture), loading WhisperKit in parallel, and providing a clear visual cue ("Recording -- tap < Back to return"). RECOMMENDED.

### What Actually Changes in the Architecture

Since no auto-return is possible, the architecture changes focus on:

1. **ColdStartOverlay** -- A minimal, single-purpose view shown when launched via `dictus://dictate` while app was not running. Shows "Recording..." with waveform and a prominent arrow pointing to the "< Back" button in the status bar.

2. **Faster engine warmup** -- After RawAudioCapture starts and user returns to keyboard, WhisperKit loads in parallel (already implemented). No architecture change needed.

3. **Extended background lifetime** -- The audio engine is already kept alive via `UIBackgroundModes:audio`. Consider adding a silent audio playback fallback when the engine is idle to extend background lifetime beyond iOS's default ~30s suspension.

### Component Changes

| Component | Change Type | Details |
|-----------|-------------|---------|
| `ColdStartOverlay` (DictusApp) | NEW | Minimal "Recording..." view with back-arrow prompt |
| `DictusApp.swift` | MODIFY | Detect launch via URL scheme, show ColdStartOverlay instead of full UI |
| `DictationCoordinator` | MODIFY | Add `isColdStartRecording` flag, track launch context |
| `KeyboardState` | MODIFY | Track cold-start state to show "Waiting for app..." briefly in overlay |
| `DarwinNotificationName` | MODIFY | Add `appLaunched` notification so keyboard knows app responded |

### New Darwin Notification: `appLaunched`

When DictusApp launches from a cold start URL, it immediately posts an `appLaunched` Darwin notification. The keyboard receives this and transitions from `.requested` to `.recording` state, showing the recording overlay. This eliminates the 500ms uncertainty window where the keyboard does not know if the app launched.

### Data Flow Change

```
BEFORE:
  Keyboard: .requested --> (500ms wait) --> open URL --> (wait for statusChanged) --> .recording

AFTER:
  Keyboard: .requested --> (500ms wait) --> open URL
  App: launches --> posts appLaunched immediately
  Keyboard: receives appLaunched --> .recording (instantly)
  App: configures audio + starts RawAudioCapture --> posts statusChanged
```

---

## Feature 3: CoreML Pre-Compilation

### Problem Statement

WhisperKit Large Turbo v3 (`openai_whisper-large-v3-v20240930_turbo`) fails CoreML compilation on some devices with ANE "E5 bundle" errors. Additionally, first-time model use has a 10-30s compilation delay.

### Current Flow

```
ModelManager.downloadModel()
  --> WhisperKit.download(variant:) -- downloads .mlpackage files from HuggingFace
  --> WhisperKit(config) with prewarm:true, load:true
  --> WhisperKit internally calls MLModel.compileModel() for each sub-model
  --> ANE compilation happens on-device
  --> If ANE fails: "E5 bundle" error, model stuck in .error state
```

### Architecture Decision: Wrap Prewarm with Retry + Fallback

The ANE compilation failure is a known WhisperKit issue (GitHub [#171](https://github.com/argmaxinc/WhisperKit/issues/171), [#268](https://github.com/argmaxinc/WhisperKit/issues/268)). Root cause: corrupted partial downloads or ANE overload from concurrent compilations.

**What to change:**

1. **Serial ANE compilation** -- Already implemented (`isPrewarming` lock in ModelManager). Keep this.

2. **Retry with cleanup on failure** -- When prewarm fails, delete the corrupted model folder and retry download from scratch. Currently, `cleanupModelFiles` exists but is only called from the catch block. Add explicit retry logic (max 2 attempts).

3. **Move CoreML compilation to onboarding** -- During `ModelDownloadPage`, after download completes and prewarm succeeds, the model is ready. This is already the flow. The issue is the UI does not clearly communicate the "Preparing model..." phase. The `.prewarming` state exists but needs better UX.

4. **Block onboarding advancement until compilation succeeds** -- `ModelDownloadPage.onNext` should only be callable when `modelStates[model] == .ready`. Already the case (button shows "Continuer" only when `downloadComplete` is true, which is set after `downloadModel` returns). No architecture change needed, just UX polish.

### Component Changes

| Component | Change Type | Details |
|-----------|-------------|---------|
| `ModelManager` | MODIFY | Add retry logic: on prewarm failure, cleanup + retry once. Add `prewarmProgress` published property for compilation status |
| `ModelDownloadPage` | MODIFY | Better UX for .prewarming state: show "Preparing for your device..." with indeterminate progress, explain ANE compilation in subtitle |
| `ModelManagerView` | MODIFY | Show compilation status when downloading new models post-onboarding |

### ANE Protection Pattern

```swift
// In ModelManager.downloadWhisperKitModel()
private func downloadWhisperKitModel(_ identifier: String, retryCount: Int = 0) async throws {
    do {
        // ... existing download + prewarm logic ...
    } catch {
        if retryCount < 1 {
            PersistentLog.log("Prewarm failed, cleaning up and retrying: \(error)")
            cleanupModelFiles(identifier)
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2s cooldown for ANE
            try await downloadWhisperKitModel(identifier, retryCount: retryCount + 1)
        } else {
            throw error
        }
    }
}
```

**Confidence:** HIGH for retry pattern. The ANE cooldown (2s sleep) is empirical -- ANE compilation failures often resolve after a brief pause.

---

## Feature 4: Animation Fixes

### Problem: Intermittent Recording/Transcription Animation Bug

Based on the code review, the likely cause is a **Darwin notification race condition** in `KeyboardRootView`'s conditional rendering:

```swift
// KeyboardRootView.swift line 72
if state.dictationStatus == .recording || state.dictationStatus == .transcribing {
    RecordingOverlay(...)
} else {
    ToolbarView(...)
    KeyboardView(...)
}
```

### Race Condition Analysis

```
Timeline of potential race:
  T0: Keyboard posts startRecording Darwin notification
  T1: Keyboard sets dictationStatus = .requested (local)
  T2: App receives notification, sets status = .recording in App Group
  T3: App posts statusChanged Darwin notification
  T4: Keyboard receives statusChanged, reads .recording from defaults
  T5: KeyboardRootView re-renders with .recording --> RecordingOverlay

Problem: Between T1 and T4 (potentially 50-200ms), the keyboard shows
the normal keyboard (not recording, not idle). If the user types during
this window, text appears behind the recording overlay when it finally shows.

Worse: If a second statusChanged arrives quickly (e.g., .recording then
.transcribing in rapid succession), SwiftUI may batch the state changes
and the overlay transition can glitch.
```

### Architecture Fix

1. **Show RecordingOverlay on `.requested` too** -- The keyboard already sets `.requested` locally in `markRequested()`. Add `.requested` to the condition:

```swift
if state.dictationStatus == .requested ||
   state.dictationStatus == .recording ||
   state.dictationStatus == .transcribing {
    RecordingOverlay(...)
}
```

This eliminates the gap between mic tap and overlay appearance.

2. **Add transition animation** -- Currently the switch between keyboard and overlay is instant (no animation). Add a matched geometry or opacity transition to smooth the swap.

3. **Debounce rapid status changes** -- If `.recording` and `.transcribing` arrive within 100ms, the overlay flickers between states. Add a 150ms debounce on `dictationStatus` changes in `KeyboardState.refreshFromDefaults()`.

### Component Changes

| Component | Change Type | Details |
|-----------|-------------|---------|
| `KeyboardRootView` | MODIFY | Include `.requested` in overlay condition, add transition animation |
| `KeyboardState` | MODIFY | Add debounce on rapid status transitions to prevent flicker |
| `RecordingOverlay` | MODIFY | Handle `.requested` state (show "Connecting..." before waveform) |

---

## Feature 5: TestFlight Deployment

### Architecture Changes Required: None

TestFlight distribution requires operational changes, not architectural ones. The app's two-process architecture, App Group configuration, and entitlements are already correct for distribution.

### Checklist (Operational, Not Architectural)

| Requirement | Status | Action |
|-------------|--------|--------|
| Apple Developer Program membership | Needed | Migrate from personal to professional account |
| Provisioning profiles (DictusApp) | Needed | Create App Store distribution profile |
| Provisioning profiles (DictusKeyboard) | Needed | Separate profile for extension, same team |
| App Group entitlement in both profiles | Verify | `group.com.pivi.dictus` must be in both |
| Bundle IDs registered | Verify | `com.pivi.dictus` + `com.pivi.dictus.keyboard` |
| Full Access privacy description | Verify | `NSMicrophoneUsageDescription` in both Info.plist |
| App Store Connect setup | Needed | Create app record, screenshots, description |
| Archive + upload | Needed | Xcode Archive > Upload to App Store Connect |

### One Potential Architecture Concern: Debug Views in Production

`DebugLogView` is currently accessible from `SettingsView`. For TestFlight, this is fine (beta testers benefit from seeing logs). For App Store release, consider gating behind a hidden gesture or removing entirely. No v1.2 action needed.

### Signing Change

The milestone mentions migrating to a professional developer account. This requires:
1. New Team ID in Xcode project settings
2. New provisioning profiles for both targets
3. Re-configure App Group with new team prefix (or keep existing if team ID allows)
4. Verify App Group container path does not change (it should not -- the group ID `group.com.pivi.dictus` is team-independent)

**Risk:** If the App Group identifier changes, all existing data (model paths, preferences, logs) is lost. Verify the group ID remains stable across team migration.

---

## Component Summary: New vs Modified

### New Files to Create

| File | Target | Purpose |
|------|--------|---------|
| `ColdStartOverlay.swift` | DictusApp | Minimal recording UI for cold-start URL launches |

### Existing Files to Modify

| File | Target | Change |
|------|--------|--------|
| `PersistentLog.swift` | DictusCore | Add log levels, process tag, privacy filter, increased line cap |
| `DictusLogger.swift` | DictusCore | Add convenience wrappers forwarding to PersistentLog |
| `DebugLogView.swift` | DictusApp | Add level filtering, search, export with device info |
| `DictusApp.swift` | DictusApp | Detect URL launch context, show ColdStartOverlay |
| `DictationCoordinator.swift` | DictusApp | Add `isColdStartRecording` flag, post `appLaunched` notification on URL launch |
| `KeyboardState.swift` | DictusKeyboard | Observe `appLaunched` notification, add status debounce |
| `KeyboardRootView.swift` | DictusKeyboard | Add `.requested` to overlay condition, add transition animation |
| `RecordingOverlay.swift` | DictusKeyboard | Handle `.requested` state ("Connecting...") |
| `DarwinNotifications.swift` | DictusCore | Add `appLaunched` notification name |
| `ModelManager.swift` | DictusApp | Add retry-with-cleanup on prewarm failure, `prewarmProgress` property |
| `ModelDownloadPage.swift` | DictusApp | Improve prewarming UX, explain ANE compilation |
| `ModelManagerView.swift` | DictusApp | Show compilation status for post-onboarding downloads |

---

## Suggested Build Order

Based on dependency analysis and integration risk:

```
Phase A: Logging Foundation (no UI changes, enables debugging for all subsequent work)
  1. PersistentLog upgrade (levels, process tags, privacy)
  2. DebugLogView improvements (filtering, export)

Phase B: Animation Fixes (keyboard-only, reduces user-visible bugs)
  3. KeyboardRootView .requested condition fix
  4. RecordingOverlay .requested state handling
  5. KeyboardState debounce on rapid status transitions

Phase C: Audio Bridge / Cold Start UX (app-side, new component)
  6. DarwinNotificationName.appLaunched addition
  7. DictationCoordinator cold-start detection + appLaunched post
  8. KeyboardState appLaunched observer
  9. ColdStartOverlay view

Phase D: CoreML Pre-Compilation (model pipeline)
  10. ModelManager retry-with-cleanup logic
  11. ModelDownloadPage prewarming UX
  12. Model download UX overhaul (modal, onboarding reorder, ANE protection)

Phase E: Polish & TestFlight (operational)
  13. French accent audit across UI strings
  14. Design polish (model manager, recording overlay, keyboard UX)
  15. Filler words toggle cleanup
  16. Signing migration + TestFlight upload
```

**Rationale:**
- Phase A first because production logging enables debugging everything else.
- Phase B next because animation bugs are the most user-visible issue.
- Phase C is the highest-complexity feature but has clear component boundaries.
- Phase D is isolated to the model pipeline, no IPC changes.
- Phase E is operational polish, must come last (TestFlight is the final gate).

---

## Scalability Considerations

| Concern | Current (v1.1) | v1.2 Impact | Notes |
|---------|----------------|-------------|-------|
| Log file size | 200 lines, no rotation | 500 lines, still single file | Consider date-based rotation in v2 if log volume grows |
| Cold start frequency | Every 2-3 app switches | Same (cannot prevent iOS killing bg apps) | Audio Bridge reduces perceived impact, not frequency |
| ANE compilation | One model at init | Serial + retry | 2s cooldown between retries prevents ANE overload |
| Darwin notification volume | 6 notification types | +1 (appLaunched) | Still lightweight, no concern |
| App Group UserDefaults size | ~15 keys | +2-3 keys | Well within limits |

---

## Sources

- [Swift Forums: Auto-return from keyboard extension](https://forums.swift.org/t/how-do-voice-dictation-keyboard-apps-like-wispr-flow-return-users-to-the-previous-app-automatically/83988) -- Confirmed no public API exists (HIGH confidence)
- [Wispr Flow FAQ](https://docs.wisprflow.ai/iphone/faq) -- "Not all apps allow the app to reopen" (HIGH confidence)
- [Wispr Flow setup](https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone) -- Flow Session model documentation
- [WhisperKit #171: prewarmModels() failure](https://github.com/argmaxinc/WhisperKit/issues/171) -- ANE compilation error patterns and recovery (HIGH confidence)
- [WhisperKit #268: Unable to load model](https://github.com/argmaxinc/WhisperKit/issues/268) -- Partial download corruption (MEDIUM confidence)
- [Apple: Downloading and Compiling a Model on Device](https://developer.apple.com/documentation/coreml/downloading-and-compiling-a-model-on-the-user-s-device) -- MLModel.compileModel() docs
- [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator) -- Cross-process file safety
- [iOS App Extensions: Data Sharing](https://dmtopolog.com/ios-app-extensions-data-sharing/) -- App Group file coordination patterns (MEDIUM confidence)
- [OSLog and Unified Logging](https://www.avanderlee.com/debugging/oslog-unified-logging/) -- Swift logging best practices
- [Apple: Custom Keyboard Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) -- Extension limitations reference
- [TestFlight](https://developer.apple.com/testflight/) -- Distribution requirements
