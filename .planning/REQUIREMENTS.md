# Requirements: Dictus v1.7 — Stability, Polish & i18n

**Defined:** 2026-04-15
**Core Value:** A user can dictate text in French in any iOS app and correct it immediately on the same keyboard — no subscription, no cloud, no account.

## v1.7 Requirements

Requirements for this milestone. Each maps to roadmap phases (34-39).

### Stability (Bug fixes)

- [ ] **STAB-01**: Transcription text is always inserted into the target app when dictation completes (fixes silent insertion failure, issue #118)

### Keyboard Polish

- [ ] **KBD-01**: Keyboard key geometry (widths, heights, gaps, padding) matches Apple system keyboard within documented tolerances across all supported device classes (issue #117)
- [ ] **KBD-02**: Keyboard layout renders correctly on every launch — no residual glitch observed in v1.6.0-beta.1 (issue #116)

### Autocorrect Quality

- [ ] **AUTO-01**: Autocorrect ranks candidates using a unified scoring function that blends edit distance, keyboard proximity, n-gram evidence, and personal language model — aligned with AOSP LatinIME architecture (issue #114)
- [ ] **AUTO-02**: User-typed words are learned into a personal language model that biases future suggestions toward the user's vocabulary
- [ ] **AUTO-03**: Autocorrect uses higher-order n-grams (trigrams minimum, with fallback) for contextual disambiguation

### Dictation Engine

- [ ] **STT-01**: Whisper Turbo model is re-tested on target devices and gated per-device based on measured performance and RAM (issue #104)

### Internationalization

- [ ] **I18N-01**: A documented, reusable process exists for adding a new language to Dictus — covers Whisper model wiring, keyboard layout, UI strings, autocorrect dictionary, n-gram data, onboarding (issue #110)
- [ ] **I18N-02**: German is fully integrated — QWERTZ keyboard layout, WhisperKit German transcription (multilingual model), German autocorrect dictionary + n-gram data, German UI strings, onboarding in German. First end-to-end validation of the I18N-01 process (issue #109)

## Out of Scope

Explicitly excluded from this milestone. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Verbal punctuation commands (#115) | Deferred — requires ASR command grammar design |
| Cold start auto-return (#23) | Deferred — already investigated in v1.4, no public API breakthrough |
| Keyboard settings button shortcuts (#31) | Deferred — nice-to-have, not blocking |
| Transcription history (#70) | Moved to premium/Pro scope |
| iCloud dictionary sync (#103) | v2+ feature |
| Real-time streaming transcription | v2+ feature |
| iPad support | v2+, iPhone-first |

## Traceability

Populated by roadmapper during Step 10 of new-milestone workflow.

| Requirement | Phase | Status |
|-------------|-------|--------|
| STAB-01 | Phase 34 | Pending |
| KBD-01 | Phase 35 | Pending |
| KBD-02 | Phase 35 | Pending |
| AUTO-01 | Phase 36 | Pending |
| AUTO-02 | Phase 36 | Pending |
| AUTO-03 | Phase 36 | Pending |
| STT-01 | Phase 37 | Pending |
| I18N-01 | Phase 38 | Pending |
| I18N-02 | Phase 39 | Pending |

**Coverage:**
- v1.7 requirements: 9 total
- Mapped to phases: 9
- Unmapped: 0 ✓

## Linked GitHub Issues

| REQ-ID | Issue | Title |
|--------|-------|-------|
| STAB-01 | #118 | Transcription text silently not inserted into target app |
| KBD-01 | #117 | Audit and align keyboard key geometry with Apple system keyboard |
| KBD-02 | #116 | Keyboard layout glitch still occurs in rare cases on v1.6.0-beta.1 |
| AUTO-01/02/03 | #114 | Align autocorrect with AOSP LatinIME |
| STT-01 | #104 | Re-test Whisper Turbo and add device compatibility gating if needed |
| I18N-01 | #110 | Create a reusable language onboarding / automation process |
| I18N-02 | #109 | German Language Support |

---
*Requirements defined: 2026-04-15*
*Last updated: 2026-04-15 after milestone v1.7 scoping*
