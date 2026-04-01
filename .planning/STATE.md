---
gsd_state_version: 1.0
milestone: v1.3
milestone_name: Public Beta
status: planning
stopped_at: Completed 23-01-PLAN.md
last_updated: "2026-04-01T19:39:49.656Z"
last_activity: 2026-04-01 — v1.4 roadmap created (4 phases, 13 requirements mapped)
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 1
  completed_plans: 1
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-01)

**Core value:** A user can dictate text in French in any iOS app and correct it immediately on the same keyboard -- no subscription, no cloud, no account.
**Current focus:** Phase 23 — Bug Fixes & License Compliance

## Current Position

Phase: 23 of 26 (Bug Fixes & License Compliance)
Plan: 0 of 1 in current phase
Status: Ready to plan
Last activity: 2026-04-01 — v1.4 roadmap created (4 phases, 13 requirements mapped)

Progress: [░░░░░░░░░░] 0% (v1.4 milestone: 0/7 plans)

## Performance Metrics

**Velocity:**
- v1.0: 18 plans in 4 days
- v1.1: 29 plans in 5 days
- v1.2: 35 plans in 17 days
- v1.3: ~14 plans (in progress)
- Total: 96+ plans across 4 milestones

## Accumulated Context

### Decisions

All prior decisions logged in PROJECT.md Key Decisions table.
Recent decisions for v1.4:

- Fix autocorrect bug #67 before any prediction engine changes (race condition risk)
- SymSpell replaces UITextChecker for corrections only; UITextChecker kept for completions
- Vendor SymSpellSwift source (~500 lines) instead of SPM dependency (French Unicode edge cases)
- Custom NgramTrie with flat binary format (16 bytes/entry, mmap) instead of Swift Dictionary (80 bytes/entry)
- KenLM rejected: C++ bridging, LGPL, 50-500MB models incompatible with 50MB extension limit
- Cold start auto-return time-boxed to 2h investigation; Apple DTS confirmed no public API exists
- Memory gate between phases: device profiling mandatory after SymSpell and after n-gram
- [Phase 23]: Used MIT for giellakbd-ios (dual Apache-2.0/MIT) since helper existed

### Pending Todos

None.

### Blockers/Concerns

- Phase 22 (Public TestFlight) still in progress -- Phase 23 depends on it completing
- SymSpell memory on physical device needs empirical validation (estimates: 3-5MB for 30K words)
- French tokenization for n-gram elisions (l'homme, aujourd'hui) needs custom tokenizer

## Session Continuity

Last session: 2026-04-01T19:37:16.910Z
Stopped at: Completed 23-01-PLAN.md
Resume file: None

---
*State initialized: 2026-03-04*
*v1.0 shipped: 2026-03-07*
*v1.1 shipped: 2026-03-11*
*v1.2 shipped: 2026-03-27*
*v1.3 roadmap: 2026-03-27*
*v1.4 roadmap: 2026-04-01*
