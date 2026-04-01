---
phase: 21-cleanup-memory-profiling
plan: 02
subsystem: profiling
tags: [instruments, memory, os_signpost, keyboard-extension, jetsam]

# Dependency graph
requires:
  - phase: 21-cleanup-memory-profiling
    provides: "Clean codebase after dead SwiftUI code removal (Plan 01)"
provides:
  - "Memory profiling report with per-operation measurements on real device"
  - "Identification of emoji picker as critical memory outlier (139 MiB)"
  - "Confirmation that core operations (typing, dictation, prediction) stay under 50 MiB"
affects: [emoji-picker-optimization, public-beta]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Instruments profiling protocol for keyboard extension"]

key-files:
  created:
    - ".planning/phases/21-cleanup-memory-profiling/21-MEMORY-REPORT.md"
  modified: []

key-decisions:
  - "Emoji picker 139 MiB is critical blocker for public beta -- needs optimization before release"
  - "System leaks (~20 in idle) are iOS internals, not Dictus code -- acceptable"
  - "KeyTapSignposter intervals not captured in Instruments -- needs wiring investigation"
  - "Dictation transcription runs in DictusApp, not keyboard extension -- memory stays low"

patterns-established:
  - "Memory profiling protocol: 7 operation modes measured independently on physical device"
  - "Instruments overhead awareness: profiler disables jetsam limits, readings may be inflated"

requirements-completed: []

# Metrics
duration: 5min
completed: 2026-03-31
---

# Phase 21 Plan 02: Memory Profiling Summary

**Real-device Instruments profiling reveals keyboard extension stays under 50 MiB for all core operations but emoji picker at 139 MiB is a critical blocker requiring optimization before public beta**

## Performance

- **Duration:** ~5 min (report generation; profiling session was user-performed)
- **Started:** 2026-03-31T14:14:20Z
- **Completed:** 2026-03-31T14:20:00Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Profiled all operation modes on iPhone 15 Pro Max (iOS 26.3.1) with Instruments
- Core keyboard operations (idle 15 MiB, typing 22 MiB, dictation 15 MiB, prediction 21 MiB) all well within 50 MiB limit
- Identified emoji picker at 139 MiB as critical memory outlier requiring optimization
- Confirmed zero application-level memory leaks (only iOS system internals)
- Documented signposter visibility issue for future investigation

## Task Commits

Each task was committed atomically:

1. **Task 1: Run Instruments profiling session** - (user-performed checkpoint, no commit)
2. **Task 2: Create memory profiling report** - `99ca567` (docs)

## Files Created/Modified
- `.planning/phases/21-cleanup-memory-profiling/21-MEMORY-REPORT.md` - Complete memory profiling report with per-operation measurements, leak analysis, signposter verification, and remediation recommendations

## Decisions Made
- Classified ~20 idle leaks as iOS system internals (UIViewServiceDeputyManager, BSServiceConnection, etc.) -- not actionable
- Marked emoji picker memory as critical blocker: 139 MiB is 2.8x the 50 MiB jetsam limit
- Noted signposter needs investigation: either not wired into touch chain or Instruments filter misconfigured
- Dictation transcription not profiled separately in keyboard extension since WhisperKit runs in DictusApp process

## Deviations from Plan

None -- plan executed exactly as written. User provided profiling data, report was generated from measurements.

## Issues Encountered
- **KeyTapSignposter not visible in Instruments:** Custom signposts from `com.pivi.dictus.keyboard` subsystem were not captured. System signposts (`keyboardPerf.UI`) were visible. Root cause unclear -- may be a wiring issue (signposter code not reached in UIKit touch chain) or Instruments filter configuration. Documented in report for future investigation.
- **Debug Navigator limitation:** DictusKeyboard extension process not listed in Debug Navigator, so no baseline comparison possible for the extension itself. Only DictusApp was visible at 62.5 MB.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Memory profiling complete -- quality gate data collected
- **Blocker identified:** Emoji picker optimization required before public beta (139 MiB >> 50 MiB limit)
- Core keyboard operations are confirmed safe for production use
- Signposter investigation can be deferred to a future phase (non-blocking for beta)

---
*Phase: 21-cleanup-memory-profiling*
*Completed: 2026-03-31*
