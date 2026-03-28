---
gsd_state_version: 1.0
milestone: v1.3
milestone_name: Public Beta
status: in-progress
stopped_at: Completed 19-02-PLAN.md
last_updated: "2026-03-28T10:57:24.033Z"
last_activity: 2026-03-28 — Completed Phase 19 Plan 02 (delete repeat acceleration, spacebar trackpad)
progress:
  total_phases: 6
  completed_phases: 2
  total_plans: 8
  completed_plans: 7
  percent: 88
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-27)

**Core value:** A user can dictate text in French in any iOS app and correct it immediately on the same keyboard -- no subscription, no cloud, no account.
**Current focus:** Phase 19 in progress -- Complex Touch Features (accents, edge keys, styling)

## Current Position

Phase: 19 of 22 (Complex Touch Features) — IN PROGRESS
Plan: 2 of 3 complete in current phase
Status: Plan 02 complete, ready for Plan 03
Last activity: 2026-03-28 — Completed Phase 19 Plan 02 (delete repeat acceleration, spacebar trackpad)

Progress: [█████████░] 88% (v1.3 milestone)

## Performance Metrics

**Velocity:**
- v1.0: 18 plans in 4 days
- v1.1: 29 plans in 5 days
- v1.2: 35 plans in 17 days
- Total: 82 plans across 3 milestones, 24 days

## Accumulated Context

### Decisions

All prior decisions logged in PROJECT.md Key Decisions table.
Recent decisions for v1.3:

- Rebuild keyboard from giellakbd-ios (UICollectionView) — 16 SwiftUI approaches failed
- Vendor ~10 source files directly, no CocoaPods
- DeviceKit 5.8.x as sole new SPM dependency
- UIKit keys + SwiftUI chrome (toolbar, overlay stay SwiftUI)
- Fix bugs before architecture change (debug in known codebase)
- Incremental feature addition with dead zone validation after each phase
- LiveActivityStateMachine: extracted pure logic from @MainActor singleton into DictusCore struct for unit testing
- Post-recording watchdog: arm after stop/cancel/error, cancel on new recording, forcePhase for recovery sync
- PersistentLog: O(1) size-based trim (200KB) replaces O(n) line-counting; 7-day retention prunes before export only
- Vendored KeyboardView renamed to GiellaKeyboardView to avoid type collision with existing SwiftUI view
- Added programmatic KeyboardDefinition init for constructing French layouts without JSON
- LegacyCompat.swift provides stubs (KeyMetrics, DeviceClass, KeySound) during UIKit keyboard migration
- [Phase 18]: Vendored KeyboardView renamed to GiellaKeyboardView to avoid Swift type collision
- [Phase 18]: DictusKeyboardBridge as separate delegate class for single responsibility and testability
- [Phase 18]: Hybrid UIKit keyboard + SwiftUI toolbar architecture -- UIKit subview for keys, SwiftUI hosting for chrome
- [Phase 18]: Combine subscription to @Published dictationStatus for recording state sync between UIKit and SwiftUI
- [Phase 18]: Haptic feedback on touchDown (GiellaKeyboardView.touchesBegan) not touchUp (delegate callback) for Apple-matching feel
- [Phase 18]: iPhone keyboard heights 216-226pt (reduced from 262-272pt) to match Apple keyboard proportions
- [Phase 18]: QWERTY row 2 needs 0.5-unit spacers for centering 9 keys in 10-unit grid

- [Phase 19]: Case-insensitive longpress lookup via key.lowercased() instead of duplicating uppercase entries
- [Phase 19]: nearestIndexPath maxDistance = 1 key width to prevent phantom hits on distant keys
- [Phase 19]: hapticFeedback.prepare() in init for zero-latency first touch
- [Phase 19]: wordModeThreshold=10 chars before word-level delete, stage 3 at 0.05s
- [Phase 19]: Trackpad dead zone 8pt (down from 20pt), baseDelta 12pt, 60Hz rate limit

### Pending Todos

None.

### Blockers/Concerns

- Spacebar trackpad gesture arbitration with UICollectionView (HIGH risk, Phase 20)
- Liquid Glass in UIKit cells needs UIVisualEffectView or CALayer approach (Phase 19)
- Beta App Review first external submission — rejection risk (Phase 23)

## Session Continuity

Last session: 2026-03-28T10:57:21.539Z
Stopped at: Completed 19-02-PLAN.md
Resume file: None

---
*State initialized: 2026-03-04*
*v1.0 shipped: 2026-03-07*
*v1.1 shipped: 2026-03-11*
*v1.2 shipped: 2026-03-27*
*v1.3 roadmap: 2026-03-27*
