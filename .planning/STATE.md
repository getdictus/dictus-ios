---
gsd_state_version: 1.0
milestone: v1.5
milestone_name: Dictus Pro
status: executing
stopped_at: Phase 30 executed — visual verification pending
last_updated: "2026-04-09T18:00:00.000Z"
last_activity: 2026-04-09 — Phase 30 plans 01+02 executed
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 2
  completed_plans: 2
  percent: 25
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-08)

**Core value:** A user can dictate text in French in any iOS app and correct it immediately on the same keyboard -- no cloud, no account. Pro adds intelligent reformulation, history, and custom vocabulary -- all 100% on-device.
**Current focus:** Phase 30 — Subscription + Paywall

## Current Position

Phase: 30 of 33 (Subscription + Paywall)
Plan: 02 of 02 (complete)
Status: Visual verification pending (Task 4)
Last activity: 2026-04-09 — Phase 30 plans 01+02 executed

Progress: ██░░░░░░░░ 25%

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
v1.5 decisions pending:
- Open Core model: all code public (MIT), Pro gated by StoreKit 2
- Single Pro tier at launch (~4-5 EUR/month)
- GRDB + FTS5 for history (not SwiftData -- avoids 0xdead10cc, native FTS)
- Apple Foundation Models primary LLM, mlx-swift fallback for older devices
- WhisperKit initialPrompt for vocabulary injection (224 token limit)

### Pending Todos

- Adaptive accent key shows apostrophe after "qu" (UI todo from v1.4)

### Known Issues

- BUG-71: Crash when starting dictation during phone call (reverted in v1.4)
- BUG-72: AirPods/media apps not resuming after recording (reverted in v1.4)

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-04-09T18:00:00.000Z
Stopped at: Phase 30 executed — visual verification pending
Resume file: .planning/phases/30-subscription-paywall/30-02-SUMMARY.md
Next step: Visual verification in Simulator, then `/gsd:execute-phase 31`

---
*State initialized: 2026-03-04*
*v1.4 shipped: 2026-04-08*
*v1.5 roadmap created: 2026-04-08*
