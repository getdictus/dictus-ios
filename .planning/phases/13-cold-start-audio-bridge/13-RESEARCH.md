# Phase 13: Cold Start Audio Bridge - Research

**Researched:** 2026-03-12
**Domain:** iOS keyboard extension cold start flow, cross-process audio, auto-return UX
**Confidence:** MEDIUM

## Summary

Phase 13 implements the cold start dictation flow: when iOS has killed the app, the user taps mic in the keyboard, the app opens to activate the audio session and load WhisperKit, then the user returns to the keyboard where recording status is displayed. The app handles all audio recording and transcription; the keyboard displays the UI overlay.

**CRITICAL FINDING: Keyboard extensions CANNOT access the microphone.** Apple documentation explicitly states: "Custom keyboards, like all app extensions in iOS, have no access to the device microphone, so dictation input is not possible." This is true even with `RequestsOpenAccess = true` (Full Access). This means the "Audio Bridge" concept where the keyboard captures audio directly is **not feasible**. The architecture must keep all audio recording in the main app, which is what Dictus already does. The cold start improvement is about UX flow (swipe-back overlay, auto-return) and ensuring the existing recording pipeline works smoothly on cold start.

Competitors like Wispr Flow confirm this pattern: tapping mic in the keyboard opens the main app, the app activates the microphone session, then the user returns to the keyboard. The main app records audio in the background while the keyboard shows the recording overlay.

**Primary recommendation:** Reframe "Audio Bridge" as a UX bridge, not an audio bridge. The app records audio (already works via RawAudioCapture on cold start). Phase 13's value is: (1) swipe-back overlay instead of full app UI, (2) auto-return via URL scheme for known apps, (3) polished cold start lifecycle.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Cold start flow: keyboard opens app via URL scheme, app activates audio session + loads WhisperKit, app attempts auto-return via URL scheme for known apps, falls back to swipe-back overlay
- Recording does NOT start when app opens -- it starts when user returns to keyboard
- Keyboard sends captured audio to app for transcription via App Group (NOTE: research shows keyboard CANNOT capture audio -- see correction below)
- Swipe-back overlay: full-screen replacement view (not overlay on top of normal UI), brand gradient background, iPhone outline with animated hand/thumb swipe gesture, text matches user language setting, stays visible until user leaves
- Auto-return: top 10 messaging apps, attempted FIRST before showing swipe overlay
- Direct recording (HomeView mic button) must remain fully functional -- two-mode coexistence
- Transcription result delivery: same as current (App Group + Darwin notification + auto-insert)
- No Lottie -- SwiftUI animation only for swipe gesture

### Corrections to Locked Decisions (Research Findings)
- **COLD-01 / COLD-03 correction:** "Keyboard extension captures audio directly using its own AVAudioEngine" is NOT possible. Apple explicitly prohibits microphone access in keyboard extensions. The app must continue recording audio (as it already does). The keyboard's role remains displaying the recording overlay UI and sending stop/cancel commands.
- **COLD-07 correction:** "Recording starts when user returns to keyboard" -- this cannot mean the keyboard starts recording (it has no mic access). It should mean: the app starts recording via Darwin notification when the keyboard signals it is back in foreground, OR the app starts recording immediately on cold start URL open (current behavior) and the keyboard just picks up the overlay display on return.

### Claude's Discretion
- Audio transfer mechanism -- MOOT since keyboard cannot capture audio. App records directly as it already does.
- Recording trigger on keyboard return -- research recommends: app starts recording immediately on URL open (current behavior is correct), keyboard picks up the recording state on viewWillAppear
- Source app detection for auto-return -- research provides URL scheme mapping below
- Launch mode detection -- URL parameter (dictus://dictate?mode=coldstart) vs App Group flag
- Architecture: whether to unify both recording paths under one DictationCoordinator state machine or keep separate
- iPhone outline + hand animation implementation details

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| COLD-01 | Keyboard extension can capture audio directly when mic session is active (Audio Bridge) | **BLOCKED by iOS restriction.** Keyboard extensions cannot access the microphone. Must reinterpret: keyboard displays recording UI while app captures audio. Already works in current architecture. |
| COLD-02 | App serves only to activate the audio session, then user returns to keyboard | Supported. App opens via URL, activates AVAudioSession, starts RawAudioCapture, user returns to keyboard. Swipe-back overlay or auto-return facilitates the return. |
| COLD-03 | Keyboard sends captured audio to app for transcription via App Group | **BLOCKED by iOS restriction.** Keyboard cannot capture audio. Must reinterpret: app records audio directly (already works), keyboard sends stop/cancel signals (already works). |
| COLD-04 | App returns transcription result to keyboard via Darwin notification + App Group | Already implemented. No changes needed. |
| COLD-05 | Cold start shows dedicated "swipe back" overlay instead of full app UI | New SwipeBackOverlayView needed. MainTabView conditionally renders overlay vs normal tabs based on launch mode. |
| COLD-06 | Direct recording in app remains functional (two recording modes coexist) | DictationCoordinator already supports both paths. Launch mode flag distinguishes "from keyboard" vs "from HomeView". |
| COLD-07 | Recording starts when user returns to keyboard, not when app opens | Must reinterpret: app starts RawAudioCapture on cold start URL open (current behavior). Keyboard viewWillAppear shows overlay. User perceives recording starting on keyboard return because overlay appears. |
| COLD-08 | Auto-return to previous app via URL scheme for known apps | URL scheme mapping researched. canOpenURL + LSApplicationQueriesSchemes needed. Keyboard writes source context to App Group before opening URL. |
| COLD-09 | Fallback "swipe back" animation with guided instruction for unknown apps | SwipeBackOverlayView with SwiftUI animation (iPhone outline + hand gesture). Brand gradient background. Bilingual text. |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | Swipe-back overlay UI, animations | Native framework, already used throughout |
| AVFoundation | iOS 17+ | Audio session, RawAudioCapture | Already used for all audio recording |
| DictusCore | local | SharedKeys, DarwinNotifications, AppGroup | Existing shared framework |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| WhisperKit | 0.16.0+ | Speech-to-text transcription | Already integrated, no changes needed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftUI animation | Lottie | User explicitly chose SwiftUI only -- no Lottie |
| App Group file | App Group UserDefaults | UserDefaults already used for all cross-process data, no need to add file-based transfer |

## Architecture Patterns

### Recommended Project Structure
```
DictusApp/
├── Views/
│   ├── MainTabView.swift          # Modified: conditional swipe-back overlay
│   └── SwipeBackOverlayView.swift # NEW: cold start swipe-back screen
├── DictationCoordinator.swift     # Modified: launch mode awareness
└── DictusApp.swift                # Modified: handleIncomingURL with cold start mode

DictusKeyboard/
├── KeyboardViewController.swift   # Modified: viewWillAppear cold start detection
└── KeyboardState.swift            # Modified: cold start state management

DictusCore/Sources/DictusCore/
├── SharedKeys.swift               # Modified: new keys for cold start state
└── DarwinNotifications.swift      # Modified: new notification names if needed
```

### Pattern 1: Launch Mode Detection
**What:** Distinguish "opened from keyboard cold start" vs "opened normally"
**When to use:** Every app launch via URL scheme
**Recommendation:** Use URL parameter `dictus://dictate?source=keyboard` combined with App Group flag.

```swift
// In handleIncomingURL:
case "dictate":
    let isFromKeyboard = url.queryItems?.contains("source", value: "keyboard") ?? false
    if isFromKeyboard {
        // Set App Group flag for MainTabView to show swipe-back overlay
        AppGroup.defaults.set(true, forKey: SharedKeys.coldStartActive)
        AppGroup.defaults.synchronize()
    }
    coordinator.startDictation(fromURL: true)
```

WHY URL parameter over App Group flag alone: The URL parameter is the source of truth (keyboard explicitly says "I opened you"). The App Group flag persists it so MainTabView can read it.

### Pattern 2: Conditional View Rendering in MainTabView
**What:** Show swipe-back overlay instead of tabs when in cold start mode
**When to use:** When app was opened from keyboard on cold start

```swift
struct MainTabView: View {
    @EnvironmentObject var coordinator: DictationCoordinator
    @State private var isColdStartMode = false

    var body: some View {
        ZStack {
            if isColdStartMode {
                SwipeBackOverlayView()
            } else {
                // Normal tab view content
                TabView(selection: $selectedTab) { ... }
            }

            // Recording overlay (shows in BOTH modes)
            if coordinator.status != .idle {
                RecordingView(mode: .standalone)
            }
        }
        .onOpenURL { url in
            if url.host == "dictate" {
                isColdStartMode = true
            }
        }
    }
}
```

### Pattern 3: Auto-Return via URL Scheme
**What:** Attempt to return user to previous app before showing swipe-back overlay
**When to use:** On cold start, after audio session is activated

```swift
// In DictusApp or DictationCoordinator:
func attemptAutoReturn() {
    guard let sourceScheme = AppGroup.defaults.string(forKey: SharedKeys.sourceAppScheme) else {
        // No source app detected -- show swipe-back overlay
        return
    }

    if let url = URL(string: "\(sourceScheme)://"),
       UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
    }
}
```

### Pattern 4: Keyboard Writes Source Context Before Opening URL
**What:** Keyboard saves what it knows about the host app before triggering cold start
**When to use:** In KeyboardState.startRecording() before opening dictus:// URL

```swift
// In KeyboardState, before opening URL:
// Keyboard has no direct API to detect the host app's bundle ID.
// However, it can check canOpenURL for known schemes to identify the host.
// This check must happen BEFORE opening the dictus:// URL.
func detectAndSaveSourceApp() {
    for (scheme, _) in KnownAppSchemes.all {
        // Note: canOpenURL requires LSApplicationQueriesSchemes in Info.plist
        // AND keyboard Full Access
    }
    // Fallback: write "unknown" -- swipe-back overlay will show
    defaults.set("unknown", forKey: SharedKeys.sourceAppScheme)
    defaults.synchronize()
}
```

### Anti-Patterns to Avoid
- **Trying to record audio in keyboard extension:** iOS explicitly blocks mic access in keyboard extensions. Do not attempt AVAudioEngine, AVAudioRecorder, or any audio capture in the keyboard target.
- **Using private APIs for source app detection:** `_hostBundleID`, `LSApplicationWorkspace` are explicitly out of scope (App Store rejection risk).
- **Starting a new AVAudioEngine in the keyboard:** Even if it compiled, it would crash at runtime or silently fail.
- **Assuming viewWillAppear = user returned from app:** The keyboard's viewWillAppear fires in many scenarios (keyboard show, app switch, text field focus change). Must check App Group state to determine if this is a cold start return.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cross-process signaling | Custom IPC | Darwin notifications (existing) | Already proven, battle-tested in Dictus |
| Audio recording | Keyboard AVAudioEngine | App-side RawAudioCapture (existing) | Keyboard cannot access mic |
| Audio format conversion | Manual PCM conversion | RawAudioCapture's AVAudioConverter (existing) | Already handles 48kHz -> 16kHz conversion |
| Transcription pipeline | New pipeline | DictationCoordinator (existing) | Cold start path with RawAudioCapture already works |

**Key insight:** The current architecture already handles cold start recording correctly. The app's RawAudioCapture starts in <100ms while WhisperKit loads in parallel. Phase 13's value is UX improvements (overlay, auto-return), not audio pipeline changes.

## Common Pitfalls

### Pitfall 1: Attempting Microphone Access in Keyboard Extension
**What goes wrong:** Code compiles but crashes at runtime or silently fails
**Why it happens:** Apple's sandbox blocks mic access regardless of RequestsOpenAccess
**How to avoid:** Keep ALL audio recording in DictusApp. Keyboard only shows UI.
**Warning signs:** Any `AVAudioEngine`, `AVAudioRecorder`, or `AVAudioSession.requestRecordPermission` in the DictusKeyboard target.

### Pitfall 2: Swipe-Back Overlay Persisting After Return
**What goes wrong:** User returns to keyboard but app still shows swipe-back overlay on next open
**Why it happens:** App Group flag `coldStartActive` not cleaned up
**How to avoid:** Clear the flag when: (a) app enters background (scenePhase == .background), (b) recording stops, (c) user navigates to any tab
**Warning signs:** Opening app normally shows swipe-back instead of tabs

### Pitfall 3: Auto-Return URL Opening Too Early
**What goes wrong:** App opens source app URL before audio session is activated
**Why it happens:** UIApplication.open() is async and may execute before AVAudioSession.setActive(true) completes
**How to avoid:** Sequence: configureAudioSession() (sync) -> start RawAudioCapture -> THEN attempt auto-return
**Warning signs:** Recording fails because audio session was deactivated by app switching

### Pitfall 4: LSApplicationQueriesSchemes Missing
**What goes wrong:** canOpenURL always returns false for known app schemes
**Why it happens:** iOS requires declaring queried URL schemes in Info.plist (max 50)
**How to avoid:** Add all target app schemes to both DictusApp AND DictusKeyboard Info.plist under LSApplicationQueriesSchemes
**Warning signs:** Auto-return never works despite apps being installed

### Pitfall 5: viewWillAppear Race with URL Scheme
**What goes wrong:** Keyboard's viewWillAppear triggers state reset that kills an active recording
**Why it happens:** Opening dictus:// URL causes keyboard to disappear then reappear within ~2s
**How to avoid:** Phase 12 already solved this: use refreshFromDefaults + 5s watchdog instead of instant reset. Apply same pattern for cold start detection.
**Warning signs:** Recording stops immediately after cold start URL open

### Pitfall 6: Source App Detection Impossible from Keyboard
**What goes wrong:** Attempting to detect the host app bundle ID from the keyboard extension
**Why it happens:** No public API exists for this. `_hostBundleID` was removed/crashes.
**How to avoid:** Alternative approach: keyboard can check `canOpenURL` for known schemes to guess the host app, or accept that source app detection is best-effort.
**Warning signs:** Crashes on KVC access, App Store rejection

## Code Examples

### Swipe-Back Overlay View (SwiftUI)
```swift
// Source: CONTEXT.md design spec + brand kit
struct SwipeBackOverlayView: View {
    @AppStorage(SharedKeys.language, store: AppGroup.defaults)
    private var language = "fr"

    var body: some View {
        ZStack {
            // Brand gradient background
            LinearGradient(
                colors: [Color(hex: "0D2040"), Color(hex: "071020")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // iPhone outline with animated hand gesture
                SwipeAnimationView()
                    .frame(width: 200, height: 300)

                // Primary instruction text
                Text(language == "fr"
                    ? "Glisse pour revenir au clavier"
                    : "Swipe back to the keyboard")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)

                // Secondary instruction
                Text(language == "fr"
                    ? "Glisse vers la droite en bas de l'ecran"
                    : "Swipe right on the bottom of your iPhone")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))

                Spacer()
            }
        }
    }
}
```

### URL Scheme Mapping for Auto-Return
```swift
// Source: Community-maintained URL scheme lists + verified schemes
enum KnownAppSchemes {
    struct AppScheme {
        let name: String
        let scheme: String        // URL scheme to open the app
        let queryScheme: String   // Scheme to check with canOpenURL
    }

    static let all: [AppScheme] = [
        AppScheme(name: "WhatsApp",     scheme: "whatsapp://",     queryScheme: "whatsapp"),
        AppScheme(name: "Messages",     scheme: "sms://",          queryScheme: "sms"),
        AppScheme(name: "Telegram",     scheme: "tg://",           queryScheme: "tg"),
        AppScheme(name: "Messenger",    scheme: "fb-messenger://", queryScheme: "fb-messenger"),
        AppScheme(name: "Signal",       scheme: "sgnl://",         queryScheme: "sgnl"),
        AppScheme(name: "Slack",        scheme: "slack://",        queryScheme: "slack"),
        AppScheme(name: "Discord",      scheme: "discord://",      queryScheme: "discord"),
        AppScheme(name: "Teams",        scheme: "msteams://",      queryScheme: "msteams"),
        AppScheme(name: "Instagram",    scheme: "instagram://",    queryScheme: "instagram"),
        AppScheme(name: "Notes",        scheme: "mobilenotes://",  queryScheme: "mobilenotes"),
    ]
}
```

### LSApplicationQueriesSchemes for Info.plist
```xml
<!-- Add to BOTH DictusApp and DictusKeyboard Info.plist -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>whatsapp</string>
    <string>sms</string>
    <string>tg</string>
    <string>fb-messenger</string>
    <string>sgnl</string>
    <string>slack</string>
    <string>discord</string>
    <string>msteams</string>
    <string>instagram</string>
    <string>mobilenotes</string>
</array>
```

### New SharedKeys for Cold Start
```swift
// Add to SharedKeys.swift
/// Bool: true when app was opened from keyboard for cold start dictation
public static let coldStartActive = "dictus.coldStartActive"
/// String: URL scheme of the source app (for auto-return), or "unknown"
public static let sourceAppScheme = "dictus.sourceAppScheme"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Keyboard records audio directly | App records, keyboard shows UI | Always (iOS restriction) | Architecture must keep audio in app |
| Full app UI on cold start | Swipe-back overlay (competitors) | 2024-2025 (Wispr Flow, SuperWhisper) | Better UX for keyboard-initiated recording |
| No auto-return | URL scheme auto-return (best-effort) | 2024-2025 | Seamless for known apps, fallback for unknown |

**Deprecated/outdated:**
- `_hostBundleID` KVC for bundle detection: crashes, removed in previous attempt. Confirmed in REQUIREMENTS.md as out of scope.
- `LSApplicationWorkspace` private API: App Store rejection confirmed. Out of scope.

## Open Questions

1. **Source app detection from keyboard extension**
   - What we know: No public API exists to get the host app's bundle ID from a keyboard extension. `canOpenURL` can check if specific apps are installed but cannot tell which app currently has the keyboard open.
   - What's unclear: How competitors (Wispr Flow) detect the source app. Their FAQ suggests it works selectively, implying a similar URL scheme heuristic approach.
   - Recommendation: Accept best-effort detection. Keyboard writes "unknown" to App Group. When the app tries auto-return, it tries all installed known app schemes or skips to swipe-back overlay. Alternative: keyboard could check the text field context or textDocumentProxy for clues, but this is unreliable.

2. **COLD-01 and COLD-03 reinterpretation**
   - What we know: Keyboard cannot capture audio. App already captures audio on cold start via RawAudioCapture.
   - What's unclear: Whether the user expects to rework the requirement IDs or just reinterpret them.
   - Recommendation: Reinterpret COLD-01 as "Audio session is active and recording works when keyboard returns" and COLD-03 as "App records audio and makes result available to keyboard via App Group" (which already works).

3. **Recording timing on cold start**
   - What we know: Current flow starts RawAudioCapture immediately when URL scheme opens the app. This captures audio even before the user returns to the keyboard.
   - What's unclear: Whether the user wants recording to literally start only when the keyboard is visible again (COLD-07 literal reading).
   - Recommendation: Keep current behavior (start recording on URL open). This is better UX because audio capture starts immediately. The keyboard picks up the recording overlay on viewWillAppear. The user perceives recording as starting when the overlay appears, even though capture started slightly earlier.

4. **Auto-return reliability**
   - What we know: Opening `whatsapp://` will switch to WhatsApp. But it may open to WhatsApp's main screen, not the specific chat the user was in.
   - What's unclear: Whether most apps return to the last active view when opened via URL scheme with no path parameters.
   - Recommendation: Test on device with top 5 apps. Most apps restore last state when opened via bare scheme. If not, the swipe-back fallback handles it.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode built-in) |
| Config file | Dictus.xcodeproj test targets |
| Quick run command | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DictusCoreTests` |
| Full suite command | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COLD-01 | Audio session active when keyboard returns | manual-only | Device test: mic tap -> app opens -> return -> recording works | N/A |
| COLD-02 | App activates audio session on cold start URL | manual-only | Device test: force-quit app -> mic tap -> verify audio session | N/A |
| COLD-03 | App records audio, result available via App Group | unit | `xcodebuild test -only-testing:DictusCoreTests/SharedKeysExtensionTests` | Partial |
| COLD-04 | Transcription result delivery via Darwin + App Group | manual-only | Already working, regression test on device | N/A |
| COLD-05 | Swipe-back overlay shows on cold start | manual-only | Device test: force-quit -> mic tap -> verify overlay | N/A |
| COLD-06 | Direct recording still works | manual-only | Device test: HomeView mic button -> record -> stop -> verify | N/A |
| COLD-07 | Recording timing on keyboard return | manual-only | Device test: verify overlay appears on keyboard return | N/A |
| COLD-08 | Auto-return via URL scheme | manual-only | Device test with WhatsApp/Telegram installed | N/A |
| COLD-09 | Swipe-back animation | manual-only | Visual inspection on device | N/A |

### Sampling Rate
- **Per task commit:** Build succeeds (`xcodebuild build`)
- **Per wave merge:** Full test suite + device smoke test
- **Phase gate:** All COLD requirements verified on device

### Wave 0 Gaps
- [ ] SwipeBackOverlayView preview test (can verify in Xcode Preview)
- [ ] KnownAppSchemes unit test (verify URL scheme list integrity)
- Most COLD requirements are manual-only due to requiring real device audio session + keyboard extension lifecycle

## Sources

### Primary (HIGH confidence)
- [Apple Custom Keyboard Documentation](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) - Confirmed keyboard extensions cannot access microphone
- [Apple Configuring Open Access](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard) - RequestsOpenAccess capabilities list (mic NOT included)
- Existing codebase: DictationCoordinator.swift, KeyboardState.swift, RawAudioCapture.swift - Current cold start architecture

### Secondary (MEDIUM confidence)
- [Swift Forums - Wispr Flow auto-return discussion](https://forums.swift.org/t/how-do-voice-dictation-keyboard-apps-like-wispr-flow-return-users-to-the-previous-app-automatically/83988) - No public API for auto-return, confirmed Jan 2026
- [9to5Mac Wispr Flow article](https://9to5mac.com/2025/06/30/wispr-flow-is-an-ai-that-transcribes-what-you-say-right-from-the-iphone-keyboard/) - Wispr Flow uses "Flow Sessions" with main app recording
- [GitHub iOS URL Schemes list](https://gist.github.com/bartleby/6588aa4782dfb3f1d50c23ce9a4554e3) - URL scheme mapping for known apps

### Tertiary (LOW confidence)
- Discord URL scheme (`discord://`) - community-sourced, needs device verification
- Microsoft Teams URL scheme (`msteams://`) - community-sourced, needs device verification

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using existing stack, no new libraries needed
- Architecture: MEDIUM - Cold start UX pattern confirmed by competitors, but source app detection remains unresolved
- Pitfalls: HIGH - Keyboard mic restriction is well-documented and critical
- Auto-return: LOW - URL scheme mapping is community-sourced, needs device testing

**Research date:** 2026-03-12
**Valid until:** 2026-04-12 (stable iOS APIs, no expected changes)
