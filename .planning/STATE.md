---
gsd_state_version: 1.0
milestone: v1.3
milestone_name: Public Beta
status: executing
stopped_at: Completed 25-02-PLAN.md
last_updated: "2026-04-03T13:16:40.440Z"
last_activity: 2026-04-03 — Completed 25-02-PLAN.md (Swift integration and prediction pipeline)
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 11
  completed_plans: 10
  percent: 91
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-01)

**Core value:** A user can dictate text in French in any iOS app and correct it immediately on the same keyboard -- no subscription, no cloud, no account.
**Current focus:** Phase 25 in progress -- N-gram next-word prediction (plan 1/3 complete)

## Current Position

Phase: 25 of 26 (N-gram Next-Word Prediction)
Plan: 2 of 3 in current phase (COMPLETE)
Status: In Progress
Last activity: 2026-04-03 — Completed 25-02-PLAN.md (Swift integration and prediction pipeline)

Progress: [█████████░] 91% (v1.4 milestone: 10/11 plans)

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
- [Phase 23.1]: English source strings with auto-generated keys for String Catalog localization
- [Phase 23.1]: Added Open Settings link localization not listed in plan (Rule 2 auto-fix)
- [Phase 24]: Dictionary format changed from ranks to counts (higher=better) to align with SymSpell
- [Phase 24]: French frequency: 70% film subtitles + 30% books for natural spoken weighting
- [Phase 24]: SymSpellSwift vendored as-is, no modifications needed for Swift 5.9+
- [Phase 24.1]: DTRI binary format with patricia compression for spell correction dictionaries (~0.4 MiB per language)
- [Phase 24.1]: Vendored C++ engine in DictusKeyboard/Vendored/AOSPTrie/ with mmap-based read-only access
- [Phase 24.1]: ObjC++ bridge pattern: pure ObjC header + .mm implementation for C++ to Swift interop in keyboard extension
- [Phase 24.1]: Used 'compiled' file type for .dict binary resources to prevent Xcode CopyPlistFile processing
- [Phase 24.1]: Two-pass spell check: user dictionary words bypass trie lookup entirely
- [Phase 24.1]: BFS serialization order for trie binary (not DFS) -- DFS caused segfaults due to non-contiguous child offsets
- [Phase 24.1]: root_child_count added to binary header for correct C++ traversal from root node
- [Phase 25]: NGRM binary format: 32-byte header + sorted variable-length entries with FNV-1a key hashes + packed string table
- [Phase 25]: Index-based binary search: build (hash, pointer) vector at load time for O(log n) lookup on variable-length entries
- [Phase 25]: Google Books Ngram data from orgtre/google-books-ngram-frequency repo (ngrams/ subdirectory)
- [Phase 25]: Stupid Backoff with lambda=0.4: trigram results + discounted bigram fallback
- [Phase 25]: Swift ObjC bridge auto-renames predictAfterWord to predict(afterWord:) -- use generated names
- [Phase 25]: Bridge reference passed to KeyboardRootView for prediction tap access

### Pending Todos

None.

### Roadmap Evolution

- Phase 23.1 inserted after Phase 23: App Localization Audit & Fix — ensure all UI strings use NSLocalizedString and app respects device language (URGENT)
- Phase 24.1 inserted after Phase 24: Replace SymSpell with AOSP-style compressed trie (C++ with Swift interop) for spell correction (URGENT)

### Blockers/Concerns

- Phase 22 (Public TestFlight) still in progress -- Phase 23 depends on it completing
- SymSpell memory on physical device needs empirical validation (estimates: 3-5MB for 30K words)
- French tokenization for n-gram elisions (l'homme, aujourd'hui) needs custom tokenizer

## Session Continuity

Last session: 2026-04-03T13:16:40.438Z
Stopped at: Completed 25-02-PLAN.md
Resume file: .planning/phases/25-n-gram-next-word-prediction/25-03-PLAN.md

---
*State initialized: 2026-03-04*
*v1.0 shipped: 2026-03-07*
*v1.1 shipped: 2026-03-11*
*v1.2 shipped: 2026-03-27*
*v1.3 roadmap: 2026-03-27*
*v1.4 roadmap: 2026-04-01*
