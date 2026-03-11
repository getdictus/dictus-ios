# Project Research Summary

**Project:** Dictus v1.2 Beta Ready
**Domain:** iOS keyboard extension with on-device voice dictation (WhisperKit)
**Researched:** 2026-03-11
**Confidence:** MEDIUM-HIGH

## Executive Summary

Dictus v1.2 is a stabilization and polish release that prepares an existing two-process iOS keyboard dictation app for TestFlight beta distribution. The existing architecture (keyboard extension communicating via Darwin notifications and App Group with a main app that owns WhisperKit and the audio session) is validated and unchanged. The critical finding across all research is that **zero new SPM dependencies are needed** -- every v1.2 feature is served by built-in Apple frameworks and upgrades to existing custom code. This dramatically reduces integration risk for a beta release.

The recommended approach is a six-phase build that starts with production logging (enables debugging everything else), then fixes the most user-visible bug (animation state in the keyboard extension), then addresses cold start UX (the biggest user friction), then polishes the model download/compilation pipeline, then handles cosmetic polish, and finally gates everything behind TestFlight deployment. The cold start auto-return problem -- where the app opens in the foreground and the user must manually tap "< Back" -- has no public API solution. Research confirms this across Swift Forums, Apple Developer Forums, and competitor analysis (Wispr Flow). The pragmatic path is to accept the limitation, minimize cold start frequency (audio engine keep-alive), and make the transition graceful with clear UX messaging.

The top risks are: (1) logging user-dictated text to the persistent log file, which violates GDPR and triggers App Store rejection -- this must be designed out before writing any logging code; (2) CoreML compilation of Large Turbo v3 crashing on 4GB RAM devices, requiring a device capability gate; (3) missing Privacy Manifest (`PrivacyInfo.xcprivacy`) blocking all TestFlight submissions -- this should be validated with a smoke-test upload early, not discovered at the end. Total estimated effort is 8-12 days across all phases.

## Key Findings

### Recommended Stack

No stack changes. The existing technology set is validated and sufficient. See [STACK.md](STACK.md) for full details.

**Core technologies (unchanged):**
- **WhisperKit 0.16.0+ via SPM**: on-device speech-to-text -- mature, handles CoreML compilation internally
- **Swift 5.9+ / SwiftUI**: iOS 17.0 minimum -- enables `withAnimation(completion:)` and `PhaseAnimator`
- **DictusCore (local SPM package)**: shared framework for App Group, Darwin notifications, logging, design tokens
- **App Group (`group.com.pivi.dictus`)**: cross-process data sharing between app and keyboard extension

**New built-in APIs to leverage (no dependencies):**
- `OSLogStore` (iOS 15+) -- export structured logs for TestFlight bug reports
- `withAnimation(completion:)` (iOS 17+) -- coordinate animation state transitions
- `UIActivityViewController` -- share exported logs from Settings

### Expected Features

See [FEATURES.md](FEATURES.md) for full analysis including complexity estimates.

**Must have (table stakes for beta):**
- Production logging system with privacy safeguards and export
- CoreML pre-compilation progress UX during onboarding
- Model download progress UX with disk space checks
- Animation state consistency (fix stale recording overlay)
- TestFlight deployment (the exit gate)
- French accent audit across UI strings

**Should have (differentiators):**
- Cold start auto-return UX messaging (Flow Session pattern)
- Privacy-safe open-source logging (marketing differentiator)
- ANE protection with retry-on-failure for CoreML compilation

**Defer (post-beta):**
- Cloud logging / analytics (contradicts privacy identity)
- Background model downloads (URLSession delegate complexity)
- Automatic model updates (risky before beta)
- Real-time streaming transcription (scope creep)
- GitHub issue integration in logs (nice-to-have)
- Fastlane/CI automation (manual upload is fine for first builds)

### Architecture Approach

The existing two-process architecture is stable and requires no structural changes. See [ARCHITECTURE.md](ARCHITECTURE.md) for component diagrams and data flow.

**Major components to modify:**
1. **PersistentLog (DictusCore)** -- add log levels, process tags, privacy filtering, increased line cap. Consider per-process log files to eliminate cross-process file contention entirely
2. **KeyboardRootView + KeyboardState (DictusKeyboard)** -- include `.requested` status in overlay condition, add debounce on rapid status transitions, reset animation state on `viewWillAppear`
3. **ModelManager + ModelDownloadPage (DictusApp)** -- add retry-with-cleanup on prewarm failure, time-estimate-based progress indication, device RAM gating for large models

**One new component:**
- **ColdStartOverlay (DictusApp)** -- minimal recording UI shown when launched via `dictus://dictate` URL scheme with the app not running. Shows "Recording..." with a prominent "< Back" instruction

**New IPC addition:**
- `appLaunched` Darwin notification -- app posts immediately on cold-start URL launch, keyboard receives it to transition from `.requested` to `.recording` without waiting for the full engine warmup

### Critical Pitfalls

See [PITFALLS.md](PITFALLS.md) for the full list of 12 pitfalls with recovery strategies.

1. **PersistentLog concurrent write corruption** -- two processes writing to the same file without coordination. Fix: use per-process log files (`dictus_app.log`, `dictus_keyboard.log`) merged at display time, or use `O_APPEND` mode for atomic small writes
2. **Logging dictated text violates GDPR / App Store rules** -- `PersistentLog` writes plaintext with zero redaction. Fix: define privacy rules BEFORE writing code. Never log transcription text, keystrokes, or audio content. Use OSLog `.private` for development-only diagnostics
3. **Private API usage for auto-return causes App Store rejection** -- Apple's static analysis detects private APIs even via `#selector`. Fix: do NOT pursue programmatic auto-return. Use the Flow Session UX pattern (accept one manual tap on cold start)
4. **CoreML Large Turbo v3 compilation crashes on 4GB devices** -- ANE compilation requires 1-3GB of memory. Fix: gate large models behind `ProcessInfo.processInfo.physicalMemory >= 6_000_000_000`. Offer CPU+GPU fallback on constrained devices
5. **Missing Privacy Manifest blocks TestFlight** -- `PrivacyInfo.xcprivacy` required since May 2024 for both DictusApp and DictusKeyboard targets. Fix: create manifests and validate the upload pipeline early with a smoke-test archive

## Implications for Roadmap

Based on dependency analysis across all four research files, here is the suggested phase structure:

### Phase 1: Logging Foundation
**Rationale:** Every subsequent phase depends on production-quality logging for debugging. This is the infrastructure layer. Low risk, high enablement value.
**Delivers:** Production-ready PersistentLog with log levels, privacy filtering, process tags, export capability. DebugLogView with filtering and share. iOS 17 cleanup (remove unnecessary `#available` guards).
**Addresses:** Production logging system (table stakes), privacy-safe logging (differentiator)
**Avoids:** Pitfall 1 (concurrent write corruption), Pitfall 2 (logging user text), Pitfall 10 (DateFormatter allocation)
**Effort:** 1-2 days

### Phase 2: Animation State Fixes
**Rationale:** The most user-visible bug. Needs logging from Phase 1 to diagnose intermittent issues on device. Keyboard-only changes, low integration risk.
**Delivers:** Reliable recording/transcription overlay transitions. No more stuck states. Timestamp-based state validation, debounce on rapid status changes, `viewWillAppear` state reset.
**Addresses:** Animation state consistency (table stakes)
**Avoids:** Pitfall 7 (stale @State in persistent keyboard views)
**Effort:** 1-2 days

### Phase 3: Cold Start Audio Bridge UX
**Rationale:** Highest UX friction point. Depends on stable animation (Phase 2) and logging (Phase 1). New component (ColdStartOverlay) with clear boundaries.
**Delivers:** ColdStartOverlay view, `appLaunched` Darwin notification, cold-start detection in DictationCoordinator. User sees "Recording... tap < Back to return" instead of the full app UI.
**Addresses:** Cold start auto-return (differentiator -- UX messaging approach only)
**Avoids:** Pitfall 3 (private API rejection), Pitfall 6 (AVAudioSession conflicts)
**Effort:** 1-2 days

### Phase 4: CoreML Compilation + Model Download UX
**Rationale:** Isolated to the model pipeline, no IPC changes. Prevents the most frustrating onboarding failure (model compilation hang/crash). Must ship before beta testers download models.
**Delivers:** Retry-with-cleanup on prewarm failure, time-estimate progress indication, device RAM gating for large models, disk space pre-check, modal download protection against accidental navigation.
**Addresses:** CoreML pre-compilation UX (table stakes), model download UX (table stakes), ANE protection (differentiator)
**Avoids:** Pitfall 4 (CoreML crash on 4GB devices), Pitfall 8 (main thread blocking during downloads), Pitfall 9 (ANE contention)
**Effort:** 2-3 days

### Phase 5: Polish + French Accent Audit
**Rationale:** Cosmetic pass before beta. Low risk, high perceived quality impact. Includes the filler words toggle cleanup.
**Delivers:** Correct French accents in all UI strings, design polish across model manager/recording overlay/keyboard, filler words toggle decision (remove or fix).
**Addresses:** French accent audit (table stakes), design polish
**Avoids:** No critical pitfalls -- this is quality polish
**Effort:** 1-2 days

### Phase 6: TestFlight Deployment
**Rationale:** The exit gate. Must come last because everything above must be stable. Includes developer account migration, Privacy Manifest creation, provisioning profiles, and first archive/upload.
**Delivers:** Working TestFlight build distributed to beta testers. Privacy policy URL. App Store Connect metadata.
**Addresses:** TestFlight deployment (table stakes)
**Avoids:** Pitfall 5 (missing Privacy Manifest), Pitfall 12 (App Group ID change during account migration)
**Effort:** 1-2 days

### Phase Ordering Rationale

- **Logging first** because it enables debugging for all subsequent phases. Every research file identified logging as the prerequisite.
- **Animation before cold start** because the animation fix is contained within the keyboard extension, while cold start UX touches both processes. Fix the simpler, higher-visibility bug first.
- **Cold start before model UX** because cold start is the highest-friction user experience issue and has clear component boundaries (one new view, one new notification).
- **Model UX before polish** because model download/compilation failures during onboarding are beta-blocking, while French accents are not.
- **TestFlight last** because it is the quality gate. All features must be stable before submitting for Beta App Review.
- **Smoke-test the upload pipeline early** (Phase 1 timeframe) -- archive and upload the current v1.1 codebase to validate signing/manifest/entitlements before writing any v1.2 code. This avoids discovering blocking issues at the end.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (Cold Start Audio Bridge):** The auto-return mechanism remains unresolved. Research confirmed no public API exists. The PiP-based approach (Pitfall 3, Option C) is speculative and needs a spike. Recommend timeboxing to 1 day -- if PiP does not work, fall back to UX messaging only.
- **Phase 4 (CoreML Compilation):** ANE compilation timing is device-specific and opaque. Time estimates for the progress UI need real-device calibration. Budget testing time on at least 3 device tiers (4GB, 6GB, 8GB RAM).

Phases with standard patterns (skip additional research):
- **Phase 1 (Logging):** Well-documented Apple APIs (OSLog, OSLogStore). Straightforward extension of existing code.
- **Phase 2 (Animation):** Standard SwiftUI patterns. Root causes identified in code review.
- **Phase 5 (Polish):** No technical research needed, purely cosmetic.
- **Phase 6 (TestFlight):** Standard Apple deployment process, thoroughly documented.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Zero new dependencies. All built-in APIs verified against official documentation. |
| Features | HIGH | Feature list is well-scoped. Clear table stakes vs differentiators. Complexity estimates grounded in existing codebase knowledge. |
| Architecture | MEDIUM-HIGH | Existing architecture validated. New components (ColdStartOverlay) have clear boundaries. Cross-process file safety for logging needs real-device testing. |
| Pitfalls | HIGH | Based on project history (v1.0/v1.1 bugs), Apple documentation, WhisperKit GitHub issues, and Swift Forums. Concrete prevention strategies for each pitfall. |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Auto-return mechanism:** No public API confirmed. PiP-based approach is speculative. Must be validated with a spike early in Phase 3. Fallback (UX messaging) is ready.
- **CoreML compilation timing:** Progress estimates (10-40s by model size) are approximations from research, not measured on Dictus specifically. Need real-device calibration during Phase 4 implementation.
- **Cross-process log file safety:** The `O_APPEND` atomicity guarantee for regular files on APFS is de facto but not POSIX-guaranteed. Per-process log files (recommended by PITFALLS.md) eliminate this concern entirely. Decision needed at Phase 1 start.
- **App Group ID stability across team migration:** Research says the group ID is team-independent, but this must be verified on a real device with the new developer account before any v1.2 code ships.
- **Wispr Flow's exact return mechanism:** Research identified the "Flow Session" pattern but the precise iOS API used for auto-return remains unknown. LOW confidence this gap can be closed -- it may be a whitelisted behavior or undocumented API.

## Sources

### Primary (HIGH confidence)
- [Apple OSLogStore documentation](https://developer.apple.com/documentation/oslog/oslogstore)
- [Apple OSLogPrivacy documentation](https://developer.apple.com/documentation/os/oslogprivacy)
- [Apple Privacy Manifest documentation](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Apple TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple CoreML compileModel(at:) documentation](https://developer.apple.com/documentation/coreml/mlmodel/compilemodel(at:)-6442s)
- [Apple Custom Keyboard Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html)
- [Apple Background Execution](https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time)
- [Swift Forums: auto-return keyboard discussion](https://forums.swift.org/t/how-do-voice-dictation-keyboard-apps-like-wispr-flow-return-users-to-the-previous-app-automatically/83988)
- [WhisperKit Configurations.swift source](https://github.com/argmaxinc/whisperkit/blob/main/Sources/WhisperKit/Core/Configurations.swift)
- [WhisperKit issue #171: prewarmModels error](https://github.com/argmaxinc/WhisperKit/issues/171)

### Secondary (MEDIUM confidence)
- [WhisperKit issue #268: Unable to load model](https://github.com/argmaxinc/WhisperKit/issues/268)
- [KeyboardKit 10.2 blog](https://keyboardkit.com/blog/2026/01/09/keyboardkit-10-2)
- [Apple ml-stable-diffusion issue #255: ANECompiler failures](https://github.com/apple/ml-stable-diffusion/issues/255)
- [fatbobman: SwiftUI animation and state pitfalls](https://fatbobman.com/en/posts/serious-issues-caused-by-delayed-state-updates-in-swiftui/)
- [SwiftLee: OSLog and Unified Logging](https://www.avanderlee.com/debugging/oslog-unified-logging/)
- [iOS 17 SwiftUI animation bugs (Medium)](https://medium.com/@talessilveira/ios-17-swiftui-animation-bugs-6b8d8951d029)
- [Wispr Flow FAQ](https://docs.wisprflow.ai/iphone/faq)

### Tertiary (LOW confidence)
- [CocoaLumberjack issue #439: log files from extensions](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/439)
- Wispr Flow exact auto-return mechanism -- inferred from behavior, not documented

---
*Research completed: 2026-03-11*
*Ready for roadmap: yes*
