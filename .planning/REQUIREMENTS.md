# Requirements: Dictus v1.5 — Dictus Pro

**Defined:** 2026-04-08
**Core Value:** A user can dictate text in French in any iOS app and correct it immediately on the same keyboard — no cloud, no account. Pro adds intelligent reformulation, transcription history, and custom vocabulary — all 100% on-device.

## v1.5 Requirements

Requirements for the Dictus Pro premium tier. Each maps to roadmap phases.

### Subscription

- [ ] **SUB-01**: User can subscribe to Dictus Pro via StoreKit 2 in-app purchase (single tier)
- [ ] **SUB-02**: User's Pro status is cached in App Group and readable by keyboard extension
- [ ] **SUB-03**: User can restore previous purchases from the paywall screen
- [ ] **SUB-04**: Pro status updates in real-time when subscription state changes (Transaction.updates)
- [ ] **SUB-05**: During beta period, all Pro features are unlocked for free with clear messaging
- [ ] **SUB-06**: FeatureGate system checks Pro status for any gated feature (ProFeature enum)

### Paywall

- [ ] **PAY-01**: User sees a paywall screen when tapping a locked Pro feature or from Settings
- [ ] **PAY-02**: Paywall displays Pro benefits, pricing, and subscribe button
- [ ] **PAY-03**: Paywall includes restore purchases functionality
- [ ] **PAY-04**: During beta, paywall shows "All Pro features free during beta" banner instead of purchase flow
- [ ] **PAY-05**: Keyboard extension shows "Upgrade in Dictus app" prompt when user taps a locked feature
- [ ] **PAY-06**: Paywall includes links to Terms of Service and Privacy Policy (Apple requirement)

### History

- [ ] **HIST-01**: Transcriptions are automatically saved after each successful dictation (text, language, duration, date, STT provider)
- [ ] **HIST-02**: User can access transcription history via swipe-up gesture from home screen
- [ ] **HIST-03**: History displays cards in reverse chronological order with text preview, date, language, duration
- [ ] **HIST-04**: User can tap a card to view full transcription text
- [ ] **HIST-05**: User can copy transcription text to clipboard from full view
- [ ] **HIST-06**: User can share transcription via iOS share sheet from full view
- [ ] **HIST-07**: User can delete individual transcriptions (swipe or long-press)
- [ ] **HIST-08**: User can search across all transcriptions with full-text search, accent-aware for French (Pro)
- [ ] **HIST-09**: History persists across app restarts (GRDB local database)
- [ ] **HIST-10**: Empty state shown when no transcriptions exist yet
- [ ] **HIST-11**: History cards match Dictus Liquid Glass visual identity

### Smart Mode

- [ ] **SMART-01**: User can select a Smart Mode template after dictation to reformulate text
- [ ] **SMART-02**: Pre-configured templates available: Email, SMS, Notes, Summary
- [ ] **SMART-03**: Templates work in French, English, and Spanish with language-appropriate prompts
- [ ] **SMART-04**: Apple Foundation Models used as primary LLM engine on iOS 26+ with compatible device
- [ ] **SMART-05**: Open-source model (mlx-swift) available as fallback for older devices with sufficient RAM (6GB+)
- [ ] **SMART-06**: User can download/manage open-source LLM model (same pattern as Whisper model manager)
- [ ] **SMART-07**: Clear loading/processing indicator shown during LLM reformulation
- [ ] **SMART-08**: User can keep original text or accept reformulated version
- [ ] **SMART-09**: Graceful degradation: clear messaging for devices that cannot run any LLM (4GB RAM)
- [ ] **SMART-10**: All LLM processing runs 100% on-device — no network calls
- [ ] **SMART-11**: Smart Mode is gated behind Pro subscription (free during beta)

### Vocabulary

- [ ] **VOCAB-01**: User can add custom terms to personal vocabulary in Settings (Pro)
- [ ] **VOCAB-02**: User can edit and delete existing vocabulary terms
- [ ] **VOCAB-03**: User can bulk-import terms by pasting a text list
- [ ] **VOCAB-04**: Custom terms are injected as contextual sentences into WhisperKit initialPrompt (FR/EN/ES)
- [ ] **VOCAB-05**: Vocabulary is capped at ~30-40 terms to respect initialPrompt 224-token limit
- [ ] **VOCAB-06**: Vocabulary persists in App Group (accessible by recording pipeline)
- [ ] **VOCAB-07**: Custom vocabulary improves recognition accuracy for technical/rare terms
- [ ] **VOCAB-08**: Vocabulary feature is gated behind Pro subscription (free during beta)

## v2 Requirements

Deferred to future milestones. Tracked but not in current roadmap.

### Pro Expert Tier

- **EXPERT-01**: Pre-built professional dictionaries (médecin, avocat, dev, psy) with specialized terminology
- **EXPERT-02**: Continuous long dictation (>5 min) with chunked transcription
- **EXPERT-03**: Desktop sync — transcription sync between Dictus iOS and Dictus Desktop (macOS)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Audio file transcription (.mp3/.m4a import) | Backlog — not prioritized for Pro launch |
| Voice message transcription (Telegram/WhatsApp) | Backlog — requires Share Sheet extension |
| Contextual reformulation ("more formal", "shorter") | After Smart Mode base is validated |
| Auto-summary / action extraction | Depends on Smart Mode quality |
| Local translation (FR→EN) | Backlog |
| Voice actions ("send by email") | Backlog — requires Shortcuts/Intents integration |
| Multi-language in same session | Backlog |
| Voice shortcuts (abbreviations) | Backlog |
| Multi-format export (.txt, .md, .docx, .pdf) | May come with desktop sync milestone |
| RevenueCat / third-party subscription SDK | Overkill for single-tier iOS-only (1% rev share) |
| Server-side receipt validation | 100% offline architecture — StoreKit 2 validates on-device |
| Multiple subscription tiers | Single tier at launch, split later based on user data |
| SwiftData for history | GRDB + FTS5 chosen instead — native full-text search, no 0xdead10cc risk |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SUB-01 | Phase 30 | Pending |
| SUB-02 | Phase 30 | Pending |
| SUB-03 | Phase 30 | Pending |
| SUB-04 | Phase 30 | Pending |
| SUB-05 | Phase 30 | Pending |
| SUB-06 | Phase 30 | Pending |
| PAY-01 | Phase 30 | Pending |
| PAY-02 | Phase 30 | Pending |
| PAY-03 | Phase 30 | Pending |
| PAY-04 | Phase 30 | Pending |
| PAY-05 | Phase 30 | Pending |
| PAY-06 | Phase 30 | Pending |
| HIST-01 | Phase 31 | Pending |
| HIST-02 | Phase 31 | Pending |
| HIST-03 | Phase 31 | Pending |
| HIST-04 | Phase 31 | Pending |
| HIST-05 | Phase 31 | Pending |
| HIST-06 | Phase 31 | Pending |
| HIST-07 | Phase 31 | Pending |
| HIST-08 | Phase 31 | Pending |
| HIST-09 | Phase 31 | Pending |
| HIST-10 | Phase 31 | Pending |
| HIST-11 | Phase 31 | Pending |
| SMART-01 | Phase 33 | Pending |
| SMART-02 | Phase 33 | Pending |
| SMART-03 | Phase 33 | Pending |
| SMART-04 | Phase 33 | Pending |
| SMART-05 | Phase 33 | Pending |
| SMART-06 | Phase 33 | Pending |
| SMART-07 | Phase 33 | Pending |
| SMART-08 | Phase 33 | Pending |
| SMART-09 | Phase 33 | Pending |
| SMART-10 | Phase 33 | Pending |
| SMART-11 | Phase 33 | Pending |
| VOCAB-01 | Phase 32 | Pending |
| VOCAB-02 | Phase 32 | Pending |
| VOCAB-03 | Phase 32 | Pending |
| VOCAB-04 | Phase 32 | Pending |
| VOCAB-05 | Phase 32 | Pending |
| VOCAB-06 | Phase 32 | Pending |
| VOCAB-07 | Phase 32 | Pending |
| VOCAB-08 | Phase 32 | Pending |

**Coverage:**
- v1.5 requirements: 42 total
- Mapped to phases: 42/42
- Unmapped: 0

---
*Requirements defined: 2026-04-08*
*Last updated: 2026-04-08 — traceability completed after roadmap creation*
