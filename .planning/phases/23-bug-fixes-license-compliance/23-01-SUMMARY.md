---
phase: 23-bug-fixes-license-compliance
plan: 01
subsystem: ui
tags: [autocorrect, license, attribution, keyboard, swift]

# Dependency graph
requires: []
provides:
  - "Autocorrect undo invalidation on new character input and external text changes"
  - "Complete open-source license attribution for all 5 dependencies"
  - "Corrected Dictus GitHub URL in license screen"
affects: [24-symspell-corrections]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Invalidate undo state before character insertion to prevent race conditions"
    - "Apache 2.0 short-form notice helper for in-app attribution"

key-files:
  created: []
  modified:
    - DictusKeyboard/DictusKeyboardBridge.swift
    - DictusKeyboard/KeyboardViewController.swift
    - DictusApp/Views/LicensesView.swift

key-decisions:
  - "Used MIT for giellakbd-ios (dual-licensed Apache-2.0/MIT) since mitLicense helper already existed"
  - "Used Apache 2.0 short-form notice (Section 4d compliant) instead of full 175-line license text"

patterns-established:
  - "apache2License(copyright:) helper for Apache 2.0 attribution blocks"

requirements-completed: [FIX-01, FIX-02, FIX-03]

# Metrics
duration: 2min
completed: 2026-04-01
---

# Phase 23 Plan 01: Bug Fixes & License Compliance Summary

**Autocorrect undo race condition fixed in keyboard bridge/controller, license screen completed with all 5 dependencies in alphabetical order with correct URLs and license types**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-01T19:34:47Z
- **Completed:** 2026-04-01T19:36:30Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Fixed autocorrect undo race condition: backspace after typing new characters now deletes normally instead of undoing a stale autocorrect
- Corrected Dictus license URL from github.com/Pivii/dictus to github.com/getdictus/dictus-ios
- Added 3 missing dependency attributions (DeviceKit, FluidAudio, giellakbd-ios) with correct authors and license types
- Added apache2License() helper for FluidAudio's Apache 2.0 attribution

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix autocorrect undo race condition (FIX-01)** - `5a83c8d` (fix)
2. **Task 2: Complete license attribution screen (FIX-02, FIX-03)** - `99c3961` (feat)

## Files Created/Modified
- `DictusKeyboard/DictusKeyboardBridge.swift` - Added lastAutocorrect = nil in handleInputKey() before character insertion
- `DictusKeyboard/KeyboardViewController.swift` - Added lastAutocorrect = nil in textDidChange() for external text changes
- `DictusApp/Views/LicensesView.swift` - Rewrote with 5 alphabetical entries, corrected URL, added apache2License helper

## Decisions Made
- Used MIT license for giellakbd-ios (dual-licensed Apache-2.0/MIT) since the mitLicense helper already existed and MIT is one of the two valid options
- Used Apache 2.0 short-form notice (Section 4d compliant) for in-app attribution rather than the full 175-line text

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- FIX-01/02/03 all resolved, keyboard and app targets build cleanly
- Ready for Phase 24 (SymSpell corrections engine)

---
*Phase: 23-bug-fixes-license-compliance*
*Completed: 2026-04-01*
