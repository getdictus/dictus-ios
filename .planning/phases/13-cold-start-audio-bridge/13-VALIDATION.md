---
phase: 13
slug: cold-start-audio-bridge
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode built-in) |
| **Config file** | Dictus.xcodeproj test targets |
| **Quick run command** | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DictusCoreTests` |
| **Full suite command** | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- **After every plan wave:** Run `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | COLD-05 | manual | Device: force-quit -> mic tap -> verify overlay | N/A | ⬜ pending |
| 13-01-02 | 01 | 1 | COLD-09 | manual | Device: verify swipe animation | N/A | ⬜ pending |
| 13-02-01 | 02 | 1 | COLD-01 | manual | Device: mic tap -> app opens -> return -> recording works | N/A | ⬜ pending |
| 13-02-02 | 02 | 1 | COLD-02 | manual | Device: force-quit -> mic tap -> verify audio session | N/A | ⬜ pending |
| 13-02-03 | 02 | 1 | COLD-06 | manual | Device: HomeView mic button -> record -> stop -> verify | N/A | ⬜ pending |
| 13-02-04 | 02 | 1 | COLD-07 | manual | Device: verify overlay appears on keyboard return | N/A | ⬜ pending |
| 13-03-01 | 03 | 2 | COLD-08 | manual | Device: test with WhatsApp/Telegram installed | N/A | ⬜ pending |
| 13-03-02 | 03 | 2 | COLD-03 | unit | `xcodebuild test -only-testing:DictusCoreTests/SharedKeysTests` | Partial | ⬜ pending |
| 13-03-03 | 03 | 2 | COLD-04 | manual | Device: verify transcription delivery | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `DictusCoreTests/KnownAppSchemesTests.swift` — unit test for URL scheme list integrity
- [ ] Verify build succeeds with new SwipeBackOverlayView in Xcode Preview

*Most COLD requirements are manual-only due to requiring real device audio session + keyboard extension lifecycle.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Audio session active on cold start | COLD-01 | Requires real device mic + keyboard extension | Force-quit app → tap mic in keyboard → verify recording works after return |
| App activates audio on URL open | COLD-02 | Requires real device audio session | Force-quit → mic tap → verify audio session activates |
| Swipe-back overlay appears | COLD-05 | Requires keyboard extension lifecycle | Force-quit → mic tap → verify overlay shows instead of tabs |
| Direct recording still works | COLD-06 | Requires real device mic | Open app normally → HomeView mic → record → verify |
| Recording timing on return | COLD-07 | Requires keyboard extension lifecycle | Verify overlay appears when keyboard becomes visible |
| Auto-return via URL scheme | COLD-08 | Requires installed third-party apps | Install WhatsApp → mic tap from WhatsApp → verify auto-return |
| Swipe-back animation quality | COLD-09 | Visual/animation quality check | Verify iPhone outline + hand swipe animation renders correctly |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
