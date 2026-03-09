---
phase: 8
slug: text-prediction
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-09
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) |
| **Config file** | DictusCore/Tests/ (existing test target) |
| **Quick run command** | `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DictusCoreTests/TextPredictionEngineTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 \| tail -30` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick command (TextPredictionEngineTests)
- **After every plan wave:** Run full DictusCore test suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | PRED-01 | unit | `xcodebuild test -scheme DictusCore -only-testing:DictusCoreTests/TextPredictionEngineTests` | ❌ W0 | ⬜ pending |
| 08-01-02 | 01 | 1 | PRED-01 | unit | Same target | ❌ W0 | ⬜ pending |
| 08-02-01 | 02 | 1 | PRED-02 | unit | Same target | ❌ W0 | ⬜ pending |
| 08-02-02 | 02 | 1 | PRED-02 | unit | Same target | ❌ W0 | ⬜ pending |
| 08-03-01 | 03 | 1 | PRED-03 | unit | `xcodebuild test -scheme DictusCore -only-testing:DictusCoreTests/AccentedCharacterTests` | Partial | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `DictusCore/Tests/DictusCoreTests/TextPredictionEngineTests.swift` — stubs for PRED-01, PRED-02
- [ ] `DictusCore/Tests/DictusCoreTests/FrequencyDictionaryTests.swift` — covers dictionary loading and ranking
- [ ] Test fixture: `DictusCore/Tests/DictusCoreTests/Fixtures/fr_frequency_test.json`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Suggestion bar renders in toolbar with correct layout | PRED-01 | UI visual validation requires simulator | Build & run on iPhone 17 Pro simulator, type a word, verify 3 slots appear between gear and mic |
| Autocorrect undo via backspace | PRED-02 | Requires UITextDocumentProxy interaction | Type misspelled word, press space (autocorrects), press backspace immediately, verify original word restored |
| Accent suggestions appear for single vowel | PRED-03 | Requires full keyboard context | Type "a" after a space, verify slots show a/à/â, tap à, verify accent inserted without space |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
