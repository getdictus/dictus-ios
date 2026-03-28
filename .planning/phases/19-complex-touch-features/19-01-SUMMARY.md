---
phase: 19-complex-touch-features
plan: 01
subsystem: ui
tags: [keyboard, accents, french, long-press, edge-keys, haptic, UICollectionView]

# Dependency graph
requires:
  - phase: 18-keyboard-base
    provides: "GiellaKeyboardView UICollectionView keyboard, DictusKeyboardBridge delegate, FrenchKeyboardLayouts"
provides:
  - "French accent long-press popup on all 8 base keys (e, a, u, i, o, c, y, n)"
  - "Case-aware accents (uppercase on shifted/capslock pages)"
  - "Fixed double-space period insertion ('. ' instead of '  ')"
  - "Nearest-cell fallback for edge key touch resolution"
  - "lastInsertedCharacter tracking for adaptive accent key (Plan 03)"
affects: [19-02-PLAN, 19-03-PLAN, 20-spacebar-trackpad]

# Tech tracking
tech-stack:
  added: []
  patterns: [nearest-cell-fallback, case-insensitive-longpress-lookup]

key-files:
  created: []
  modified:
    - DictusKeyboard/FrenchKeyboardLayouts.swift
    - DictusKeyboard/DictusKeyboardBridge.swift
    - DictusKeyboard/Vendored/Views/KeyboardView.swift

key-decisions:
  - "Case-insensitive longpress lookup via key.lowercased() instead of duplicating uppercase entries in dictionary"
  - "nearestIndexPath maxDistance = 1 key width to prevent phantom hits on distant keys"
  - "hapticFeedback.prepare() in init for zero-latency first touch"

patterns-established:
  - "nearestIndexPath fallback: when indexPathForItem returns nil, iterate visibleCells with distance check"
  - "Case transformation in longpressKeys(for:) applies uppercased() to accent variants on shifted/capslock pages"

requirements-completed: [KBD-08, FEEL-04]

# Metrics
duration: 3min
completed: 2026-03-28
---

# Phase 19 Plan 01: Wire Accents, Fix Edge Keys & Double-Space Summary

**French accent long-press popups on all vowels + c/y/n, nearest-cell fallback for edge keys, and fixed double-space period insertion**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-28T10:47:24Z
- **Completed:** 2026-03-28T10:50:30Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Wired AccentedCharacters.mappings into FrenchKeyboardLayouts.frenchLongPress for all 8 French base keys
- Added case-insensitive lookup and uppercase transformation so shifted/capslock pages show uppercase accents
- Fixed handleAutoFullStop to check hasSuffix(" ") before second space insertion (was checking suffix(2)=="  " which never matched)
- Added nearestIndexPath(to:) fallback with maxDistance guard for edge key touch resolution
- Applied fallback in handleTouches, touchesMoved, and touchesFoundLongpress
- Pre-warmed haptic generator in init for zero-latency first touch
- Added lastInsertedCharacter tracking property for future adaptive accent key

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire accent data and fix double-space period** - `0399799` (feat)
2. **Task 2: Fix edge key touchDown with nearest-cell fallback** - `740e5a8` (feat)

## Files Created/Modified
- `DictusKeyboard/FrenchKeyboardLayouts.swift` - Populated frenchLongPress from AccentedCharacters.mappings
- `DictusKeyboard/DictusKeyboardBridge.swift` - Fixed handleAutoFullStop logic, added lastInsertedCharacter tracking
- `DictusKeyboard/Vendored/Views/KeyboardView.swift` - Added nearestIndexPath fallback, case-insensitive longpress lookup, uppercase accent transformation, haptic pre-warm

## Decisions Made
- Used case-insensitive lookup (key.lowercased()) rather than duplicating uppercase entries in the longPress dictionary -- keeps data source single and consistent with AccentedCharacters.mappings
- Set nearestIndexPath maxDistance to one full key width -- balances edge hit resolution with preventing phantom matches on distant keys
- Pre-warmed hapticFeedback in init rather than only in touchesBegan -- eliminates cold-start latency on very first touch

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Accent popups ready for on-device testing (long-press any vowel or c/y/n)
- Edge key fallback ready for testing (tap a, q, p, m at screen edges)
- Double-space period ready for testing (type word + space + space)
- Plan 02 (accent popup styling and drag-to-select) can proceed
- Plan 03 (adaptive accent key) can use lastInsertedCharacter tracking

---
*Phase: 19-complex-touch-features*
*Completed: 2026-03-28*
