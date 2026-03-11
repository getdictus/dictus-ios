# Phase 12: Animation State Fixes - Research

**Researched:** 2026-03-11
**Domain:** SwiftUI animation state management, cross-process state synchronization, watchdog patterns
**Confidence:** HIGH

## Summary

This phase fixes intermittent recording overlay and waveform animation bugs across all dictation state transitions. The work is entirely within existing codebase patterns (SwiftUI + Darwin notifications + App Group), requiring no new libraries or frameworks. The core issue is a mismatch between the DictationStatus state machine and the UI's visibility/animation conditions.

Three concrete bugs drive the work: (1) the overlay visibility condition in KeyboardRootView.swift:72 excludes `.requested`, causing the overlay to not appear on mic tap; (2) AnimatedMicButton.swift:185 uses `asyncAfter` for success flash timing which races with rapid taps; (3) KeyboardState.swift:107-109 resets local state immediately on cancel while the Darwin notification propagation is async, creating a potential UI/state mismatch. Additionally, two new watchdog mechanisms are needed to recover from stuck states.

**Primary recommendation:** Fix the overlay visibility condition to include `.requested`, add a `.requested` visual state to RecordingOverlay (flat waveform + "Demarrage..." + cancel only), implement debounce/disable on the mic button during transitions, and add periodic watchdog timers in both keyboard and app to force-reset stale states.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Overlay appears IMMEDIATELY on mic tap (when status transitions to .requested)
- During .requested: flat waveform bars (no energy data yet), cancel button only (no validate), status text "Demarrage..."
- When .recording arrives: waveform starts moving, validate button appears, status changes to "Listening..." + timer
- No timeout message -- overlay stays with "Demarrage..." until .recording arrives, even on cold start URL scheme path
- Short recordings (< 1s) are still transcribed -- honor user intent, let WhisperKit handle empty results
- No cooldown after transcription -- mic re-enables instantly when status returns to .idle/.ready
- Power users can dictate sentence by sentence rapidly
- TWO recovery mechanisms (belt and suspenders): periodic watchdog + reset on keyboard appear
- Recovery applies to BOTH keyboard (KeyboardState) AND main app (DictationCoordinator)
- Silent reset -- no user-facing error message, just log the event
- Logging: every DictationStatus state change with timestamp + source (keyboard vs app)
- Consistent with Phase 11's structured logging approach (LogEvent types, not free-text)
- No per-frame or per-buffer logging

### Claude's Discretion
- Exact rapid tap protection mechanism (disable during transitions vs debounce vs combo)
- Logging depth calibration (state transitions + overlay events + watchdog events, skip silent periodic checks)
- Animation reset implementation details (SwiftUI state invalidation approach)
- Whether to refactor DictationStatus enum or add overlay-specific state tracking
- Watchdog timer intervals and stale thresholds

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ANIM-01 | Recording overlay always appears when dictation starts (no intermittent disappearance) | Fix overlay visibility condition in KeyboardRootView to include `.requested`; add `.requested` visual state to RecordingOverlay |
| ANIM-02 | Animation state resets properly on rapid status transitions (recording -> transcribing -> ready) | Disable mic button during non-idle/non-ready states; remove asyncAfter race in AnimatedMicButton; use SwiftUI animation state reset pattern |
| ANIM-03 | Waveform and mic button animations never get stuck in stale state | Periodic watchdog timer in KeyboardState + transcription timeout in DictationCoordinator; reset-on-appear in viewWillAppear |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | UI framework (animations, state, views) | Already used throughout project |
| Combine | iOS 17+ | Reactive state forwarding (AudioRecorder -> Coordinator) | Already used for energy/seconds sinks |
| Foundation Timer | iOS 17+ | Watchdog periodic checks | Lightweight, no external dependency |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| DictusCore | Local SPM | Shared types (DictationStatus, LogEvent, PersistentLog) | All state and logging changes |
| Darwin notifications | System | Cross-process state sync | Already the established IPC pattern |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Foundation Timer watchdog | Combine Timer.publish | Timer is simpler for periodic fire-and-forget; Combine Timer requires subscription management |
| @State animation reset | Custom Animatable conformance | @State reset is simpler and matches existing codebase patterns |

## Architecture Patterns

### Recommended Project Structure
No new files needed. All changes are modifications to existing files:
```
DictusKeyboard/
  KeyboardRootView.swift      # Fix overlay visibility condition
  KeyboardState.swift          # Add watchdog timer, debounce logic
  Views/RecordingOverlay.swift # Add .requested visual state
DictusCore/Sources/DictusCore/
  Design/AnimatedMicButton.swift  # Fix asyncAfter race, .requested handling
  LogEvent.swift                  # Add animation/watchdog log events
DictusApp/
  DictationCoordinator.swift      # Add transcription timeout watchdog, .requested guard
```

### Pattern 1: Overlay Visibility with .requested State
**What:** Include `.requested` in the overlay visibility condition so it appears immediately on mic tap.
**When to use:** KeyboardRootView body, the conditional that switches between overlay and keyboard.
**Example:**
```swift
// KeyboardRootView.swift - current (broken):
if state.dictationStatus == .recording || state.dictationStatus == .transcribing {

// Fixed:
if state.dictationStatus == .requested || state.dictationStatus == .recording || state.dictationStatus == .transcribing {
```

### Pattern 2: RecordingOverlay with .requested State
**What:** A new parameter or binding that distinguishes `.requested` from `.recording` to show flat bars + "Demarrage..." + cancel-only.
**When to use:** RecordingOverlay needs to know it's in the requested/waiting state.
**Example:**
```swift
// Add a dictationStatus parameter instead of just isTranscribing:
struct RecordingOverlay: View {
    let dictationStatus: DictationStatus  // replaces isTranscribing Bool
    let waveformEnergy: [Float]
    let elapsedSeconds: Double
    let onCancel: () -> Void
    let onStop: () -> Void

    var body: some View {
        ZStack {
            Color.clear
            switch dictationStatus {
            case .requested:
                requestedContent  // flat bars, "Demarrage...", cancel only
            case .transcribing:
                transcribingContent
            default:
                recordingContent  // waveform + timer + cancel + validate
            }
        }
    }
}
```

### Pattern 3: Mic Button Disable During Transitions
**What:** Disable the mic button for all non-tappable states to prevent rapid-fire starts.
**When to use:** AnimatedMicButton and ToolbarView.
**Example:**
```swift
// AnimatedMicButton - current:
.disabled(status == .recording || status == .transcribing)

// Fixed - also disable during .requested:
.disabled(status != .idle && status != .ready && status != .failed)
```

### Pattern 4: SwiftUI Animation State Reset
**What:** When transitioning away from an animation state, explicitly reset @State animation properties before starting new animations.
**When to use:** AnimatedMicButton.handleStatusChange, BrandWaveform state transitions.
**Example:**
```swift
private func handleStatusChange(from oldStatus: DictationStatus, to newStatus: DictationStatus) {
    // Cancel any pending async work (replaces DispatchQueue.main.asyncAfter)
    showSuccessFlash = false  // Immediate reset

    // Reset ALL animation state variables before starting new animation
    pulseScale = 1.0
    glowOpacity = 0.3
    shimmerOffset = -1.0

    // Success flash: use withAnimation completion (iOS 17+) instead of asyncAfter
    if oldStatus == .transcribing && (newStatus == .ready || newStatus == .idle) {
        showSuccessFlash = true
        withAnimation(.easeOut(duration: 0.3)) {
            showSuccessFlash = false
        }
    }

    // Start new state's animation
    switch newStatus {
    case .idle, .ready, .failed:
        startIdleAnimation()
    case .recording:
        startRecordingAnimation()
    case .transcribing:
        startTranscribingAnimation()
    case .requested:
        break  // No animation -- static state
    }
}
```

### Pattern 5: Watchdog Timer (Keyboard Side)
**What:** A periodic timer that runs during active dictation states and force-resets to `.idle` if no waveform updates arrive for ~5 seconds.
**When to use:** KeyboardState, started when entering `.recording`, stopped when leaving active states.
**Example:**
```swift
// KeyboardState
private var watchdogTimer: Timer?

private func startWatchdog() {
    var lastUpdate = Date()
    watchdogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        guard let self = self else { return }
        DispatchQueue.main.async {
            let isActive = self.dictationStatus == .recording || self.dictationStatus == .transcribing
            guard isActive else {
                self.stopWatchdog()
                return
            }
            // Check if waveform data has been updated recently
            // (refreshFromDefaults updates dictationStatus, waveform updates arrive separately)
            if Date().timeIntervalSince(lastUpdate) > 5.0 {
                PersistentLog.log(.watchdogReset(source: "keyboard", staleState: self.dictationStatus.rawValue))
                self.forceResetToIdle()
            }
        }
    }
}
```

### Pattern 6: Reset on Keyboard Appear
**What:** Check for stale dictation state when the keyboard extension appears and force-reset.
**When to use:** On the `.dictusKeyboardWillAppear` notification in KeyboardRootView.
**Example:**
```swift
.onReceive(NotificationCenter.default.publisher(for: .dictusKeyboardWillAppear)) { _ in
    // Check for stale state from a previous crashed/abandoned session
    if state.dictationStatus == .recording || state.dictationStatus == .transcribing || state.dictationStatus == .requested {
        // Read fresh from App Group to see if the app side agrees
        state.refreshFromDefaults()
        // If still stale after refresh, force reset
        if state.dictationStatus == .recording || state.dictationStatus == .transcribing || state.dictationStatus == .requested {
            PersistentLog.log(.watchdogReset(source: "keyboardAppear", staleState: state.dictationStatus.rawValue))
            state.forceResetToIdle()
        }
    }
}
```

### Anti-Patterns to Avoid
- **DispatchQueue.main.asyncAfter for animation timing:** Races with state changes. Use `withAnimation` completion or immediate state resets instead.
- **Separate Bool flags for overlay visibility:** The DictationStatus enum already contains all necessary states. Adding `isOverlayVisible: Bool` would create dual-source-of-truth bugs.
- **Continuous watchdog polling during idle:** Only run the watchdog timer during active states (.recording, .transcribing). No CPU cost when idle.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Animation cancellation | Custom animation token system | SwiftUI @State reset + withAnimation | SwiftUI handles animation interruption when @State values change |
| Cross-process state sync | Custom file-based IPC | Darwin notifications + App Group UserDefaults | Already established pattern in codebase, battle-tested |
| Periodic timer | GCD timer source | Foundation Timer.scheduledTimer | Simpler API, auto-invalidation on deinit, sufficient for 1s intervals |
| Debounce | Custom DispatchWorkItem-based debounce | Button disable during non-idle states | Simpler, more reliable than time-based debounce for state machine transitions |

**Key insight:** The animation bugs stem from state machine gaps, not from animation framework limitations. The fix is making the state machine complete and ensuring UI conditions match all states.

## Common Pitfalls

### Pitfall 1: SwiftUI Animation Stacking
**What goes wrong:** When a new `withAnimation` call starts while a previous repeating animation is still running, SwiftUI can stack them, causing erratic behavior (e.g., pulseScale oscillating at two different frequencies).
**Why it happens:** `withAnimation(.repeatForever)` creates an animation that never ends. Starting a new `withAnimation` on the same @State property doesn't cancel the old one -- it layers on top.
**How to avoid:** Reset the @State property to a concrete value WITHOUT animation before starting the new animation. The reset cancels the old repeating animation.
**Warning signs:** Button glow or pulse that speeds up or becomes erratic after multiple state transitions.

```swift
// BAD: new animation stacks on old one
func startRecordingAnimation() {
    withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
        pulseScale = 1.3
    }
}

// GOOD: reset first, then animate
func startRecordingAnimation() {
    pulseScale = 1.0  // Cancel old animation by setting concrete value
    glowOpacity = 0.5
    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
        pulseScale = 1.3
    }
}
```

### Pitfall 2: Darwin Notification Delivery Timing
**What goes wrong:** KeyboardState.requestCancel() resets local state immediately, but the Darwin notification to the app is async. If the app side takes time to process, the keyboard might re-enter a "ready" state and accept a new mic tap before the app has actually cleaned up.
**Why it happens:** Darwin notifications are delivered asynchronously across processes. There is no guaranteed delivery time.
**How to avoid:** After cancelling, transition through a brief disabled state. The mic button should only re-enable when status is definitively `.idle` (confirmed by the next App Group read).
**Warning signs:** Tap cancel then immediately tap mic -- gets into a confused state.

### Pitfall 3: Timer Retain Cycles in KeyboardState
**What goes wrong:** `Timer.scheduledTimer(withTimeInterval:repeats:block:)` with a closure that captures `self` creates a retain cycle that prevents KeyboardState from deallocating.
**Why it happens:** The Timer retains the closure, the closure retains self, self's lifecycle is tied to the keyboard extension which can be reloaded.
**How to avoid:** Use `[weak self]` in the timer closure. Also explicitly `invalidate()` the timer when stopping the watchdog and in `deinit`.
**Warning signs:** Memory usage creeping up in the keyboard extension across multiple keyboard show/hide cycles.

### Pitfall 4: viewWillAppear vs .onAppear in Keyboard Extensions
**What goes wrong:** SwiftUI's `.onAppear` fires only ONCE per extension process lifetime (the hosting UIHostingController is created once). But the keyboard appears/disappears many times.
**Why it happens:** The keyboard extension keeps its UIHostingController alive across keyboard show/hide cycles. SwiftUI considers the view as "appeared" the whole time.
**How to avoid:** Use the custom `.dictusKeyboardWillAppear` notification (already posted from the keyboard controller's `viewWillAppear`) for per-appearance logic like stale state detection.
**Warning signs:** Watchdog reset logic that only works the first time the keyboard appears.

### Pitfall 5: BrandWaveform displayLevels Not Resetting
**What goes wrong:** When transitioning from `.recording` to `.idle`, the BrandWaveform's `@State displayLevels` retain their last values. If the view is conditionally shown (removed from hierarchy), SwiftUI may or may not preserve @State.
**Why it happens:** SwiftUI's @State preservation depends on view identity. If the overlay is conditionally rendered (`if status == .recording`), SwiftUI destroys and recreates the view, resetting @State. But if the condition changes to include `.requested`, the view stays alive across `.requested` -> `.recording` -> `.transcribing`, so displayLevels persist.
**How to avoid:** Explicitly reset `displayLevels` when entering `.requested` or when energyLevels is empty. The `targetLevels()` function already handles empty input, but displayLevels might retain previous non-zero values that decay slowly.
**Warning signs:** Brief flash of old waveform pattern when starting a new recording.

## Code Examples

### New LogEvent Cases for Phase 12
```swift
// Add to LogEvent.swift
// MARK: Animation / Watchdog
case overlayShown(status: String)        // When overlay becomes visible
case overlayHidden(status: String)       // When overlay is removed
case statusChanged(from: String, to: String, source: String)  // Every DictationStatus transition
case watchdogReset(source: String, staleState: String)  // Watchdog force-reset
case rapidTapRejected                    // Mic tap ignored during transition
```

### ForceResetToIdle for KeyboardState
```swift
// KeyboardState.swift
func forceResetToIdle() {
    dictationStatus = .idle
    waveformEnergy = []
    recordingElapsed = 0
    statusMessage = nil

    // Also write to App Group so the app side sees the reset
    defaults.set(DictationStatus.idle.rawValue, forKey: SharedKeys.dictationStatus)
    defaults.synchronize()
    DarwinNotificationCenter.post(DarwinNotificationName.statusChanged)
}
```

### Transcription Timeout Watchdog for DictationCoordinator
```swift
// DictationCoordinator.swift
private var transcriptionWatchdog: Timer?

private func startTranscriptionWatchdog() {
    transcriptionWatchdog?.invalidate()
    transcriptionWatchdog = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
        DispatchQueue.main.async {
            guard let self = self, self.status == .transcribing else { return }
            PersistentLog.log(.watchdogReset(source: "appTranscription", staleState: "transcribing"))
            self.cancelDictation()  // Force-reset, cleans up everything
        }
    }
}
```

### DictationCoordinator startDictation Guard Fix
```swift
// Current (missing .requested):
guard status == .idle || status == .failed || status == .ready else { return }

// Fixed -- also allow starting from .requested (keyboard already set this):
guard status == .idle || status == .failed || status == .ready || status == .requested else { return }
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| asyncAfter for animation timing | withAnimation + immediate @State reset | iOS 17 (withAnimation completion API) | Eliminates race conditions on rapid transitions |
| Bool flags for overlay (isTranscribing) | DictationStatus enum directly | This phase | Single source of truth, no dual-state bugs |
| No recovery mechanism | Watchdog timer + reset-on-appear | This phase | Self-healing from stuck states |

**Deprecated/outdated:**
- `DispatchQueue.main.asyncAfter` for animation timing in AnimatedMicButton: Replace with immediate @State manipulation. The asyncAfter pattern is a race condition source.

## Open Questions

1. **iOS 17 withAnimation completion API availability**
   - What we know: iOS 17 introduced `withAnimation(.easeOut(duration: 0.3)) { ... } completion: { ... }` which could replace the asyncAfter for the success flash.
   - What's unclear: Whether this completion API works reliably with the `showSuccessFlash` Bool toggle pattern.
   - Recommendation: Test with a simpler approach first -- just set `showSuccessFlash = true`, then immediately `withAnimation(.easeOut(duration: 0.3)) { showSuccessFlash = false }`. SwiftUI will animate the transition. If that doesn't work visually, use the completion API.

2. **Waveform state across overlay lifecycle**
   - What we know: When the overlay view is conditionally shown in KeyboardRootView, SwiftUI destroys/recreates it. With `.requested` included in the condition, the overlay persists across `.requested` -> `.recording` -> `.transcribing`.
   - What's unclear: Whether BrandWaveform's @State displayLevels correctly resets when transitioning from `.requested` (flat) to `.recording` (live energy).
   - Recommendation: Pass an explicit `isRequested` or use the DictationStatus to control whether BrandWaveform renders flat bars vs. live data. The targetLevels() function already returns zeros for empty energyLevels, so this should work naturally as long as waveformEnergy is empty during `.requested`.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (bundled with Xcode) |
| Config file | Dictus.xcodeproj scheme settings |
| Quick run command | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DictusAppTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 \| tail -30` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ANIM-01 | Overlay appears on .requested status | manual-only | Manual: tap mic 20x, verify overlay appears every time | N/A -- SwiftUI view state, requires device testing |
| ANIM-02 | Rapid taps don't leave stale state | manual-only | Manual: rapid start/stop/start within 1s, verify no stale overlay | N/A -- cross-process timing, requires device |
| ANIM-03 | Waveform/mic never stuck | manual-only | Manual: complete dictation, verify mic returns to ready | N/A -- requires real audio session |

**Justification for manual-only:** All three requirements involve cross-process Darwin notification timing, AVAudioSession state, and SwiftUI animation rendering. These cannot be reliably tested in XCTest unit tests. The success criteria explicitly state "20 consecutive tests" which implies manual device testing. Phase 11's logging infrastructure enables diagnosis when manual tests reveal issues.

### Sampling Rate
- **Per task commit:** Build succeeds (`xcodebuild build -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`)
- **Per wave merge:** Manual testing protocol on device (20 consecutive mic taps, rapid tap sequences, full dictation cycle)
- **Phase gate:** All 3 success criteria pass manual verification

### Wave 0 Gaps
None -- no automated test infrastructure needed. This phase relies on manual device testing supported by Phase 11's logging. The LogEvent additions (statusChanged, watchdogReset, overlayShown/Hidden) serve as the verification mechanism.

## Sources

### Primary (HIGH confidence)
- Source code analysis of all 7 files involved: KeyboardRootView.swift, KeyboardState.swift, RecordingOverlay.swift, AnimatedMicButton.swift, BrandWaveform.swift, DictationCoordinator.swift, DictationStatus.swift
- Source code analysis of Phase 11 logging infrastructure: LogEvent.swift, PersistentLog.swift
- CONTEXT.md user decisions from discussion session

### Secondary (MEDIUM confidence)
- SwiftUI animation stacking behavior: based on established SwiftUI patterns. `withAnimation(.repeatForever)` stacking is a well-documented gotcha in the SwiftUI community.
- Timer retain cycle patterns: standard Foundation behavior, documented in Apple's Timer documentation.

### Tertiary (LOW confidence)
- iOS 17 `withAnimation` completion API: verified it exists in iOS 17, but exact behavior with Bool toggling needs validation during implementation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new libraries, all changes within existing codebase patterns
- Architecture: HIGH -- bugs are clearly identified with line numbers, fixes are straightforward state machine corrections
- Pitfalls: HIGH -- derived directly from code analysis of actual race conditions and SwiftUI animation behavior

**Research date:** 2026-03-11
**Valid until:** No expiry -- this research is codebase-specific, not library-version-dependent
