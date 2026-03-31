# Roadmap: Dictus

**Created:** 2026-03-04
**Granularity:** Coarse

---

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-03-07)
- ✅ **v1.1 UX & Keyboard** — Phases 6-10 (shipped 2026-03-11)
- ✅ **v1.2 Beta Ready** — Phases 11-16 (shipped 2026-03-27)
- 🚧 **v1.3 Public Beta** — Phases 17-22 (in progress)

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

### 🚧 v1.3 Public Beta (In Progress)

**Milestone Goal:** Rebuild keyboard from scratch using giellakbd-ios (UICollectionView, zero dead zones), fix beta bugs, and open public TestFlight.

- [x] **Phase 17: Bug Fixes** — Fix Dynamic Island REC desync and export logs performance before architecture change (completed 2026-03-27)
- [x] **Phase 18: Keyboard Base** — Vendor giellakbd-ios, AZERTY/QWERTY with zero dead zones, haptics, sounds, key popup (completed 2026-03-28)
- [x] **Phase 19: Complex Touch Features** — Delete repeat, spacebar trackpad, accent long-press, adaptive accent, edge key touch fix, double-space period fix (completed 2026-03-30)
- [x] **Phase 20: Feature Reintegration** — Reconnect dictation, text prediction, suggestions, and settings (completed 2026-03-30)
- [x] **Phase 21: Cleanup & Memory Profiling** — Delete old SwiftUI keyboard, verify memory budget, instrument (completed 2026-03-31)
- [ ] **Phase 22: Public TestFlight** — Beta App Review, external group, public link, README update

## Phase Details

### Phase 17: Bug Fixes
**Goal**: Known v1.2 beta bugs are fixed before the keyboard architecture change
**Depends on**: Phase 16 (v1.2 shipped)
**Requirements**: FIX-01, FIX-02
**Success Criteria** (what must be TRUE):
  1. Dynamic Island never gets stuck on REC state after recording ends or is cancelled
  2. Export logs completes within a few seconds and shows a spinner during export
**Plans**: 2 plans
Plans:
- [ ] 17-01-PLAN.md — Dynamic Island watchdog + state machine extraction + unit tests (FIX-01)
- [ ] 17-02-PLAN.md — Export logs optimization + 7-day retention + spinner UX (FIX-02)

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
- [ ] 18-01-PLAN.md — Vendor giellakbd-ios files, strip dependencies, add DeviceKit, create French layouts
- [ ] 18-02-PLAN.md — Create keyboard bridge, adapt KeyboardViewController for UIKit keyboard + SwiftUI toolbar
- [ ] 18-03-PLAN.md — Autocapitalization, double-space period, shift state machine, user verification

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
- [ ] 19-01-PLAN.md — Wire accent data, fix double-space period, fix edge key touchDown with nearest-cell fallback
- [ ] 19-02-PLAN.md — Delete repeat with acceleration and spacebar trackpad cursor movement
- [ ] 19-03-PLAN.md — Adaptive accent key in AZERTY layout and full device verification

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
- [ ] 20-01-PLAN.md — Wire text prediction into bridge, autocorrect, emoji key layout, default layer setting
- [ ] 20-02-PLAN.md — Emoji picker UI integration, post-transcription suggestion refresh, full UAT

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
- [ ] 21-01-PLAN.md — Extract LegacyCompat types, delete old SwiftUI files, clean pbxproj
- [ ] 21-02-PLAN.md — Memory profiling on device, leak check, signposter verification, report

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
- [ ] 21-01-PLAN.md — Extract LegacyCompat types, delete old SwiftUI files, clean pbxproj
- [ ] 21-02-PLAN.md — Memory profiling on device, leak check, signposter verification, report

## Progress

**Execution Order:**
Phases execute in numeric order: 17 -> 18 -> 19 -> 20 -> 21 -> 22

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
| 17. Bug Fixes | 2/2 | Complete    | 2026-03-27 | - |
| 18. Keyboard Base | 3/3 | Complete    | 2026-03-28 | - |
| 19. Complex Touch Features | 3/3 | Complete    | 2026-03-30 | - |
| 20. Feature Reintegration | 2/2 | Complete    | 2026-03-30 | - |
| 21. Cleanup & Memory Profiling | 2/2 | Complete   | 2026-03-31 | - |
| 22. Public TestFlight | v1.3 | 0/? | Not started | - |

---
*Roadmap created: 2026-03-04*
*v1.0 shipped: 2026-03-07*
*v1.1 shipped: 2026-03-11*
*v1.2 shipped: 2026-03-27*
*v1.3 started: 2026-03-27*
