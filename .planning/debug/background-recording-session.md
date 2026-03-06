---
title: Background Recording & UX Session Summary
date: 2026-03-06
status: in-progress
phase: 03-dictation-ux (gap closure + improvements)
---

# Background Recording & UX — Session Summary

## What We Did (Commits on main)

### 1. Triple text insertion fix
**Commit:** `404647e` (included in later commits)
**Problem:** Transcription inserted 3x into text field.
**Root cause:** `handleTranscriptionReady()` in `KeyboardState.swift` never cleared `SharedKeys.lastTranscription` from UserDefaults after inserting. Multiple Darwin notifications caused re-reads and re-inserts.
**Fix:** Clear `defaults.removeObject(forKey: SharedKeys.lastTranscription)` BEFORE calling `insertText()`.
**Status:** VERIFIED by Pierre.

### 2. Background recording architecture (Wispr Flow-inspired)
**Commits:** `404647e`, `b284988`, `9539ebe`, `bd5428f`
**Goal:** After first app launch, subsequent recordings happen entirely in background — no app switch.
**Architecture:**
- Added `startRecording` Darwin notification (keyboard -> app)
- `KeyboardState.startRecording()`: posts notification first, falls back to URL after 500ms
- `DictationCoordinator`: observes `startRecording` notification, calls `startDictation()` from background
- Audio engine kept running between recordings (`collectSamples()` instead of `stopRecording()`)
- `UIBackgroundModes: audio` keeps app alive with running engine

**Key files changed:**
- `DictusCore/Sources/DictusCore/DarwinNotifications.swift` — added `startRecording` notification
- `DictusApp/DictationCoordinator.swift` — observer + pre-load + simplified pipeline
- `DictusApp/Audio/AudioRecorder.swift` — `warmUp()`, `collectSamples()`, `configureAudioSession()`, engine state management
- `DictusKeyboard/KeyboardState.swift` — notification-first approach with URL fallback

**Status:** Background recording WORKS after engine is warm. Pierre confirmed.

### 3. SmartModelRouter removed from pipeline
**Commit:** `627012b`
**Problem:** SmartModelRouter switched WhisperKit models between recordings (e.g., small -> tiny for short audio). This killed the warm engine and broke background recording.
**Fix:** Removed SmartModelRouter call from `stopDictation()`. User's chosen model is loaded once and reused.
**Note:** SmartModelRouter code still exists, just not called. Can be deleted in cleanup.
**Status:** VERIFIED — no more model switch crashes.

### 4. Toolbar hidden during recording
**Commit:** `a33b050`
**Problem:** Gear icon + mic button visible behind recording overlay.
**Fix:** Moved `ToolbarView` inside the `else` branch — only shown when NOT recording.
**Status:** VERIFIED partially — see remaining bug below.

### 5. Pre-load WhisperKit + warm engine at launch
**Commits:** `680c160`, `1f1377e`
**Goal:** First dictation starts instantly (no 4-5s model loading).
**Implementation:** In `DictationCoordinator.init()`:
```swift
Task {
    try await ensureWhisperKitReady()
    try audioRecorder.warmUp()  // starts engine in idle mode
}
```
**Status:** Pre-load works (logs confirm). But see remaining issues.

### 6. Removed broken `suspend` auto-return
**Commit:** `680c160`
**Problem:** `UIControl().sendAction(suspend)` sent user to Home screen instead of previous app.
**Fix:** Removed entirely. No reliable iOS public API for "return to previous app".
**User taps "< Back" in status bar** (standard iOS behavior).

---

## Remaining Issues (for next session)

### BUG 1: First launch still slow (4-5s) despite pre-load
**Severity:** High
**Description:** When app is force-closed and user taps mic in keyboard, the URL opens Dictus but it takes 4-5 seconds before recording starts. Pre-load happens in `init()` but if app was killed, init + WhisperKit load takes time.
**Possible causes:**
- WhisperKit model loading (small model = ~4-5s, tiny = ~1s)
- The pre-load runs in `init()` but `startDictation()` from URL may arrive before pre-load completes
**Ideas to investigate:**
- Check if `ensureWhisperKitReady()` in `startDictation()` waits properly for ongoing init
- Consider showing a minimal "loading" UI in the app during first launch
- Check `isInitializing` flag — there's a race between pre-load Task and URL handler Task
- Other dictation apps (Wispr Flow, Super Whisper) may use smaller models or pre-compiled CoreML
- Consider using `tiny` model for first recording, switch to user's preferred model after

### BUG 2: First recording via URL sometimes fails / needs retry
**Severity:** High
**Description:** The first transcription after app opens often fails. User has to retry.
**Likely cause:** Race condition between pre-load Task and URL-triggered `startDictation()`. Both call `ensureWhisperKitReady()`. The `isInitializing` flag exists but may not be properly guarded.
**Where to look:** `DictationCoordinator.startDictation()` and `ensureWhisperKitReady()` — need to handle concurrent calls properly (await the ongoing init instead of starting a new one).

### BUG 3: Recording overlay not taking full keyboard height (intermittent)
**Severity:** Medium
**Description:** After returning from Dictus app (first launch), the recording overlay doesn't fill the full keyboard area. The toolbar icons (X and checkmark) are compressed/cut off at the top. The globe and mic icons from the system keyboard row are visible at the bottom.
**When it happens:** Only after the first app switch (URL opens Dictus, user returns). Switching keyboards and coming back fixes it.
**Likely cause:** When the keyboard extension is brought back to foreground after an app switch, the `inputView` height may not be properly recalculated. The `keyboardHeight` computed property uses fixed values that may not account for the keyboard's actual available height after an app transition.
**Where to look:**
- `KeyboardRootView.swift` — `keyboardHeight` calculation
- `KeyboardViewController.swift` — `viewWillAppear` / `viewDidAppear` height updates
- Consider using `GeometryReader` instead of fixed height calculation
- Consider calling `self.inputView?.needsUpdateConstraints()` or similar on view reappear

### BUG 4: Light mode — black recording overlay looks bad
**Severity:** Medium (visual/design)
**Description:** Recording overlay uses `Color.black.opacity(0.95)` background which looks jarring in light mode. Should adapt to system appearance.
**Where to fix:** `RecordingOverlay.swift` line 21 — use `Color(.systemBackground)` or a dynamic color.
**Note:** General design polish (colors, branding, logo) is planned for a later phase. Pierre mentioned he hasn't done the design system yet.

### BUG 5: Engine start fails from background on cold start
**Severity:** Low (mitigated by warm-up)
**Description:** If the app was in background but engine was NOT running (cold), `startRecordingLive()` fails with `AUIOClient_StartIO failed (2003329396)`. iOS doesn't allow starting audio IO from background.
**Current mitigation:** `warmUp()` starts the engine at launch. As long as the app isn't killed, the engine stays warm.
**Edge case:** If iOS kills the app in background due to memory pressure, the engine dies. Next keyboard tap will trigger URL fallback (which opens app → foreground → can start engine).
**The URL fallback path works but is slow** (see BUG 1).

---

## Architecture Overview (Current State)

```
[Keyboard Extension]                    [DictusApp]

KeyboardState.startRecording()          DictationCoordinator.init()
  |                                       |
  +-- markRequested() (sets .requested)   +-- ensureWhisperKitReady()
  +-- post(startRecording notification)   +-- audioRecorder.warmUp()
  |                                       |   (engine starts idle)
  +-- 500ms timeout:                      |
      if still .requested                 Observes:
        -> openURL(dictus://dictate)      - startRecording notification
                                          - stopRecording notification
                                          - cancelRecording notification

Recording flow (warm):                  startDictation()
  notification -> startDictation()        |
  -> audioRecorder.startRecording()       +-- purge old samples
     (engine already running,             +-- isRecording = true
      just purge + collect)               +-- updateStatus(.recording)

Stop flow:                              stopDictation()
  keyboard requestStop()                  |
  -> Darwin notification                  +-- collectSamples() (no engine stop!)
  -> coordinator.stopDictation()          +-- transcribe
  -> collectSamples() (keeps engine)      +-- post transcriptionReady
  -> transcribe                           +-- keyboard inserts text
  -> post result
```

---

## Files Modified in This Session

| File | Changes |
|------|---------|
| `DictusCore/.../DarwinNotifications.swift` | Added `startRecording` notification |
| `DictusApp/DictationCoordinator.swift` | Background recording observer, pre-load, removed SmartModelRouter, removed suspend |
| `DictusApp/Audio/AudioRecorder.swift` | `warmUp()`, `collectSamples()`, `configureAudioSession()`, `isEngineRunning`, model switch handling |
| `DictusApp/DictusApp.swift` | Simplified URL handler |
| `DictusKeyboard/KeyboardState.swift` | Notification-first + URL fallback, duplicate insertion fix |
| `DictusKeyboard/KeyboardRootView.swift` | Toolbar hidden during recording |

---

## Git Log (this session)

```
1f1377e fix: warm up audio engine at launch for instant background recording
680c160 fix: pre-load WhisperKit at launch, remove broken suspend auto-return
627012b simplify: remove SmartModelRouter from dictation pipeline
a33b050 fix: hide toolbar during recording + reset engine on model switch
bd5428f feat(audio): keep engine running between recordings for background dictation
9539ebe fix(audio): configure session once, skip reconfiguration from background
b284988 fix(audio): keep AVAudioSession alive for background recording
404647e feat(03): background recording + auto-return for Wispr Flow-like UX
```
