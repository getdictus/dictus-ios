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

## Milestone: v1.2 — Beta Ready

**Shipped:** 2026-03-27
**Phases:** 9 | **Plans:** 35 | **Commits:** 236

### What Was Built
- Structured logging system with LogEvent API, privacy-by-construction, NSFileCoordinator cross-process safety
- Animation state machine eliminating intermittent overlay/waveform bugs
- Cold start Audio Bridge — keyboard captures audio directly when app was killed, swipe-back overlay UX
- Model pipeline hardening — RAM gating, CoreML compilation progress, retry-with-cleanup
- Full French accent audit, model card redesign (tap-to-select, swipe-to-delete), recording overlay polish
- Sound feedback service with system sound integration
- Waveform recovery from off-screen/suspension, Dynamic Island state machine for chained recordings
- Keyboard optimization — touchDown haptic/audio, 3 device classes, zero-dead-zone DragGesture
- GitHub issue triage (resolved, consolidated, deferred)
- TestFlight deployment — professional signing, Privacy Manifests, App Group migration, private beta

### What Worked
- **Inserted phases (15.1, 15.2, 15.3)**: Decimal phase numbering handled urgent work cleanly without disrupting the main roadmap sequence
- **GitHub issue-driven planning**: Phases 15.1-15.3 were driven by real bug reports and testing feedback, keeping work grounded in actual user problems
- **Audio Bridge pattern**: Creative solution to cold start — keyboard captures audio directly instead of relying on app, avoiding the unsolvable auto-return-to-keyboard problem
- **Privacy-by-construction logging**: LogEvent enum with typed parameters makes it impossible to accidentally log transcription text — better than post-hoc filtering
- **Device-adaptive key dimensions**: 3 device classes with screen height breakpoints scaled well across iPhone lineup

### What Was Inefficient
- **UIViewRepresentable for keyboard touch → reverted**: Full UIKit touch handler implementation was reverted due to edge clipping — DragGesture with contentShape was simpler and sufficient. Prototype first.
- **Dead zone investigation (Phase 15.4)**: Extensive research into AOSP/Apple/Fleksy keyboard architectures revealed the problem is architectural (SwiftUI vs UIKit), not solvable with patches. Should have recognized this earlier.
- **Requirements tracking drift**: Several requirements (LOG-01/02/04, TF-03/04, ANIM-03) weren't updated as work completed. Traceability table became stale.
- **Multiple App Group migrations**: Changed from group.com.pivi.dictus to group.solutions.pivi.dictus during TestFlight prep — would have been caught earlier with a signing dry-run

### Patterns Established
- `renderTick` @State counter to force Canvas re-evaluation after extension suspension
- `LiveActivityPhase` enum separate from `ContentState.Phase` with `.idle` state for transition validation
- `.id(refreshID)` pattern to force SwiftUI view recreation on keyboard reappear
- `AudioServicesPlaySystemSound` for key sounds (respects silent switch, no AVAudioPlayer conflict)
- Start sound before `configureAudioSession` to avoid WhisperKit session suppression
- 3 device classes via screen height breakpoints for all keyboard metrics

### Key Lessons
1. **Prototype touch handling approaches before committing**: UIViewRepresentable was fully built, tested, merged, then reverted. A 30-minute prototype would have revealed the edge clipping issue.
2. **Some problems are architectural, not fixable with patches**: Keyboard dead zones require UIKit-first architecture, not SwiftUI-first with UIKit patches. Recognize when the right fix is a rewrite.
3. **Keep requirements tracking current**: Stale traceability tables make milestone completion harder. Update requirements as each plan completes, not retroactively.
4. **Test signing and distribution early**: App Group ID conflicts, icon alpha channels, and missing plist keys were all discovered during archive — a dry-run earlier in the milestone would have caught these.
5. **Decimal phases work well for urgent insertions**: 15.1, 15.2, 15.3 handled 3 rounds of urgent fixes without renumbering. The pattern is validated.

### Cost Observations
- Model mix: ~75% opus, ~25% sonnet (quality profile)
- Sessions: ~20 across 17 days
- Notable: Longer milestone (17 days vs 5 for v1.1) due to more exploratory work (dead zones research, signing/distribution issues). Plan execution stayed ~6 min avg.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~15 | 5 | Initial process — coarse granularity, yolo mode, UAT gap closure pattern |
| v1.1 | ~12 | 5 | Matured UAT loop, integration checker, 4min avg plan execution |
| v1.2 | ~20 | 9 | Decimal phases for urgent insertions, GitHub issue-driven planning, TestFlight distribution |

### Cumulative Quality

| Milestone | Tests | LOC | Files |
|-----------|-------|-----|-------|
| v1.0 | 52 | 7,305 | 156 |
| v1.1 | 62+ | 10,893 | ~261 |
| v1.2 | 62+ | 16,495 | ~333 |

### Top Lessons (Verified Across Milestones)

1. Device testing catches issues simulators miss — always verify on hardware (v1.0, v1.1, v1.2)
2. Milestone audits catch integration gaps — always audit before shipping (v1.0, v1.1)
3. Infrastructure phases pay dividends — shared design system enabled all subsequent work (v1.1)
4. Prototype before committing to complex approaches — SmartModelRouter (v1.0), 3-mode system (v1.1), UIViewRepresentable touch (v1.2) all reverted (v1.0, v1.1, v1.2)
5. Plan execution speeds up with codebase familiarity — 25min → 4min → 6min average (v1.0 → v1.1 → v1.2)
6. Keep requirements tracking current — stale traceability makes milestone completion harder (v1.2)
7. Test signing/distribution early — dry-run catches ID conflicts and validation issues (v1.2)
