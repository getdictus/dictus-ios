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

## Fixed Issues (commit 970d9cf)

### ~~BUG 1~~ FIXED: WhisperKit init race condition
**Fix:** Replaced unused `isInitializing` flag with `initTask: Task<Void, Error>?`. Concurrent callers now await the ongoing init instead of starting a duplicate one.

### ~~BUG 2~~ FIXED: First recording via URL sometimes fails
**Fix:** Same initTask fix as BUG 1 — `startDictation()` awaits in-progress pre-load.

### ~~BUG 2b~~ FIXED: Second recording rejected ("already ready")
**Fix:** Guard in `startDictation()` now accepts `.ready` status (was only `.idle` and `.failed`). The 2-second checkmark flash no longer blocks a new recording.

### ~~BUG 3~~ FIXED: Recording overlay height after app switch
**Fix:** Added explicit height constraint on inputView + `viewWillAppear` layout refresh.

### ~~BUG 4~~ FIXED: Recording overlay visual issues
**Fix:** Overlay background is now `Color.clear` (native keyboard chrome shows through). All text/waveform colors adapt to light/dark mode via `@Environment(\.colorScheme)`.

---

## Remaining Issues

### ISSUE 1: Cold start — app opens but no feedback + no auto-return
**Severity:** High (UX)
**When:** User taps mic in keyboard, app is NOT running (force-closed or killed by iOS).
**What happens:**
1. Keyboard opens DictusApp via URL scheme (`dictus://dictate`)
2. App opens on its main screen (settings/home) — no loading indicator
3. WhisperKit loads in background (3-5s depending on model)
4. Recording starts silently — user doesn't know it's happening
5. User must manually tap "◄ Back" in status bar to return to keyboard

**Two sub-problems:**

#### 1a. Auto-return to previous app
Super Whisper and Wispr Flow both return the user to the previous app automatically after opening. Need to research how they achieve this.
**Ideas to investigate:**
- `NSExtensionContext.completeRequest()` or similar API
- Private API that Super Whisper/Wispr Flow might use (risk of App Store rejection)
- `UIApplication.shared.perform(#selector(NSXPCConnection.suspend))` — we tried this, it goes to Home Screen instead
- Observing `UIScene.didEnterBackgroundNotification` and using that as trigger
- Check if there's a way to immediately dismiss via `openURL` back to the host app
- Reverse-engineer Super Whisper's approach (check their entitlements, background modes)

#### 1b. Loading/feedback screen when app opens from keyboard
If auto-return can't be solved, the UX needs improvement:
- **In-app:** Show a dedicated "loading" screen when opened via `dictus://dictate` — progress indicator + "WhisperKit is loading..." message + "You can return to your keyboard" instruction
- **In-keyboard:** Before opening URL, show a brief message like "Opening Dictus... Please return here after" so the user knows what to expect
- **After recording starts:** Show "Recording in progress — tap ◄ Back to return to your keyboard"

**Priority:** Research auto-return first (1a). If not feasible, implement the loading/feedback UX (1b) as a fallback.

### ISSUE 2: Engine start fails from background on cold start
**Severity:** Low (mitigated by warm-up)
**Description:** If the app was in background but engine was NOT running (cold), `startRecordingLive()` fails with `AUIOClient_StartIO failed (2003329396)`. iOS doesn't allow starting audio IO from background.
**Current mitigation:** `warmUp()` starts the engine at launch. As long as the app isn't killed, the engine stays warm.
**Edge case:** If iOS kills the app in background due to memory pressure, the engine dies. Next keyboard tap will trigger URL fallback (which opens app → foreground → can start engine).
**The URL fallback path works but UX is poor** (see ISSUE 1).

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
