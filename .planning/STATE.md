---
gsd_state_version: 1.0
milestone: v1.3
milestone_name: Public Beta
status: completed
stopped_at: Phase 22 context gathered
last_updated: "2026-03-31T15:33:23.574Z"
last_activity: "2026-03-31 - Completed 21-02: memory profiling report, emoji picker 139 MiB critical blocker identified"
progress:
  total_phases: 6
  completed_phases: 5
  total_plans: 12
  completed_plans: 12
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-27)

**Core value:** A user can dictate text in French in any iOS app and correct it immediately on the same keyboard -- no subscription, no cloud, no account.
**Current focus:** Phase 20 in progress -- Feature Reintegration (predictions, emoji, settings)

## Current Position

Phase: 21 of 22 (Cleanup & Memory Profiling)
Plan: 2 of 2 complete in current phase
Status: Phase 21 complete
Last activity: 2026-03-31 - Completed 21-02: memory profiling report, emoji picker 139 MiB critical blocker identified

Progress: [██████████] 100% (v1.3 milestone)

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
- [Phase 19]: UIWindow gesture delay was root cause of edge key sluggishness since Phase 18 -- override delaysContentTouches on window
- [Phase 19]: Point clamping replaces nearestIndexPath for simpler and more reliable edge touch resolution
- [Phase 19]: preferredScreenEdgesDeferringSystemGestures = .all to prevent iOS intercepting edge key taps

- [Phase 20]: SuggestionState owned by KeyboardViewController, injected into bridge (weak) and SwiftUI (@ObservedObject)
- [Phase 20]: Autocorrect-on-space matches iOS native behavior, undo via AutocorrectState on next backspace
- [Phase 20]: Emoji key uses .input with alternate="emoji" routed through bridge callback
- [Phase 20]: Default layer set in viewWillAppear for immediate setting changes
- [Phase 20]: Emoji key identified by glyph character, not alternate label, for clean rendering
- [Phase 20]: UIHostingController.safeAreaRegions disabled for full-width SwiftUI in keyboard extension
- [Phase 20]: Sound feedback default false to match first-install behavior
- [Phase 21]: Extracted DeviceClass, KeyMetrics, KeySound, KeyPopup from LegacyCompat into permanent KeyboardMetrics.swift
- [Phase 21]: Emoji picker 139 MiB is critical blocker for public beta -- needs optimization before release

### Pending Todos

None.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260330-e6i | Adaptive accent key shows apostrophe after qu | 2026-03-30 | 5abb2a7 | [260330-e6i-adaptive-accent-key-shows-apostrophe-aft](./quick/260330-e6i-adaptive-accent-key-shows-apostrophe-aft/) |
| Phase 20 P02 | 27min | 2 tasks | 6 files |
| Phase 21 P01 | 3min | 2 tasks | 7 files |
| Phase 21 P02 | 5min | 2 tasks | 1 files |

### Blockers/Concerns

- Spacebar trackpad gesture arbitration with UICollectionView (HIGH risk, Phase 20)
- Liquid Glass in UIKit cells needs UIVisualEffectView or CALayer approach (Phase 19)
- Beta App Review first external submission — rejection risk (Phase 23)

## Session Continuity

Last session: 2026-03-31T15:33:23.571Z
Stopped at: Phase 22 context gathered
Resume file: .planning/phases/22-public-testflight/22-CONTEXT.md

---
*State initialized: 2026-03-04*
*v1.0 shipped: 2026-03-07*
*v1.1 shipped: 2026-03-11*
*v1.2 shipped: 2026-03-27*
*v1.3 roadmap: 2026-03-27*
