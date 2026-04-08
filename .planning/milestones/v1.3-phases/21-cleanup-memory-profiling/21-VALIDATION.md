---
phase: 21
slug: cleanup-memory-profiling
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-30
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Xcode Instruments + xcodebuild |
| **Config file** | None — Instruments is an external tool |
| **Quick run command** | `xcodebuild build -scheme DictusKeyboard -destination generic/platform=iOS` |
| **Full suite command** | Instruments profiling session (manual — requires physical device) |
| **Estimated runtime** | ~30 seconds (build), ~10 minutes (Instruments session) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme DictusKeyboard -destination generic/platform=iOS`
- **After every plan wave:** Run full build for all schemes
- **Before `/gsd:verify-work`:** Full Instruments profiling session must be complete
- **Max feedback latency:** 30 seconds (build check)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 21-01-01 | 01 | 1 | SC-1 (dead code removal) | build | `xcodebuild build -scheme DictusKeyboard -destination generic/platform=iOS` | ✅ | ⬜ pending |
| 21-01-02 | 01 | 1 | SC-1 (pbxproj cleanup) | grep | `grep -c 'KeyButton\|KeyRow\|SpecialKeyButton\|AccentPopup' Dictus.xcodeproj/project.pbxproj` returns 0 | ✅ | ⬜ pending |
| 21-02-01 | 02 | 2 | SC-2 (memory < 50MB) | manual | Instruments Allocations + Leaks on device | N/A | ⬜ pending |
| 21-02-02 | 02 | 2 | SC-3 (signposter) | manual | Instruments os_signpost template on device | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test framework needed — validation is build success + manual Instruments session.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Memory under 50MB in all operations | SC-2 | Requires real device + Instruments Allocations | 1. Attach Instruments to DictusKeyboard on iPhone 15 Pro Max. 2. Run typing, dictation, prediction, emoji picker separately. 3. Run combined peak scenario. 4. Verify peak < 50MB. |
| No memory leaks | SC-2 | Requires real device + Instruments Leaks | Run Leaks instrument during profiling session. Verify 0 leaks. |
| Signposter produces data | SC-3 | Requires real device + Instruments os_signpost | 1. Open Instruments with os_signpost template. 2. Attach to DictusKeyboard. 3. Type several keys. 4. Verify KeyPress intervals appear in timeline. |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
