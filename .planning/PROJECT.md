# Dictus

## What This Is

Dictus is a free, open-source iOS keyboard app for on-device French speech-to-text dictation. Users speak into any iOS app and get accurate French transcription auto-inserted at the cursor — no subscription, no cloud, no account. Built with WhisperKit and Parakeet (FluidAudio) for multi-engine speech recognition, featuring full AZERTY/QWERTY keyboard with text prediction, spacebar trackpad, haptic feedback, and iOS 26 Liquid Glass design.

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

### Active

<!-- Next milestone: v1.2 -->

- [ ] Cold start auto-return to keyboard (competitors handle this, frequent in production)
- [ ] Cold start optimization (init time < 2s)
- [ ] Background audio keep-alive to reduce iOS app kills

### Out of Scope

- Smart modes (LLM post-processing) — deferred to v1.2+, focus on keyboard UX first
- Real-time streaming transcription — v2+ feature, current batch approach works well
- iPad support — v2+, iPhone-first
- Android port — v3+, different platform entirely
- iCloud sync — v2+, local storage sufficient
- Cloud transcription — contradicts privacy/offline identity
- Subscription / monetization — contradicts open-source positioning
- Smart Model Routing at runtime — breaks background recording, user selects model once
- Full emoji picker in keyboard extension — memory-unsafe (emoji glyph cache), use system cycling
- Apple Foundation Models — requires iPhone 15 Pro+, iOS 26.1+ — too restrictive

## Context

Shipped v1.1 with 10,893 LOC Swift across ~261 files in 8 days total (v1.0 + v1.1).
Tech stack: Swift 5.9+ / SwiftUI / WhisperKit 0.16.0+ / FluidAudio (Parakeet) via SPM.
Architecture: Two-process (keyboard extension + main app via Darwin notifications + URL scheme).
App Group: `group.com.pivi.dictus` for all cross-process data sharing.
Minimum target: iOS 17.0 (raised from 16.0 in v1.1 for Parakeet support).
Keyboard extension memory limit: ~50MB.

Known remaining issues:
- Cold start auto-return is the top priority for v1.2
- Text prediction memory budget needs real-device profiling (5MB limit)
- 11 human verification items pending device testing from v1.1

## Constraints

- **Memory**: Keyboard extensions limited to ~50MB RAM
- **Permissions**: Microphone in keyboard requires Full Access enabled
- **Extension limitations**: No `UIApplication.shared` in keyboard extensions
- **Data sharing**: All shared data via App Group (`group.com.pivi.dictus`)
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
| UITextChecker + FrequencyDictionary | System spell-check + custom ranking, no ML model needed | ✓ Good — low memory, good quality |
| 3-mode system simplified to 2 layers | UAT showed 3 modes over-engineered, 2 default layers cleaner | ✓ Good — simpler UX |
| Parakeet via FluidAudio SDK | Multi-engine future-proofing, alternative to WhisperKit | ✓ Good — works, French quality TBD |
| iOS 17 minimum (raised from 16) | Required for FluidAudio/Parakeet support | ✓ Good — 95%+ device coverage |
| collectSamples() for cancel | Keeps audio engine alive between recordings | ✓ Good — no cold restart |
| NotificationCenter for mode refresh | viewWillAppear bridge avoids stale @State in SwiftUI | ✓ Good — reliable sync |

---
*Last updated: 2026-03-11 after v1.1 milestone completion*
