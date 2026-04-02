---
phase: 24
slug: symspell-spell-correction
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual device testing + Instruments profiling (keyboard extensions cannot run XCTest) |
| **Config file** | none |
| **Quick run command** | `xcodebuild build -scheme DictusKeyboard -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Full suite command** | Build & run on physical device + Instruments memory profiling |
| **Estimated runtime** | ~30 seconds (build) + manual testing |

---

## Sampling Rate

- **After every task commit:** Build on Simulator, verify suggestion bar behavior
- **After every plan wave:** Physical device test: memory profiling + all test scenarios
- **Before `/gsd:verify-work`:** Memory profiling confirms <50MB total with SymSpell loaded
- **Max feedback latency:** 30 seconds (build time)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 24-01-01 | 01 | 1 | PRED-01 | smoke | `python3 scripts/curate_fr_dict.py && python3 -c "import json; d=json.load(open('fr_frequency.json')); print(len(d)); assert 30000<=len(d)<=50000"` | ❌ W0 | ⬜ pending |
| 24-01-02 | 01 | 1 | PRED-02 | smoke | `python3 scripts/curate_en_dict.py && python3 -c "import json; d=json.load(open('en_frequency.json')); print(len(d)); assert 30000<=len(d)<=50000"` | ❌ W0 | ⬜ pending |
| 24-02-01 | 02 | 1 | PRED-03 | build | `xcodebuild build -scheme DictusKeyboard -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | ❌ W0 | ⬜ pending |
| 24-02-02 | 02 | 1 | PRED-03 | manual | Type "helo" → bar shows "hello" as bold center slot | manual-only | ⬜ pending |
| 24-02-03 | 02 | 1 | PRED-03 | manual | Type "cafe" → bar shows accented "café" | manual-only | ⬜ pending |
| 24-02-04 | 02 | 1 | PRED-03 | manual | Autocorrect rejection: helo+space→hello→backspace→helo→space→helo stays | manual-only | ⬜ pending |
| 24-02-05 | 02 | 1 | PRED-03 | manual | Switch to EN, type "teh" → "the" correction | manual-only | ⬜ pending |
| 24-02-06 | 02 | 1 | PRED-03 | manual | Instruments: memory <50MB with SymSpell loaded on device | manual-only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Python dictionary curation scripts (`scripts/curate_fr_dict.py`, `scripts/curate_en_dict.py`)
- [ ] Expanded `fr_frequency.json` (30-50K entries from Lexique 3.83)
- [ ] Expanded `en_frequency.json` (30-50K entries from Norvig count_1w.txt)
- [ ] Vendored SymSpellSwift source files in `DictusKeyboard/Vendored/SymSpell/`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Spell correction suggestions | PRED-03 | Keyboard extension requires device/Simulator UI interaction | Type misspelled words, verify suggestion bar shows frequency-ranked corrections |
| Accent correction | PRED-03 | Requires keyboard input on device | Type unaccented words (cafe, resume), verify accented forms appear |
| Autocorrect rejection | PRED-03 | Requires sequential user interaction (type→space→backspace→space) | Follow undo flow, verify word not re-corrected |
| Memory under 50MB | PRED-03 | Requires Instruments profiling on physical device | Profile with Instruments, check total memory footprint |
| Language switch | PRED-03 | Requires keyboard settings interaction | Switch language, verify correct dictionary loaded |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
