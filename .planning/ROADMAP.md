# Roadmap: Dictus

**Created:** 2026-03-04
**Granularity:** Coarse

---

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-03-07)
- ✅ **v1.1 UX & Keyboard** — Phases 6-10 (shipped 2026-03-11)
- ✅ **v1.2 Beta Ready** — Phases 11-16 (shipped 2026-03-27)
- 🚧 **v1.3 Public Beta** — Phases 17-22 (in progress)
- 📋 **v1.4 Prediction & Stability** — Phases 23-26 (planned)

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
<summary>🚧 v1.3 Public Beta (Phases 17-22) — IN PROGRESS</summary>

- [x] Phase 17: Bug Fixes (2/2 plans) — completed 2026-03-27
- [x] Phase 18: Keyboard Base (3/3 plans) — completed 2026-03-28
- [x] Phase 19: Complex Touch Features (3/3 plans) — completed 2026-03-30
- [x] Phase 20: Feature Reintegration (2/2 plans) — completed 2026-03-30
- [x] Phase 21: Cleanup & Memory Profiling (2/2 plans) — completed 2026-03-31
- [ ] Phase 22: Public TestFlight (1/2 plans) — in progress

Full details: see Phase Details below (v1.3 phases 17-22)

</details>

### v1.4 Prediction & Stability (Planned)

**Milestone Goal:** Upgrade the text prediction engine with probability-based suggestions (SymSpell + n-gram), fix known bugs, and stabilize based on beta feedback.

- [ ] **Phase 23: Bug Fixes & License Compliance** — Fix autocorrect undo race condition, update licenses and Parakeet attribution
- [ ] **Phase 24: SymSpell Spell Correction** — Expand dictionaries, vendor SymSpell, replace UITextChecker for frequency-ranked corrections
- [ ] **Phase 25: N-gram Next-Word Prediction** — Build trigram data pipeline, integrate NgramPredictor, wire next-word suggestions into UI
- [ ] **Phase 26: Cold Start & Beta Polish** — Time-boxed cold start auto-return investigation, beta feedback triage

## Phase Details

<details>
<summary>v1.3 Phase Details (Phases 17-22)</summary>

### Phase 17: Bug Fixes
**Goal**: Known v1.2 beta bugs are fixed before the keyboard architecture change
**Depends on**: Phase 16 (v1.2 shipped)
**Requirements**: FIX-01, FIX-02
**Success Criteria** (what must be TRUE):
  1. Dynamic Island never gets stuck on REC state after recording ends or is cancelled
  2. Export logs completes within a few seconds and shows a spinner during export
**Plans**: 2 plans
Plans:
- [x] 17-01-PLAN.md — Dynamic Island watchdog + state machine extraction + unit tests (FIX-01)
- [x] 17-02-PLAN.md — Export logs optimization + 7-day retention + spinner UX (FIX-02)

### Phase 18: Keyboard Base
**Goal**: Users can type on a UICollectionView-based keyboard with zero dead zones, haptic feedback, key sounds, and key popup -- feels like a real keyboard from day one
**Depends on**: Phase 17
**Requirements**: KBD-01, KBD-02, KBD-03, KBD-04, KBD-06, KBD-07, KBD-08, FEEL-01, FEEL-02, FEEL-03
**Success Criteria** (what must be TRUE):
  1. User can type any character on the AZERTY keyboard with no dead zones anywhere on the key grid
  2. User can switch to QWERTY layout and type with the same zero-dead-zone behavior
  3. User can toggle shift (single tap) and caps lock (double tap) with visual state changes on keys
  4. User can switch between letters, numbers, and symbols layers
  5. User gets autocapitalization after sentence-ending punctuation and double-space period insertion
  6. User feels haptic feedback on touchDown and hears 3-category key sounds respecting silent switch
  7. User sees key popup preview on press (provided by giellakbd-ios)
**Plans**: 3 plans
Plans:
- [x] 18-01-PLAN.md — Vendor giellakbd-ios files, strip dependencies, add DeviceKit, create French layouts
- [x] 18-02-PLAN.md — Create keyboard bridge, adapt KeyboardViewController for UIKit keyboard + SwiftUI toolbar
- [x] 18-03-PLAN.md — Autocapitalization, double-space period, shift state machine, user verification

### Phase 19: Complex Touch Features
**Goal**: Users have access to all advanced touch interactions -- delete repeat, spacebar trackpad, accent selection, and adaptive accent key
**Depends on**: Phase 18
**Requirements**: KBD-05, KBD-08, FEEL-04, FEEL-05, FEEL-06
**Success Criteria** (what must be TRUE):
  1. User can hold backspace and characters delete with accelerating repeat speed
  2. User can long-press vowels to see French accent characters and drag to select one
  3. User can drag the spacebar to move the cursor with haptic ticks at each character position
  4. User sees adaptive accent key that shows apostrophe after consonants and accent after vowels
  5. Double-space inserts a period followed by a space (iOS native behavior)
  6. Edge keys (a, q, p, m, etc.) produce haptic feedback and popup on touchDown, not touchUp
**Plans**: 3 plans
Plans:
- [x] 19-01-PLAN.md — Wire accent data, fix double-space period, fix edge key touchDown with nearest-cell fallback
- [x] 19-02-PLAN.md — Delete repeat with acceleration and spacebar trackpad cursor movement
- [x] 19-03-PLAN.md — Adaptive accent key in AZERTY layout and full device verification

### Phase 20: Feature Reintegration
**Goal**: All Dictus-specific features work on the new UIKit keyboard -- dictation, text prediction, suggestions, and settings
**Depends on**: Phase 19
**Requirements**: DICT-01, DICT-02, DICT-03, DICT-04, PRED-01, PRED-02, PRED-03, SET-01
**Success Criteria** (what must be TRUE):
  1. User can tap mic button in toolbar to start recording and sees the recording overlay with waveform replacing the keyboard
  2. User gets transcription auto-inserted at cursor after recording completes
  3. User sees Full Access banner when permissions are needed for microphone access
  4. User sees 3-slot suggestion bar with French autocorrect, can tap to insert, and can undo autocorrect with backspace
  5. User can select default opening layer (letters or numbers) in settings with live preview
**Plans**: 2 plans
Plans:
- [x] 20-01-PLAN.md — Wire text prediction into bridge, autocorrect, emoji key layout, default layer setting
- [x] 20-02-PLAN.md — Emoji picker UI integration, post-transcription suggestion refresh, full UAT

### Phase 21: Cleanup & Memory Profiling
**Goal**: Old SwiftUI keyboard code is removed, memory budget is verified on device, and the keyboard is instrumented for performance monitoring
**Depends on**: Phase 20
**Requirements**: None (quality gate -- no feature requirements, but blocks public beta)
**Success Criteria** (what must be TRUE):
  1. All old SwiftUI keyboard files (KeyButton, KeyRow, KeyboardView, SpecialKeyButton, AccentPopup) are deleted from the project
  2. Keyboard extension memory usage stays under 50MB during all operations (typing, dictation, prediction) on a real device
  3. OSSignposter instrumentation is in place for key touch-to-character latency measurement
**Plans**: 2 plans
Plans:
- [x] 21-01-PLAN.md — Extract LegacyCompat types, delete old SwiftUI files, clean pbxproj
- [x] 21-02-PLAN.md — Memory profiling on device, leak check, signposter verification, report

### Phase 22: Public TestFlight
**Goal**: Dictus is available as a public TestFlight beta that anyone can install
**Depends on**: Phase 21
**Requirements**: TF-01, TF-02, TF-03, TF-04
**Success Criteria** (what must be TRUE):
  1. App passes Beta App Review with complete Privacy Manifests and Full Access justification
  2. External testing group exists in App Store Connect and public TestFlight link is active
  3. README on GitHub includes the public TestFlight link with install instructions
**Plans**: 2 plans
Plans:
- [x] 22-01-PLAN.md — Fix emoji picker memory blocker (139 MiB -> <50 MiB) via category pagination
- [ ] 22-02-PLAN.md — Privacy manifests, version bump, Beta App Review submission, README + GitHub Release

</details>

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
| 22. Public TestFlight | 2/2 | Complete    | 2026-04-07 | - |
| 23. Bug Fixes & License Compliance | 1/1 | Complete    | 2026-04-01 | - |
| 24. SymSpell Spell Correction | 2/2 | Complete    | 2026-04-03 | - |
| 24.1. AOSP Trie Spell Correction | 3/3 | Complete    | 2026-04-03 | - |
| 25. N-gram Next-Word Prediction | 3/3 | Complete    | 2026-04-05 | - |
| 26. Cold Start & Beta Polish | 2/2 | Complete   | 2026-04-07 | - |
| 27. Critical Audio Bugs & Autocorrect | 2/2 | Complete   | 2026-04-07 | - |

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
*v1.3 started: 2026-03-27*
*v1.4 roadmap: 2026-04-01*
