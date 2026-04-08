---
phase: 25
slug: n-gram-next-word-prediction
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 25 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode) + Python pytest (pipeline) + manual device testing |
| **Config file** | Dictus.xcodeproj (no separate test config) |
| **Quick run command** | `xcodebuild build -project Dictus.xcodeproj -scheme DictusKeyboard -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Full suite command** | `python3 tools/test_ngram_builder.py && xcodebuild build -scheme DictusKeyboard` + manual device testing |
| **Estimated runtime** | ~30 seconds (build) + manual device verification |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme DictusKeyboard`
- **After every plan wave:** Device testing on physical iPhone
- **Before `/gsd:verify-work`:** Full suite must be green, all PRED requirements verified on device
- **Max feedback latency:** 30 seconds (build)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 25-01-01 | 01 | 1 | PRED-04 | unit | `python3 tools/test_ngram_builder.py` | ❌ W0 | ⬜ pending |
| 25-01-02 | 01 | 1 | PRED-06 | unit | `ls -la DictusKeyboard/Resources/*.dict` (check <20MB) | ❌ W0 | ⬜ pending |
| 25-02-01 | 02 | 2 | PRED-04 | manual | Device: type "je" + space → see 3 predictions | N/A | ⬜ pending |
| 25-02-02 | 02 | 2 | PRED-05 | manual | Instruments Time Profiler: <10ms per keystroke | N/A | ⬜ pending |
| 25-02-03 | 02 | 2 | PRED-04 | manual | Device: tap prediction → chains to new predictions | N/A | ⬜ pending |
| 25-02-04 | 02 | 2 | PRED-06 | manual | Device memory profiling: total <20MB/language | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tools/test_ngram_builder.py` — unit tests for n-gram pipeline (frequency counting, binary serialization, round-trip verification)
- [ ] Build verification: `xcodebuild build -scheme DictusKeyboard` compiles without errors

*Existing infrastructure covers C++ build and mmap loading (from Phase 24.1).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 3 predicted next words after space | PRED-04 | Keyboard extension UI requires device testing | 1. Open Messages, 2. Type "je" + space, 3. Verify 3 predictions appear in suggestion bar |
| Chained prediction | PRED-04 | Interactive UI behavior | 1. After predictions appear, tap a prediction, 2. Verify new predictions appear, 3. Verify word + trailing space inserted |
| Sub-10ms per keystroke | PRED-05 | Performance requires Instruments profiling | 1. Profile with Time Profiler, 2. Verify suggestion update < 10ms, 3. No dropped frames |
| Total memory under 20MB | PRED-06 | Memory requires device profiling | 1. Profile with Memory Graph, 2. Check total prediction memory per language |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
