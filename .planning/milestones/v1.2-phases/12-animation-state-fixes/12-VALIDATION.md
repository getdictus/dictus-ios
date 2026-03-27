---
phase: 12
slug: animation-state-fixes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-11
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (bundled with Xcode) |
| **Config file** | Dictus.xcodeproj scheme settings |
| **Quick run command** | `xcodebuild build -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 \| tail -30` |
| **Estimated runtime** | ~30 seconds (build only — tests are manual) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` (compilation check)
- **After every plan wave:** Manual testing protocol on device (20 consecutive mic taps, rapid tap sequences, full dictation cycle)
- **Before `/gsd:verify-work`:** All 3 success criteria pass manual verification on device
- **Max feedback latency:** ~30 seconds (build time)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | ANIM-01 | manual | Build check + manual: tap mic 20x, verify overlay appears every time | N/A | ⬜ pending |
| 12-01-02 | 01 | 1 | ANIM-01 | manual | Manual: verify .requested visual state (flat bars, "Demarrage...", cancel only) | N/A | ⬜ pending |
| 12-01-03 | 01 | 1 | ANIM-02 | manual | Manual: rapid start/stop/start within 1s, verify no stale overlay/waveform | N/A | ⬜ pending |
| 12-01-04 | 01 | 1 | ANIM-02 | manual | Manual: verify mic button disabled during transitions | N/A | ⬜ pending |
| 12-01-05 | 01 | 1 | ANIM-03 | manual | Manual: complete dictation, verify mic returns to ready and waveform stops | N/A | ⬜ pending |
| 12-01-06 | 01 | 1 | ANIM-03 | manual | Manual: verify watchdog resets stale state after timeout | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test stubs needed — this phase relies on manual device testing supported by Phase 11's logging infrastructure (LogEvent, PersistentLog).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Overlay appears on every mic tap | ANIM-01 | Cross-process Darwin notification timing + SwiftUI view state requires real device | Tap mic 20 consecutive times, verify overlay appears every time without exception |
| .requested visual state renders correctly | ANIM-01 | Visual appearance requires device rendering | Tap mic, verify flat waveform bars + "Demarrage..." text + cancel-only (no validate button) |
| Rapid taps don't create stale state | ANIM-02 | Cross-process timing + AVAudioSession state requires real device | Rapid start/stop/start within 1 second, 10 times. Verify no stuck overlay or waveform |
| Mic button disabled during transitions | ANIM-02 | UI interaction state requires device testing | Tap mic during .requested/.transcribing states, verify tap is rejected |
| Waveform stops cleanly on completion | ANIM-03 | Animation rendering + audio session cleanup requires device | Complete a dictation, verify waveform stops and mic button returns to ready state |
| Watchdog resets stale state | ANIM-03 | Requires simulating a stuck state (kill app during recording) | Force-kill DictusApp during recording, reopen keyboard, verify state resets within watchdog interval |

---

## Validation Sign-Off

- [ ] All tasks have manual verification instructions
- [ ] Sampling continuity: build check after every commit, manual test after every wave
- [ ] Wave 0 covers all MISSING references (none needed)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (build check)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
