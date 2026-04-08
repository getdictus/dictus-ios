# Phase 17: Bug Fixes - Research

**Researched:** 2026-03-27
**Domain:** iOS Live Activity state machine, file I/O optimization, cold start timing
**Confidence:** HIGH

## Summary

Phase 17 fixes 3 known bugs in the v1.2 codebase before the keyboard architecture change (Phase 18+). The bugs span three distinct domains: (1) Dynamic Island state desync after recording ends, (2) slow log export with no spinner, and (3) grayed-out overlay on cold start swipe-back. All three bugs live in well-understood code with extensive existing comments and logging infrastructure.

The codebase already has a formal state machine in `LiveActivityManager` with transition validation (added during issue #42), structured logging via `PersistentLog` with typed `LogEvent` cases, and a cold start flow using `SwipeBackOverlayView`. The test infrastructure exists in `DictusCore` (SPM test target, 13 test files) but there is NO `DictusAppTests` Xcode test target -- LiveActivityManager tests will need to be designed as pure state machine logic tests in DictusCore, or a new test target must be created in Xcode.

**Primary recommendation:** Fix bugs in order FIX-01 (watchdog), FIX-02 (export), FIX-03 (overlay) -- each is independent and can be verified before moving to the next. Add unit tests for LiveActivityManager state transitions by extracting testable logic into DictusCore.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- FIX-01: Twofold approach -- audit state machine + add post-recording watchdog (~10s) that forces standby if DI stuck on REC after recording ended. Watchdog logs detailed error when it fires.
- FIX-02: Investigate and optimize `PersistentLog.exportContent()`, add spinner, implement 7-day log retention with auto-prune.
- FIX-03: User performs targeted manual tests first (fast vs slow swipe-back), then reinforce logs, then fix. Overlay must show valid state or "connecting..." -- never grayed-out dead state.
- Testing: Unit tests for LiveActivityManager state machine transitions (first unit tests in project). Manual test checklist for Pierre.

### Claude's Discretion
- Exact watchdog timeout duration (around 10s, adjustable)
- Export spinner placement (inline ProgressView vs fullscreen overlay) based on measured export time
- Log retention implementation approach (prune on write, prune on export, or background task)
- Unit test framework setup and file organization
- How to handle the cold start overlay "connecting" intermediate state

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FIX-01 | Dynamic Island no longer gets stuck on REC state (issue #60) | State machine analysis complete -- identified race conditions in transition paths, watchdog pattern documented |
| FIX-02 | Export logs shows spinner and completes quickly (issue #61) | PersistentLog I/O analysis complete -- NSFileCoordinator double-read identified as bottleneck, retention approach researched |

</phase_requirements>

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Notes |
|---------|---------|---------|-------|
| ActivityKit | iOS 17+ | Live Activity / Dynamic Island | Already used in LiveActivityManager |
| XCTest | built-in | Unit testing | Already configured for DictusCore SPM package |
| NSFileCoordinator | Foundation | Cross-process file coordination | Already used in PersistentLog |

### No New Dependencies Required
This phase is pure bug fixes in existing code. No new libraries needed.

## Architecture Patterns

### Pattern 1: Post-Recording Watchdog for Dynamic Island
**What:** A safety net that detects when the DI stays on `.recording` phase after DictationCoordinator has signaled recording stopped (via `endWithResult`, `endWithFailure`, or `returnToStandby`).
**When to use:** After every recording stop/cancel.

**Analysis of current race conditions:**

The state machine has 5 transition paths out of `.recording`:
1. `stopDictation()` -> `transitionToTranscribing()` -> `endWithResult()` -> `returnToStandby()` (happy path)
2. `stopDictation()` -> `transitionToTranscribing()` -> `endWithFailure()` -> `returnToStandby()` (transcription error)
3. `cancelDictation()` -> `returnToStandby()` (user cancel)
4. `handleError()` -> `endWithFailure()` -> `returnToStandby()` (engine error)
5. `transcriptionWatchdog` -> `cancelDictation()` -> `returnToStandby()` (30s timeout)

**Where DI can get stuck on REC:**
- If `validateTransition(to: .transcribing)` rejects (currentPhase not `.recording` due to race)
- If `endWithResult`/`endWithFailure` guard on `currentActivity == nil` returns early (activity was killed externally)
- If the `autoDismissTask` is cancelled between states and `returnToStandby()` never fires
- If `Task { await activity.update(...) }` silently fails (ActivityKit budget exceeded, activity expired)

**Watchdog implementation pattern:**
```swift
// In LiveActivityManager
private var recordingWatchdog: Task<Void, Never>?

func startRecordingWatchdog() {
    recordingWatchdog?.cancel()
    recordingWatchdog = Task {
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
        guard !Task.isCancelled else { return }
        guard currentPhase == .recording else { return }
        // DI is still on recording but nobody is recording
        PersistentLog.log(.watchdogReset(source: "liveActivity", staleState: "recording"))
        await returnToStandby()
    }
}

func cancelRecordingWatchdog() {
    recordingWatchdog?.cancel()
    recordingWatchdog = nil
}
```

**Key insight:** The watchdog does NOT run during recording. It starts when DictationCoordinator signals the recording has ended. If the DI successfully transitions away from `.recording`, the watchdog's `guard currentPhase == .recording` exits harmlessly.

**Where to trigger:**
- Start watchdog in `DictationCoordinator.stopDictation()` and `cancelDictation()` AFTER the LiveActivityManager transition call
- Cancel watchdog in `transitionToRecording()` (new recording started)
- The watchdog is a LiveActivityManager concern, but DictationCoordinator tells it when to arm

### Pattern 2: Optimized Log Export
**What:** Replace the current double-read pattern with a single coordinated read.
**Current bottleneck analysis:**

`exportContent()` calls:
1. `buildExportHeader()` -- reads Bundle info + AppGroup defaults (fast, <1ms)
2. `read()` -- calls `coordinatedRead()` which uses `NSFileCoordinator.coordinate(readingItemAt:)` + `String(contentsOf:)`

The issue is NOT just the file read. The `coordinatedRead` acquires a file coordination lock, which blocks if another process (keyboard extension) is writing. Additionally, on every `log()` call, `coordinatedTrim()` reads the ENTIRE file to count lines, then rewrites it if over limit. This means:
- During active dictation, the keyboard and app are both writing logs
- `coordinatedTrim()` reads + rewrites the file on EVERY log write
- `exportContent()` must wait for any in-progress write+trim to release the lock

**Optimization strategy:**
1. **Replace line-counting trim with byte-size limit** -- check file size instead of reading all content to count lines. A 1000-line log at ~150 bytes/line is ~150KB. Set a byte limit (e.g., 200KB) and truncate from the front when exceeded.
2. **Add date-based retention** -- before export, prune entries older than 7 days. Parse the ISO8601 timestamp at the start of each line.
3. **Consider reading without NSFileCoordinator for export** -- the export is a snapshot read. If we tolerate a potentially incomplete last line, we can skip coordination. However, this risks reading a partially-written file. Safer: keep coordination but optimize trim.

**Spinner placement recommendation:**
The current code already has `isExporting` state and a `ProgressView()` inline on the button. The issue is that the export completes so slowly that the user sees nothing for seconds. After optimization, if export takes <1s, the inline spinner is sufficient. If it still takes >1s, switch to a small overlay. Recommend: optimize first, measure, then decide.

### Pattern 3: Cold Start Overlay State Sync
**What:** The grayed-out overlay happens when the user swipe-backs to the keyboard before the app has fully established the recording state in App Group.
**Analysis of the timing gap:**

Cold start flow:
1. Keyboard sends Darwin notification -> app not running -> falls back to URL scheme after 500ms
2. `DictusApp.handleIncomingURL` sets `coldStartActive = true`, calls `coordinator.startDictation(fromURL: true)`
3. `startDictation` detects `appState != .active` -> sets `pendingColdStartDictation = true` -> returns
4. `didBecomeActive` fires -> calls `startDictation(fromURL: true)` for real
5. Audio engine starts, `updateStatus(.recording)` writes to App Group
6. User swipe-backs to keyboard

**Where it breaks:** If user swipe-backs between step 3 and step 5 (before `updateStatus(.recording)` fires), the keyboard sees `dictationStatus = requested` (from step 2) but no active recording data. The overlay renders in a half-initialized state.

**Fix approach:**
- The keyboard overlay should check both `dictationStatus` AND a heartbeat/timestamp
- Add a "connecting" intermediate UI state in the keyboard overlay
- DictationCoordinator should write a `recordingHeartbeat` timestamp to App Group periodically during recording
- If the keyboard sees `dictationStatus = recording` but heartbeat is stale (>2s old), show "Connexion..." instead of the full recording overlay

### Anti-Patterns to Avoid
- **Increasing the autoDismissTask timeout** to "fix" stuck DI -- this masks the root cause
- **Adding multiple watchdogs** that compete -- one watchdog per concern (recording DI, transcription timeout)
- **Removing NSFileCoordinator** entirely -- it exists because both processes write to the same file

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Date parsing in logs | Custom date parser | ISO8601DateFormatter | Already used in log write path, guaranteed format match |
| File size check | Read file + count lines | FileManager.attributesOfItem(atPath:)[.size] | O(1) vs O(n) for trim decision |
| Task cancellation | Manual boolean flags | Swift structured concurrency Task.isCancelled | Built-in, race-free cancellation |

## Common Pitfalls

### Pitfall 1: Watchdog fires during legitimate recording
**What goes wrong:** Watchdog starts too early (before recording actually ends) and kills a valid recording.
**Why it happens:** If the watchdog is started in `transitionToRecording()` instead of when recording ENDS.
**How to avoid:** Only arm the watchdog AFTER DictationCoordinator has called stop/cancel. The watchdog should be a "post-recording" safety net, not a recording timeout.
**Warning signs:** Recordings being cut off at exactly 10 seconds.

### Pitfall 2: coordinatedTrim creates write amplification
**What goes wrong:** Every log write triggers a full file read + potential rewrite, making logging O(n) instead of O(1).
**Why it happens:** `coordinatedTrim` reads the entire file to count lines on every `log()` call.
**How to avoid:** Check file size (O(1)) instead of line count (O(n)). Only trim when size exceeds threshold.
**Warning signs:** Logging itself becoming slow, export taking seconds.

### Pitfall 3: Race between isColdStartMode reset and recording state
**What goes wrong:** `scenePhase == .background` sets `isColdStartMode = false` in MainTabView, but the recording overlay check (`coordinator.status != .idle && !isColdStartMode`) may not show the RecordingView if timing is wrong.
**Why it happens:** SwiftUI state updates are asynchronous. The scenePhase change and the coordinator status change may not arrive in the expected order.
**How to avoid:** The overlay decision should be based on a single source of truth, not two independent state variables.
**Warning signs:** Flash of wrong UI when returning from cold start overlay.

### Pitfall 4: ActivityKit silently drops updates
**What goes wrong:** `activity.update()` succeeds (no error thrown) but the DI doesn't visually change.
**Why it happens:** ActivityKit has an undocumented update budget (~1/second). Exceeding it causes silent drops.
**How to avoid:** The existing 1Hz throttle on waveform updates is correct. State transitions (recording->transcribing->ready) are infrequent enough. But rapid cancel+restart could hit the limit.
**Warning signs:** DI shows stale state briefly after transitions.

### Pitfall 5: Test target isolation from UIKit/ActivityKit
**What goes wrong:** Trying to test LiveActivityManager directly requires ActivityKit which is unavailable in SPM test targets.
**Why it happens:** LiveActivityManager depends on `Activity<T>`, `ActivityAuthorizationInfo`, and `UIApplication` -- all iOS-only, no macOS equivalent.
**How to avoid:** Extract the pure state machine logic (transition validation, phase tracking, watchdog timing) into a protocol or testable struct in DictusCore. Test the logic, not the ActivityKit calls.
**Warning signs:** Tests that only work in Xcode simulator, not `swift test`.

## Code Examples

### Extractable State Machine for Testing
```swift
// In DictusCore -- testable without ActivityKit
struct LiveActivityStateMachine {
    enum Phase: String { case idle, standby, recording, transcribing, ready, failed }

    private(set) var currentPhase: Phase = .idle

    private let validTransitions: [Phase: Set<Phase>] = [
        .idle: [.standby],
        .standby: [.recording, .idle],
        .recording: [.transcribing, .standby],
        .transcribing: [.ready, .failed],
        .ready: [.standby, .recording],
        .failed: [.standby, .recording, .idle]
    ]

    mutating func transition(to target: Phase) -> Bool {
        let allowed = validTransitions[currentPhase] ?? []
        guard allowed.contains(target) else { return false }
        currentPhase = target
        return true
    }
}
```

### Optimized Trim by File Size
```swift
// Replace coordinatedTrim with size-based check
private static let maxFileSize: UInt64 = 200_000 // ~200KB

private static func shouldTrim(url: URL) -> Bool {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
          let size = attrs[.size] as? UInt64 else { return false }
    return size > maxFileSize
}
```

### Date-Based Log Retention
```swift
// Prune entries older than 7 days
static func pruneOldEntries(from content: String, maxAge: TimeInterval = 7 * 24 * 3600) -> String {
    let cutoff = Date().addingTimeInterval(-maxAge)
    let formatter = ISO8601DateFormatter()

    return content
        .components(separatedBy: "\n")
        .filter { line in
            // Log format: [2026-03-27T10:30:00Z] ...
            guard line.count > 22,
                  let bracket = line.firstIndex(of: "]"),
                  let dateStr = line.dropFirst().prefix(upTo: bracket) as? Substring,
                  let date = formatter.date(from: String(dateStr)) else {
                return true // keep unparseable lines
            }
            return date > cutoff
        }
        .joined(separator: "\n")
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Line-counting trim on every write | Size-based trim check | This phase | O(1) instead of O(n) per log write |
| No post-recording DI watchdog | Watchdog forces standby after recording ends | This phase | Eliminates stuck DI bug |
| Binary cold start (recording or not) | Three-state: not-recording / connecting / recording | This phase | Eliminates grayed-out overlay |

## Open Questions

1. **Can LiveActivityManager state machine be extracted to DictusCore?**
   - What we know: The transition validation logic is pure (no ActivityKit dependency). Phase enum and validation table can be extracted.
   - What's unclear: Whether DictusCore's Package.swift needs changes, and whether the existing LiveActivityManager can delegate to the extracted logic cleanly.
   - Recommendation: Extract `LiveActivityStateMachine` struct to DictusCore, have LiveActivityManager use it internally. Tests go in DictusCoreTests.

2. **Exact export duration after optimization**
   - What we know: Current export is "painfully slow" even with small logs. The trim-on-every-write is the likely culprit.
   - What's unclear: How much improvement the size-based trim gives. Need to measure before deciding spinner placement.
   - Recommendation: Implement optimization first, measure on device, then decide inline vs overlay spinner.

3. **FIX-03 cold start overlay -- what exactly does "grayed out" mean?**
   - What we know: Timer runs, "En ecoute..." visible, waveform flat, buttons non-responsive. Happens ~1/3 cold starts.
   - What's unclear: Whether the keyboard overlay is reading stale App Group data, or whether the view is rendered but events aren't reaching it.
   - Recommendation: User manual testing first (per CONTEXT.md decision), then enhanced logging before coding the fix.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built-in, already configured) |
| Config file | `DictusCore/Package.swift` (testTarget: DictusCoreTests) |
| Quick run command | `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet` |
| Full suite command | `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FIX-01 | DI transitions never get stuck on .recording after recording ends | unit | `xcodebuild test -scheme DictusCore ... -only-testing:DictusCoreTests/LiveActivityStateMachineTests` | No -- Wave 0 |
| FIX-01 | Watchdog fires when phase stays .recording too long after stop | unit | same as above | No -- Wave 0 |
| FIX-01 | All valid transition paths succeed, invalid ones are rejected | unit | same as above | No -- Wave 0 |
| FIX-02 | Export produces valid content with header | unit | `xcodebuild test -scheme DictusCore ... -only-testing:DictusCoreTests/PersistentLogTests` | Yes (exists) |
| FIX-02 | Log retention prunes entries older than 7 days | unit | same as above | No -- Wave 0 |
| FIX-02 | Trim uses file size, not line counting | unit | same as above | No -- Wave 0 |
| FIX-01 | DI visual state matches internal state during real recording flow | manual | Pierre manual test checklist | N/A |
| FIX-02 | Export shows spinner and completes in <2s | manual | Pierre manual test checklist | N/A |
| FIX-03 | Cold start overlay never shows grayed-out dead state | manual | Pierre manual test checklist | N/A |

### Sampling Rate
- **Per task commit:** Quick test of affected module
- **Per wave merge:** Full DictusCoreTests suite
- **Phase gate:** Full suite green + Pierre manual test checklist passed

### Wave 0 Gaps
- [ ] `DictusCore/Sources/DictusCore/LiveActivityStateMachine.swift` -- extracted testable state machine
- [ ] `DictusCore/Tests/DictusCoreTests/LiveActivityStateMachineTests.swift` -- covers FIX-01
- [ ] `DictusCore/Tests/DictusCoreTests/PersistentLogTests.swift` -- extend existing file with retention + size-based trim tests
- [ ] Fix `maxLines` discrepancy: code says 1000, existing test asserts 500 -- reconcile before adding new tests

## Sources

### Primary (HIGH confidence)
- Direct code analysis of `LiveActivityManager.swift` (542 lines) -- full state machine with extensive WHY comments
- Direct code analysis of `PersistentLog.swift` (247 lines) -- NSFileCoordinator I/O pattern
- Direct code analysis of `DictationCoordinator.swift` (684 lines) -- all recording lifecycle paths
- Direct code analysis of `MainTabView.swift` (115 lines) -- cold start overlay flow
- Direct code analysis of `DictusApp.swift` (161 lines) -- URL scheme handling
- Existing test files in `DictusCore/Tests/DictusCoreTests/` -- 13 test files, established patterns

### Secondary (MEDIUM confidence)
- ActivityKit update budget (~1/sec) -- based on Apple documentation and developer experience, not formally documented limit

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, all existing code
- Architecture (FIX-01): HIGH -- state machine is well-documented, race conditions identifiable from code
- Architecture (FIX-02): HIGH -- I/O bottleneck is clear from code analysis
- Architecture (FIX-03): MEDIUM -- exact cause needs manual testing first (per user decision)
- Pitfalls: HIGH -- drawn from existing code comments documenting past bugs (#42, #49)

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stable codebase, no external dependency changes expected)
