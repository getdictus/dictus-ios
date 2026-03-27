# Requirements: Dictus v1.3 Public Beta

**Defined:** 2026-03-27
**Core Value:** A user can dictate text in French in any iOS app and correct it immediately on the same keyboard -- no subscription, no cloud, no account.

## v1.3 Requirements

Requirements for v1.3 milestone. Each maps to roadmap phases.

### Keyboard Base

- [x] **KBD-01**: User can type characters on a UICollectionView-based AZERTY keyboard with zero dead zones
- [x] **KBD-02**: User can switch to QWERTY layout in keyboard settings
- [x] **KBD-03**: User can toggle shift (single tap) and caps lock (double tap) with visual feedback
- [x] **KBD-04**: User can switch between letters, numbers, and symbols layers
- [ ] **KBD-05**: User can delete characters with backspace, with accelerating repeat on hold
- [x] **KBD-06**: User can insert space, return, and use globe key to switch keyboards
- [ ] **KBD-07**: User gets autocapitalization after sentence-ending punctuation
- [ ] **KBD-08**: User gets double-space period insertion

### Keyboard Feel

- [x] **FEEL-01**: User gets haptic feedback on touchDown matching Apple keyboard feel
- [x] **FEEL-02**: User hears 3-category key sounds (letter/delete/modifier) respecting silent switch
- [x] **FEEL-03**: User sees key popup preview on press
- [ ] **FEEL-04**: User can long-press vowels to access French accent characters with drag-to-select
- [ ] **FEEL-05**: User can drag spacebar to move cursor (trackpad) with haptic ticks
- [ ] **FEEL-06**: User sees adaptive accent key (apostrophe after consonants, accent after vowels)

### Dictation Reintegration

- [ ] **DICT-01**: User can tap mic button in toolbar to start recording
- [ ] **DICT-02**: User sees recording overlay with waveform replacing keyboard during dictation
- [ ] **DICT-03**: User gets transcription auto-inserted at cursor after recording
- [ ] **DICT-04**: User sees Full Access banner when permissions needed

### Text Prediction

- [ ] **PRED-01**: User sees 3-slot suggestion bar with French autocorrect suggestions
- [ ] **PRED-02**: User can tap suggestion to insert it
- [ ] **PRED-03**: User can undo autocorrect by pressing backspace immediately after

### Keyboard Settings

- [ ] **SET-01**: User can select default opening layer (letters or numbers) with live preview

### Bug Fixes

- [x] **FIX-01**: Dynamic Island no longer gets stuck on REC state (issue #60)
- [x] **FIX-02**: Export logs shows spinner and completes quickly (issue #61)

### Public TestFlight

- [ ] **TF-01**: App passes Beta App Review with complete Privacy Manifests
- [ ] **TF-02**: External testing group created in App Store Connect
- [ ] **TF-03**: Public TestFlight link active and shareable
- [ ] **TF-04**: README updated with public TestFlight link and install instructions

## Future Requirements

Deferred to v1.4+. Tracked but not in current roadmap.

### Smart Modes

- **SMART-01**: User can enable LLM post-processing for dictation refinement
- **SMART-02**: User can select formatting style (email, notes, messages)

### Platform Expansion

- **PLAT-01**: User can use Dictus on iPad with adapted layout
- **PLAT-02**: User can sync preferences via iCloud

### Advanced Dictation

- **ADV-01**: User sees real-time streaming transcription during recording

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Full emoji picker in keyboard | Memory-unsafe (emoji glyph cache blows 50MB limit) -- use system cycling via globe key |
| iPad/split keyboard support | iPhone-first for v1.3, iPad is v1.4+ |
| DivvunSpell integration | Dictus uses UITextChecker + FrequencyDictionary, not Divvun's speller |
| CocoaPods dependency | Dictus uses SPM exclusively. giellakbd-ios files are vendored, not added as a Pod |
| Auto-return to previous app | No reliable public API -- confirmed in v1.2 research. Swipe-back overlay is correct UX |
| Android port | Different platform entirely, v3+ |
| Cloud transcription | Contradicts privacy/offline identity |
| Subscription / monetization | Contradicts open-source positioning |
| Liquid Glass on UIKit keyboard keys | Too complex in UIKit, adding SwiftUI on top defeats the purpose. Liquid Glass already exists on toolbar mic button (separate SwiftUI layer, untouched by rebuild) |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| KBD-01 | Phase 18 | Complete |
| KBD-02 | Phase 18 | Complete |
| KBD-03 | Phase 18 | Complete |
| KBD-04 | Phase 18 | Complete |
| KBD-05 | Phase 19 | Pending |
| KBD-06 | Phase 18 | Complete |
| KBD-07 | Phase 18 | Pending |
| KBD-08 | Phase 18 | Pending |
| FEEL-01 | Phase 18 | Complete |
| FEEL-02 | Phase 18 | Complete |
| FEEL-03 | Phase 18 | Complete |
| FEEL-04 | Phase 19 | Pending |
| FEEL-05 | Phase 19 | Pending |
| FEEL-06 | Phase 19 | Pending |
| DICT-01 | Phase 20 | Pending |
| DICT-02 | Phase 20 | Pending |
| DICT-03 | Phase 20 | Pending |
| DICT-04 | Phase 20 | Pending |
| PRED-01 | Phase 20 | Pending |
| PRED-02 | Phase 20 | Pending |
| PRED-03 | Phase 20 | Pending |
| SET-01 | Phase 20 | Pending |
| FIX-01 | Phase 17 | Complete |
| FIX-02 | Phase 17 | Complete |
| TF-01 | Phase 22 | Pending |
| TF-02 | Phase 22 | Pending |
| TF-03 | Phase 22 | Pending |
| TF-04 | Phase 22 | Pending |

**Coverage:**
- v1.3 requirements: 28 total
- Mapped to phases: 28
- Unmapped: 0

---
*Requirements defined: 2026-03-27*
*Last updated: 2026-03-27 after roadmap creation*
