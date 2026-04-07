# Phase 27: Critical Audio Bugs & Autocorrect Fix - Research

**Researched:** 2026-04-07
**Domain:** iOS AVAudioSession lifecycle, CallKit call detection, N-gram autocorrection guards
**Confidence:** HIGH

## Summary

Phase 27 addresses three bugs filed by beta testers: a SIGABRT crash when starting dictation during a phone call (#71), AirPods/media playback interference from Dictus holding the audio session active (#72), and N-gram autocorrection incorrectly replacing numeric tokens (#74).

Issue #71 is a crash caused by an uncatchable Objective-C NSException thrown by `AVAudioNode.installTapOnBus` when the system owns the audio hardware during a phone call. The fix is prevention via `CXCallObserver` (CallKit), which requires no user permission and detects all call types. Issue #72 stems from Dictus keeping `AVAudioEngine` running continuously with `.playAndRecord` category, making iOS treat it as the "now playing" app and routing AirPods controls to it. The fix involves switching to `.ambient` or deactivating the session when idle, while preserving low-latency recording readiness. Issue #74 is a simple guard: tokens containing digits should never be autocorrected.

**Primary recommendation:** Implement a `CallStateMonitor` using `CXCallObserver`, add an idle/recording audio session lifecycle (deactivate or switch to `.ambient` when not recording), and add a numeric token guard in `handleSpace()` and `SuggestionState.update()`.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BUG-71 | Prevent SIGABRT crash when starting dictation during phone call | CXCallObserver call detection + user-facing message in overlay |
| BUG-72 | Stop AirPods/media interference when Dictus is idle | Audio session lifecycle: deactivate or switch category when not recording |
| BUG-74 | Do not autocorrect tokens containing digits | Numeric guard in handleSpace() and SuggestionState update paths |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| CallKit (CXCallObserver) | iOS 10+ | Detect active phone/VoIP/FaceTime calls | Apple framework, no permission needed, detects all call types |
| AVFoundation (AVAudioSession) | iOS 17+ | Audio session lifecycle management | Already in use, needs interruption notification handling |

### Supporting
No new dependencies needed. All fixes use existing Apple frameworks.

## Architecture Patterns

### Bug #71: Call State Detection

**Pattern: Preventive Guard with CXCallObserver**

The crash at `installTapOnBus` throws an Objective-C `NSException` which Swift `do/catch` cannot intercept. Prevention is the only option.

```
CallStateMonitor (new file)
  - CXCallObserver instance
  - CXCallObserverDelegate
  - @Published var isCallActive: Bool
  - Checks calls.filter { $0.hasConnected || !$0.hasEnded }

DictationCoordinator.startDictation()
  - Before startRecording(), check CallStateMonitor.isCallActive
  - If active -> write error to App Group, update status to .failed
  - Show "Recording unavailable during a call" in overlay
  - Re-enable automatically when call ends (delegate callback)
```

**Key implementation detail:** `CXCallObserver.calls` gives the current list of `CXCall` objects. A call is active when `hasConnected == true` or when `!hasEnded` (covers connecting state too). The delegate method `callObserver(_:callChanged:)` fires on state changes, allowing automatic recovery.

**Files to modify:**
- NEW: `DictusApp/Audio/CallStateMonitor.swift`
- EDIT: `DictusApp/DictationCoordinator.swift` (add guard in `startDictation()`)
- EDIT: Keyboard overlay to display the call-active message

### Bug #72: Audio Session Idle Lifecycle

**Pattern: Dynamic Session Activation**

Current behavior: engine runs continuously with `.playAndRecord` + `setActive(true)`. This makes iOS treat Dictus as the "now playing" app, routing AirPods play/pause to Dictus.

**The trade-off:** Dictus keeps the engine alive for two reasons:
1. Instant recording (no cold start latency)
2. Background survival via `UIBackgroundModes:audio`

**Proposed approach -- Deactivate session when idle:**
1. After `collectSamples()` or `cancelDictation()`: call `setActive(false, options: .notifyOthersOnDeactivation)` and reset category to `.ambient`
2. Before `startRecording()`: reconfigure to `.playAndRecord` and `setActive(true)`
3. Keep the engine object alive (no teardown) -- just stop it and deactivate the session
4. Accept that cold start from idle will add ~100-200ms for session activation

**Why this works:**
- `.notifyOthersOnDeactivation` tells other apps (Spotify, YouTube) to resume playback
- Switching to `.ambient` or deactivating entirely removes Dictus from "now playing"
- AirPods remote controls return to the last media app

**Important: Background survival impact.** Stopping the engine means iOS may suspend the app. Two mitigations:
- Keep a `BGAppRefreshTask` or rely on Darwin notification + URL scheme fallback (already exists)
- Accept 100-200ms re-activation cost on next recording (users expect a brief tap-to-record delay)

**Files to modify:**
- EDIT: `DictusApp/Audio/UnifiedAudioEngine.swift` (add `deactivateAndIdle()` method)
- EDIT: `DictusApp/DictationCoordinator.swift` (call deactivate after recording completes/cancels)

**Alternative considered:** Keep engine running but switch to `.ambient` category only. This is simpler but `.ambient` doesn't support input, so `installTap` might fail. Stopping the engine entirely is safer.

### Bug #74: Numeric Token Guard

**Pattern: Early return for numeric input**

The fix is a simple guard at two locations where autocorrect fires:

1. `DictusKeyboardBridge.handleSpace()` line ~359: before `performSpellCheck`, skip if `freshWord` contains any digit
2. `SuggestionState.update()` / `updateAsync()`: before spell check, skip if partial word contains digits

```swift
// Guard: never autocorrect tokens containing digits
let containsDigit = freshWord.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
if containsDigit { /* skip spell check, proceed to normal space */ }
```

**Why `CharacterSet.decimalDigits`:** Covers all Unicode digits (0-9 plus other scripts), not just ASCII 0-9. Safer for international input.

**Files to modify:**
- EDIT: `DictusKeyboard/DictusKeyboardBridge.swift` (handleSpace)
- EDIT: `DictusKeyboard/TextPrediction/SuggestionState.swift` (update, updateAsync)

### Recommended File Change Summary

| File | Bug | Change |
|------|-----|--------|
| NEW `DictusApp/Audio/CallStateMonitor.swift` | #71 | CXCallObserver wrapper |
| `DictusApp/DictationCoordinator.swift` | #71, #72 | Call guard + session deactivation after recording |
| `DictusApp/Audio/UnifiedAudioEngine.swift` | #72 | Add idle deactivation method |
| `DictusKeyboard/DictusKeyboardBridge.swift` | #74 | Numeric guard in handleSpace |
| `DictusKeyboard/TextPrediction/SuggestionState.swift` | #74 | Numeric guard in update/updateAsync |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Call detection | Custom audio session interruption parsing | CXCallObserver (CallKit) | Interruption notifications don't distinguish call from alarm; CXCallObserver detects all call types with no permission |
| Audio interruption recovery | Manual AVAudioEngine restart logic | AVAudioSession.interruptionNotification + began/ended handling | Apple's notification system handles all interruption types |

## Common Pitfalls

### Pitfall 1: NSException not catchable in Swift
**What goes wrong:** `installTapOnBus` throws an Objective-C NSException during a phone call. Swift `do/catch` cannot intercept NSExceptions -- the process aborts immediately.
**Why it happens:** AVFAudio is Objective-C under the hood; it throws NSException, not Swift Error.
**How to avoid:** Never attempt to start recording during a call. Use CXCallObserver to prevent the call entirely.
**Warning signs:** SIGABRT in crash logs with AVFAudio stack frames.

### Pitfall 2: Audio session category change while engine is running
**What goes wrong:** Calling `setCategory` while `AVAudioEngine` is running may cause undefined behavior or silent failure.
**Why it happens:** The engine's audio graph is configured for the current category. Changing mid-stream invalidates the graph.
**How to avoid:** Always stop the engine before changing category. Sequence: engine.stop() -> removeTap -> setCategory -> setActive -> installTap -> engine.start().

### Pitfall 3: notifyOthersOnDeactivation timing
**What goes wrong:** Other apps don't resume playback after Dictus deactivates its session.
**Why it happens:** `.notifyOthersOnDeactivation` only works when passed to `setActive(false, ...)`. Some apps don't observe the notification properly.
**How to avoid:** Always pass the option when deactivating. This is already done in `deactivateSession()`.

### Pitfall 4: Background suspension after engine stop
**What goes wrong:** iOS suspends the app after the audio engine stops because `UIBackgroundModes:audio` requires an active audio session.
**Why it happens:** No active audio processing = no background entitlement justification.
**How to avoid:** This is actually acceptable for the idle case. The keyboard's existing Darwin notification + URL scheme fallback handles wake-up. Document this trade-off in the ADR.

### Pitfall 5: CXCallObserver delegate not retained
**What goes wrong:** The delegate is deallocated and callbacks stop firing.
**Why it happens:** `setDelegate(_:queue:)` does not retain the delegate.
**How to avoid:** Store the CallStateMonitor as a strong property on DictationCoordinator.

## Code Examples

### CXCallObserver Usage
```swift
// Source: Apple CallKit documentation
import CallKit

@MainActor
class CallStateMonitor: NSObject, ObservableObject, CXCallObserverDelegate {
    @Published private(set) var isCallActive = false
    private let callObserver = CXCallObserver()

    override init() {
        super.init()
        callObserver.setDelegate(self, queue: .main)
        // Check initial state
        updateCallState()
    }

    private func updateCallState() {
        isCallActive = callObserver.calls.contains { !$0.hasEnded }
    }

    nonisolated func callObserver(_ observer: CXCallObserver, callChanged call: CXCall) {
        DispatchQueue.main.async { [weak self] in
            self?.updateCallState()
        }
    }
}
```

### Audio Session Deactivation After Recording
```swift
// In UnifiedAudioEngine
func deactivateAndIdle() {
    isRecording = false
    isRecordingFlag = false
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    audioSamples = []
    
    let session = AVAudioSession.sharedInstance()
    try? session.setActive(false, options: .notifyOthersOnDeactivation)
    sessionConfigured = false
    
    bufferEnergy = []
    bufferSeconds = 0
}
```

### Numeric Token Guard
```swift
// In handleSpace(), before spell check block
let containsDigit = freshWord.unicodeScalars.contains {
    CharacterSet.decimalDigits.contains($0)
}
guard !containsDigit else {
    // Skip autocorrect for numeric tokens -- insert space normally
    controller?.textDocumentProxy.insertText(" ")
    lastInsertedCharacter = " "
    // Still trigger predictions and learning
    suggestionState?.lastAutocorrect = nil
    suggestionState?.clear()
    suggestionState?.rejectedWords.removeAll()
    let ctx = controller?.textDocumentProxy.documentContextBeforeInput
    suggestionState?.updatePredictions(context: ctx)
    updateCapitalization()
    updateAccentKeyDisplay()
    return
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CTCallCenter (deprecated) | CXCallObserver (CallKit) | iOS 10 (2016) | Modern call detection, no permission needed |
| Keep audio engine running forever | Activate/deactivate session per recording | Best practice | Prevents media app interference |
| No interruption handling | AVAudioSession.interruptionNotification | Always recommended | Graceful recovery from phone calls, alarms |

## Open Questions

1. **Background survival without audio engine**
   - What we know: Stopping the engine means iOS will suspend the app (no active audio = no background justification)
   - What's unclear: Exact timing before iOS suspends (could be 3-30 seconds)
   - Recommendation: Accept suspension. The existing URL scheme fallback handles cold start. Document as conscious trade-off.

2. **WhisperKit session conflict after deactivation**
   - What we know: WhisperKit internally calls `setCategory` + `setActive` in `startRecordingLive()`
   - What's unclear: Whether WhisperKit's internal session management conflicts with our deactivation
   - Recommendation: Since we use `UnifiedAudioEngine` (not WhisperKit for recording), this should be fine. WhisperKit is only used for transcription (no audio session needed).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Swift Package Manager tests for DictusCore) |
| Config file | DictusCore/Package.swift |
| Quick run command | `cd DictusCore && swift test` |
| Full suite command | `cd DictusCore && swift test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BUG-71 | Block recording during call | manual-only | N/A -- requires phone call on device | N/A |
| BUG-72 | No media interference when idle | manual-only | N/A -- requires AirPods + media app on device | N/A |
| BUG-74 | Numeric tokens skip autocorrect | unit | `cd DictusCore && swift test` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `cd DictusCore && swift test`
- **Per wave merge:** `cd DictusCore && swift test` + manual device test for audio bugs
- **Phase gate:** Manual verification on physical device (AirPods + phone call)

### Wave 0 Gaps
- [ ] BUG-71 and BUG-72 are manual-only (AVAudioSession + CallKit require real device)
- [ ] BUG-74 could have a unit test if the numeric guard logic is extracted to a testable function, but the current code is in the keyboard extension (not testable via SPM). Consider extracting the guard to DictusCore for testability.

## Sources

### Primary (HIGH confidence)
- GitHub Issue #71 -- SIGABRT crash stack trace, CXCallObserver proposed fix
- GitHub Issue #72 -- AirPods hijack symptoms, session lifecycle analysis
- GitHub Issue #74 -- Numeric token autocorrection bug, reproduction steps
- Codebase: `UnifiedAudioEngine.swift`, `DictationCoordinator.swift`, `DictusKeyboardBridge.swift`, `SuggestionState.swift`, `TextPredictionEngine.swift`
- [Apple CXCallObserver documentation](https://developer.apple.com/documentation/callkit/cxcallobserver)
- [Apple AVAudioSession interruption handling](https://developer.apple.com/documentation/avfaudio/avaudiosession/responding_to_audio_session_interruptions)

### Secondary (MEDIUM confidence)
- [Apple notifyOthersOnDeactivation documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession/setactiveoptions/notifyothersondeactivation)
- [Apple mixWithOthers documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers)

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All solutions use Apple frameworks already available in the project
- Architecture: HIGH - Codebase thoroughly read, exact files and line numbers identified
- Pitfalls: HIGH - NSException behavior is well-documented, audio session lifecycle is a known iOS challenge documented in project memory

**Research date:** 2026-04-07
**Valid until:** 2026-05-07 (stable iOS APIs, unlikely to change)
