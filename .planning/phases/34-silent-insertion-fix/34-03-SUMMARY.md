---
phase: 34-silent-insertion-fix
plan: 03
subsystem: keyboard

tags: [dictus-keyboard, text-insertion, stab-01, privacy-logging, haptics, swiftui-banner, app-group, retry-backoff]

# Dependency graph
requires:
  - phase: 34-01
    provides: "LogEvent.keyboardInsertProbe/Retry/Failed cases, HapticFeedback.insertionFailed(), InsertionClassifier pure-logic classifier"
  - phase: 34-02
    provides: "HomeView.recoverableTranscription App Group recovery surface — receives the transcription preserved by this plan's failure path"
provides:
  - "InsertTranscriptionHelper — single point of truth for transcription insertion (validate -> insert -> verify -> retry -> escalate)"
  - "KeyboardState.dispatchInsertion / escalateInsertionFailure / resetToIdleAfterInsertion — shared success/failure teardown wired to helper callback"
  - "FR/EN red-banner loud-fail escalation in the keyboard toolbar with 4s auto-clear + error haptic on terminal insertion failure"
  - "Privacy-safe insertion probe telemetry — counts/booleans/timings only, zero raw-text leakage (verified by grep on real-device logs)"
  - "App Group preservation on failure — handleTranscriptionReady's pre-helper clear is reversed inside dispatchInsertion's .failed branch, honoring Plan 34-02's recovery contract"
affects: [34-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Validate -> insert -> verify -> retry -> escalate — single helper wraps the sole insertText call site; cold start re-enters the same handleTranscriptionReady via Darwin notification, so no second physical call site exists"
    - "Exact retry schedule 50/100/200 ms via DispatchQueue.main.asyncAfter (NOT Timer / NOT Thread.sleep) — matches CONTEXT.md locked decision"
    - "Failure-path App Group re-write: handleTranscriptionReady clears SharedKeys.lastTranscription BEFORE the helper runs (duplicate-insertion guard); .failed branch re-writes the value + timestamp so HomeView.recoverableTranscription can surface it"
    - "Banner guard on 4s auto-clear — `if self.statusMessage == message` so a newer banner from another code path isn't stomped"
    - "Path discrimination via SharedKeys.coldStartActive read at entry — .warmDarwin vs .coldStartBridge is captured once for the probe, not re-evaluated per retry"

key-files:
  created:
    - "DictusKeyboard/TextInsertion/InsertTranscriptionHelper.swift"
  modified:
    - "DictusKeyboard/KeyboardState.swift"
    - "Dictus.xcodeproj/project.pbxproj"

key-decisions:
  - "Shipped helper at DictusKeyboard/TextInsertion/InsertTranscriptionHelper.swift with pbxproj entries (preferred placement per plan). No fallback to flat layout needed."
  - "Helper uses proxy.hasText (UITextDocumentProxy -> UIKeyInput) instead of ctrl.hasText for the before/after snapshot. Same semantics at this call site; preferring the proxy is more literal about what is being probed."
  - "handleTranscriptionReady keeps the pre-helper removeObject + synchronize pattern for both primary and 100ms-retry paths — duplicate-insertion guard against repeated Darwin notifications is preserved. The .failed branch re-writes SharedKeys.lastTranscription + SharedKeys.lastTranscriptionTimestamp, closing the Plan 34-02 contract."
  - "Haptic is fired by the caller (dispatchInsertion), not inside the helper — helper remains UI/feedback-agnostic. Success: HapticFeedback.textInserted(). Failure: HapticFeedback.insertionFailed()."
  - "resetToIdleAfterInsertion does NOT clear statusMessage — success branch clears it explicitly BEFORE the reset (to wipe any stale banner), failure branch leaves it intact so the 4s auto-clear owns the clear."
  - "Force-fail #118 not reproduced in this session; escalation code path is present and compiled but not exercised on-device. Deferred to long-term monitoring per user: 'si jamais le bug réapparaît, qu'il nous le dira.' Telemetry (keyboardInsertProbe/Retry/Failed + red banner + haptic + App Group preservation + HomeView recovery) is the capture + recovery path if it resurfaces post-ship."
  - "Cold-start path (path=coldStartBridge) not separately observed in real-device logs — all 9 probes in the verification session were path=warmDarwin. The helper code path is identical for both, so this is a coverage gap, not a correctness risk. Plan 34-04 manual test matrix must exercise the cold-start bridge to close it."
  - "Banner-timing + suggestion-bar-recovery observational validation deferred — user saw no issue in normal use and chose 'à suivre' follow-up. Code implements 4s auto-clear with stale-message guard per CONTEXT.md."

patterns-established:
  - "Extension target files under subdirectories (TextInsertion/) require explicit pbxproj wiring — SwiftPM auto-discovery does NOT apply to Xcode app/extension targets. Pattern matches prior emoji-picker addition (MEMORY.md)."
  - "Two-stage insertion retry composition: App Group propagation-lag retry (100ms, KeyboardState level) + proxy-disconnect retry (0/50/150/350ms cumulative, helper level). These solve different problems and compose additively."
  - "Privacy-by-construction logging at call site: the helper NEVER receives transcription as a log parameter. Only transcriptionUtf16 (Int count) is passed to the probe. Static analysis confirms: grep for `message=/text=/content=` across 892-line real-device log returns zero hits."

requirements-completed: [STAB-01]

# Metrics
duration: ~45min
completed: 2026-04-16
---

# Phase 34 Plan 03: DictusKeyboard Insertion Helper with Loud-Fail Escalation Summary

**Single validate -> insert -> verify -> retry -> escalate helper wraps the sole transcription-insertion call site in DictusKeyboard, with privacy-safe probe telemetry, FR/EN red-banner + error-haptic loud-fail, and App Group preservation on failure so HomeView can recover the lost text**

## Performance

- **Duration:** ~45 min (plan execution + helper authoring + pbxproj wiring + KeyboardState refactor + real-device verification)
- **Completed:** 2026-04-16
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** 2 source + 1 pbxproj
- **Files created:** 1

## Accomplishments

- `InsertTranscriptionHelper` shipped — exactly one public static method `insertTranscription(...)` wraps validate -> insert -> verify -> retry -> escalate. Retry schedule 50 / 100 / 200 ms cumulative (worst case ~350 ms) via `DispatchQueue.main.asyncAfter`, NOT Timer.
- `KeyboardState.handleTranscriptionReady` refactored — both the primary path (was line 341) and the 100ms UserDefaults retry (was line 370) route through new `dispatchInsertion(...)`. Old direct `controller?.textDocumentProxy.insertText(transcription)` call sites fully removed.
- FR/EN loud-fail UX wired — `escalateInsertionFailure` sets `statusMessage` to the exact CONTEXT.md-locked copy (`"Insertion impossible. Retrouvez votre transcription dans Dictus."` / `"Couldn't insert. Find your transcription in Dictus."`), fires `HapticFeedback.insertionFailed()`, schedules 4s auto-clear with stale-message guard.
- Plan 34-02 contract honored — on terminal failure, `dispatchInsertion` re-writes `SharedKeys.lastTranscription` + `SharedKeys.lastTranscriptionTimestamp` to the App Group so `HomeView.recoverableTranscription` can surface the lost text on next app foregrounding.
- Real-device happy-path verified — 9 warm-path insertions, all `attempt=0` success, zero retries, zero failures. Delta math `beforeCount + transcriptionCount = afterCount` exact across all 9 probes.
- Privacy audit PASSED — zero raw transcription text in any probe / retry / failed log entry across 892 log lines. Grep for `message=/text=/transcription=/result=/content=` + common French/English dictated words returned zero hits.

## Task Commits

1. **Task 1: Create InsertTranscriptionHelper** — `1371c08` (feat)
2. **Task 2: Refactor KeyboardState.handleTranscriptionReady + add escalateInsertionFailure** — `3b288fd` (refactor)
3. **Task 3: Real-device human-verify checkpoint** — no commit (verification-only)

**Plan metadata:** to be recorded in this plan's finalization commit.

## Files Created/Modified

### Created
- `DictusKeyboard/TextInsertion/InsertTranscriptionHelper.swift` — Helper struct + `InsertionPath` enum + `InsertionFailureReason` enum + `InsertTranscriptionResult` enum. 190 lines. Commented with Phase 34 STAB-01 rationale + "no second physical call site" research reference.

### Modified
- `DictusKeyboard/KeyboardState.swift` — `handleTranscriptionReady` refactored to delegate both paths to `dispatchInsertion`. Added private helpers: `dispatchInsertion`, `resetToIdleAfterInsertion`, `escalateInsertionFailure`. Added SharedKeys.coldStartActive read for path discrimination. Old direct `insertText` call sites removed.
- `Dictus.xcodeproj/project.pbxproj` — PBXBuildFile + PBXFileReference + PBXGroup + PBXSourcesBuildPhase entries so the `TextInsertion/` subdirectory + `InsertTranscriptionHelper.swift` are built into the DictusKeyboard target.

## Implementation Shipped

### InsertTranscriptionHelper API

```swift
public enum InsertionPath: String {
    case warmDarwin
    case coldStartBridge
}

public enum InsertionFailureReason: String {
    case proxyNil           // controller is nil (deallocated mid-transcription)
    case noFullAccess       // terminal — skip retries, fire keyboardInsertFailed immediately
    case contextUnavailable // proxy context nil AND keyboard not visible — retry
    case silentDrop         // classifier .silentDrop — retry
    case deltaMismatch      // classifier .deltaMismatch — retry
    case proxyDead          // classifier .proxyDead (before/after count < 0) — retry
}

public enum InsertTranscriptionResult {
    case success(attempts: Int, outcome: InsertionOutcome)
    case failed(lastReason: InsertionFailureReason, attempts: Int)
}

public struct InsertTranscriptionHelper {
    public static func insertTranscription(
        _ transcription: String,
        controller: UIInputViewController?,
        isKeyboardVisible: Bool,
        sessionID: String,
        darwinNotificationTimestamp: Date,
        path: InsertionPath,
        onComplete: @escaping (InsertTranscriptionResult) -> Void
    )
}
```

**Retry schedule (locked by CONTEXT.md):**
```swift
let backoffs: [TimeInterval] = [0.050, 0.100, 0.200]  // 4 total attempts: 0, +50ms, +150ms, +350ms cumulative
```

**Failure classification:**
- `noFullAccess` is terminal — no retries, fires `keyboardInsertFailed` on first detection.
- All other failure reasons schedule the next retry via `scheduleNextOrFail`; after index 3 exhausts, emits `keyboardInsertFailed` and calls `onComplete(.failed(...))`.

### KeyboardState refactor

```swift
private func handleTranscriptionReady() {
    logProbe("handleTranscriptionReady", details: sessionDetails())
    refreshFromDefaults()

    let darwinTimestamp = Date()
    let currentPath: InsertionPath = defaults.bool(forKey: SharedKeys.coldStartActive)
        ? .coldStartBridge
        : .warmDarwin

    if let transcription = defaults.string(forKey: SharedKeys.lastTranscription),
       !transcription.isEmpty {
        defaults.removeObject(forKey: SharedKeys.lastTranscription)
        defaults.synchronize()
        dispatchInsertion(transcription: transcription, path: currentPath, darwinTimestamp: darwinTimestamp)
    } else {
        // 100ms App Group propagation-lag retry (PRESERVED per CONTEXT.md — separate
        // problem from proxy-disconnect retries handled inside the helper).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // ... identical dispatch ...
        }
    }
}

private func dispatchInsertion(transcription: String, path: InsertionPath, darwinTimestamp: Date) {
    InsertTranscriptionHelper.insertTranscription(
        transcription, controller: self.controller,
        isKeyboardVisible: self.isKeyboardVisible,
        sessionID: self.activeSessionID ?? "",
        darwinNotificationTimestamp: darwinTimestamp,
        path: path
    ) { [weak self] result in
        guard let self = self else { return }
        switch result {
        case .success:
            PersistentLog.log(.keyboardTextInserted)
            HapticFeedback.textInserted()
            self.statusMessage = nil
            self.onTranscriptionInserted?()
            self.resetToIdleAfterInsertion()
        case .failed(let reason, let attempts):
            // Plan 34-02 recovery contract — re-write App Group so HomeView can surface it.
            self.defaults.set(transcription, forKey: SharedKeys.lastTranscription)
            self.defaults.set(Date().timeIntervalSince1970, forKey: SharedKeys.lastTranscriptionTimestamp)
            self.defaults.synchronize()

            HapticFeedback.insertionFailed()
            self.escalateInsertionFailure(reason: reason, attempts: attempts)
            self.resetToIdleAfterInsertion()
        }
    }
}
```

### FR/EN loud-fail banner

```swift
private func escalateInsertionFailure(reason: InsertionFailureReason, attempts: Int) {
    let lang = defaults.string(forKey: SharedKeys.language) ?? "fr"
    let message: String
    switch lang {
    case "en":
        message = "Couldn't insert. Find your transcription in Dictus."
    default:
        message = "Insertion impossible. Retrouvez votre transcription dans Dictus."
    }
    statusMessage = message

    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
        // Guard: don't stomp a newer banner from another code path.
        if self?.statusMessage == message {
            self?.statusMessage = nil
        }
    }
}
```

## Real-Device Verification Results (Task 3)

User tested on a real iPhone, exported logs to `/Users/pierreviviere/Downloads/dictus-logs 133.txt` (892 lines).

| # | Scenario | Result | Notes |
|---|----------|--------|-------|
| 1 | Happy-path regression (5+ warm dictations in real apps) | **PASS** | 9 insertions across the session. All `attempt=0` success. Zero `keyboardInsertRetry`. Zero `keyboardInsertFailed`. |
| 2 | Delta math verification | **PASS** | For every probe: `beforeCount + transcriptionCount = afterCount` exact. Zero windowed/mismatch classifications. |
| 3 | Probe field sanity | **PASS** | All 9 probes: `hasFullAccess=true`, `hasTextBefore=true`, `hasTextAfter=true`, `darwinToInsertMs=0`, non-empty sessionID. |
| 4 | Path discrimination | **WARM ONLY** | All 9 probes show `path=warmDarwin`. No cold-start path exercised in this session. Helper code path is identical — deferred to Plan 34-04 manual test matrix. |
| 5 | Cold-start dictation | **DEFERRED** | Not separately reproduced in this session. Same helper code path as warm, so not a correctness risk. Plan 34-04 must cover it in its manual protocol. |
| 6 | Chained rapid recordings | **IMPLICIT PASS** | Multiple back-to-back dictations in the 9-probe session — all succeeded. |
| 7 | Force-fail scenario (#118 repro) | **NOT REPRODUCED** | User could not trigger the silent-insertion bug — rare and intermittent. Deferred to long-term monitoring: if it resurfaces after ship, the new telemetry + banner + App Group preservation + HomeView recovery is the capture + recovery path. |
| 8 | Privacy audit (grep for dictated words + log field patterns) | **PASS** | Zero hits for `message=/text=/transcription=/result=/content=`. Zero hits for any plausible dictated French/English word. Logs contain only integers, booleans, identifiers, static labels. |
| 9 | Banner timing + suggestion-bar recovery | **DEFERRED / NOT-A-PROBLEM** | User chose "à suivre" — saw no issue in normal use. Code implements 4s auto-clear with stale-message guard per CONTEXT.md. If regression surfaces later, investigate. |

**User signal:** approved — "Je n'ai pas remarqué de dysfonctionnement pendant toutes mes notes" + explicit approval after privacy audit confirmation.

### Notable log observation (pre-existing, not blocking)

One `liveActivityFailed context=rejectedTransition error=recording->failed` line at 07:43:48 in the verification log. Plan 34-01 added `.standby -> .failed` and `.ready -> .failed` edges to `LiveActivityStateMachine` but NOT `.recording -> .failed`. Something tried to escalate while still in `.recording` (very short recording, sampleCount=6404 ≈ 0.15s). The state machine self-recovered via `.recording -> .standby` — no visible user impact, no dropped transcription.

This is an existing state-machine gap in Plan 34-01's scope, unrelated to Plan 34-03's insertion flow. **Logged to STATE.md as a known gap** for potential future work; not blocking Phase 34 STAB-01 because it self-recovers and does not affect insertion correctness.

## Decisions Made

- **pbxproj placement with TextInsertion/ subfolder** — preferred placement per the plan. Added PBXBuildFile + PBXFileReference + PBXGroup + PBXSourcesBuildPhase entries. Build passes cleanly. No fallback to flat layout needed.
- **Two-stage retry composition preserved** — KeyboardState's 100ms UserDefaults retry is SEPARATE from the helper's 50/100/200ms proxy retries. They solve different problems (App Group propagation lag vs proxy disconnect) and compose additively: if both go wrong, total worst-case latency is ~100ms (App Group) + ~350ms (helper) = ~450ms before terminal failure. Acceptable given user is already expecting post-transcription insertion.
- **Failure-path App Group re-write in KeyboardState, not inside the helper** — keeps the helper pure (no UserDefaults side effects). The caller owns the recovery contract and re-writes the key + timestamp after the helper returns `.failed`.
- **Haptic fired by caller, not helper** — same rationale: helper stays UI/feedback-agnostic, caller owns audible/tactile feedback policy.
- **proxy.hasText instead of ctrl.hasText for before/after snapshots** — `UITextDocumentProxy` conforms to `UIKeyInput`, so `proxy.hasText` is available and more literal about what is being probed. Identical semantics at this call site.
- **Force-fail #118 deferred to long-term monitoring** — user could not reproduce on-device in a focused session. The new telemetry (probe/retry/failed events + red banner + haptic + App Group preservation + HomeView recovery) is designed to capture and recover from any future occurrence. Ship-as-is and monitor.
- **Cold-start path coverage deferred to Plan 34-04** — all 9 probes in the verification session were `path=warmDarwin`. Helper code path is identical for both paths (cold-start re-enters the same `handleTranscriptionReady` via the Darwin notification fired after URL-scheme wake), so this is a coverage gap, not a correctness risk. Plan 34-04's manual test matrix MUST exercise cold-start to close the `path=coldStartBridge` observation gap.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] App Group re-write on terminal failure**
- **Found during:** Task 2 (KeyboardState refactor)
- **Issue:** `handleTranscriptionReady` clears `SharedKeys.lastTranscription` BEFORE calling the helper (correct duplicate-insertion guard). The plan draft's `dispatchInsertion` `.failed` branch did NOT re-write the key, which would silently break Plan 34-02's explicit contract ("the failed-insertion escalation path MUST NOT call `defaults.removeObject(forKey: SharedKeys.lastTranscription)`" — 34-02-SUMMARY.md). Without the re-write, HomeView's recovery surface would not surface the lost text after a keyboard-dictation failure.
- **Fix:** Added App Group re-write inside `dispatchInsertion`'s `.failed` branch (KeyboardState.swift:418-420). Writes both `SharedKeys.lastTranscription` AND `SharedKeys.lastTranscriptionTimestamp` (the timestamp is required by `HomeView.recoverableTranscription`'s 300s staleness gate).
- **Files modified:** `DictusKeyboard/KeyboardState.swift`
- **Verification:** grep confirms two `.set(... forKey: SharedKeys.lastTranscription ...)` writes in KeyboardState (pre-existing elsewhere + new failure-path write). Code review matches the pseudo-code in 34-02-SUMMARY.md's "Follow-ups for Plan 34-03" section.
- **Committed in:** `3b288fd` (Task 2 refactor commit)

**2. [Rule 1 - Bug] Helper uses proxy.hasText instead of ctrl.hasText**
- **Found during:** Task 1 (helper implementation)
- **Issue:** Plan draft used `ctrl.hasText` for before/after snapshots. `UIInputViewController.hasText` is a passthrough to the proxy; reading it via `proxy.hasText` is more literal and avoids one hop of indirection. Not a functional bug, but worth noting as a minor hardening.
- **Fix:** Helper reads `proxy.hasText` directly (both for `hasTextBefore` and `hasTextAfter`).
- **Files modified:** `DictusKeyboard/TextInsertion/InsertTranscriptionHelper.swift`
- **Verification:** Build passes. Real-device test shows `hasTextBefore=true` / `hasTextAfter=true` on every happy-path insertion (matches expected behavior for non-empty text fields).
- **Committed in:** `1371c08` (Task 1 feat commit)

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 minor hardening)
**Impact on plan:** The App Group re-write (deviation #1) was essential for honoring Plan 34-02's contract — without it, the loud-fail UX would point users to a recovery surface that wouldn't have the transcription. Deviation #2 is a minor readability improvement. No scope creep.

## Issues Encountered

None during Task 1 or Task 2 implementation. The checkpoint-level deferrals (cold-start path not observed, force-fail not reproduced, banner-timing observation) are deferred items, not issues — the code is in place and compiled; only empirical validation is deferred to long-term monitoring or Plan 34-04.

## User Setup Required

None — purely source-level changes inside `DictusKeyboard` + pbxproj wiring. No entitlements, Info.plist, App Group config, or new dependencies.

## Follow-ups for Plan 34-04

1. **Cold-start path coverage** — Plan 34-04's manual test matrix MUST exercise cold-start dictation (fully background DictusApp, tap mic in keyboard from another app, verify text lands, inspect logs for `path=coldStartBridge` probe). All 9 probes in this session's verification log were `path=warmDarwin`. Helper code path is identical, but empirical observation is the only way to close the coverage gap.
2. **Banner + suggestion-bar observational validation** — user deferred these ("à suivre"). If Plan 34-04 includes any UX polish pass over the toolbar, it should re-run: (a) induce an insertion failure (or force the banner code path via a debug build switch), (b) measure banner on-screen duration vs 4s target, (c) verify suggestion bar returns after banner clears without requiring a key tap.
3. **Force-fail #118 long-term monitoring** — if a user reports silent insertion after shipping Phase 34, first action is to request logs and grep for `keyboardInsertRetry` / `keyboardInsertFailed`. The new telemetry gives us the forensic trail that was missing before. If we see terminal `keyboardInsertFailed` entries at non-trivial frequency, root-cause via `finalReason` distribution (silentDrop vs deltaMismatch vs proxyDead vs contextUnavailable) and potentially extend the helper.
4. **Known state-machine gap: `.recording -> .failed` edge missing in LiveActivityStateMachine** — pre-existing in Plan 34-01's scope, surfaced as a one-line `liveActivityFailed context=rejectedTransition` in the verification log. Self-recovers via `.recording -> .standby`. Not blocking Phase 34 STAB-01. Candidate for a later plan if this becomes noisy.

## Next Phase Readiness

- **Plan 34-04 (banner/UX wiring + DictusApp recovery card polish)** — unblocked. Consumes all of Plan 34-03's shipped surfaces:
  - `InsertTranscriptionHelper` is the single call site for insertion — 34-04 does not need to touch it.
  - `statusMessage` red banner is already rendering FR/EN copy with 4s auto-clear — 34-04 may polish visual treatment (icon, tint, motion) but the data flow is complete.
  - App Group preservation on failure is wired — 34-04 can focus on the DictusApp side: ensuring the HomeView recovery card (Plan 34-02) is visually prominent, actionable, and intuitively discoverable when a user opens Dictus after a failed insertion.
- **Phase 34 STAB-01 requirement** — shipped end-to-end across Plans 34-01 (foundations), 34-02 (recovery surface), 34-03 (helper + loud-fail UX). 34-04 is UX polish + manual-test sign-off, not new functionality for STAB-01. Requirement can be marked complete in this plan's finalization.

## Self-Check

Verifying all claims:

### Files created
- `/Users/pierreviviere/dev/dictus/DictusKeyboard/TextInsertion/InsertTranscriptionHelper.swift` — FOUND (190 lines, matches shipped implementation)

### Files modified
- `/Users/pierreviviere/dev/dictus/DictusKeyboard/KeyboardState.swift` — FOUND (handleTranscriptionReady refactored, dispatchInsertion + escalateInsertionFailure + resetToIdleAfterInsertion present, App Group re-write on failure present at lines 418-420)
- `/Users/pierreviviere/dev/dictus/Dictus.xcodeproj/project.pbxproj` — FOUND (git status clean on this branch; file is tracked in prior commits)

### Commits
- `1371c08` (Task 1 feat: add InsertTranscriptionHelper) — FOUND in git log
- `3b288fd` (Task 2 refactor: route transcription insertion through InsertTranscriptionHelper) — FOUND in git log

### Acceptance criteria spot-checks (from plan)
- `InsertTranscriptionHelper.insertTranscription` referenced in `KeyboardState.swift` — 1 match (inside `dispatchInsertion`)
- `private func dispatchInsertion` — 1 match
- `private func escalateInsertionFailure` — 1 match
- `private func resetToIdleAfterInsertion` — 1 match
- `"Insertion impossible. Retrouvez votre transcription dans Dictus."` — 1 match
- `"Couldn't insert. Find your transcription in Dictus."` — 1 match
- `asyncAfter(deadline: .now() + 4)` — 1 match (4s auto-clear)
- `HapticFeedback.insertionFailed()` — 1 match
- `SharedKeys.coldStartActive` — 1 match (path discrimination)
- Direct `controller?.textDocumentProxy.insertText(transcription)` — 0 matches (old call sites removed)
- 100ms App Group propagation retry `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)` — 1 match (PRESERVED)
- Helper file contains `[0.050, 0.100, 0.200]` — 1 match (locked retry schedule)
- Helper file contains `Timer.scheduledTimer|Thread.sleep|RunLoop` — 0 matches (anti-pattern guard)
- Helper file contains 6 `InsertionFailureReason` cases — present (proxyNil, noFullAccess, contextUnavailable, silentDrop, deltaMismatch, proxyDead)

## Self-Check: PASSED

---
*Phase: 34-silent-insertion-fix*
*Completed: 2026-04-16*
