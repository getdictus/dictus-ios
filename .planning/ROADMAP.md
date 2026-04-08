# Roadmap: Dictus

**Created:** 2026-03-04
**Granularity:** Coarse

---

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-03-07)
- ✅ **v1.1 UX & Keyboard** — Phases 6-10 (shipped 2026-03-11)
- ✅ **v1.2 Beta Ready** — Phases 11-16 (shipped 2026-03-27)
- ✅ **v1.3 Public Beta** — Phases 17-22 (shipped 2026-04-07)
- ✅ **v1.4 Prediction & Stability** — Phases 23-27 (shipped 2026-04-08)
- **v1.5 Dictus Pro** — Phases 30-33 (in progress)

## Phases

<details>
<summary>v1.0 MVP (Phases 1-5) — SHIPPED 2026-03-07</summary>

- [x] Phase 1: Cross-Process Foundation (4/4 plans) — completed 2026-03-05
- [x] Phase 2: Transcription Pipeline (3/3 plans) — completed 2026-03-06
- [x] Phase 3: Dictation UX (4/4 plans) — completed 2026-03-06
- [x] Phase 4: Main App, Onboarding, and Polish (5/5 plans) — completed 2026-03-07
- [x] Phase 5: Wire Settings & Code Hygiene (2/2 plans) — completed 2026-03-07

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>v1.1 UX & Keyboard (Phases 6-10) — SHIPPED 2026-03-11</summary>

- [x] Phase 6: Infrastructure & App Polish (5/5 plans) — completed 2026-03-07
- [x] Phase 7: Keyboard Parity & Visual (12/12 plans) — completed 2026-03-08
- [x] Phase 8: Text Prediction (2/2 plans) — completed 2026-03-09
- [x] Phase 9: Keyboard Modes (6/6 plans) — completed 2026-03-10
- [x] Phase 10: Model Catalog (4/4 plans) — completed 2026-03-11

Full details: `.planning/milestones/v1.1-ROADMAP.md`

</details>

<details>
<summary>v1.2 Beta Ready (Phases 11-16) — SHIPPED 2026-03-27</summary>

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
<summary>v1.3 Public Beta (Phases 17-22) — SHIPPED 2026-04-07</summary>

- [x] Phase 17: Bug Fixes (2/2 plans) — completed 2026-03-27
- [x] Phase 18: Keyboard Base (3/3 plans) — completed 2026-03-28
- [x] Phase 19: Complex Touch Features (3/3 plans) — completed 2026-03-30
- [x] Phase 20: Feature Reintegration (2/2 plans) — completed 2026-03-30
- [x] Phase 21: Cleanup & Memory Profiling (2/2 plans) — completed 2026-03-31
- [x] Phase 22: Public TestFlight (2/2 plans) — completed 2026-04-07

Full details: `.planning/milestones/v1.3-ROADMAP.md`

</details>

<details>
<summary>v1.4 Prediction & Stability (Phases 23-27) — SHIPPED 2026-04-08</summary>

- [x] Phase 23: Bug Fixes & License Compliance (1/1 plan) — completed 2026-04-01
- [x] Phase 23.1: App Localization Audit (2/2 plans) — completed 2026-04-01 (INSERTED)
- [x] Phase 24: SymSpell Spell Correction (2/2 plans) — completed 2026-04-03
- [x] Phase 24.1: AOSP Trie Spell Correction (3/3 plans) — completed 2026-04-03 (INSERTED)
- [x] Phase 25: N-gram Next-Word Prediction (3/3 plans) — completed 2026-04-05
- [x] Phase 26: Cold Start & Beta Polish (2/2 plans) — completed 2026-04-07
- [x] Phase 27: Critical Audio Bugs & Autocorrect (2/2 plans) — completed 2026-04-07

Full details: `.planning/milestones/v1.4-ROADMAP.md`

</details>

### v1.5 Dictus Pro (In Progress)

**Milestone Goal:** Introduce a premium tier (Open Core model) with Smart Mode LLM reformulation, transcription history, and custom vocabulary — all processing 100% on-device. StoreKit 2 native, no RevenueCat. Single "Dictus Pro" tier (~4-5 EUR/month).

- [ ] **Phase 30: Subscription + Paywall** - StoreKit 2 infrastructure with feature gating, paywall UI, restore purchases, and beta override
- [ ] **Phase 31: Transcription History** - Local journal with GRDB + FTS5, swipe-up access, Pro-gated search/export
- [ ] **Phase 32: Custom Vocabulary** - Personal dictionary injected as WhisperKit initialPrompt for improved recognition of technical/rare terms
- [ ] **Phase 33: Smart Mode LLM** - On-device text reformulation via Apple Foundation Models + mlx-swift fallback, template system (Email/SMS/Notes/Summary)

## Phase Details

### Phase 30: Subscription + Paywall
**Goal**: Users can subscribe to Dictus Pro and access gated features, with a smooth beta experience where everything is free
**Depends on**: Nothing (first phase of v1.5)
**Requirements**: SUB-01, SUB-02, SUB-03, SUB-04, SUB-05, SUB-06, PAY-01, PAY-02, PAY-03, PAY-04, PAY-05, PAY-06
**Success Criteria** (what must be TRUE):
  1. User can tap a locked Pro feature and see a paywall with pricing, benefits, and a subscribe button
  2. User can complete a StoreKit 2 purchase and immediately access Pro features without restarting the app
  3. Keyboard extension reads Pro status from App Group and gates features accordingly (no network needed)
  4. During beta period, all Pro features are unlocked for free with visible "beta" messaging on the paywall
  5. User can restore a previous purchase from the paywall screen
**Plans**: TBD

Plans:
- [ ] 30-01: TBD
- [ ] 30-02: TBD

### Phase 31: Transcription History
**Goal**: Users have a persistent, searchable journal of all their dictations accessible from the home screen
**Depends on**: Phase 30 (history save is free; search/export gated behind Pro via FeatureGate)
**Requirements**: HIST-01, HIST-02, HIST-03, HIST-04, HIST-05, HIST-06, HIST-07, HIST-08, HIST-09, HIST-10, HIST-11
**Success Criteria** (what must be TRUE):
  1. After dictating, the transcription appears automatically in the history list without any user action
  2. User can swipe up from the home screen to browse all past transcriptions in reverse chronological order
  3. User can tap a transcription card to view full text, then copy or share it via the iOS share sheet
  4. Pro user can search across all transcriptions with accent-aware full-text search (e.g. "cafe" finds entries containing "cafe")
  5. User can delete individual transcriptions via swipe or long-press
**Plans**: TBD

Plans:
- [ ] 31-01: TBD
- [ ] 31-02: TBD

### Phase 32: Custom Vocabulary
**Goal**: Users can teach Dictus their personal terminology so speech recognition handles technical and rare words correctly
**Depends on**: Phase 30 (vocabulary feature gated behind Pro via FeatureGate)
**Requirements**: VOCAB-01, VOCAB-02, VOCAB-03, VOCAB-04, VOCAB-05, VOCAB-06, VOCAB-07, VOCAB-08
**Success Criteria** (what must be TRUE):
  1. User can add, edit, and delete custom terms from a vocabulary screen in Settings
  2. User can bulk-import terms by pasting a text list
  3. After adding a term, subsequent dictations recognize that term with improved accuracy
  4. Vocabulary respects the 224-token initialPrompt limit with clear feedback when approaching the cap (~30-40 terms)
**Plans**: TBD

Plans:
- [ ] 32-01: TBD

### Phase 33: Smart Mode LLM
**Goal**: Users can reformulate their dictated text using on-device LLM with pre-configured templates, with no data leaving the phone
**Depends on**: Phase 30 (Smart Mode gated behind Pro), Phase 31 (reformulated text stored in history)
**Requirements**: SMART-01, SMART-02, SMART-03, SMART-04, SMART-05, SMART-06, SMART-07, SMART-08, SMART-09, SMART-10, SMART-11
**Success Criteria** (what must be TRUE):
  1. After dictation, user can select a template (Email, SMS, Notes, Summary) and see their text reformulated
  2. User can keep the original text or accept the reformulated version before it is inserted
  3. On iPhone 15 Pro+ with iOS 26, reformulation uses Apple Foundation Models with no download required
  4. On older compatible devices (6GB+ RAM), user can download an open-source LLM model and use Smart Mode
  5. On incompatible devices (4GB RAM), user sees a clear message explaining why Smart Mode is unavailable
**Plans**: TBD

Plans:
- [ ] 33-01: TBD
- [ ] 33-02: TBD
- [ ] 33-03: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-5 | v1.0 | 18/18 | Complete | 2026-03-07 |
| 6-10 | v1.1 | 29/29 | Complete | 2026-03-11 |
| 11-16 | v1.2 | 35/35 | Complete | 2026-03-27 |
| 17-22 | v1.3 | 14/14 | Complete | 2026-04-07 |
| 23-27 | v1.4 | 15/15 | Complete | 2026-04-08 |
| 30. Subscription + Paywall | v1.5 | 0/? | Not started | - |
| 31. Transcription History | v1.5 | 0/? | Not started | - |
| 32. Custom Vocabulary | v1.5 | 0/? | Not started | - |
| 33. Smart Mode LLM | v1.5 | 0/? | Not started | - |

**Total: 111 plans across 5 milestones + 4 new phases planned**

---
*Roadmap created: 2026-03-04*
*v1.0 shipped: 2026-03-07*
*v1.1 shipped: 2026-03-11*
*v1.2 shipped: 2026-03-27*
*v1.3 shipped: 2026-04-07*
*v1.4 shipped: 2026-04-08*
*v1.5 started: 2026-04-08*
