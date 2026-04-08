---
phase: 21-cleanup-memory-profiling
plan: 01
subsystem: ui
tags: [swift, keyboard, cleanup, dead-code, pbxproj]

# Dependency graph
requires:
  - phase: 18-uikit-keyboard-integration
    provides: "UIKit keyboard replaced SwiftUI keyboard, LegacyCompat stubs"
provides:
  - "KeyboardMetrics.swift with DeviceClass, KeyMetrics, KeySound, KeyPopup types"
  - "Clean project with zero old SwiftUI keyboard files"
  - "Clean pbxproj with zero ghost references"
affects: [21-02-memory-profiling]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Permanent metrics file for shared keyboard constants"

key-files:
  created:
    - DictusKeyboard/KeyboardMetrics.swift
  modified:
    - Dictus.xcodeproj/project.pbxproj

key-decisions:
  - "Extracted 4 types (DeviceClass, KeyMetrics, KeySound, KeyPopup) from LegacyCompat into permanent KeyboardMetrics.swift"
  - "Removed imports DictusCore and AVFoundation from extracted file -- only needed by dead placeholder KeyboardView"

patterns-established:
  - "KeyboardMetrics.swift: single source of truth for keyboard layout constants and feedback types"

requirements-completed: []

# Metrics
duration: 3min
completed: 2026-03-30
---

# Phase 21 Plan 01: Cleanup Old SwiftUI Keyboard Code Summary

**Deleted 6 dead SwiftUI keyboard files (1686 lines), extracted 4 reusable types into KeyboardMetrics.swift, cleaned all ghost references from pbxproj**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-30T16:08:16Z
- **Completed:** 2026-03-30T16:11:09Z
- **Tasks:** 2
- **Files modified:** 7 (1 created, 6 deleted, 1 modified)

## Accomplishments
- Extracted DeviceClass, KeyMetrics, KeySound, KeyPopup from LegacyCompat.swift into permanent KeyboardMetrics.swift
- Deleted 6 dead SwiftUI keyboard files: LegacyCompat.swift, KeyButton.swift, KeyRow.swift, KeyboardView.swift, SpecialKeyButton.swift, AccentPopup.swift (1686 lines removed)
- Cleaned all 19 ghost references from project.pbxproj and added KeyboardMetrics.swift registration
- Verified DictusKeyboard scheme builds successfully with BUILD SUCCEEDED

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract LegacyCompat types into KeyboardMetrics.swift and delete old files** - `68af985` (refactor)
2. **Task 2: Clean pbxproj and add KeyboardMetrics.swift, then verify build** - `1e19df4` (chore)

## Files Created/Modified
- `DictusKeyboard/KeyboardMetrics.swift` - Permanent file with DeviceClass, KeyMetrics, KeySound, KeyPopup types
- `Dictus.xcodeproj/project.pbxproj` - Removed 19 ghost references, added KeyboardMetrics.swift
- `DictusKeyboard/LegacyCompat.swift` - DELETED (types extracted to KeyboardMetrics.swift)
- `DictusKeyboard/Views/KeyButton.swift` - DELETED (dead SwiftUI code)
- `DictusKeyboard/Views/KeyRow.swift` - DELETED (dead SwiftUI code)
- `DictusKeyboard/Views/KeyboardView.swift` - DELETED (dead SwiftUI code, not the Vendored UIKit one)
- `DictusKeyboard/Views/SpecialKeyButton.swift` - DELETED (dead SwiftUI code)
- `DictusKeyboard/Views/AccentPopup.swift` - DELETED (dead SwiftUI code)

## Decisions Made
- Removed `import DictusCore` and `import AVFoundation` from extracted file -- these were only needed by the dead placeholder KeyboardView struct, not by the 4 extracted types
- Used `import AudioToolbox` (for SystemSoundID in KeySound) instead of AVFoundation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Codebase is clean with no dead SwiftUI keyboard code
- Ready for Plan 02 (memory profiling)
- All consumers (EmojiPickerView, EmojiCategoryBar, DictusKeyboardBridge) compile with the new KeyboardMetrics.swift

---
*Phase: 21-cleanup-memory-profiling*
*Completed: 2026-03-30*
