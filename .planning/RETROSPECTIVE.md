# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — MVP

**Shipped:** 2026-03-07
**Phases:** 5 | **Plans:** 18 | **Commits:** 137

### What Was Built
- Two-process dictation architecture (keyboard extension + main app via Darwin notifications)
- On-device French speech-to-text with WhisperKit model manager (5 models)
- Full AZERTY/QWERTY keyboard with accented character long-press
- Wispr Flow-inspired dictation UX with auto-insert, waveform, haptics
- iOS 26 Liquid Glass design system with iOS 16-25 Material fallback
- 5-step guided onboarding flow
- Settings wired end-to-end (language, haptics, filler words, layout)

### What Worked
- **Coarse granularity + yolo mode**: 5 phases in 4 days, minimal overhead
- **UAT gap closure pattern**: Phases 3-4 each needed extra plans (3.4, 4.4, 4.5) to close device-testing gaps — the pattern of "execute, test on device, fix gaps" was effective
- **Phase 5 from audit**: Running `/gsd:audit-milestone` before completion caught real integration gaps (unwired settings toggles), Phase 5 closed them cleanly
- **Darwin notification + Bool flag pattern**: Reliable cross-process IPC despite no payload support
- **Two-process architecture**: Correct decision given 50MB keyboard extension limit

### What Was Inefficient
- **Design file duplication**: 6 files manually synced between DictusApp and DictusKeyboard — a DictusUI SPM package would eliminate this
- **SmartModelRouter built then dropped**: Full TDD implementation (24 tests) that was bypassed at runtime because model switching breaks background recording. Should have prototyped before committing to the approach
- **Multiple UAT rounds**: Phases 3 and 4 each needed 1-2 extra gap closure plans. Earlier device testing during initial plans would reduce rework
- **FillerWordFilter built then removed**: Whisper model handles filler removal natively. Research should have caught this before implementation

### Patterns Established
- `dictusGlass()` modifier for all glass surfaces (single point of iOS 26 upgrade)
- Darwin notification + Bool flag + UserDefaults for cross-process communication
- `canImport(UIKit) && !os(macOS)` guard for shared SPM packages
- Fixed font sizes for keyboard keys (native iOS behavior, not Dynamic Type)
- `Task.sleep` over `Timer.scheduledTimer` in keyboard extensions
- Precomposed Unicode for accented characters

### Key Lessons
1. **Test on device early**: Simulator misses AVAudioSession behavior, haptics, keyboard extension memory, and UI sizing issues. Every phase needed device verification.
2. **Audit before milestone completion**: The milestone audit caught 3 unwired settings toggles that would have shipped broken. Always audit.
3. **Prototype runtime behavior before building features**: SmartModelRouter and FillerWordFilter were well-engineered but unnecessary. A 30-minute prototype would have revealed this.
4. **iOS keyboard extensions are severely constrained**: 50MB memory, no UIApplication.shared, no URL opening, unreliable Timer — design around these from day one.
5. **WhisperKit owns the audio session**: It calls setCategory + setActive internally. Must align our config with WhisperKit's expectations, not fight it.

### Cost Observations
- Model mix: ~80% opus, ~20% sonnet (balanced profile)
- Sessions: ~15 across 4 days
- Notable: Yolo mode + coarse granularity kept planning overhead minimal. Most time spent on actual implementation and device testing.

---

## Milestone: v1.1 — UX & Keyboard

**Shipped:** 2026-03-11
**Phases:** 5 | **Plans:** 29 | **Commits:** 186

### What Was Built
- Shared design system in DictusCore (colors, glass, waveform, mic button, logo)
- Apple-parity keyboard: spacebar trackpad, adaptive accent key, emoji button, haptics, 3-category key sounds
- Text prediction: 3-slot suggestion bar, French autocorrect via UITextChecker + frequency dictionary, accent suggestions, undo-on-backspace
- Keyboard mode system: default layer selection (letters/numbers) with live preview in settings and onboarding
- Multi-engine model catalog: WhisperKit + Parakeet (FluidAudio), gauge bars, catalog cleanup (7 models, 5 available)
- Mic pill + recording overlay redesign with Canvas waveform at 60fps

### What Worked
- **UAT gap closure pattern matured**: Phases 07, 09, 10 all used the "execute → UAT → diagnose → fix" loop. The pattern is now systematic with dedicated UAT.md files.
- **Integration checker at milestone audit**: Caught the MODE-01 architecture evolution (3 modes → 2 layers) and verified all 26 requirement wiring paths.
- **Yolo mode + coarse granularity**: 29 plans in 5 days, minimal planning overhead. Average plan execution: ~4 minutes.
- **DictusCore consolidation (Phase 06)**: Eliminated design file duplication early, every subsequent phase benefited from shared components.
- **Notification bridge pattern**: viewWillAppear → NotificationCenter → SwiftUI solved the stale @State problem for keyboard mode sync.

### What Was Inefficient
- **3-mode system built then simplified**: Full MicroModeView + EmojiMicroModeView implementation (Plans 09-02, 09-05, 09-06) was replaced by DefaultKeyboardLayer system. Earlier user testing during planning would have caught this.
- **Multiple UAT rounds on Phase 07**: 12 plans needed (4 core + 8 gap closure). More thorough initial implementation would reduce rework.
- **Nyquist validation gaps**: 3 of 5 phases lack Nyquist compliance — validation wasn't prioritized during execution speed.
- **Human verification backlog**: 11 items accumulated across 3 phases without device testing. Should integrate device testing into each phase completion.

### Patterns Established
- `DefaultKeyboardLayer` over multi-mode enums — simpler state management for keyboard variants
- Pre-allocated static `UIImpactFeedbackGenerator` instances for zero-latency haptics
- `AudioServicesPlaySystemSound` with 3 category IDs (1104/1155/1156) for key sounds
- `DispatchQueue.main.async` after keystroke for suggestion updates (avoids stale proxy reads)
- `collectSamples()` instead of `stopRecording()` to keep audio engine alive between recordings
- Device-adaptive key height via `UIScreen.main.bounds` breakpoints (42pt/46pt/50pt)
- Canvas single-pass rendering for waveform visualization
- Word boundary detection via manual iteration (UITextDocumentProxy lacks deleteWordBackward)

### Key Lessons
1. **UAT before building complex alternatives**: The 3-mode keyboard system was fully implemented before testing showed it was over-engineered. A paper prototype or minimal POC would have saved 3 plans.
2. **NotificationCenter bridges UIKit lifecycle to SwiftUI**: viewWillAppear doesn't trigger SwiftUI body re-evaluation — posting a notification that SwiftUI observes is the correct pattern.
3. **iOS keyboard extension constraints compound**: 50MB memory + no UIApplication + stale proxy reads + no line-width API = every feature needs creative workarounds.
4. **Shared design package pays dividends immediately**: Phase 06's DictusCore consolidation was the foundation for every subsequent phase. Do infrastructure first.
5. **WhisperKit owns more than you think**: It controls audio session category, activation, and recording lifecycle. Align with it, don't fight it.

### Cost Observations
- Model mix: ~70% opus, ~30% sonnet (quality profile)
- Sessions: ~12 across 5 days
- Notable: Plan execution averaged 4 minutes (down from 25 min in v1.0). Codebase familiarity and established patterns dramatically reduced execution time.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~15 | 5 | Initial process — coarse granularity, yolo mode, UAT gap closure pattern |
| v1.1 | ~12 | 5 | Matured UAT loop, integration checker, 4min avg plan execution |

### Cumulative Quality

| Milestone | Tests | LOC | Files |
|-----------|-------|-----|-------|
| v1.0 | 52 | 7,305 | 156 |
| v1.1 | 62+ | 10,893 | ~261 |

### Top Lessons (Verified Across Milestones)

1. Device testing catches issues simulators miss — always verify on hardware (v1.0, v1.1)
2. Milestone audits catch integration gaps — always audit before shipping (v1.0, v1.1)
3. Infrastructure phases pay dividends — shared design system enabled all subsequent work (v1.1)
4. UAT before complex alternatives — test simple approaches before building elaborate systems (v1.1)
5. Plan execution speeds up with codebase familiarity — 25min → 4min average (v1.0 → v1.1)
