---
gsd_state_version: 1.0
milestone: v1.7
milestone_name: Stability, Polish & i18n
status: executing
stopped_at: Completed 34-01-PLAN.md (DictusCore foundations for insertion fix)
last_updated: "2026-04-16T05:35:59.641Z"
last_activity: 2026-04-16 — Plan 34-01 executed (LogEvent probe cases, HapticFeedback, state machine edges, InsertionClassifier)
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 4
  completed_plans: 1
  percent: 4
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-15)

**Core value:** A user can dictate text in French in any iOS app and correct it immediately on the same keyboard -- no subscription, no cloud, no account.
**Current focus:** Milestone v1.7 — Stability, Polish & i18n (roadmap defined, ready for Phase 34 planning)

## Current Position

Phase: 34 (Silent Insertion Fix) — executing
Plan: 34-01 complete; next: 34-02 (HomeView App Group recovery fallback)
Status: Plan 34-01 executed — DictusCore foundations shipped (log events, haptic, state machine edges, InsertionClassifier)
Last activity: 2026-04-16 — Plan 34-01 executed

Progress: [█░░░░░░░░░] 4% (1/24 plans across 6 phases; 1/4 in Phase 34)

## Performance Metrics

**Velocity:**
- v1.0: 18 plans in 4 days
- v1.1: 29 plans in 5 days
- v1.2: 35 plans in 17 days
- v1.3: 14 plans in 11 days
- v1.4: 15 plans in 7 days
- Total: 111 plans across 5 milestones in 35 days

## Accumulated Context

### Decisions

All prior decisions logged in PROJECT.md Key Decisions table.

**v1.7 roadmap decisions:**
- Phase numbering starts at 34 to avoid collision with v1.5 Dictus Pro premium worktree (phases 30-33).
- STAB-01 isolated in Phase 34 so the silent insertion bug can ship as a hotfix independent of heavier keyboard/autocorrect/i18n work.
- KBD-01 + KBD-02 bundled in Phase 35 because both target keyboard geometry and the audit (KBD-01) drives the glitch fix (KBD-02).
- AUTO-01 + AUTO-02 + AUTO-03 bundled in Phase 36 — AOSP LatinIME alignment is a single coherent architectural change, splitting would cause rework.
- I18N-01 (Phase 38) scheduled before I18N-02 (Phase 39) — German is the first validation of the i18n process, not an independent feature.

**Phase 34 execution decisions (Plan 34-01):**
- Use `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` for DictusCore tests, NOT `swift test --package-path DictusCore` — the package is iOS-only (UIKit, ActivityKit, iOS 26 SwiftUI APIs) and does not compile for macOS. Plans 34-02/03/04 should use the same command.
- Pre-existing `AccentedCharacterTests` + `FrequencyDictionaryTests` failures on `develop` documented in `.planning/phases/34-silent-insertion-fix/deferred-items.md` and deferred to a future cleanup issue — out of STAB-01 scope.
- `InsertionClassifier` shipped as an `enum` (static-function namespace) — pure policy, no stored state, no allocator churn when called per-insertion-attempt.

### Pending Todos

- Adaptive accent key shows apostrophe after "qu" (UI todo from v1.4)

### Known Issues Carried to v1.7

None — BUG-71 fixed via PR #81, BUG-72 fixed via PR #86.

### Parallel Milestone

- **v1.5 Dictus Pro** in progress on `feature/premium` worktree (Phase 30/33 — 25% done)
- Sync via `sync/develop-to-premium` branch
- v1.7 uses phases 34-39 to avoid collision with premium phases 30-33

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-04-16T05:34:07Z
Stopped at: Completed 34-01-PLAN.md (DictusCore foundations for insertion fix)
Resume file: .planning/phases/34-silent-insertion-fix/34-01-SUMMARY.md
Next step: `/gsd:execute-phase 34` to continue with Plan 34-02 (HomeView App Group recovery fallback)

---
*State initialized: 2026-03-04*
*v1.0 shipped: 2026-03-07*
*v1.1 shipped: 2026-03-11*
*v1.2 shipped: 2026-03-27*
*v1.3 shipped: 2026-04-07*
*v1.4 shipped: 2026-04-08*
*v1.7 milestone started: 2026-04-15*
*v1.7 roadmap defined: 2026-04-15*
