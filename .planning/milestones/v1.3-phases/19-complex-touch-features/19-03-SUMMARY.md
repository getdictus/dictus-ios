---
phase: 19-complex-touch-features
plan: 03
subsystem: ui
tags: [keyboard, accent-key, adaptive, french, azerty, edge-keys, UIWindow, gesture-delay, UAT]

# Dependency graph
requires:
  - phase: 19-01
    provides: "AccentedCharacters mappings, lastInsertedCharacter tracking, nearestIndexPath fallback"
  - phase: 19-02
    provides: "Delete repeat acceleration, spacebar trackpad with dead zone"
provides:
  - "Adaptive accent key on AZERTY row 3 (apostrophe after consonant, accent after vowel)"
  - "UIWindow gesture delay fix for immediate edge key response (root cause of Phase 18+ edge bug)"
  - "Point clamping replaces nearestIndexPath for more reliable touch resolution"
  - "Keyboard height stability fix (no resize on top-row tap)"
  - "Full UAT verification of all 6 Phase 19 features on device"
affects: [20-spacebar-trackpad, testing, future-phases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Point clamping for out-of-bounds touches instead of nearest-cell search"
    - "UIWindow gesture delay override for keyboard extensions"
    - "preferredScreenEdgesDeferringSystemGestures for edge key zones"

key-files:
  created: []
  modified:
    - DictusKeyboard/FrenchKeyboardLayouts.swift
    - DictusKeyboard/DictusKeyboardBridge.swift
    - DictusKeyboard/Vendored/Views/KeyboardView.swift
    - DictusKeyboard/Vendored/Views/KeyView.swift
    - DictusKeyboard/KeyboardViewController.swift

key-decisions:
  - "UIWindow gesture delay was the root cause of edge key sluggishness since Phase 18 -- override delaysContentTouches and isMultipleTouchEnabled on window"
  - "Replaced nearestIndexPath distance search with point clamping (clamp touch to collectionView bounds) for simpler and more reliable edge key resolution"
  - "preferredScreenEdgesDeferringSystemGestures defers system gestures at all edges to prevent iOS intercepting keyboard edge taps"
  - "Keyboard height expansion prevented by removing auto-resizing behavior on top-row key press"

patterns-established:
  - "Point clamping: clamp touch coordinates to collectionView.bounds before indexPathForItem lookup"
  - "UIWindow gesture override: set delaysContentTouches=false on UIWindow for immediate touch delivery in keyboard extensions"
  - "Edge gesture deferral: override preferredScreenEdgesDeferringSystemGestures = .all in KeyboardViewController"

requirements-completed: [FEEL-06]

# Metrics
duration: ~25min
completed: 2026-03-28
---

# Phase 19 Plan 03: Adaptive Accent Key & Full UAT Summary

**Adaptive accent key on AZERTY row 3 with context-aware label, plus 6 UAT bug fixes including root cause fix for Phase 18+ edge key delay (UIWindow gesture interception)**

## Performance

- **Duration:** ~25 min (implementation + UAT + 6 bug fixes)
- **Started:** 2026-03-28T11:00:00Z (approx)
- **Completed:** 2026-03-28T11:25:00Z (approx)
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Adaptive accent key on AZERTY row 3: shows apostrophe by default, switches to accent character after vowel input, tapping replaces vowel with accented version
- Found and fixed root cause of edge key sluggishness that persisted since Phase 18: UIWindow's default gesture delay was intercepting touches before they reached the keyboard's UICollectionView
- Replaced nearestIndexPath fallback with simpler point clamping approach for more reliable edge key resolution
- Fixed keyboard height expansion bug triggered by top-row key taps
- Deferred system edge gestures to prevent iOS from intercepting taps near screen edges
- All 6 Phase 19 features verified working on physical device with zero dead zones

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement adaptive accent key** - `c566402` (feat)
2. **Task 2: Device verification (UAT)** - human-verified, bug fixes below

**UAT bug fix commits (applied during device testing):**
- `03ab852` - fix 5 UAT issues (edge keys, delete speed, trackpad cursor, accent label)
- `d3205ac` - replace nearestIndexPath with point clamping, fix keyboard height expansion
- `099df97` - defer system edge gestures + immediate touch delivery
- `62b950d` - CRITICAL: disable UIWindow gesture delay for immediate edge key response
- `945b7d4` - cleanup diagnostic logging
- `b989ede` - prevent keyboard height resize on top-row key tap

## Files Created/Modified
- `DictusKeyboard/FrenchKeyboardLayouts.swift` - Added accent key with "accent" sentinel to AZERTY row 3 (normal + shifted)
- `DictusKeyboard/DictusKeyboardBridge.swift` - Added handleAdaptiveAccentKey(), updateAccentKeyDisplay(), accent routing in didTriggerKey
- `DictusKeyboard/Vendored/Views/KeyboardView.swift` - Point clamping for edge touches, updateAccentKeyLabel(), accentKeyLabel property, keyboard height stability
- `DictusKeyboard/Vendored/Views/KeyView.swift` - Edge key rendering fixes
- `DictusKeyboard/KeyboardViewController.swift` - UIWindow gesture delay override, preferredScreenEdgesDeferringSystemGestures

## Decisions Made
- UIWindow gesture delay identified as root cause of edge key sluggishness since Phase 18 -- iOS's default `delaysContentTouches` on UIWindow was adding ~150ms delay to all touches, especially noticeable on edge keys. Overriding this on the keyboard's UIWindow provides immediate touch delivery.
- Replaced nearestIndexPath (iterate visible cells with distance calculation) with point clamping (clamp touch coordinates to collectionView bounds, then call indexPathForItem). Simpler code, more reliable results, no maxDistance tuning needed.
- preferredScreenEdgesDeferringSystemGestures set to .all -- keyboard extensions sit at bottom of screen where iOS home indicator gesture normally intercepts touches. Deferring at all edges ensures no system gesture steals taps from edge keys.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed UIWindow gesture delay causing edge key sluggishness**
- **Found during:** Task 2 (UAT)
- **Issue:** UIWindow's default delaysContentTouches added ~150ms delay to all touches, making edge keys feel unresponsive
- **Fix:** Override UIWindow properties: delaysContentTouches=false, isMultipleTouchEnabled=false
- **Files modified:** DictusKeyboard/KeyboardViewController.swift
- **Committed in:** `62b950d`

**2. [Rule 1 - Bug] Replaced nearestIndexPath with point clamping**
- **Found during:** Task 2 (UAT)
- **Issue:** nearestIndexPath distance-based search was unreliable for edge touches
- **Fix:** Clamp touch coordinates to collectionView bounds before lookup
- **Files modified:** DictusKeyboard/Vendored/Views/KeyboardView.swift
- **Committed in:** `d3205ac`

**3. [Rule 1 - Bug] Fixed keyboard height expansion on top-row tap**
- **Found during:** Task 2 (UAT)
- **Issue:** Tapping top-row keys caused keyboard to resize/expand
- **Fix:** Prevented auto-resize behavior on key press
- **Files modified:** DictusKeyboard/Vendored/Views/KeyboardView.swift
- **Committed in:** `b989ede`

**4. [Rule 1 - Bug] Fixed system edge gesture interception**
- **Found during:** Task 2 (UAT)
- **Issue:** iOS system gestures intercepting taps near screen edges
- **Fix:** Override preferredScreenEdgesDeferringSystemGestures = .all
- **Files modified:** DictusKeyboard/KeyboardViewController.swift
- **Committed in:** `099df97`

**5. [Rule 1 - Bug] Fixed 5 UAT issues (edge keys, delete speed, trackpad, accent label)**
- **Found during:** Task 2 (UAT)
- **Issue:** Multiple minor issues found during device testing
- **Fix:** Batch fix for edge key sensitivity, delete speed tuning, trackpad cursor movement, accent label display
- **Files modified:** Multiple keyboard files
- **Committed in:** `03ab852`

---

**Total deviations:** 5 auto-fixed (all Rule 1 - Bug)
**Impact on plan:** All fixes were necessary for correct device behavior. The UIWindow gesture delay fix (`62b950d`) was the most significant -- it resolved a bug that had persisted since Phase 18.

## Issues Encountered
- Edge key delay root cause was not in the keyboard code itself but in UIWindow's default gesture handling -- required investigation beyond the keyboard's UICollectionView to find

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All Phase 19 features verified on physical device
- Zero dead zones confirmed across all keyboard pages
- Edge key response is now immediate (touchDown, not touchUp)
- Ready for Phase 20 (spacebar trackpad gesture arbitration already handled)

---
*Phase: 19-complex-touch-features*
*Completed: 2026-03-28*
