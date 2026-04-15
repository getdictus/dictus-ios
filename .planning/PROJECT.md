# Dictus

## What This Is

Dictus is a free, open-source iOS keyboard app for on-device French speech-to-text dictation. Users speak into any iOS app and get accurate French transcription auto-inserted at the cursor — no subscription, no cloud, no account. Built with WhisperKit and Parakeet (FluidAudio) for multi-engine speech recognition, featuring full AZERTY/QWERTY UIKit keyboard (giellakbd-ios) with AOSP compressed trie spell correction (C++), n-gram next-word prediction (trigram with Stupid Backoff), spacebar trackpad, haptic feedback, iOS 26 Liquid Glass design, and cold start Audio Bridge for seamless dictation even when iOS kills the app. Currently in public TestFlight beta (v1.4).

## Core Value

A user can dictate text in French in any iOS app and correct it immediately on the same keyboard without switching — no subscription, no cloud, no account.

## Requirements

### Validated

- ✓ On-device speech-to-text via WhisperKit (French primary) — v1.0
- ✓ Custom iOS keyboard extension with full AZERTY layout — v1.0
- ✓ QWERTY layout option (secondary to AZERTY) — v1.0
- ✓ Dictation works in any app via the keyboard extension — v1.0
- ✓ Microphone recording with visual/haptic feedback — v1.0
- ✓ Automatic filler word removal (handled natively by Whisper) — v1.0
- ✓ Auto-insert transcription into active text field — v1.0
- ✓ Whisper model manager (download, select, delete) — v1.0
- ✓ Onboarding flow (permissions, keyboard setup, model download) — v1.0
- ✓ Settings (model, language, keyboard layout, filler word toggle, haptic toggle) — v1.0
- ✓ iOS 26 Liquid Glass design throughout — v1.0
- ✓ Two-process architecture (keyboard triggers app for recording) — v1.0
- ✓ Design files consolidated into DictusCore shared package — v1.1
- ✓ App icon generated from brand kit (light/dark/tinted) — v1.1
- ✓ Spacebar trackpad with haptic ticks and line-based vertical movement — v1.1
- ✓ Adaptive accent key (apostrophe/accent based on context, case-preserving) — v1.1
- ✓ Haptic feedback on all key types with pre-allocated generators — v1.1
- ✓ Emoji button replacing duplicate globe (iOS cycling limitation documented) — v1.1
- ✓ 3-category key sounds (letter/delete/modifier) — v1.1
- ✓ Mic pill button + recording pill buttons redesign — v1.1
- ✓ Canvas waveform at 60fps with silence threshold — v1.1
- ✓ 3-slot suggestion bar with French autocorrect and accent suggestions — v1.1
- ✓ Autocorrect undo-on-backspace — v1.1
- ✓ Keyboard default layer selection with live preview in settings — v1.1
- ✓ Multi-engine model catalog (WhisperKit + Parakeet via FluidAudio) — v1.1
- ✓ Model catalog cleaned (tiny/base deprecated, English-only removed) — v1.1
- ✓ Structured privacy-safe logging with export (LogEvent API, NSFileCoordinator) — v1.2
- ✓ Animation state machine for reliable recording overlay/waveform transitions — v1.2
- ✓ Cold start Audio Bridge (keyboard captures audio, swipe-back overlay UX) — v1.2
- ✓ Model pipeline hardened (RAM gating, compilation progress, retry-with-cleanup) — v1.2
- ✓ French accent audit across all UI strings — v1.2
- ✓ Model card redesign (tap-to-select, swipe-to-delete, active highlight) — v1.2
- ✓ Recording overlay polish (44pt hit areas, haptics, smooth dismiss) — v1.2
- ✓ Sound feedback service with settings — v1.2
- ✓ Waveform recovery from off-screen/suspension — v1.2
- ✓ Dynamic Island state machine for chained recordings — v1.2
- ✓ Keyboard touchDown haptic/audio matching Apple keyboard — v1.2
- ✓ Device-adaptive key dimensions (3 device classes) — v1.2
- ✓ Professional developer signing + Privacy Manifests — v1.2
- ✓ TestFlight private beta distributed — v1.2
- ✓ Open-source docs (README, CONTRIBUTING, issue templates) — v1.2
- ✓ UIKit keyboard rebuild with giellakbd-ios UICollectionView (zero dead zones) — v1.3
- ✓ Advanced touch: delete repeat, spacebar trackpad, accent long-press, adaptive accent key — v1.3
- ✓ Feature reintegration on UIKit keyboard (dictation, prediction, emoji, autocorrect) — v1.3
- ✓ Memory-safe emoji picker via category pagination (139 MiB -> <50 MiB) — v1.3
- ✓ Public TestFlight beta with privacy manifests and Full Access justification — v1.3
- ✓ AOSP compressed trie spell correction (C++ with ObjC++ bridge, proximity scoring, accent-aware) — v1.4
- ✓ N-gram next-word prediction (trigram with Stupid Backoff, context-boosted corrections) — v1.4
- ✓ App localization via iOS String Catalogs (EN source + FR translations) — v1.4
- ✓ Cold start auto-return investigated (5 approaches, all rejected — no public iOS API) — v1.4
- ✓ Wispr Flow-style swipe-back overlay redesign — v1.4
- ✓ Autocorrect undo race condition fix — v1.4
- ✓ License attribution complete (FluidAudio/DeviceKit/giellakbd-ios) — v1.4
- ✓ Numeric token autocorrect guard — v1.4

### Active

**Milestone v1.7 — Stability, Polish & i18n**

**Goal:** Fix remaining critical bugs post-v1.6, align keyboard geometry with Apple system keyboard, and establish a reusable i18n foundation with German as first new language.

**Target features:**
- Fix silent transcription insertion bug (intermittent, app-visible failure)
- Keyboard layout glitch residual in v1.6.0-beta.1
- Audit and align keyboard key geometry with Apple system keyboard
- Autocorrect v2 — align with AOSP LatinIME (personal LM + richer n-grams + unified scoring)
- Re-test Whisper Turbo and add device compatibility gating
- Build reusable language onboarding/automation process
- Add German language support (first use case of i18n process)

**Carried from v1.4 (deferred):**
- [ ] BUG-71: Crash when starting dictation during phone call (CXCallObserver guard needed)
- [ ] BUG-72: AirPods/media apps not resuming after recording (.notifyOthersOnDeactivation)
- [ ] Cold start auto-return UX improvement (beyond current swipe-back overlay)

### Out of Scope

- Smart modes (LLM post-processing) — deferred, focus on keyboard quality first
- Real-time streaming transcription — v2+ feature, current batch approach works well
- iPad support — v2+, iPhone-first
- Android port — v3+, different platform entirely
- iCloud sync — v2+, local storage sufficient
- Cloud transcription — contradicts privacy/offline identity
- Subscription / monetization — contradicts open-source positioning
- Smart Model Routing at runtime — breaks background recording, user selects model once
- Full emoji picker in keyboard extension — memory-unsafe (emoji glyph cache), use system cycling
- Apple Foundation Models — requires iPhone 15 Pro+, iOS 26.1+ — too restrictive
- LSApplicationWorkspace for auto-return — private API, App Store rejection confirmed

## Context

Shipped v1.4 with ~21K LOC Swift + 1.7K C++ + 1.3K Python across 5 milestones in 35 days.
Tech stack: Swift 5.9+ / SwiftUI / WhisperKit 0.16.0+ / FluidAudio (Parakeet) via SPM / C++ AOSP trie + N-gram engine (ObjC++ bridge).
Architecture: Two-process (keyboard extension + main app via Darwin notifications + URL scheme + Audio Bridge for cold start).
Keyboard: giellakbd-ios UICollectionView with DictusKeyboardBridge delegate adapter.
App Group: `group.solutions.pivi.dictus`.
Minimum target: iOS 17.0.
Keyboard extension memory limit: ~50MB (verified on device).
Distribution: Public TestFlight beta (v1.4 build 6), Apple Developer Team 9B8B36C2FA.
Public link: https://testflight.apple.com/join/b55atKYX

Known remaining issues:
- BUG-71: Crash when starting dictation during active phone call (reverted fix, deferred to v1.5)
- BUG-72: AirPods/media apps not resuming after recording (reverted fix, deferred to v1.5)

## Constraints

- **Memory**: Keyboard extensions limited to ~50MB RAM
- **Permissions**: Microphone in keyboard requires Full Access enabled
- **Extension limitations**: No `UIApplication.shared` in keyboard extensions
- **Data sharing**: All shared data via App Group (`group.solutions.pivi.dictus`)
- **Minimum target**: iOS 17.0, iPhone 12+ (A14 Bionic) recommended
- **Stack**: Swift 5.9+ / SwiftUI / WhisperKit + FluidAudio via SPM
- **License**: MIT — fully open source

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| WhisperKit over whisper.cpp | Native Swift, Core ML + Metal optimized, maintained by Argmax | ✓ Good — accurate French STT, easy integration |
| AZERTY as default layout | Primary user is French, main competitive advantage | ✓ Good — key differentiator |
| Liquid Glass from day one | Design is a project motivation | ✓ Good — premium look achieved |
| Two-process architecture | Keyboard 50MB limit prevents loading Whisper models | ✓ Good — works reliably |
| Darwin notifications for IPC | Lightweight cross-process signaling | ✓ Good — <100ms latency |
| Audio background mode | Keep recording alive when user returns to previous app | ✓ Good — seamless UX |
| SmartModelRouter dropped | Runtime model switching breaks background recording | ✓ Good — stability over feature |
| FillerWordFilter removed | Whisper model handles filler removal natively | ✓ Good — less code |
| Design consolidated into DictusCore | Eliminated 6-file duplication between targets | ✓ Good — single source of truth |
| Pre-allocated haptic generators | Static instances eliminate 2-5ms per-tap latency | ✓ Good — native-feel haptics |
| Canvas waveform over per-bar gradient | Single-pass rendering for 60fps performance | ✓ Good — smooth animation |
| AOSP trie over SymSpell | Proximity scoring, accent-aware costs, lower memory (~0.4 MiB vs ~8 MiB) | ✓ Good — production-grade quality |
| N-gram mmap binary format | C++ engine with FNV-1a hashing, O(log n) binary search, 57KB/language | ✓ Good — fast, minimal memory |
| Auto-return REJECTED | All 5 approaches fail, no public iOS API for keyboard host detection | ✓ Good — documented in ADR |
| BUG-71/72 revert | CallStateMonitor caused cold start regressions and post-call crashes | ⚠️ Revisit — need different approach in v1.5 |
| Public TestFlight beta | Keyboard rework complete, ready for public exposure | ✓ Good — public beta live in v1.3 |
| App Group migration to group.solutions.pivi.dictus | Old ID claimed by personal team, professional team needed new ID | ✓ Good — clean separation |

---
*Last updated: 2026-04-15 after v1.7 milestone start*
