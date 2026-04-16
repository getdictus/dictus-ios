# Phase 34 Deferred Items

Tracks pre-existing issues discovered during Phase 34 execution that are out of scope for STAB-01 (silent insertion fix).

## Pre-existing DictusCore test failures (discovered during Plan 34-01)

The following 10 tests were already failing on `develop` BEFORE any Phase 34 changes were applied. They are unrelated to the insertion-failure fix (STAB-01) and must not be fixed inside this phase:

### AccentedCharacterTests (4 failures)

- `testAMapsTo3AccentedVariants` — expects 3 variants, actual 4 (`á` added)
- `testIMapsTo2Variants` — expects 2 variants, actual 3 (`í` added)
- `testOMapsTo2Variants` — expects 2 variants, actual 3 (`ó` added)
- `testUMapsTo3Variants` — expects 3 variants, actual 4 (`ú` added)

**Root cause:** The accented-variants table was extended (4th accent option) but test expectations were not updated.

### FrequencyDictionaryTests (2 failures)

- `testLoadFromInvalidDataProducesEmptyDict` — expects rank `Int.max` (9223372036854775807), returns `0`
- `testRankReturnsIntMaxForUnknownWord` — same mismatch

**Root cause:** Semantic change to `rank(for:)` — it now returns `0` for unknown words where tests expect `Int.max`.

### Other failures (unverified in detail)

The full run reported 10 failures total; only the 6 above were inspected. The remaining 4 are almost certainly in the same files (other tests asserting the same stale expectations).

## Why deferred

Per `<deviation_rules>` SCOPE BOUNDARY: "Only auto-fix issues DIRECTLY caused by the current task's changes. Pre-existing warnings, linting errors, or failures in unrelated files are out of scope."

Plan 34-01 does not touch `AccentedCharacters.swift`, `FrequencyDictionary.swift`, or their tests. Fixing them would inflate the scope and risk breaking the dictation/keyboard code outside STAB-01.

## Suggested follow-up

Open a separate issue `chore: fix stale DictusCore test expectations (accented variants + rank)`. Attach to milestone v1.7 cleanup. Low risk, no dictation impact.
