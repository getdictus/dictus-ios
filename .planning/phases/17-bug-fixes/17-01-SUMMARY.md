---
phase: 17-bug-fixes
plan: 01
subsystem: lifecycle
tags: [live-activity, dynamic-island, watchdog, state-machine, tdd]

# Dependency graph
requires: []
provides:
  - "LiveActivityStateMachine struct in DictusCore with transition validation"
  - "Post-recording watchdog in LiveActivityManager preventing DI stuck on REC"
  - "17 unit tests covering all valid/invalid state machine transitions"
affects: [18-keyboard-rebuild, 19-keyboard-features]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Extracted testable state machine from manager singleton", "Post-recording watchdog with guard-based exit"]

key-files:
  created:
    - DictusCore/Sources/DictusCore/LiveActivityStateMachine.swift
    - DictusCore/Tests/DictusCoreTests/LiveActivityStateMachineTests.swift
  modified:
    - DictusApp/LiveActivityManager.swift
    - DictusApp/DictationCoordinator.swift

key-decisions:
  - "Added forcePhase() to state machine for recovery/bootstrap path sync instead of walking transition chain"
  - "Kept private LiveActivityPhase enum as canonical state, state machine used for validation only"

patterns-established:
  - "Extract pure logic from @MainActor singletons into DictusCore structs for unit testing"
  - "Watchdog pattern: arm after stop/cancel, cancel at start of new recording, guard-based no-op if already transitioned"

requirements-completed: [FIX-01]

# Metrics
duration: 9min
completed: 2026-03-27
---

# Phase 17 Plan 01: DI Watchdog Summary

**Extracted LiveActivityStateMachine to DictusCore with 17 unit tests and added post-recording watchdog to prevent Dynamic Island stuck on REC state**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-27T17:20:22Z
- **Completed:** 2026-03-27T17:29:51Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Extracted testable state machine from LiveActivityManager into DictusCore struct
- 17 unit tests covering all valid transitions, invalid transitions, watchdog flag, and reset
- Post-recording watchdog armed after every stop/cancel/error, forces DI to standby after 10s if stuck
- Watchdog cancelled at start of transitionToRecording to prevent false positive on quick chain
- State machine synced with LiveActivityManager on all direct phase assignments

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract LiveActivityStateMachine to DictusCore with unit tests** - `7e94e84` (test)
2. **Task 2: Add post-recording watchdog to LiveActivityManager and arm from DictationCoordinator** - `cd4b423` (feat)

## Files Created/Modified
- `DictusCore/Sources/DictusCore/LiveActivityStateMachine.swift` - Testable state machine with Phase enum, transition validation, needsWatchdog flag, forcePhase for recovery
- `DictusCore/Tests/DictusCoreTests/LiveActivityStateMachineTests.swift` - 17 tests: 11 valid transitions, 4 invalid transitions, 1 watchdog flag, 1 reset
- `DictusApp/LiveActivityManager.swift` - Added stateMachine property, recordingWatchdog Task, startRecordingWatchdog/cancelRecordingWatchdog methods, syncStateMachine helper, delegated validation to extracted state machine
- `DictusApp/DictationCoordinator.swift` - Armed watchdog after stopDictation, cancelDictation, and handleError

## Decisions Made
- Added `forcePhase()` to LiveActivityStateMachine for recovery/bootstrap paths where normal transition validation would reject the sync (not in original plan, needed for correctness)
- Kept private `LiveActivityPhase` enum as canonical state in LiveActivityManager; state machine serves as validation layer only
- Added `syncStateMachine` helper to keep state machine in sync on all direct `currentPhase` assignments

## Deviations from Plan

None - plan executed exactly as written. The `forcePhase()` addition and `syncStateMachine` helper were implicit requirements of the plan's instruction to "sync stateMachine.currentPhase whenever currentPhase changes."

## Issues Encountered
- Pre-existing uncommitted change in LogEvent.swift (added `logExportCompleted` case) caused initial build failure due to non-exhaustive switches. Was already fixed in the working directory (stale build cache). Not a blocker.
- DictusCore SPM scheme test runner initially failed due to pre-existing PersistentLog compilation errors (platform-specific APIs). Tests run successfully via xcodebuild with iOS Simulator destination.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- DI watchdog is active and will catch stuck .recording states
- State machine is unit-tested and ready for any future transition rule changes
- Plan 02 (export logs optimization) can proceed independently

---
*Phase: 17-bug-fixes*
*Completed: 2026-03-27*
