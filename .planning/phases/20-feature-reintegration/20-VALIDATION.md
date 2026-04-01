---
phase: 20
slug: feature-reintegration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-30
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (DictusCore SPM package) |
| **Config file** | DictusCore/Package.swift |
| **Quick run command** | `cd /Users/pierreviviere/dev/dictus/DictusCore && swift test --filter DictusCoreTests` |
| **Full suite command** | `cd /Users/pierreviviere/dev/dictus/DictusCore && swift test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Build + install on simulator, manual smoke test
- **After every plan wave:** Full UAT checklist on physical device
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds (build + deploy to simulator)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 20-01-01 | 01 | 1 | PRED-01 | manual | On-device UAT (keyboard extension) | N/A | ⬜ pending |
| 20-01-02 | 01 | 1 | PRED-02 | manual | On-device UAT (textDocumentProxy) | N/A | ⬜ pending |
| 20-01-03 | 01 | 1 | PRED-03 | manual | On-device UAT (textDocumentProxy) | N/A | ⬜ pending |
| 20-02-01 | 02 | 2 | DICT-01 | manual | On-device UAT (mic + extension) | N/A | ⬜ pending |
| 20-02-02 | 02 | 2 | DICT-02 | manual | On-device UAT (recording state) | N/A | ⬜ pending |
| 20-02-03 | 02 | 2 | DICT-03 | manual | On-device UAT (WhisperKit) | N/A | ⬜ pending |
| 20-02-04 | 02 | 2 | DICT-04 | manual | On-device UAT (permission state) | N/A | ⬜ pending |
| 20-03-01 | 03 | 2 | SET-01 | manual | On-device UAT (App Group) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Phase 20 features are integration-level (keyboard extension runtime) and require manual validation — no Wave 0 test stubs needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mic button starts recording | DICT-01 | Requires keyboard extension runtime + AVAudioSession + Darwin notifications | Tap mic in toolbar → verify recording overlay appears with waveform |
| Recording overlay with waveform | DICT-02 | Requires active audio session + real-time waveform data | Record speech → verify waveform animates during recording |
| Transcription auto-insert | DICT-03 | Requires WhisperKit + textDocumentProxy | Stop recording → verify transcription appears at cursor position |
| Full Access banner | DICT-04 | Requires keyboard permission state | Disable Full Access in Settings → verify banner appears with disabled mic |
| Suggestion bar shows suggestions | PRED-01 | Requires textDocumentProxy context + French dictionary | Type "bon" → verify 3 suggestions appear in suggestion bar |
| Tap suggestion to insert | PRED-02 | Requires textDocumentProxy insert | Type partial word → tap suggestion → verify word replaces partial |
| Undo autocorrect with backspace | PRED-03 | Requires autocorrect state + textDocumentProxy | Type misspelled word + space (autocorrect fires) → backspace → verify original restored |
| Default opening layer | SET-01 | Requires App Group UserDefaults + keyboard reload | Set "numbers" in Settings → reopen keyboard → verify number layer shown |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: manual verification after every task commit
- [x] Wave 0 covers all MISSING references (none needed)
- [x] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
