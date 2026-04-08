# Milestones

## v1.4 Prediction & Stability (Shipped: 2026-04-08)

**Phases completed:** 7 phases, 15 plans
**Timeline:** 7 days (2026-04-01 -> 2026-04-07)
**Commits:** ~121 | **LOC:** 21K Swift + 1.7K C++ + 1.3K Python

**Delivered:** Production-grade text prediction engine with AOSP compressed trie spell correction (C++) and n-gram next-word prediction, full app localization, cold start UX polish, and beta bug fixes.

**Key accomplishments:**
1. AOSP trie spell correction — compressed patricia trie (C++ with ObjC++ bridge), mmap-based, edit distance 2, keyboard proximity scoring, accent-aware costs (~0.4 MiB/language)
2. N-gram next-word prediction — trigram engine (C++ with mmap), Stupid Backoff scoring, context-boosted spell corrections, prediction tap chaining
3. App localization — iOS String Catalogs (EN source + FR translations) for both DictusApp and DictusKeyboard targets, developmentRegion=en
4. Cold start investigation — 5 approaches tested for auto-return, all rejected (no public iOS API), ADR documented, Wispr Flow-style overlay redesign
5. Bug fixes — autocorrect undo race condition, license URL + NVIDIA attribution, numeric token autocorrect guard
6. SymSpell → AOSP trie migration — complete replacement with better quality, lower memory, and proximity scoring

**Git range:** `fix(23)` -> `revert(27)`

### Known Gaps
- **BUG-71**: Crash during phone call — CallStateMonitor reverted (caused cold start regressions), deferred to v1.5
- **BUG-72**: AirPods media not resuming after recording — deactivateAndIdle reverted alongside BUG-71, deferred to v1.5

---

## v1.3 Public Beta (Shipped: 2026-04-07)

**Phases completed:** 6 phases, 14 plans
**Timeline:** 11 days (2026-03-27 -> 2026-04-07)
**Files:** 225 modified | **LOC:** +35,046 / -3,395

**Delivered:** Complete UIKit keyboard rebuild with giellakbd-ios, advanced touch interactions, feature reintegration, memory-safe emoji picker, and first public TestFlight beta.

**Key accomplishments:**
1. UIKit keyboard rebuild — replaced SwiftUI keyboard with giellakbd-ios UICollectionView architecture, eliminating dead zones
2. Advanced touch interactions — delete repeat with acceleration, spacebar trackpad, French accent long-press, adaptive accent key
3. Feature reintegration — dictation, text prediction, autocorrect, emoji picker wired onto new UIKit keyboard
4. Memory optimization — emoji picker reduced from 139 MiB to under 50 MiB via category pagination
5. Public TestFlight — privacy manifests, Beta App Review passed, public link live
6. Bug fixes — Dynamic Island watchdog, export logs optimization, 7-day retention

**Git range:** `feat(17-01)` -> `docs(phase-22)`

---

## v1.2 Beta Ready (Shipped: 2026-03-27)

**Phases completed:** 9 phases, 35 plans
**Timeline:** 17 days (2026-03-11 -> 2026-03-27)
**Commits:** 236 | **Files:** 333 modified | **LOC:** 16,495 Swift (+5,602 from v1.1)

**Delivered:** Bug fixes, design polish, keyboard optimization, and TestFlight deployment — first private beta distributed to testers with professional signing and Privacy Manifests.

**Key accomplishments:**
1. Production logging — structured LogEvent API with privacy-by-construction, cross-process NSFileCoordinator, export with device header
2. Cold start Audio Bridge — keyboard captures audio directly when app was killed, swipe-back overlay for seamless return to previous app
3. Model pipeline hardened — Large Turbo v3 removed for low-RAM devices, CoreML compilation progress, retry-with-cleanup, Parakeet routing verified
4. Full design polish — French accent audit, model card redesign (tap-to-select, swipe-to-delete, active highlight), recording overlay with 44pt hit areas and haptics
5. Keyboard optimization — touchDown haptic/audio matching Apple keyboard, 3 device classes adaptive dimensions, zero-dead-zone DragGesture, OSSignposter instrumentation
6. TestFlight live — professional developer signing, Privacy Manifests, App Group migration, private beta build 1.2(1) distributed

**Git range:** `feat(11-01)` -> `docs(16)`

### Known Gaps
- **LOG-01, LOG-02, LOG-04**: Logging requirements partially implemented (structured API exists but tracking not fully updated)
- **TF-09**: Public TestFlight link deferred — Pierre wants keyboard rework before public beta
- **ANIM-03**: Traceability table stale (requirement actually completed)
- Dead zones in keyboard touch handling remain partially unsolved (Phase 15.4 research documented, deferred)

---

## v1.1 UX & Keyboard (Shipped: 2026-03-11)

**Phases completed:** 5 phases, 29 plans
**Timeline:** 5 days (2026-03-07 -> 2026-03-11)
**Commits:** 186 | **Files:** 261 modified | **LOC:** 10,893 Swift (+3,588 from v1.0)

**Delivered:** Apple-level keyboard parity with spacebar trackpad, haptics, text prediction, keyboard modes, and multi-engine model catalog (WhisperKit + Parakeet).

**Key accomplishments:**
1. Design system consolidated into DictusCore — shared colors, glass modifiers, waveform, mic button across all targets
2. Apple-parity keyboard — spacebar trackpad with haptic ticks, adaptive accent key, emoji button, 3-category key sounds
3. Text prediction engine — 3-slot suggestion bar with French autocorrect, accent suggestions, undo-on-backspace
4. Keyboard mode system — user-selectable default layer with live preview in settings and onboarding
5. Multi-engine model catalog — WhisperKit + Parakeet (FluidAudio), gauge bars for accuracy/speed, catalog cleanup
6. Mic pill + recording overlay redesign — pill-shaped buttons, Canvas waveform at 60fps, processing animation

**Git range:** `feat(06-01)` -> `fix(10-04)`

### Known Gaps
- Cold start auto-return deferred to v1.2 (needs deeper research into competitor techniques)
- Text prediction memory budget needs real-device profiling (5MB keyboard extension limit)
- 11 human verification items pending device testing across phases 06, 09, 10
- 3 phases need Nyquist validation (07, 09, 10)

---

## v1.0 MVP (Shipped: 2026-03-07)

**Phases completed:** 5 phases, 18 plans
**Timeline:** 4 days (2026-03-04 -> 2026-03-07)
**Commits:** 137 | **Files:** 156 | **LOC:** 7,305 Swift

**Delivered:** A free, open-source iOS keyboard with on-device French speech-to-text via WhisperKit, AZERTY/QWERTY layouts, and iOS 26 Liquid Glass design.

**Key accomplishments:**
1. Two-process dictation architecture — keyboard extension triggers main app via Darwin notifications + URL scheme
2. On-device French speech-to-text — WhisperKit integration with model manager (5 Whisper models)
3. Wispr Flow-inspired dictation UX — mic tap, recording overlay with waveform/haptics, auto-insert into any text field
4. Full AZERTY/QWERTY keyboard — 3-layer layout, accented character long-press, shift/caps lock, delete repeat
5. iOS 26 Liquid Glass design — .glassEffect() throughout with Material fallback on iOS 16-25
6. Guided 5-step onboarding — mic permission, keyboard setup, model download, test dictation

**Git range:** `feat(01-01)` -> `refactor(05)`

### Known Gaps
- **STT-04** (Smart Model Routing): Dropped — runtime model switching breaks background recording. User selects model once.
- **APP-03** (Settings): 3/4 toggles wired in Phase 5. Language toggle functional but limited by Whisper model language support.
- SmartModelRouter code exists but bypassed at runtime (intentional)
- FullAccessBanner cannot open URLs from keyboard extension (iOS limitation)
- 6 design files duplicated between DictusApp and DictusKeyboard (manual sync required)

---

