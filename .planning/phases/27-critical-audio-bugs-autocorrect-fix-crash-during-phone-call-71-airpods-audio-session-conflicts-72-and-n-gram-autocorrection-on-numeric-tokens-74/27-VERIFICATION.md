---
phase: 27-critical-audio-bugs-autocorrect-fix
verified: 2026-04-07T19:00:00Z
status: human_needed
score: 3/3 must-haves verified
human_verification:
  - test: "Start dictation during an active phone call"
    expected: "Keyboard shows 'Recording unavailable during a call' error message — no crash"
    why_human: "Requires a real device with an active phone call; cannot simulate CXCallObserver state or SIGABRT prevention in static analysis"
  - test: "Play music via AirPods, record dictation, stop recording"
    expected: "Music resumes on AirPods within ~1-2 seconds of dictation stopping; AirPods play/pause controls return to music app"
    why_human: "Requires physical AirPods and a media playback app; .notifyOthersOnDeactivation effect cannot be verified without hardware"
  - test: "Type 'test123' then press space"
    expected: "The token 'test123 ' is inserted as-is — no autocorrection occurs"
    why_human: "Core guard logic is verified via grep; real device confirms no regression in overall autocorrect UX and space insertion flow"
---

# Phase 27: Critical Audio Bugs & Autocorrect Fix — Verification Report

**Phase Goal:** Three beta-reported bugs are fixed: no crash when starting dictation during a phone call, AirPods/media apps resume normally after recording, and numeric tokens are never autocorrected
**Verified:** 2026-04-07
**Status:** human_needed — all automated checks pass; 3 items require device testing
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Success Criteria from ROADMAP.md)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Starting dictation during a phone call shows "Recording unavailable during a call" instead of crashing | VERIFIED | `CallStateMonitor.swift` exists (51 lines, `CXCallObserver`, `isCallActive`); `DictationCoordinator.swift` line 263 guards on `callStateMonitor.isCallActive` and calls `handleError("Recording unavailable during a call")` |
| 2 | After recording completes, other apps (Spotify, YouTube) resume playback on AirPods | VERIFIED | `UnifiedAudioEngine.deactivateAndIdle()` (line 267) calls `session.setActive(false, options: .notifyOthersOnDeactivation)`; called in both `stopDictation()` (line 356) and `cancelDictation()` (line 429) of DictationCoordinator |
| 3 | Typing "test123" + space does not autocorrect the token | VERIFIED | `containsDigit` guard present in `handleSpace()` (line 346, returns early before autocorrect block at line 380); also in `SuggestionState.update()` (line 119) and `updateAsync()` (line 198) |

**Score:** 3/3 truths verified at code level

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `DictusApp/Audio/CallStateMonitor.swift` | CXCallObserver wrapper for call state detection | VERIFIED | Exists, 51 lines, contains `CXCallObserver`, `isCallActive`, `updateCallState()`, delegate method `callObserver(_:callChanged:)`, `import DictusCore` |
| `DictusApp/Audio/UnifiedAudioEngine.swift` | Idle deactivation method that stops engine and deactivates session | VERIFIED | `deactivateAndIdle()` at line 267 — stops engine, calls `setActive(false, options: .notifyOthersOnDeactivation)`, resets `sessionConfigured = false` |
| `DictusApp/DictationCoordinator.swift` | Call guard before recording + session deactivation after recording | VERIFIED | `callStateMonitor` property at line 39; `isCallActive` guard at line 263; `deactivateAndIdle()` at lines 356 and 429 |
| `DictusKeyboard/DictusKeyboardBridge.swift` | Numeric guard in handleSpace() before spell check | VERIFIED | `containsDigit` at line 346 — placed before autocorrect block at line 380; early return inserts space normally |
| `DictusKeyboard/TextPrediction/SuggestionState.swift` | Numeric guard in update() and updateAsync() before spell check | VERIFIED | 2 occurrences of `containsDigit` — lines 119 (`update()`) and 198 (`updateAsync()`); both guard before `spellCheck` calls |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `DictationCoordinator.swift` | `CallStateMonitor.swift` | `callStateMonitor.isCallActive` before `startRecording` | WIRED | Property declared at line 39; guard at line 263 (`if callStateMonitor.isCallActive`) before dictation task starts |
| `DictationCoordinator.swift` | `UnifiedAudioEngine.swift` | `audioEngine.deactivateAndIdle()` after `collectSamples` | WIRED | Line 356 (stopDictation, after collectSamples) and line 429 (cancelDictation, after collectSamples) — both call sites present |
| `DictusKeyboardBridge.swift` | `SuggestionState.swift` | numeric guard mirrors update logic in handleSpace | VERIFIED | `containsDigit` pattern consistent across all 3 entry points; `handleSpace` returns early, `update`/`updateAsync` skip to completions-only mode |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| BUG-71 | 27-01-PLAN.md | Crash during phone call (SIGABRT from installTapOnBus) | SATISFIED | `CallStateMonitor` detects call via `CXCallObserver`; guard in `DictationCoordinator.startDictation()` prevents reaching `installTapOnBus` entirely |
| BUG-72 | 27-01-PLAN.md | AirPods/media apps interrupted after recording | SATISFIED | `deactivateAndIdle()` deactivates session with `.notifyOthersOnDeactivation` in both stop and cancel paths |
| BUG-74 | 27-02-PLAN.md | N-gram autocorrection on numeric tokens | SATISFIED | `CharacterSet.decimalDigits` guard blocks all 3 correction entry points (handleSpace, update, updateAsync) |

**REQUIREMENTS.md cross-reference:** BUG-71, BUG-72, BUG-74 are referenced under ROADMAP.md Phase 27 (line 308: `**Requirements**: BUG-71, BUG-72, BUG-74`). These IDs are not defined as standalone entries in REQUIREMENTS.md — they map to `BETA-01` ("Critical bugs reported by public beta testers are triaged and fixed"). All three are accounted for across the two plans. No orphaned requirements.

**Xcode project registration:** `CallStateMonitor.swift` registered in `project.pbxproj` with PBXBuildFile `AA0000C2` and PBXFileReference `AA1000C2`, placed in the Audio group, included in DictusApp Sources build phase.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | No anti-patterns found in modified files |

All `return nil` / `return []` occurrences in scanned files are legitimate guard-statement early returns, not stub implementations.

### Human Verification Required

#### 1. Phone Call Crash Prevention (BUG-71)

**Test:** On a physical device, initiate a phone call, then open a text field, activate the Dictus keyboard, and tap the microphone button.
**Expected:** The keyboard displays "Recording unavailable during a call" — no crash, no SIGABRT, the keyboard remains functional.
**Why human:** Requires a real device and an active telephony call. `CXCallObserver.calls` only reflects real calls; the SIGABRT itself (from `installTapOnBus` during an occupied AVAudioSession) cannot be reproduced statically.

#### 2. AirPods / Media App Resumption (BUG-72)

**Test:** Connect AirPods, start playing music in Spotify or Apple Music, switch to a text field with Dictus keyboard, record a short dictation, then stop.
**Expected:** Within ~2 seconds of stopping, music resumes on AirPods. Pressing play/pause on AirPods controls the music app, not Dictus.
**Why human:** `.notifyOthersOnDeactivation` triggers iOS inter-app audio routing. Requires physical AirPods and a media app running concurrently; not verifiable from static code alone.

#### 3. Numeric Token Autocorrect Guard (BUG-74)

**Test:** In any text field with Dictus keyboard active (French layout), type "test123" and press space. Also type "42nd" + space and "h2o" + space.
**Expected:** All tokens are inserted as typed — no replacement. The suggestion bar may show completions but no correction in bold center slot.
**Why human:** The guard logic is fully verified in code; device test confirms no regression in the space-insertion flow and that `lastAutocorrect` state is correctly cleared for subsequent undo behaviour.

### Gaps Summary

No gaps. All three artifacts are substantive and wired. Both commits (`db796a2`, `e7083b4`, `da208b0`) exist in git history. The only items outstanding are device-level behavioural checks that cannot be automated.

---

_Verified: 2026-04-07_
_Verifier: Claude (gsd-verifier)_
