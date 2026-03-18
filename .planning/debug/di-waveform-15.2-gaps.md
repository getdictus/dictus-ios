---
status: awaiting_human_verify
trigger: "Phase 15.2 on-device testing: DI stuck in .failed, waveform dies after app switch, stale transcription card"
created: 2026-03-17T00:00:00Z
updated: 2026-03-17T00:03:00Z
---

## Current Focus

hypothesis: CONFIRMED — BrandWaveform @State displayLevels initializes to all zeros on .id() recreation
test: Added .onAppear to seed displayLevels from current energyLevels
expecting: Waveform shows correct bars immediately on keyboard reappear during cold start
next_action: Awaiting human verification on device

## Symptoms

expected:
1. Dynamic Island recovers from .failed state and continues tracking recording state
2. Waveform animation in keyboard extension survives app switching
3. Previous transcription card is cleared when starting new recording

actual:
1. DI gets stuck in .failed permanently — every transition gets REJECTED
2. Waveform animation stops painting after app switches despite data flowing
3. Stale transcription card may still appear

errors:
- 17 REJECTED transitions from LiveActivityManager
- Pattern: failed->REJECTED-recording, failed->REJECTED-transcribing, failed->REJECTED-ready
- renderTick increments but Canvas does not repaint

reproduction:
1. Cold start triggers endWithFailure -> DI enters .failed -> auto-dismiss Task dies -> stuck
2. Switch between 3+ apps with keyboard open -> waveform stops
3. Start new recording -> old card may persist

started: Phase 15.2 state machine refactor

## Eliminated

## Evidence

- timestamp: 2026-03-17T00:00:30Z
  checked: LiveActivityManager.swift validateTransition() transition table (line 46-53)
  found: `.failed: [.standby]` — only .standby is allowed from .failed. No recovery to .recording or .idle.
  implication: When autoDismissTask is killed by iOS (cold start chaos), there is NO way out of .failed. Every subsequent recording triggers REJECTED transitions.

- timestamp: 2026-03-17T00:00:30Z
  checked: LiveActivityManager.swift transitionToRecording() (line 214-245)
  found: transitionToRecording() cancels autoDismissTask (line 219-220) BEFORE validateTransition (line 223). If state is .failed, the cancel succeeds but validate rejects. The autoDismissTask that would have returned to .standby is now gone AND the transition is rejected — permanent deadlock.
  implication: CONFIRMED root cause for Issue 1. The cancel-before-validate ordering removes the only recovery path.

- timestamp: 2026-03-17T00:00:30Z
  checked: BrandWaveform.swift body (line 73-103)
  found: TimelineView(.animation) drives updateDisplayLevels() via onChange(of: timeline.date). After app switch (keyboardDidDisappear + keyboardDidAppear), the TimelineView's CADisplayLink may not restart. There's a fallback onChange(of: energyLevels) at line 97 but it only calls updateDisplayLevels() which updates @State displayLevels — this does NOT guarantee Canvas repainting if SwiftUI's view identity was invalidated during suspension.
  implication: The existing fallback (onChange of energyLevels) should theoretically work, but combined with renderTick already being used, the issue may be that Canvas reads `renderTick` but SwiftUI doesn't know it's a dependency because Canvas doesn't participate in normal SwiftUI diffing. Need to force view identity reset or use .id() modifier.

- timestamp: 2026-03-17T00:00:30Z
  checked: Device logs (dictus-logs 35.txt lines 20, 29, 54, 97)
  found: Every single DI transition is REJECTED from .failed state. Pattern repeats across all recordings in the session. The .failed state was entered before logging started.
  implication: Confirms Issue 1 root cause — .failed is a terminal state with no recovery.

- timestamp: 2026-03-17T00:00:30Z
  checked: DictationCoordinator.swift startDictation() (line 196-199)
  found: lastResult = nil is set at line 196, BEFORE status guard at line 202. The clearing happens correctly regardless of entry path (DI tap, lockscreen, keyboard). Logs at line 46 confirm "clearing-for-new" fires.
  implication: Issue 3 (stale card) is likely NOT a data issue but a SwiftUI rendering timing issue — the keyboard extension may show cached view state briefly after reload. Lower priority, may resolve itself once DI issue is fixed (fewer error states = less UI chaos).

- timestamp: 2026-03-17T00:03:00Z
  checked: Device logs dictus-logs 36.txt — cold start overlay freeze sequence
  found: |
    DI fix CONFIRMED WORKING (zero REJECTED transitions in new logs).
    Cold start overlay freeze sequence:
    1. 14:45:43 — keyboard briefly reappears, body fires with energyCount=9/12/15
    2. 14:45:44 — keyboardDidDisappear, keyboard goes off-screen again
    3. 14:45:44-49 — readWaveformData() continues (18→30 levels) but ZERO body: logs
    4. Screenshot shows "00:01 En écoute..." with completely grey waveform
    Root cause: BrandWaveform recreated via .id(waveformRefreshID) on keyboard reappear,
    but @State displayLevels initializes to Array(repeating: 0, count: 30). The lerp
    animation (smoothingFactor=0.3) needs multiple frames to reach visible levels.
    Keyboard disappears again before animation catches up → frozen grey waveform.
    Second recording (14:46:20, warm start) works perfectly — body: logs fire continuously
    with increasing energy counts, waveform animates normally.
  implication: Fix must initialize displayLevels from energyLevels on first appearance, not from zeros.

## Resolution

root_cause: |
  Issue 1 (DI stuck): FIXED in prior session. validateTransition() table expanded, confirmed working.

  Issue 2 (waveform grey on cold start reappear): BrandWaveform is recreated via .id(waveformRefreshID)
  when the keyboard reappears. The @State displayLevels initializes to Array(repeating: 0, count: 30).
  The lerp animation needs ~10 frames (smoothingFactor=0.3) to reach visible energy levels. During cold
  start, the keyboard only stays visible for ~1 second before disappearing again due to the app-switch
  dance. The waveform appears grey/empty because the animation hasn't caught up before the view goes
  off-screen. When SwiftUI stops evaluating body for off-screen views, the animation freezes at near-zero.

  Issue 3 (timer frozen at 00:01): NOT actually a bug — the timer correctly showed ~1 second because the
  recording had only been running for 1 second when the keyboard briefly appeared during cold start.
  The timer mechanism works correctly; the appearance of being "frozen" is because the keyboard goes
  off-screen again and doesn't come back during the recording.

fix: |
  Issue 1 — ALREADY FIXED (prior session). DI recovery from .failed confirmed working on device.

  Issue 2 — BrandWaveform.swift:
  Added .onAppear handler that seeds @State displayLevels from current energyLevels via targetLevels().
  When the view is recreated via .id(waveformRefreshID) on keyboard reappear, displayLevels is
  immediately populated with the current energy snapshot instead of all zeros. The waveform shows
  correctly on the very first frame — no animation catch-up needed.

  Prior session fixes remain in place:
  - waveformRefreshID counter in KeyboardState (incremented on every keyboard reappear)
  - .id(waveformRefreshID) on all 3 BrandWaveform instances in RecordingOverlay
  - refreshFromDefaults() + readWaveformData() on keyboard reappear

  Issue 3 — No code change needed. Timer was showing correct value.

verification: Build passes (xcodebuild -scheme DictusApp -destination iPhone 17 Pro simulator). Awaiting on-device verification.
files_changed:
  - DictusCore/Sources/DictusCore/Design/BrandWaveform.swift
