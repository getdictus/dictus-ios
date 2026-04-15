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
- 🚧 **v1.5 Dictus Pro** — Phases 30-33 (in progress on `feature/premium` worktree)
- 🚧 **v1.7 Stability, Polish & i18n** — Phases 34-39 (in progress)

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

<details>
<summary>✅ v1.4 Prediction & Stability (Phases 23-27) — SHIPPED 2026-04-08</summary>

- [x] Phase 23: Bug Fixes & License Compliance (1/1 plan) — completed 2026-04-01
- [x] Phase 23.1: App Localization Audit (2/2 plans) — completed 2026-04-01 (INSERTED)
- [x] Phase 24: SymSpell Spell Correction (2/2 plans) — completed 2026-04-03
- [x] Phase 24.1: AOSP Trie Spell Correction (3/3 plans) — completed 2026-04-03 (INSERTED)
- [x] Phase 25: N-gram Next-Word Prediction (3/3 plans) — completed 2026-04-05
- [x] Phase 26: Cold Start & Beta Polish (2/2 plans) — completed 2026-04-07
- [x] Phase 27: Critical Audio Bugs & Autocorrect (2/2 plans) — completed 2026-04-07

Full details: `.planning/milestones/v1.4-ROADMAP.md`

</details>

<details open>
<summary>🚧 v1.7 Stability, Polish & i18n (Phases 34-39) — IN PROGRESS</summary>

- [ ] **Phase 34: Silent Insertion Fix** — Transcription text always reaches the target app (STAB-01)
- [ ] **Phase 35: Keyboard Geometry Polish** — Key geometry matches Apple system keyboard, glitch residual eliminated (KBD-01, KBD-02)
- [ ] **Phase 36: Autocorrect v2** — AOSP-aligned unified scoring + personal LM + higher-order n-grams (AUTO-01, AUTO-02, AUTO-03)
- [ ] **Phase 37: Whisper Turbo Retest & Device Gating** — Turbo re-validated and gated per device (STT-01)
- [ ] **Phase 38: i18n Foundation** — Reusable documented process for adding a new language (I18N-01)
- [ ] **Phase 39: German Language Support** — QWERTZ + German STT + German UI, end-to-end validation of i18n process (I18N-02)

</details>

## Phase Details

### Phase 34: Silent Insertion Fix
**Goal**: Transcription text is reliably inserted into the target app every time dictation completes — no silent failures.
**Depends on**: Nothing (hotfix-style, can ship independently)
**Requirements**: STAB-01
**Milestone**: v1.7
**Linked issues**: #118
**Success Criteria** (what must be TRUE):
  1. When dictation ends, the transcribed text appears in the host app's text field on every run — no silent drops across 50 consecutive dictations on a real device.
  2. All known repro scenarios from issue #118 (cold start, warm start, backgrounded keyboard, rapid chained recordings) pass without text loss.
  3. The existing insertion paths (warm insert via Darwin notification, cold start Audio Bridge, chained recording) continue to insert correctly — no regression vs v1.6.
  4. When insertion fails for any reason, the failure is surfaced in logs with enough context (path taken, target doc state, error) to diagnose, instead of failing silently.
**Plans**: TBD

### Phase 35: Keyboard Geometry Polish
**Goal**: The Dictus keyboard matches the visual dimensions and proportions of the Apple system keyboard, and renders correctly on every launch.
**Depends on**: Phase 34 (ship STAB-01 hotfix first so this phase does not block a critical reliability bug)
**Requirements**: KBD-01, KBD-02
**Milestone**: v1.7
**Linked issues**: #117, #116
**Success Criteria** (what must be TRUE):
  1. On every supported device class (small/medium/large iPhones), Dictus key widths, heights, gaps, and padding match the Apple system keyboard within 2pt tolerance — measured via a documented audit vs screenshots of iOS keyboard.
  2. The keyboard layout renders correctly on every launch and layer switch — the residual glitch from v1.6.0-beta.1 (misaligned keys on first appearance) is not reproducible across 30 consecutive cold starts.
  3. Layer transitions (letters ↔ numbers ↔ symbols) keep keys aligned to the audited geometry — no transient shrink or shift.
  4. The audit report (measured vs target for each device class) is committed to the repo so future regressions can be caught.
**Plans**: TBD

### Phase 36: Autocorrect v2
**Goal**: Autocorrect quality matches the AOSP LatinIME baseline — unified scoring, personal vocabulary adaptation, and contextual n-gram disambiguation.
**Depends on**: Phase 35 (keyboard geometry stable so touch input feeds reliable keystream into autocorrect)
**Requirements**: AUTO-01, AUTO-02, AUTO-03
**Milestone**: v1.7
**Linked issues**: #114
**Success Criteria** (what must be TRUE):
  1. When the user types a misspelling, the top suggestion is ranked by a single unified score combining edit distance, keyboard proximity, n-gram probability, and personal LM weight — not by any single signal in isolation.
  2. Words the user types repeatedly (names, jargon, personal vocabulary) start appearing as top suggestions within the same session — the personal LM visibly biases future suggestions toward the user's own vocabulary.
  3. Contextually ambiguous corrections (e.g. "ces" vs "ses", "a" vs "à") are resolved correctly using trigram (with bigram/unigram fallback) context from preceding words.
  4. A regression suite of French autocorrect cases (curated from real user samples) scores at or above the current v1.6 baseline on precision and recall — no quality regression while gaining personalization.
**Plans**: TBD

### Phase 37: Whisper Turbo Retest & Device Gating
**Goal**: Whisper Turbo is validated on current target devices and only offered to users whose device can actually run it well.
**Depends on**: Nothing (independent of keyboard/autocorrect work, can run in parallel if desired but scheduled sequentially per coarse granularity)
**Requirements**: STT-01
**Milestone**: v1.7
**Linked issues**: #104
**Success Criteria** (what must be TRUE):
  1. Whisper Turbo has been re-tested on the current supported device matrix (iPhone 12 through latest) with measured transcription latency and peak RAM recorded.
  2. The model catalog gates Turbo availability per-device — devices that fail the latency/RAM bar do not see Turbo as a selectable option in Settings.
  3. On devices that pass the gate, selecting Turbo produces a stable dictation experience (no OOM, no thermal throttle within a 30s recording) across 10 test dictations.
  4. The gating decision is documented (thresholds, test methodology, per-device verdict) so it can be re-evaluated as iOS and WhisperKit evolve.
**Plans**: TBD

### Phase 38: i18n Foundation
**Goal**: Adding a new language to Dictus is a documented, repeatable process with tooling — not ad-hoc engineering.
**Depends on**: Nothing (pure process/tooling work, independent of other v1.7 phases)
**Requirements**: I18N-01
**Milestone**: v1.7
**Linked issues**: #110
**Success Criteria** (what must be TRUE):
  1. A single documented runbook exists in the repo covering every step to add a language: WhisperKit model wiring, keyboard layout integration, UI string catalog entries, autocorrect dictionary generation, n-gram data generation, and onboarding screens.
  2. Automation scripts for dictionary generation and n-gram training run end-to-end from a corpus input to binary artifacts without manual intervention — verified by running them clean on at least one language corpus.
  3. The runbook defines checkpoints and validation gates (e.g. "dictionary contains >N entries", "keyboard renders on 3 device classes", "onboarding strings have no missing keys") so a new language cannot ship partially integrated.
  4. The process is testable by a developer other than the author — an independent dev can follow the runbook and reach a working language build without blocking questions.
**Plans**: TBD

### Phase 39: German Language Support
**Goal**: A German-speaking user can install Dictus, complete onboarding in German, dictate in German, and type in German with a proper QWERTZ keyboard and German autocorrect — proving the i18n process works end-to-end.
**Depends on**: Phase 38 (German is the first user of the I18N-01 process)
**Requirements**: I18N-02
**Milestone**: v1.7
**Linked issues**: #109
**Success Criteria** (what must be TRUE):
  1. When the device language is German (or the user selects German in Dictus settings), the full onboarding flow — permissions, keyboard setup, model download, test dictation — runs in German with all strings translated and rendered correctly.
  2. A German user can type on a QWERTZ keyboard layout (with correct umlauts via long-press, sharp-s ß key placement) with no dead zones and with autocorrect producing German-appropriate suggestions from a German dictionary and German n-gram data.
  3. A German user can dictate a sentence in German using a multilingual Whisper model and see accurate German transcription inserted into the host app.
  4. The German build was produced by following the Phase 38 runbook without needing process modifications — any deviations are logged back as amendments to the runbook, closing the loop on I18N-01.
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-5 | v1.0 | 18/18 | Complete | 2026-03-07 |
| 6-10 | v1.1 | 29/29 | Complete | 2026-03-11 |
| 11-16 | v1.2 | 35/35 | Complete | 2026-03-27 |
| 17-22 | v1.3 | 14/14 | Complete | 2026-04-07 |
| 23-27 | v1.4 | 15/15 | Complete | 2026-04-08 |
| 34 | v1.7 | 0/? | Not started | - |
| 35 | v1.7 | 0/? | Not started | - |
| 36 | v1.7 | 0/? | Not started | - |
| 37 | v1.7 | 0/? | Not started | - |
| 38 | v1.7 | 0/? | Not started | - |
| 39 | v1.7 | 0/? | Not started | - |

**Total: 111 plans across 5 shipped milestones + v1.7 in progress**

---
*Roadmap created: 2026-03-04*
*v1.0 shipped: 2026-03-07*
*v1.1 shipped: 2026-03-11*
*v1.2 shipped: 2026-03-27*
*v1.3 shipped: 2026-04-07*
*v1.4 shipped: 2026-04-08*
*v1.7 milestone started: 2026-04-15*
