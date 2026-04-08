# Roadmap: Dictus

**Created:** 2026-03-04
**Granularity:** Coarse

---

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-03-07)
- ✅ **v1.1 UX & Keyboard** — Phases 6-10 (shipped 2026-03-11)
- ✅ **v1.2 Beta Ready** — Phases 11-16 (shipped 2026-03-27)
- ✅ **v1.3 Public Beta** — Phases 17-22 (shipped 2026-04-07)
- 🚧 **v1.4 Prediction & Stability** — Phases 23-27 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-5) — SHIPPED 2026-03-07</summary>

- [x] Phase 1: Cross-Process Foundation (4/4 plans) — completed 2026-03-05
- [x] Phase 2: Transcription Pipeline (3/3 plans) — completed 2026-03-06
- [x] Phase 3: Dictation UX (4/4 plans) — completed 2026-03-06
- [x] Phase 4: Main App, Onboarding, and Polish (5/5 plans) — completed 2026-03-07
- [x] Phase 5: Wire Settings & Code Hygiene (2/2 plans) — completed 2026-03-07

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>✅ v1.1 UX & Keyboard (Phases 6-10) — SHIPPED 2026-03-11</summary>

- [x] Phase 6: Infrastructure & App Polish (5/5 plans) — completed 2026-03-07
- [x] Phase 7: Keyboard Parity & Visual (12/12 plans) — completed 2026-03-08
- [x] Phase 8: Text Prediction (2/2 plans) — completed 2026-03-09
- [x] Phase 9: Keyboard Modes (6/6 plans) — completed 2026-03-10
- [x] Phase 10: Model Catalog (4/4 plans) — completed 2026-03-11

Full details: `.planning/milestones/v1.1-ROADMAP.md`

</details>

<details>
<summary>✅ v1.2 Beta Ready (Phases 11-16) — SHIPPED 2026-03-27</summary>

- [x] Phase 11: Logging Foundation (2/2 plans) — completed 2026-03-11
- [x] Phase 12: Animation State Fixes (2/2 plans) — completed 2026-03-12
- [x] Phase 13: Cold Start Audio Bridge (3/3 plans) — completed 2026-03-12
- [x] Phase 14: Model Pipeline (4/4 plans) — completed 2026-03-12
- [x] Phase 15: Design Polish (10/10 plans) — completed 2026-03-13
- [x] Phase 15.1: UI Polish Fixes (3/3 plans) — completed 2026-03-13 (INSERTED)
- [x] Phase 15.2: Cleaning & Fix GitHub Issues (4/4 plans) — completed 2026-03-17 (INSERTED)
- [x] Phase 15.3: Keyboard Optimization (4/4 plans) — completed 2026-03-24 (INSERTED)
- [x] Phase 16: TestFlight Deployment (3/3 plans) — completed 2026-03-27

Full details: `.planning/milestones/v1.2-ROADMAP.md`

</details>

<details>
<summary>✅ v1.3 Public Beta (Phases 17-22) — SHIPPED 2026-04-07</summary>

- [x] Phase 17: Bug Fixes (2/2 plans) — completed 2026-03-27
- [x] Phase 18: Keyboard Base (3/3 plans) — completed 2026-03-28
- [x] Phase 19: Complex Touch Features (3/3 plans) — completed 2026-03-30
- [x] Phase 20: Feature Reintegration (2/2 plans) — completed 2026-03-30
- [x] Phase 21: Cleanup & Memory Profiling (2/2 plans) — completed 2026-03-31
- [x] Phase 22: Public TestFlight (2/2 plans) — completed 2026-04-07

Full details: `.planning/milestones/v1.3-ROADMAP.md`

</details>

### v1.4 Prediction & Stability (In Progress)

**Milestone Goal:** Upgrade the text prediction engine with probability-based suggestions (SymSpell + n-gram), fix known bugs, and stabilize based on beta feedback.

- [ ] **Phase 23: Bug Fixes & License Compliance** — Fix autocorrect undo race condition, update licenses and Parakeet attribution
- [ ] **Phase 24: SymSpell Spell Correction** — Expand dictionaries, vendor SymSpell, replace UITextChecker for frequency-ranked corrections
- [ ] **Phase 25: N-gram Next-Word Prediction** — Build trigram data pipeline, integrate NgramPredictor, wire next-word suggestions into UI
- [ ] **Phase 26: Cold Start & Beta Polish** — Time-boxed cold start auto-return investigation, beta feedback triage

## Phase Details

### Phase 23: Bug Fixes & License Compliance
**Goal**: Known bugs are fixed and license compliance is complete before any prediction engine changes
**Depends on**: Phase 22
**Requirements**: FIX-01, FIX-02, FIX-03
**Success Criteria** (what must be TRUE):
  1. User can type new characters after an autocorrect, then press backspace, and the backspace deletes the last typed character (not undo the earlier autocorrect)
  2. User can tap "Licenses" in Settings and sees a link pointing to getdictus/dictus-ios repository
  3. User can see Parakeet/NVIDIA attribution listed on the licenses screen alongside existing credits
**Plans**: 1 plan

Plans:
- [ ] 23-01-PLAN.md — Fix autocorrect undo race condition + complete license attribution (FIX-01, FIX-02, FIX-03)

### Phase 23.1: App Localization Audit & Fix — ensure all UI strings use NSLocalizedString and app respects device language (INSERTED)

**Goal:** All UI strings use iOS String Catalogs with English as development language and French translations; app respects device language automatically
**Requirements**: L10N-01, L10N-02, L10N-03, L10N-04, L10N-05, L10N-06
**Depends on:** Phase 23
**Plans:** 2/2 plans complete

Plans:
- [ ] 23.1-01-PLAN.md — DictusApp localization: project config, string replacement, String Catalog, ModelInfo extension (L10N-01 through L10N-05)
- [ ] 23.1-02-PLAN.md — DictusKeyboard localization: string replacement, String Catalog, human verification (L10N-01, L10N-02, L10N-06)

### Phase 24: SymSpell Spell Correction
**Goal**: Users get frequency-ranked spell corrections that match their intent instead of alphabetical guesses
**Depends on**: Phase 23
**Requirements**: PRED-01, PRED-02, PRED-03
**Success Criteria** (what must be TRUE):
  1. User types a misspelled French word (e.g. "helo") and the suggestion bar shows the most common correct word first (e.g. "hello"), not an alphabetical guess
  2. User types a word missing an accent (e.g. "cafe") and the suggestion bar offers the accented form ("cafe") as the top correction
  3. User switches language to English and gets English spell corrections from the expanded English dictionary
  4. Keyboard extension memory stays under 50MB with SymSpell dictionaries loaded (verified on physical device)
**Plans**: 2 plans

Plans:
- [ ] 24-01-PLAN.md — Curate FR/EN frequency dictionaries (30-50K words), vendor SymSpellSwift, create SymSpellEngine wrapper (PRED-01, PRED-02)
- [ ] 24-02-PLAN.md — Wire SymSpell into prediction pipeline, suggestion bar reorder, autocorrect rejection, remove accent suggestions, device verification (PRED-03)

### Phase 24.1: Replace SymSpell with AOSP-style compressed trie (C++ with Swift interop) for spell correction (INSERTED)

**Goal:** Users get production-grade spell corrections from a compressed patricia trie (C++ with ObjC++ bridge) that supports 100K+ words, edit distance 2, keyboard proximity scoring, and accent-aware costs -- all within ~3-5 MiB via mmap
**Requirements**: PRED-03
**Depends on:** Phase 24
**Success Criteria** (what must be TRUE):
  1. User types a misspelled French word and gets frequency-ranked correction with keyboard proximity scoring
  2. User types a word missing an accent and gets the accented form as top correction
  3. Keyboard extension memory stays under 50MB with trie dictionaries loaded
  4. SymSpell code is fully removed and replaced by AOSP trie engine
**Plans:** 3/3 plans complete

Plans:
- [x] 24.1-01-PLAN.md — Python dict-builder + C++ trie reader, scorer, proximity maps (PRED-03)
- [x] 24.1-02-PLAN.md — ObjC++ bridge, bridging header, Swift AOSPTrieEngine, Xcode project config (PRED-03)
- [x] 24.1-03-PLAN.md — Wire into TextPredictionEngine, remove SymSpell, device verification (PRED-03)

### Phase 25: N-gram Next-Word Prediction
**Goal**: Users see contextual next-word suggestions after completing a word, and all prediction stays fast and within memory budget
**Depends on**: Phase 24
**Requirements**: PRED-04, PRED-05, PRED-06
**Success Criteria** (what must be TRUE):
  1. User completes a word and presses space -- the suggestion bar shows 3 predicted next words based on previous context (e.g. "Je" + space shows "suis", "ne", "vais")
  2. User taps a predicted word and it inserts with a trailing space, then the suggestion bar refreshes with new predictions based on the updated context (chained prediction)
  3. Typing any character produces a suggestion update within 10ms with no visible lag or dropped frames
  4. Total prediction memory (AOSP trie dictionaries + n-gram data) stays under 20MB per language on a physical device
**Plans**: 3 plans

Plans:
- [ ] 25-01-PLAN.md — Python ngram_builder.py + C++ NgramEngine (mmap, binary search, Stupid Backoff) + FR/EN n-gram binaries (PRED-04, PRED-06)
- [ ] 25-02-PLAN.md — ObjC++ bridge n-gram methods + Swift integration + SuggestionState .predictions mode + keyboard wiring (PRED-04, PRED-05)
- [ ] 25-03-PLAN.md — N-gram context-boosted spell corrections + device verification checkpoint (PRED-04, PRED-05, PRED-06)

### Phase 26: Cold Start & Beta Polish
**Goal**: Cold start UX is investigated and improved if viable, and critical beta feedback is addressed
**Depends on**: Phase 25
**Requirements**: COLD-01, COLD-02, COLD-03, BETA-01
**Success Criteria** (what must be TRUE):
  1. sourceApplication investigation is complete (2h timebox) with a documented conclusion on feasibility
  2. If auto-return is viable: user returns to their source app automatically after cold start dictation completes
  3. If auto-return is not viable: swipe-back overlay shows improved guidance (e.g. app name if sourceApplication returns it)
  4. Critical bugs reported by public beta testers are triaged with fixes shipped or issues filed
**Plans**: 2 plans

Plans:
- [ ] 26-01-PLAN.md — sourceApplication investigation (2h timebox), ADR documentation, GitHub issue #23 update (COLD-01, COLD-02)
- [ ] 26-02-PLAN.md — Wispr Flow-style overlay redesign with gesture teaching + localization + beta bug triage (COLD-03, BETA-01)

## Progress

**Execution Order:**
Phases execute in numeric order: 23 -> 23.1 -> 24 -> 24.1 -> 25 -> 26 -> 27

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Cross-Process Foundation | v1.0 | 4/4 | Complete | 2026-03-05 |
| 2. Transcription Pipeline | v1.0 | 3/3 | Complete | 2026-03-06 |
| 3. Dictation UX | v1.0 | 4/4 | Complete | 2026-03-06 |
| 4. Main App & Polish | v1.0 | 5/5 | Complete | 2026-03-07 |
| 5. Wire Settings & Hygiene | v1.0 | 2/2 | Complete | 2026-03-07 |
| 6. Infrastructure & App Polish | v1.1 | 5/5 | Complete | 2026-03-07 |
| 7. Keyboard Parity & Visual | v1.1 | 12/12 | Complete | 2026-03-08 |
| 8. Text Prediction | v1.1 | 2/2 | Complete | 2026-03-09 |
| 9. Keyboard Modes | v1.1 | 6/6 | Complete | 2026-03-10 |
| 10. Model Catalog | v1.1 | 4/4 | Complete | 2026-03-11 |
| 11. Logging Foundation | v1.2 | 2/2 | Complete | 2026-03-11 |
| 12. Animation State Fixes | v1.2 | 2/2 | Complete | 2026-03-12 |
| 13. Cold Start Audio Bridge | v1.2 | 3/3 | Complete | 2026-03-12 |
| 14. Model Pipeline | v1.2 | 4/4 | Complete | 2026-03-12 |
| 15. Design Polish | v1.2 | 10/10 | Complete | 2026-03-13 |
| 15.1. UI Polish Fixes | v1.2 | 3/3 | Complete | 2026-03-13 |
| 15.2. Cleaning & Fix Issues | v1.2 | 4/4 | Complete | 2026-03-17 |
| 15.3. Keyboard Optimization | v1.2 | 4/4 | Complete | 2026-03-24 |
| 16. TestFlight Deployment | v1.2 | 3/3 | Complete | 2026-03-27 |
| 17. Bug Fixes | v1.3 | 2/2 | Complete | 2026-03-27 |
| 18. Keyboard Base | v1.3 | 3/3 | Complete | 2026-03-28 |
| 19. Complex Touch Features | v1.3 | 3/3 | Complete | 2026-03-30 |
| 20. Feature Reintegration | v1.3 | 2/2 | Complete | 2026-03-30 |
| 21. Cleanup & Memory Profiling | v1.3 | 2/2 | Complete | 2026-03-31 |
| 22. Public TestFlight | v1.3 | 2/2 | Complete | 2026-04-07 |
| 23. Bug Fixes & License Compliance | v1.4 | 1/1 | Complete | 2026-04-01 |
| 23.1. App Localization Audit | v1.4 | 2/2 | Complete | 2026-04-01 |
| 24. SymSpell Spell Correction | v1.4 | 2/2 | Complete | 2026-04-03 |
| 24.1. AOSP Trie Spell Correction | v1.4 | 3/3 | Complete | 2026-04-03 |
| 25. N-gram Next-Word Prediction | v1.4 | 3/3 | Complete | 2026-04-05 |
| 26. Cold Start & Beta Polish | v1.4 | 2/2 | Complete | 2026-04-07 |
| 27. Critical Audio Bugs & Autocorrect | v1.4 | 2/2 | Complete | 2026-04-07 |

### Phase 27: Critical audio bugs & autocorrect fix: crash during phone call (#71), AirPods audio session conflicts (#72), and N-gram autocorrection on numeric tokens (#74)

**Goal:** Three beta-reported bugs are fixed: no crash when starting dictation during a phone call, AirPods/media apps resume normally after recording, and numeric tokens are never autocorrected
**Requirements**: BUG-71, BUG-72, BUG-74
**Depends on:** Phase 26
**Success Criteria** (what must be TRUE):
  1. Starting dictation during a phone call shows "Recording unavailable during a call" instead of crashing
  2. After recording completes, other apps (Spotify, YouTube) resume playback on AirPods
  3. Typing "test123" + space does not autocorrect the token
**Plans:** 2/2 plans complete

Plans:
- [ ] 27-01-PLAN.md — Call state detection (CXCallObserver) + audio session idle deactivation (BUG-71, BUG-72)
- [ ] 27-02-PLAN.md — Numeric token guard in autocorrect and suggestion paths (BUG-74)

---
*Roadmap created: 2026-03-04*
*v1.0 shipped: 2026-03-07*
*v1.1 shipped: 2026-03-11*
*v1.2 shipped: 2026-03-27*
*v1.3 shipped: 2026-04-07*
*v1.4 started: 2026-04-01*
