# Feature Landscape

**Domain:** iOS Keyboard Extension - Voice Dictation (v1.2 Beta Ready)
**Researched:** 2026-03-11
**Focus:** Production logging, cold start auto-return, CoreML compilation UX, model download UX, animation fixes, TestFlight deployment

## Table Stakes

Features users expect for a beta-quality dictation keyboard. Missing = beta feels broken.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|-------------|-------|
| Production logging system | Beta testers need to report bugs with context; devs need to debug without Xcode attached | Medium | Existing PersistentLog + DictusLogger | Upgrade existing system, don't rebuild from scratch |
| CoreML pre-compilation during onboarding | First transcription fails or lags 10-30s without prewarm; current spinner gives no progress feedback | Medium | Existing ModelManager.prewarming state | Already partially implemented; needs progress UX overhaul |
| Model download progress UX | Users abandon downloads without clear feedback; current ProgressView is minimal | Low | Existing downloadProgress dictionary | Polish, not rebuild |
| Animation state consistency | Stale recording overlay or stuck transcribing state breaks trust in the app | Medium | KeyboardState + RecordingOverlay | Cross-process state sync is the root cause |
| TestFlight deployment | Cannot distribute beta without it; this is the exit gate for v1.2 | Medium | Apple Developer account, signing, metadata | One-time setup + ongoing workflow |
| French accent audit | Missing accents in UI strings look unprofessional in a French-first app | Low | All UI string files | Grep + manual review |

## Differentiators

Features that set Dictus apart from competitors. Not strictly required for beta, but high value.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|-------------|-------|
| Cold start auto-return to keyboard | Eliminates the biggest UX friction: 2 mic taps needed on cold start vs 1 | **High** | NSExtensionContext, URL scheme, iOS limitations | Wispr Flow's key differentiator; no public API exists |
| Privacy-safe open-source logging | Competitors are cloud-based; Dictus can prove via code that it never logs speech content | Low | PersistentLog refactor | Marketing differentiator: "read our logging code" |
| ANE protection for CoreML compilation | Prevent "E5 bundle" crashes that brick model downloads | Medium | Existing isPrewarming lock | Already partially handled; needs robustness |
| GitHub issue integration in logs | One-tap "Report Bug" from debug view creates GitHub issue with sanitized logs | Medium | GitHub API, log sanitization | Unique for open-source keyboard apps |

## Anti-Features

Features to explicitly NOT build for v1.2.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Cloud logging / analytics | Contradicts privacy identity; open-source apps must not phone home | File-based logging only, user-initiated export |
| Crashlytics / Firebase | Binary SDK adds size, requires network, contradicts offline-first | OSLog + PersistentLog with user-exportable reports |
| Background model downloads | Adds URLSession delegate complexity, session restoration, lifecycle management | Foreground downloads with clear progress; defer to v2 |
| Automatic model updates | Could break working setup; users on limited data plans | Manual update check in Model Manager |
| Private API for auto-return | App Store rejection risk; Apple actively blocks these in iOS 18+ | Flow Session pattern (pre-launch app, then dictate from keyboard) |
| Real-time streaming transcription | Scope creep; batch approach works well | Keep batch transcription; streaming is v2+ |

---

## Detailed Feature Analysis

### 1. Production Logging System

**Current state:** PersistentLog writes timestamped strings to a file in App Group. DictusLogger provides OSLog categories (app, keyboard, appGroup). DebugLogView displays logs with copy/clear. No privacy controls, no structured data, no export.

**What to build:**

**Log Categories (extend DictusLogger):**
- `audio` -- AVAudioSession lifecycle, engine start/stop, configuration
- `dictation` -- recording start/stop/cancel, transcription timing, model used
- `keyboard` -- already exists; add key metrics (overlay shown/hidden, status transitions)
- `model` -- download progress, prewarm timing, ANE errors
- `ipc` -- Darwin notification sent/received, URL scheme handling

**Privacy Rules (CRITICAL for open-source):**

| ALWAYS Log | NEVER Log |
|-----------|-----------|
| Timestamps | Transcription text |
| Status transitions | Audio samples/buffers |
| Error messages | Keystrokes / typed text |
| Model identifiers | App bundle IDs (host apps) |
| Duration (seconds) | User location |
| Memory usage | File paths with usernames |
| iOS version, device class | Full file paths |
| ANE compilation timing | Any personal identifiers |

**OSLog Privacy Implementation:**
OSLog redacts dynamic strings by default in production builds (they show as `<private>` in Console). Only mark operational metadata as `.public`. Transcription text, if logged at all, must use the default `.private` level.

```swift
// GOOD: Public metadata
logger.info("Model \(modelName, privacy: .public) ready in \(duration, privacy: .public)s")

// GOOD: Redacted by default (strings are private by default)
logger.debug("Transcription completed: \(text)")

// BAD: Never do this
logger.info("User typed: \(keystroke, privacy: .public)")
```

**PersistentLog upgrade:**
- Add log levels: `.debug`, `.info`, `.warning`, `.error`
- Add category prefix: `[audio]`, `[dictation]`, `[ipc]`
- Increase maxLines from 200 to 500 for beta (more context for bug reports)
- Add structured session markers: `--- Session Start ---` with device info
- Dedicated serial queue for thread safety (replace DispatchQueue.global(qos: .utility))

**Export for GitHub Issues:**
- "Share Logs" button in DebugLogView that uses UIActivityViewController
- Auto-prepend device info header: iOS version, device model, app version, active model
- Strip any lines containing transcription text (defense in depth)
- Template for GitHub issue body with log attachment

**Confidence:** HIGH -- OSLog privacy levels are well-documented by Apple. PersistentLog upgrade is straightforward extension of existing code.

**Sources:**
- [Apple OSLogPrivacy docs](https://developer.apple.com/documentation/os/oslogprivacy)
- [Donny Wals: Modern logging with OSLog](https://www.donnywals.com/modern-logging-with-the-oslog-framework-in-swift/)
- [SwiftLee: OSLog and Unified Logging](https://www.avanderlee.com/debugging/oslog-unified-logging/)
- [Lord Codes: Clear and searchable logging with OSLog](https://www.lordcodes.com/articles/swift-logging-with-oslog/)

---

### 2. Cold Start Auto-Return (Audio Bridge Pattern)

**Current state:** When DictusApp is not running (cold start), the keyboard opens the app via `dictus://dictate` URL scheme. The app appears briefly, starts recording, but the user must manually tap the "< Back to [app]" status bar link to return to their previous app. Warm start (app alive in background) works seamlessly via Darwin notification -- no app switch visible.

**The core problem:** There is NO public iOS API to programmatically return to the previous app from a containing app opened by a keyboard extension. This is confirmed on Swift Forums, Apple Developer Forums, and by analyzing Wispr Flow's behavior.

**How Wispr Flow solves this (HIGH confidence on pattern, LOW on mechanism):**
Wispr Flow uses a "Flow Session" pattern:
1. User explicitly taps "Start Flow" in keyboard -- app opens
2. App activates a persistent audio session (UIBackgroundModes: audio)
3. App returns user to previous app (mechanism unclear -- possibly user taps back once, then all subsequent interactions are background-only)
4. From then on, mic button works via background Darwin notifications -- no app switch
5. Flow Session has a configurable timeout (5min, 15min, 1hr, never)
6. Their FAQ: "Not all apps allow the app to reopen" -- confirming it is NOT universal

**What Dictus can do (realistic approaches):**

**Approach A: Flow Session pattern with clear UX (RECOMMENDED)**
- Reframe the cold start as "session activation" in UX
- Show a clear "Tap < Back to return" instruction overlay when app opens for recording
- Auto-dismiss the overlay after 2s so the recording screen is visible
- After first activation, all subsequent recordings work in background (already implemented)
- Add session timeout concept: keep audio engine warm for configurable duration
- UX messaging: "Dictus needs to activate once per session. Tap < Back to return."

Complexity: **Low** -- mostly UX messaging changes, not architectural.

**Approach B: Minimize cold start frequency**
- Keep audio engine alive longer via background audio mode (already done)
- Add `beginBackgroundTask` to extend background time when recording finishes
- Attempt to pre-warm on significant location change or other background wake events
- Goal: cold start happens rarely enough that users tolerate it

Complexity: **Medium** -- background task management, battery impact testing needed.

**Approach C: Investigate NSExtensionContext behavior (SPECULATIVE)**
- `NSExtensionContext.open(URL)` from keyboard extension opens URLs
- Research whether opening a special URL after the app auto-backgrounds could trigger return
- This is the path most likely to be fragile across iOS versions

Complexity: **High** risk, **LOW confidence** of working.

**Recommendation:** Implement Approach A + B together. Accept that cold start requires one user tap, but minimize how often cold start occurs and make the UX clear when it does. This matches what Wispr Flow does in practice.

**Confidence:** MEDIUM -- the Flow Session pattern is well-understood from competitor analysis, but the exact return mechanism remains unclear.

**Sources:**
- [Swift Forums: How do keyboard apps return to previous app](https://forums.swift.org/t/how-do-voice-dictation-keyboard-apps-like-wispr-flow-return-users-to-the-previous-app-automatically/83988)
- [Wispr Flow App Store listing](https://apps.apple.com/us/app/wispr-flow-ai-voice-keyboard/id6497229487)
- [KeyboardKit: iOS 18 breaks selector-based URL opening](https://keyboardkit.com/blog/2024/09/11/ios18-breaks-selector-based-url-opening)
- [9to5Mac: Wispr Flow review](https://9to5mac.com/2025/06/30/wispr-flow-is-an-ai-that-transcribes-what-you-say-right-from-the-iphone-keyboard/)

---

### 3. CoreML Pre-Compilation UX

**Current state:** ModelManager has a `.prewarming` state that shows an indeterminate ProgressView spinner with "Preparation du modele..." text. WhisperKit's prewarm happens inside `WhisperKit(config)` init with `prewarm: true` -- no granular progress callback for CoreML compilation. The ANE serialization lock (`isPrewarming` flag with 500ms polling) prevents concurrent compilations.

**The problem:** CoreML compilation for Whisper models takes 10-30 seconds on first run. Users see a spinner with no indication of how long it will take. Large V3 Turbo model compilation can fail entirely with ANE "E5 bundle" errors (issue #16).

**What to build:**

**Progress indication strategy:**
CoreML model compilation does not expose per-layer progress callbacks. WhisperKit's init is a single async call. This means a real percentage bar for compilation is NOT possible.

**Realistic UX pattern -- phased progress with time estimates:**

| Phase | Progress Display | Source |
|-------|-----------------|--------|
| Download | Real % bar (0-100%) | WhisperKit progressCallback -- already implemented |
| Compilation | Indeterminate spinner + estimated time label | Timer-based estimate from model size |
| Verification | Quick check mark animation | Post-init verification |

**Time estimates by model (to display during compilation):**

| Model | Estimated Compile Time | Display Text |
|-------|----------------------|--------------|
| whisper-small | 10-15s | "Environ 15 secondes..." |
| whisper-large-v3 | 25-40s | "Environ 30 secondes..." |
| whisper-large-v3-turbo | 20-35s | "Environ 30 secondes..." |
| parakeet-* | 15-25s | "Environ 20 secondes..." |

**Implementation:**
- Start a timer when entering `.prewarming` state
- Display elapsed time + estimated remaining: "Optimisation pour votre appareil... (12s / ~30s)"
- Show "Ne quittez pas l'application" warning (compilation fails if app is backgrounded)
- If compilation exceeds 2x estimated time, show "Cela prend plus longtemps que prevu"
- Animated progress ring that fills based on elapsed/estimated ratio (not real progress, but psychologically satisfying)

**ANE protection (robustness):**
- Catch ANE "E5 bundle" errors specifically and offer retry with 3-second delay
- Add 2-second delay between sequential compilations (replace busy-wait polling with Task.sleep)
- If compilation fails 2x consecutively, offer to skip prewarm ("Compile on first use" option)
- Log compilation timing per model to PersistentLog for diagnostics
- Detect device thermal state via `ProcessInfo.processInfo.thermalState` -- warn user if `.serious` or `.critical`

**Onboarding integration:**
- Move model download to step 3 (before keyboard setup) so users do something useful while compilation runs
- Show "this is a one-time setup" messaging
- Disable the back button during compilation to prevent orphaned states
- Auto-advance to next page when compilation completes

**Confidence:** MEDIUM -- CoreML compilation internals are opaque. Time estimates are approximations that need real-device calibration. ANE error handling paths need testing.

---

### 4. Model Download UX Overhaul

**Current state:** ModelDownloadPage shows a ProgressView bar with percentage during download, then switches to indeterminate spinner during prewarm. ModelManagerView (settings) shows per-model states. No modal blocking, no app-backgrounding protection.

**What to build:**

**Modal download sheet (settings context):**
- When downloading from Model Manager, present a `.sheet` modal that cannot be dismissed during download
- Show: model name, size, download progress, phase label (Telechargement / Optimisation)
- Prevent accidental navigation away during CoreML compilation
- Use `interactiveDismissDisabled(true)` during active download/compilation

**Onboarding reorder:**
Current: Welcome > Mic Permission > Mode Selection > Model Download > Keyboard Setup > Test
Better: Welcome > Mic Permission > **Model Download** > Keyboard Setup > Mode Selection > Test

Why: Model download + compilation takes 1-2 minutes. By doing it at step 3, the longest step is not last, reducing perceived wait time.

**App backgrounding protection:**
- Detect app about to background via `.onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification))`
- Show "Le telechargement sera interrompu si vous quittez" warning
- On return, resume download if possible (WhisperKit download uses URLSession, may be resumable)
- CoreML compilation: if interrupted, clean up partial files and offer retry

**Download size display:**
- Show estimated download size before starting (already partially there: "~500 Mo" in card)
- Show downloaded/total bytes during download: "245 Mo / 500 Mo"
- Show disk space required (download needs ~2x due to extraction): "Espace necessaire: ~1 Go"
- Check available disk space before starting download, warn if insufficient

**Confidence:** HIGH -- standard iOS UX patterns applied to existing infrastructure.

---

### 5. SwiftUI Animation State Management

**Current state:** KeyboardState is an ObservableObject reading dictation status from App Group via Darwin notifications. RecordingOverlay renders based on `isTranscribing` and `waveformEnergy` props. Known bug: recording/transcription animation sometimes gets stuck or shows stale state.

**Root causes of stale animation state in keyboard extensions:**

1. **Cross-process sync lag:** Darwin notifications + UserDefaults propagation has variable latency (0-500ms). The keyboard may show `.recording` while the app has already moved to `.transcribing`.

2. **Extension lifecycle:** iOS can suspend and resume keyboard extensions without full view lifecycle callbacks. @State values persist but @Published values from ObservableObject may be stale after resume.

3. **Duplicate notifications:** Darwin notifications can be delivered multiple times. Status transitions may fire out of order.

4. **No timestamp validation:** Current `refreshFromDefaults()` reads status without checking if it's newer than what it already has.

**Best practices for reliable animation state:**

**Pattern 1: Timestamp-based state validation**
Write status WITH timestamp in App Group. In keyboard, only update if timestamp is newer than last known. This prevents stale re-delivery from overwriting current state.

**Pattern 2: Explicit animation scoping with .animation(_:value:)**
Tie animations to specific value changes. Avoid the deprecated parameterless `.animation(.spring)` which animates all state changes including stale recovery.

**Pattern 3: NotificationCenter bridge for lifecycle events**
Force state refresh on `UIApplication.didBecomeActiveNotification` (already noted in PROJECT.md as a key decision). Extend to keyboard extension lifecycle: refresh on `viewWillAppear` via hosting controller.

**Pattern 4: Timeout-based state recovery**
If status is `.recording` but no waveform updates arrive for 3 seconds, force-reset to `.idle`. If status is `.transcribing` for > 30 seconds, reset. This prevents permanent stuck states.

**Pattern 5: @GestureState over @State for interactive animations**
For gesture-driven animations (long press on mic button), @GestureState auto-resets on interruption. @State does NOT reset on gesture interruption, leaving views stuck in interactive state.

**What to build:**
- Add timestamp validation to `KeyboardState.refreshFromDefaults()`
- Add 3-second timeout watchdog for `.recording` state (no waveform = stale)
- Add 30-second timeout for `.transcribing` state
- Scope all RecordingOverlay animations with `.animation(_:value:)` explicitly
- Force state refresh on extension lifecycle events (`viewWillAppear`, `didBecomeActive`)
- Add `.idle` recovery path from any stuck state

**Confidence:** HIGH -- these are well-understood SwiftUI patterns. The cross-process aspect follows standard Darwin notification patterns already in use.

**Sources:**
- [Mindful Chase: Fixing State Management in SwiftUI](https://www.mindfulchase.com/explore/troubleshooting-tips/fixing-state-management,-ui-rendering-delays,-and-animation-issues-in-swiftui.html)
- [Fatbobman: @GestureState vs @State differences](https://fatbobman.com/en/snippet/differences-between-gesturestate-and-state-in-swiftui/)

---

### 6. TestFlight Beta Deployment

**Current state:** No TestFlight setup. Project uses personal development signing, needs migration to professional developer account.

**What's needed:**

**One-time setup:**

| Requirement | Status | Action |
|-------------|--------|--------|
| Apple Developer Program membership ($99/yr) | Needed | Enroll or verify enrollment |
| App Store Connect app record | Not created | Create with bundle ID com.pivi.dictus |
| Provisioning profiles (distribution) | Personal dev only | Generate distribution profiles for App + Keyboard Extension |
| App Group capability in distribution profile | Needed | Ensure both targets share group.com.pivi.dictus |
| Keyboard extension entitlements | Needed | RequestsOpenAccess in distribution profile |
| Privacy Policy URL | Not created | Required for apps requesting Full Access keyboard; host on GitHub Pages or repo |

**Metadata required for TestFlight:**

| Field | Value | Notes |
|-------|-------|-------|
| App Name | Dictus | Must match across all localizations |
| Bundle ID | com.pivi.dictus | Already set |
| Primary Language | French (fr-FR) | French-first app |
| App Category | Utilities | Best fit for keyboard apps |
| Beta App Description | Description in French explaining app + what to test | Required for external testers |
| Beta App Review Info | Contact, notes for reviewer explaining Full Access need | Required for first external build |
| What to Test | Testing instructions (mic button, dictation flow, model download) | Strongly recommended |
| Feedback Email | Pierre's contact email | Required |
| Privacy Policy URL | URL explaining on-device processing, no data transmission | **Required** for Full Access keyboard |
| App Icon | 1024x1024 | Already generated |

**Build submission workflow:**

1. Set version to 1.2.0, build number to 1
2. Archive in Xcode (Product > Archive)
3. Upload to App Store Connect (Xcode Organizer > Distribute App)
4. Wait for processing (5-30 minutes)
5. Add build to internal testing group (up to 100 testers, no review needed)
6. For external testers: submit for Beta App Review (required for first build of a new version)
7. Once approved, share public link or invite external testers (up to 10,000)

**Keyboard extension specific review notes:**
- Must explain why Full Access (microphone) is needed in review notes
- Must have a hosted privacy policy explaining on-device-only processing
- "No data is transmitted to any server" -- key messaging for reviewer
- Open-source nature (MIT license, GitHub link) reinforces privacy claims
- Reviewer will test that the keyboard works in at least one host app

**Subsequent builds:**
Once the first build of v1.2.0 is approved for external testing, subsequent builds with the same version but incremented build number (v1.2.0 build 2, build 3...) are typically approved much faster, often automatically.

**Automation (recommended for ongoing beta iterations):**
- Use `xcodebuild archive` + `xcrun altool --upload-app` for CLI uploads
- Or fastlane's `testflight` action for full automation
- Increment build number automatically via build script or Xcode build phase
- Defer automation to after first manual upload succeeds

**Confidence:** HIGH -- TestFlight workflow is well-documented and stable. Keyboard extension review has specific requirements but they are documented in App Review Guidelines.

**Sources:**
- [Apple TestFlight Overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Apple TestFlight Developer Page](https://developer.apple.com/testflight/)
- [QED42: Comprehensive Guide to TestFlight](https://www.qed42.com/insights/a-comprehensive-guide-to-deploying-apps-to-testflight-for-seamless-testing)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Kodeco: TestFlight Essentials](https://www.kodeco.com/10868372-testflight-essentials-quickstart-guide-for-ios-beta-testing)

---

## Feature Dependencies

```
French accent audit (standalone, no dependencies)
    |
Logging system upgrade --> Animation state fixes (logging needed to debug animation issues)
    |
    v
CoreML compilation UX --> Model download UX overhaul (share progress infrastructure)
    |
    v
Cold start auto-return (needs stable recording pipeline + good logging for debugging)
    |
    v
TestFlight deployment (everything above must be stable before beta)
```

## MVP Recommendation

**Must have for v1.2 beta (in implementation order):**

1. **Production logging system** -- enables debugging everything else; LOW risk, MEDIUM effort
2. **French accent audit** -- quick win, no risk; LOW effort
3. **Animation state fixes** -- fixes the most visible bug; MEDIUM effort
4. **CoreML compilation UX + model download UX** -- prevents user-facing failures; MEDIUM effort
5. **Cold start auto-return (Approach A: UX messaging only)** -- reduces friction with minimal code; LOW effort
6. **TestFlight deployment** -- the exit gate; MEDIUM effort (one-time setup)

**Defer to post-beta:**
- Cold start auto-return Approach B (background optimization) -- needs real-device battery testing over days
- GitHub issue integration in logs -- nice to have, not blocking beta
- Download automation via fastlane -- manual upload is fine for first few builds
- Automatic model updates -- too risky to add right before beta

## Complexity Budget

| Feature | Est. Effort | Risk | Phase Recommendation |
|---------|------------|------|---------------------|
| Logging system | 1-2 days | Low | Phase 1 (foundation) |
| French accent audit | 0.5 days | Low | Phase 1 (quick win) |
| Animation state fixes | 1-2 days | Medium | Phase 2 (needs logging) |
| CoreML + download UX | 2-3 days | Medium | Phase 3 (UX polish) |
| Cold start UX messaging | 0.5-1 day | Low | Phase 4 (UX improvement) |
| Design polish (various) | 1-2 days | Low | Phase 5 (visual) |
| TestFlight setup + deploy | 1-2 days | Medium | Phase 6 (final gate) |
| **Total** | **~8-12 days** | | |
