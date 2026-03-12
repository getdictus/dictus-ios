---
phase: 14-model-pipeline
plan: 02
subsystem: models
tags: [onboarding, ram-detection, parakeet, model-recommendation, dynamic-ui]

# Dependency graph
requires:
  - phase: 14-model-pipeline
    plan: 01
    provides: ModelInfo.recommendedIdentifier() and isRecommended() static methods
provides:
  - Dynamic RAM-based model recommendation in onboarding
  - Data-driven model card (name, size, description from ModelInfo catalog)
  - Verified Parakeet routing and display names across codebase
affects: [onboarding, beta-testing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Data-driven UI from catalog: ModelInfo.forIdentifier() populates view instead of hardcoded strings"

key-files:
  created: []
  modified:
    - DictusApp/Onboarding/ModelDownloadPage.swift

key-decisions:
  - "No code changes needed for Parakeet routing or display names -- verified correct as-is"

patterns-established:
  - "Onboarding model card driven by ModelInfo catalog data, not hardcoded strings"

requirements-completed: [MODEL-03, MODEL-04, MODEL-06, MODEL-07, MODEL-08]

# Metrics
duration: 1min
completed: 2026-03-12
---

# Phase 14 Plan 02: Onboarding Dynamic Recommendation + Parakeet Verification Summary

**Dynamic RAM-based model recommendation in onboarding with data-driven model card, plus verified Parakeet routing and display names**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-12T22:18:29Z
- **Completed:** 2026-03-12T22:19:52Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Onboarding now dynamically recommends the best model for the device (Parakeet v3 on >=6GB RAM, Whisper Small on <=4GB)
- Model card displays name, size, and description from ModelInfo catalog instead of hardcoded "Whisper Small / ~500 Mo"
- Verified Parakeet engine routing is correct (DictationCoordinator creates ParakeetEngine and sets it on TranscriptionService)
- Verified no "Whisper Parakeet" strings exist in codebase -- display name is "Parakeet v3" everywhere
- MODEL-03, MODEL-04, MODEL-06 confirmed as removed scope (no implementation per user decision)

## Task Commits

Each task was committed atomically:

1. **Task 1: Make onboarding model recommendation dynamic** - `e271d8c` (feat)
2. **Task 2: Verify Parakeet routing and display names** - No commit (verification-only, no code changes)

## Files Created/Modified
- `DictusApp/Onboarding/ModelDownloadPage.swift` - Replaced hardcoded recommendedModel with computed property using ModelInfo.recommendedIdentifier(), data-driven model card, updated download time text and prewarm label

## Decisions Made
- No code changes needed for Parakeet routing (MODEL-07) or display names (MODEL-08) -- both verified correct through code inspection and grep
- MODEL-03 (onboarding reorder), MODEL-04 (full-screen modal), MODEL-06 (mic disabled during compilation) confirmed as removed scope per user decision -- requirement IDs assigned for traceability only

## Deviations from Plan

None -- plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None -- no external service configuration required.

## Next Phase Readiness
- Phase 14 (Model Pipeline) is fully complete
- All MODEL requirements satisfied (MODEL-01 through MODEL-08)
- Ready for Phase 15

---
*Phase: 14-model-pipeline*
*Completed: 2026-03-12*
