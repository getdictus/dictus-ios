# Requirements: Dictus v1.4 Prediction & Stability

**Defined:** 2026-04-01
**Core Value:** A user can dictate text in French in any iOS app and correct it immediately on the same keyboard -- no subscription, no cloud, no account.

## v1.4 Requirements

Requirements for v1.4 milestone. Each maps to roadmap phases.

### Bug Fixes

- [ ] **FIX-01**: Autocorrect undo only triggers on immediate backspace, not after new character input (#67)
- [ ] **FIX-02**: Settings licenses link points to correct getdictus/dictus-ios repo (#63)
- [ ] **FIX-03**: Parakeet/NVIDIA model attribution added to licenses screen (#63)

### Prediction Engine

- [ ] **PRED-01**: French frequency dictionary expanded to 30-50K words (from current ~1.3K)
- [ ] **PRED-02**: English frequency dictionary expanded to 30-50K words (from current ~1.1K)
- [ ] **PRED-03**: SymSpell replaces UITextChecker for spell correction with sub-millisecond lookups
- [ ] **PRED-04**: N-gram next-word prediction suggests top 3 words based on previous context (bigram/trigram)
- [ ] **PRED-05**: Prediction engine stays under 10ms per keystroke with no typing fluidity regression
- [ ] **PRED-06**: Total prediction memory (dictionaries + models) stays under 20MB per language

### Cold Start UX

- [ ] **COLD-01**: Time-boxed investigation of sourceApplication for auto-return (2h max)
- [ ] **COLD-02**: If auto-return viable, user returns to source app automatically after cold start dictation
- [ ] **COLD-03**: If auto-return not viable, swipe-back overlay UX is polished with improved guidance

### Beta Feedback

- [ ] **BETA-01**: Critical bugs reported by public beta testers are triaged and fixed

## Future Requirements

Deferred to v1.5+. Tracked but not in current roadmap.

### Smart Modes

- **SMART-01**: User can enable LLM post-processing for dictation refinement
- **SMART-02**: User can select formatting style (email, notes, messages)

### Platform Expansion

- **PLAT-01**: User can use Dictus on iPad with adapted layout
- **PLAT-02**: User can sync preferences via iCloud

### Advanced Dictation

- **ADV-01**: User sees real-time streaming transcription during recording

### Premium

- **PRO-01**: SubscriptionManager + StoreKit 2 + Pro feature gating (#55)
- **PRO-02**: Dictus Pro premium features roadmap (#54)

### Testing

- **TEST-01**: Automated test suite (DictusCore, DictusApp, UI tests) (#22)

### UX Enhancements

- **UX-01**: Language picker redesign with searchable list (#52)
- **UX-02**: Settings button quick shortcuts from keyboard (#31)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| KenLM (C++ n-gram library) | LGPL license, C++ bridging complexity, overkill for keyboard extension — custom Swift trie instead |
| Neural/ML prediction models | Too large for 50MB keyboard extension memory limit |
| FleksySDK or proprietary solutions | Contradicts open-source positioning |
| Swipe typing | High complexity, not core to dictation value — v2+ |
| Private API for auto-return (_hostBundleID, LSApplicationWorkspace) | App Store rejection confirmed |
| Full emoji picker in keyboard | Memory-unsafe (emoji glyph cache), use system cycling |
| iPad support | iPhone-first, v1.5+ |
| Android port | Different platform, v3+ |
| Cloud transcription | Contradicts privacy/offline identity |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FIX-01 | — | Pending |
| FIX-02 | — | Pending |
| FIX-03 | — | Pending |
| PRED-01 | — | Pending |
| PRED-02 | — | Pending |
| PRED-03 | — | Pending |
| PRED-04 | — | Pending |
| PRED-05 | — | Pending |
| PRED-06 | — | Pending |
| COLD-01 | — | Pending |
| COLD-02 | — | Pending |
| COLD-03 | — | Pending |
| BETA-01 | — | Pending |

**Coverage:**
- v1.4 requirements: 13 total
- Mapped to phases: 0
- Unmapped: 13 ⚠️

---
*Requirements defined: 2026-04-01*
*Last updated: 2026-04-01 after initial definition*
