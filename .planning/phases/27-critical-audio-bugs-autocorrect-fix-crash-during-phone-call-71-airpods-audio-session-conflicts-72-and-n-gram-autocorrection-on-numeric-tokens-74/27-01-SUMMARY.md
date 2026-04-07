---
phase: 27-critical-audio-bugs-autocorrect-fix
plan: 01
subsystem: audio
tags: [callkit, avaudio, airpods, crash-prevention, audio-session]

# Dependency graph
requires:
  - phase: 01-cross-process-foundation
    provides: UnifiedAudioEngine, DictationCoordinator
provides:
  - CallStateMonitor for phone call detection via CXCallObserver
  - deactivateAndIdle method for post-recording audio session cleanup
  - Call guard in DictationCoordinator preventing SIGABRT during phone calls
affects: [audio, dictation-pipeline, airpods-integration]

# Tech tracking
tech-stack:
  added: [CallKit]
  patterns: [pre-recording safety guard, audio session idle deactivation]

key-files:
  created:
    - DictusApp/Audio/CallStateMonitor.swift
  modified:
    - DictusApp/Audio/UnifiedAudioEngine.swift
    - DictusApp/DictationCoordinator.swift
    - Dictus.xcodeproj/project.pbxproj

key-decisions:
  - "Prevention over try/catch for phone call crash: NSException from installTapOnBus cannot be caught by Swift do/catch"
  - "deactivateAndIdle separate from deactivateSession: different lifecycle semantics (auto-cleanup vs explicit user stop)"
  - "Trade-off accepted: ~100-200ms re-activation cost on next recording vs hijacking AirPods controls"

patterns-established:
  - "Pre-recording safety guard: check system state before audio engine operations"
  - "Audio session idle deactivation: release session with .notifyOthersOnDeactivation after recording"

requirements-completed: [BUG-71, BUG-72]

# Metrics
duration: 4min
completed: 2026-04-07
---

# Phase 27 Plan 01: Audio Bugs Fix Summary

**CallStateMonitor prevents SIGABRT crash during phone calls (#71) and deactivateAndIdle releases AirPods/media session after recording (#72)**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-07T18:37:09Z
- **Completed:** 2026-04-07T18:40:35Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments
- Phone call detection via CXCallObserver blocks recording with user-visible error instead of crashing
- Audio session fully deactivated with .notifyOthersOnDeactivation after every recording/cancel
- AirPods play/pause controls return to other apps (Spotify, YouTube) when Dictus is idle
- Build succeeds for DictusApp target

## Task Commits

Each task was committed atomically:

1. **Task 1: Create CallStateMonitor and add call guard** - `db796a2` (fix)
2. **Task 2: Add audio session idle deactivation** - `e7083b4` (fix)

## Files Created/Modified
- `DictusApp/Audio/CallStateMonitor.swift` - CXCallObserver wrapper detecting active phone calls
- `DictusApp/Audio/UnifiedAudioEngine.swift` - Added deactivateAndIdle() for post-recording cleanup
- `DictusApp/DictationCoordinator.swift` - Call guard before recording + deactivateAndIdle after stop/cancel
- `Dictus.xcodeproj/project.pbxproj` - Added CallStateMonitor.swift to DictusApp target

## Decisions Made
- Prevention over try/catch for phone call crash: NSException from installTapOnBus cannot be caught by Swift do/catch, so we check CXCallObserver state before attempting to record
- deactivateAndIdle is separate from deactivateSession because they serve different lifecycle semantics (auto-cleanup vs explicit user Power button stop)
- Accepted ~100-200ms re-activation cost on next recording as trade-off for releasing AirPods controls

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed pbxproj ID collision for CallStateMonitor**
- **Found during:** Task 2 (build verification)
- **Issue:** IDs AA0000C1/AA1000C1 were already used by Settings.bundle, causing CallStateMonitor to not compile
- **Fix:** Changed to AA0000C2/AA1000C2
- **Files modified:** Dictus.xcodeproj/project.pbxproj
- **Verification:** Build succeeded
- **Committed in:** e7083b4 (Task 2 commit)

**2. [Rule 3 - Blocking] Added missing DictusCore import to CallStateMonitor**
- **Found during:** Task 2 (build verification)
- **Issue:** DictusLogger is defined in DictusCore framework, import was missing
- **Fix:** Added `import DictusCore` to CallStateMonitor.swift
- **Files modified:** DictusApp/Audio/CallStateMonitor.swift
- **Verification:** Build succeeded
- **Committed in:** e7083b4 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both auto-fixes necessary for compilation. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Audio bugs #71 and #72 are fixed at the code level
- Device testing required: verify on physical device with phone call + AirPods scenarios
- Plan 27-02 (numeric token autocorrect) is independent and can proceed in parallel

---
*Phase: 27-critical-audio-bugs-autocorrect-fix*
*Completed: 2026-04-07*
