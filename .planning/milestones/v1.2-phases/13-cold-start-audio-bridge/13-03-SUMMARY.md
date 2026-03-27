---
phase: 13-cold-start-audio-bridge
plan: 03
subsystem: ipc, audio, ui
tags: [url-scheme, cold-start, auto-return, waveform, audio-thread, canOpenURL]

# Dependency graph
requires:
  - phase: 13-cold-start-audio-bridge
    plan: 01
    provides: "SharedKeys, KnownAppSchemes, cold start detection in DictusApp"
  - phase: 13-cold-start-audio-bridge
    plan: 02
    provides: "SwipeBackOverlayView for fallback navigation"
provides:
  - "source=keyboard URL parameter for keyboard-to-app cold start signaling"
  - "LSApplicationQueriesSchemes in both Info.plist files (10 known app schemes)"
  - "Cold start detection via SharedKeys.coldStartActive flag"
  - "Audio-thread waveform forwarding for both RawAudioCapture and AudioRecorder"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: ["Audio-thread App Group writes to bypass main thread throttling in background", "Darwin notification waveform energy forwarding from installTap callback"]

key-files:
  created: []
  modified:
    - "DictusApp/DictusApp.swift"
    - "DictusApp/Audio/RawAudioCapture.swift"
    - "DictusApp/Audio/AudioRecorder.swift"
    - "DictusApp/DictationCoordinator.swift"
    - "DictusApp/Info.plist"
    - "DictusKeyboard/Info.plist"
    - "DictusKeyboard/KeyboardState.swift"

key-decisions:
  - "Auto-return removed entirely -- attemptAutoReturn() always opened first installed app (e.g. WhatsApp) regardless of actual source app. Swipe-back overlay is the correct UX."
  - "Audio-thread waveform writes added to both RawAudioCapture and AudioRecorder to bypass iOS main thread throttling when app is in background"
  - "Waveform energy scaling increased from rms * 5.0 to rms * 15.0 for visible bar animation with Parakeet audio levels"

patterns-established:
  - "Audio-thread App Group writes: write waveform energy directly from installTap callback, not from main thread timer"
  - "Dual audio engine waveform support: both RawAudioCapture (Parakeet) and AudioRecorder (WhisperKit) write energy to App Group"

requirements-completed: [COLD-01, COLD-03, COLD-04, COLD-07, COLD-08]

# Metrics
duration: ~45min
completed: 2026-03-12
---

# Phase 13 Plan 03: Auto-Return + Cold Start Detection Summary

**Removed broken auto-return heuristic, added source=keyboard URL param, LSApplicationQueriesSchemes in both plists, and audio-thread waveform forwarding to fix background animation throttling**

## Performance

- **Duration:** ~45 min (spread across multiple iterations with device testing)
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint, approved)
- **Files modified:** 7

## Accomplishments
- URL scheme updated to include `?source=keyboard` parameter for cold start detection
- LSApplicationQueriesSchemes added to both Info.plist files with 10 known messaging app schemes
- Auto-return logic implemented then removed after discovering it always opens wrong app (first installed, not source)
- Audio-thread waveform forwarding added to both RawAudioCapture (Parakeet) and AudioRecorder (WhisperKit), fixing waveform animation that was frozen when app runs in background due to iOS main thread throttling
- Cold start flow verified end-to-end on device: keyboard mic tap -> app opens with overlay -> swipe back -> recording overlay with live waveform -> transcription works

## Task Commits

Each task was committed atomically (with subsequent deviation fixes):

1. **Task 1: Info.plist LSApplicationQueriesSchemes + keyboard URL update** - `bd31598` (feat)
2. **Task 2: Auto-return logic + cold start detection** - Multiple commits due to deviations:
   - `b3799b2` - Remove auto-return heuristic, add audio-thread waveform for RawAudioCapture (fix)
   - `cb339b2` - Increase waveform energy scaling for Parakeet (fix)
   - `816442c` - Add audio-thread waveform for AudioRecorder/WhisperKit (fix)
3. **Task 3: Human-verify checkpoint** - Approved by user

## Files Created/Modified
- `DictusApp/DictusApp.swift` - URL handling with source=keyboard detection, cold start flag, auto-return removed
- `DictusApp/Audio/RawAudioCapture.swift` - Audio-thread waveform energy writes to App Group from installTap callback
- `DictusApp/Audio/AudioRecorder.swift` - Audio-thread waveform energy writes to App Group from installTap callback
- `DictusApp/DictationCoordinator.swift` - Removed main-thread App Group waveform forwarding (replaced by audio-thread writes)
- `DictusApp/Info.plist` - LSApplicationQueriesSchemes with 10 known app schemes
- `DictusKeyboard/Info.plist` - LSApplicationQueriesSchemes with 10 known app schemes
- `DictusKeyboard/KeyboardState.swift` - URL updated to dictus://dictate?source=keyboard

## Decisions Made
- Auto-return (`attemptAutoReturn()`) removed entirely. The approach of iterating KnownAppSchemes.all via canOpenURL always opened the first installed app (typically WhatsApp), not the actual source app the user was typing in. The swipe-back overlay (Plan 02) is the correct and reliable UX for returning to the source app.
- Waveform energy must be written from the audio thread (installTap callback), not from a main-thread timer. iOS aggressively throttles the main thread when the app is in background, causing waveform animation to freeze in the keyboard. Writing directly from the audio callback bypasses this.
- Energy scaling factor increased to 15.0 (from 5.0) because Parakeet's RawAudioCapture produces lower RMS values than WhisperKit's AudioRecorder.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Auto-return always opens wrong app**
- **Found during:** Task 2 (auto-return implementation)
- **Issue:** `attemptAutoReturn()` iterates known apps in order and opens the first installed one via canOpenURL. Since most users have WhatsApp installed, it always navigates to WhatsApp regardless of which app the user was typing in.
- **Fix:** Removed `attemptAutoReturn()` entirely. Swipe-back overlay is the correct UX.
- **Files modified:** DictusApp/DictusApp.swift
- **Committed in:** `b3799b2`

**2. [Rule 1 - Bug] Waveform animation frozen in background**
- **Found during:** Device testing after Task 2
- **Issue:** When DictusApp runs in background (user returned to keyboard), iOS throttles the main thread. The main-thread timer in DictationCoordinator that forwarded waveform energy to App Group stopped firing, causing the keyboard waveform bars to freeze.
- **Fix:** Added audio-thread waveform writes directly from the installTap callback in both RawAudioCapture and AudioRecorder. Removed redundant main-thread forwarding from DictationCoordinator.
- **Files modified:** DictusApp/Audio/RawAudioCapture.swift, DictusApp/Audio/AudioRecorder.swift, DictusApp/DictationCoordinator.swift
- **Committed in:** `b3799b2`, `816442c`

**3. [Rule 1 - Bug] Waveform bars invisible with Parakeet**
- **Found during:** Device testing after waveform fix
- **Issue:** RawAudioCapture (Parakeet) produces lower RMS values than AudioRecorder (WhisperKit). With `rms * 5.0` scaling, the waveform bars were barely visible.
- **Fix:** Increased energy scaling from `rms * 5.0` to `rms * 15.0` in RawAudioCapture.
- **Files modified:** DictusApp/Audio/RawAudioCapture.swift
- **Committed in:** `cb339b2`

---

**Total deviations:** 3 auto-fixed (3 bugs)
**Impact on plan:** Auto-return removal is a significant plan change but the correct decision -- the heuristic was fundamentally flawed. Waveform fixes were essential for the feature to work in production (background app scenario).

## Issues Encountered
- canOpenURL iterates in order and has no way to determine which app the user was actually typing in. This is a known iOS limitation with no public API workaround.
- iOS main thread throttling in background is aggressive -- timers and display links stop firing. Audio thread callbacks (installTap) continue running and are the correct mechanism for real-time data forwarding.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 13 complete. Cold start flow works end-to-end: keyboard mic tap -> app opens -> overlay shown -> swipe back -> recording with live waveform -> transcription.
- All three plans delivered: infrastructure (01), swipe-back overlay (02), URL scheme + waveform bridge (03).
- Ready for Phase 14 (Model Management) or other v1.2 milestones.

## Self-Check: PASSED

All 4 commits verified (bd31598, b3799b2, cb339b2, 816442c). All 7 modified files confirmed on disk (DictusApp/Info.plist, not Dictus/Info.plist -- corrected in summary).

---
*Phase: 13-cold-start-audio-bridge*
*Completed: 2026-03-12*
