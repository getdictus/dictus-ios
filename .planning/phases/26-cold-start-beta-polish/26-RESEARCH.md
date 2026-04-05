# Phase 26: Cold Start & Beta Polish - Research

**Researched:** 2026-04-05
**Domain:** iOS cold start auto-return, SwiftUI overlay animation, beta triage
**Confidence:** MEDIUM

## Summary

Phase 26 has three work streams: (1) a time-boxed 2h investigation of auto-return feasibility, (2) a Wispr Flow-style swipe-back overlay redesign, and (3) beta bug triage. Research reveals that **auto-return is almost certainly not viable via public APIs**, and the investigation should confirm this quickly so effort focuses on the overlay redesign.

The `sourceApplication` property on `UIOpenURLContext.Options` is the most promising public API, but it only returns the bundle ID of apps from the **same development team** -- meaning it will return `nil` for all third-party apps (WhatsApp, Messages, etc.). The private `_hostBundleID` API that KeyboardKit used was **removed in iOS 26.4**, making even the private-API route dead. The overlay redesign is the high-value deliverable: a Wispr Flow-style full-screen view with an animated iPhone mockup, gesture teaching animation, and empathetic localized text.

**Primary recommendation:** Spend the first hour of the 2h timebox confirming `sourceApplication` returns nil for cross-team URL opens and documenting findings in the ADR. Then invest all remaining effort into the Wispr Flow-style overlay redesign.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Full 2h investigation of sourceApplication -- exhaust all options (UIScene sourceApplication, pasteboard tricks, Shortcuts integration, etc.) before concluding "not viable"
- Viability bar: must work reliably for top 15-20 apps, not partial shipping
- Document findings in ADR (`.planning/adr-cold-start-autoreturn.md`) AND update GitHub issue #23
- Already confirmed out of scope: `LSApplicationWorkspace` (private API), `_hostBundleID` (private API)
- Swipe-back overlay: Wispr Flow style -- large iPhone mockup with actual Dictus recording state, animated finger/circle on home bar showing swipe-right gesture
- Layout: 2-zone with title at top, iPhone mockup center, empathetic text below, instruction pinned at bottom
- Mockup content: Show Dictus waveform canvas + recording state inside iPhone outline
- Text tone: Empathetic, Wispr Flow-inspired, adapted for Dictus. Honest about iOS limitation
- Text must be localized: FR + EN via String Catalog
- Key fix: Replace "Swipe back to the keyboard" (wrong) with reference to previous app
- Overlay must TEACH the swipe-back gesture visually, not just mention it
- Beta triage: Claude triages by user impact (can't dictate/correct = critical, cosmetic = GitHub issue)
- No per-fix TestFlight builds -- all fixes ship as single build at end of v1.4
- Bug fixes scoped to what's reported, not proactive bug hunting

### Claude's Discretion
- Exact approaches during sourceApplication investigation
- Waveform rendering inside mockup (simplified or actual Canvas)
- Exact French + English copy for overlay text
- Animation timing, easing, visual details for swipe gesture
- Bug severity assessment
- Whether to extend KnownAppSchemes or use different detection approach

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| COLD-01 | Time-boxed investigation of sourceApplication for auto-return (2h max) | sourceApplication API analysis, iOS 26.4 hostBundleID removal, pasteboard/Shortcuts research -- all documented below |
| COLD-02 | If auto-return viable, user returns to source app automatically after cold start dictation | Research indicates NOT viable -- no public API returns cross-team bundle IDs. Investigation should confirm and document |
| COLD-03 | If auto-return not viable, swipe-back overlay UX is polished with improved guidance | Wispr Flow reference design, SwiftUI animation patterns, localization patterns documented below |
| BETA-01 | Critical bugs reported by public beta testers are triaged and fixed | Triage framework and severity criteria documented below |
</phase_requirements>

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | Overlay UI, animations, shapes | Project standard, all views are SwiftUI |
| DictusCore | local | Shared keys, App Group, KnownAppSchemes | Cross-target shared framework |

### Supporting (no new dependencies needed)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| String Catalog (.xcstrings) | Xcode 15+ | FR/EN localization | All user-facing overlay text |
| SF Symbols | iOS 17+ | Icons in overlay if needed | System icons (chevron.right already used) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Pure SwiftUI animation | Lottie | User decision: no external animation libs |
| Manual iPhone shape | DeviceKit | Overkill for a static mockup shape |
| KeyboardKit host detection | Custom solution | KeyboardKit's API was removed in iOS 26.4 anyway |

**Installation:**
No new dependencies required. All work uses existing project frameworks.

## Architecture Patterns

### sourceApplication Investigation (COLD-01)

**What to investigate and expected outcomes:**

#### Approach 1: UIOpenURLContext.Options.sourceApplication
**What:** When DictusApp is opened via `dictus://dictate?source=keyboard`, check `urlContext.options.sourceApplication` in the SceneDelegate/SwiftUI `onOpenURL`.
**Expected result:** Returns `nil` because the keyboard extension (DictusKeyboard) and the host app (e.g., WhatsApp) are from different teams. iOS only populates `sourceApplication` for same-team apps since iOS 13.
**How to test:** Add logging in `handleIncomingURL` to print `sourceApplication` value. Run from simulator with Messages (same team) vs WhatsApp (different team).
**Confidence:** HIGH that this will NOT work for cross-team apps.

#### Approach 2: Keyboard extension passing host info via URL
**What:** Have the keyboard extension detect the host app bundle ID and pass it as a URL parameter (`dictus://dictate?source=keyboard&host=com.whatsapp`).
**Expected result:** WILL NOT WORK. The private API `_hostBundleID` was removed in iOS 26.4 (returns nil). KeyboardKit 10.4 confirmed this is a system-level change. No public API exists to get the host bundle ID from a keyboard extension.
**Confidence:** HIGH that this is dead.

#### Approach 3: Named UIPasteboard for host detection
**What:** Keyboard extension writes host info to a named pasteboard shared with the app.
**Expected result:** WILL NOT WORK. Same problem -- the keyboard extension has no way to determine the host app bundle ID in the first place. The pasteboard is just a transport mechanism; the data source is the missing host detection.
**Confidence:** HIGH that this is blocked by the same root cause.

#### Approach 4: Shortcuts integration
**What:** Use Siri Shortcuts to trigger dictation with a return URL.
**Expected result:** NOT VIABLE for the cold start flow. Wispr Flow uses Shortcuts for separate dictation modes (not keyboard integration). On iOS 26.4, even Wispr Flow's Shortcuts "briefly switch you out of Flow, requiring a manual swipe back." This is strictly worse UX than the current cold start flow.
**Confidence:** HIGH that this doesn't solve the problem.

#### Approach 5: canOpenURL enumeration from the app
**What:** After recording completes, iterate `KnownAppSchemes` and open the first one that was recently active.
**Expected result:** ALREADY TRIED AND REMOVED (see DictusApp.swift line 164 comment). Always opens the first installed app (e.g., WhatsApp) regardless of actual source. No way to determine which app was actually being used.
**Confidence:** HIGH -- already proven to not work.

**ADR conclusion template:** All five approaches fail because iOS provides no public API for a keyboard extension to identify its host app, and the private `_hostBundleID` API was removed in iOS 26.4. Auto-return requires knowing which app to return to, making it fundamentally impossible with current iOS capabilities.

### Swipe-Back Overlay Redesign (COLD-03)

**Recommended Structure:**
```
SwipeBackOverlayView.swift (redesigned)
├── Brand gradient background (existing)
├── VStack (main layout)
│   ├── Title text ("Dictation in progress..." or similar)
│   ├── Spacer
│   ├── IPhoneMockupView (NEW)
│   │   ├── RoundedRectangle device outline
│   │   ├── Dynamic Island capsule
│   │   ├── Inner content area showing:
│   │   │   ├── Simplified waveform animation (reuse existing canvas or simplified bars)
│   │   │   └── "Listening..." label
│   │   ├── Home indicator bar
│   │   └── SwipeGestureAnimation (animated circle sliding right on home bar)
│   ├── Empathetic explanation text
│   ├── Spacer
│   └── Bottom instruction ("Swipe right at the bottom")
```

**Key design decisions:**
1. iPhone mockup should be ~180x390pt (larger than current 120x260) -- Wispr Flow uses a prominent mockup
2. Waveform inside mockup: use simplified animated bars (3-5 bars with height animation) rather than the full Canvas waveform to keep the mockup clean and memory-light
3. Swipe animation: circle + chevron trail sliding right along the home bar area, with 1.2s duration and easeInOut, autoreverses: false
4. Two-zone layout: visual teaching area (mockup + animation) takes 60% of screen, text takes 40%

### Localization Pattern (existing)
```swift
// English source string (key = English text)
Text("We'd love to skip this step, but iOS requires switching apps to activate the microphone.")
    .font(.subheadline)

// French translation goes in DictusApp/Localizable.xcstrings:
// Key: "We'd love to skip this step, but iOS requires switching apps to activate the microphone."
// FR value: "Nous aimerions ne pas avoir a changer d'app, mais iOS l'exige pour activer le micro."
```

### Anti-Patterns to Avoid
- **Hardcoded French strings:** All text must go through String Catalog, never hardcode French directly in Swift
- **Complex waveform in mockup:** Don't embed the real WaveformCanvasView inside the mockup -- too heavy, risks memory issues
- **Blocking the recording:** The overlay is shown WHILE recording happens in background. Never add any logic that pauses or interferes with the recording

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| iPhone device shape | Custom CGPath | RoundedRectangle with `.continuous` corner style | SwiftUI handles device-like proportions natively |
| Repeating animation | Manual timer-based animation | `withAnimation(.repeatForever)` | Built-in SwiftUI, already used in current code |
| Localization | NSLocalizedString manually | String Catalog (Localizable.xcstrings) | Project pattern from Phase 23.1 |
| Host app detection | Custom private API workaround | Accept it's not possible | iOS 26.4 removed the last viable private API |

## Common Pitfalls

### Pitfall 1: sourceApplication returns nil for cross-team apps
**What goes wrong:** Developer assumes `sourceApplication` will contain the bundle ID of the app that triggered the URL open.
**Why it happens:** Since iOS 13, `sourceApplication` is only populated for apps from the same development team. All third-party apps return nil.
**How to avoid:** Test with a third-party app in the first 15 minutes of investigation. Log the value and confirm nil.
**Warning signs:** Getting excited about seeing a bundle ID in simulator with Messages (same team app).

### Pitfall 2: Overlay blocks recording view
**What goes wrong:** The overlay redesign accidentally prevents the recording from happening or the waveform data from flowing.
**Why it happens:** SwipeBackOverlayView replaces the normal TabView content (MainTabView line 37-42). Recording happens via DictationCoordinator in the background.
**How to avoid:** Never add any recording/audio logic to SwipeBackOverlayView. It's purely visual. Recording state flows through App Group + Darwin notifications.
**Warning signs:** Recording stops when overlay appears, or waveform data stops updating.

### Pitfall 3: Animation not starting on cold start
**What goes wrong:** SwiftUI animation doesn't trigger because the view lifecycle behaves differently during cold start (app launched into background then foreground).
**Why it happens:** `onAppear` may fire at unexpected times during the cold start transition chain.
**How to avoid:** Use the existing pattern: `@State private var isAnimating = false` + `onAppear { withAnimation(.repeatForever) { isAnimating = true } }`. This pattern is proven in the current SwipeAnimationView.
**Warning signs:** Static overlay with no animation on first cold start launch.

### Pitfall 4: String Catalog keys mismatch
**What goes wrong:** English string in code doesn't match the key in Localizable.xcstrings, causing French translation to not appear.
**Why it happens:** Typo or whitespace difference between the Swift `Text("...")` string and the xcstrings key.
**How to avoid:** Build in Xcode after adding strings -- Xcode auto-detects new keys. Then add French translations.
**Warning signs:** French text appears in English on device.

### Pitfall 5: iOS 26.4 hostBundleID regression
**What goes wrong:** Developer tries to use KeyboardKit-style host detection and it works on iOS 17-26.3 but breaks on 26.4.
**Why it happens:** Apple removed the private API in iOS 26.4 beta/RC. The `hostApplicationBundleId` now returns empty/nil.
**How to avoid:** Don't rely on any private API for host detection. The ADR should document this as a permanent limitation.
**Warning signs:** Feature works on older iOS versions but breaks on latest.

## Code Examples

### Pattern 1: iPhone Mockup with Animated Content
```swift
// Wispr Flow-style iPhone mockup with waveform and swipe animation
struct IPhoneMockupView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Device outline -- continuous corner style matches real iPhone
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 2.5)
            
            // Dynamic Island
            VStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 50, height: 14)
                    .padding(.top, 18)
                Spacer()
            }
            
            // Inner content: simplified waveform + "Listening" label
            VStack(spacing: 12) {
                // Simplified waveform bars
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.dictusAccent)
                            .frame(width: 4, height: isAnimating
                                ? CGFloat.random(in: 12...40)
                                : CGFloat.random(in: 6...20))
                    }
                }
                .animation(
                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: isAnimating
                )
                
                Text("Listening...")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Home indicator + swipe animation at bottom
            VStack {
                Spacer()
                
                // Swipe gesture area
                ZStack {
                    // Animated circle sliding right
                    Circle()
                        .fill(Color.dictusAccent)
                        .frame(width: 28, height: 28)
                        .shadow(color: Color.dictusAccent.opacity(0.5), radius: 8)
                        .offset(x: isAnimating ? 50 : -30)
                    
                    // Chevron trail
                    ForEach(0..<2, id: \.self) { i in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.dictusAccent.opacity(0.3 - Double(i) * 0.1))
                            .offset(x: isAnimating
                                ? CGFloat(25 - i * 14)
                                : CGFloat(-35 - i * 14))
                    }
                }
                .padding(.bottom, 8)
                
                // Home indicator bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 60, height: 5)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: 180, height: 390)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}
```

### Pattern 2: sourceApplication Check (for investigation)
```swift
// In DictusApp.swift or MainTabView.swift -- add during investigation
// SwiftUI onOpenURL doesn't expose sourceApplication directly.
// Need SceneDelegate or UIApplicationDelegate hook:

// Option A: UIApplicationDelegate (if not using scenes)
func application(_ app: UIApplication, open url: URL, 
                 options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    let source = options[.sourceApplication] as? String
    PersistentLog.log(.diagnosticProbe(
        component: "sourceApp", instanceID: "0",
        action: "check", details: "source=\(source ?? "nil")"
    ))
    // Expected: nil for cross-team apps
    return true
}

// Option B: SceneDelegate (UIScene-based)
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
        let source = context.options.sourceApplication
        PersistentLog.log(.diagnosticProbe(
            component: "sourceApp", instanceID: "0",
            action: "check", details: "source=\(source ?? "nil")"
        ))
    }
}
```

### Pattern 3: Localized Overlay Text
```swift
// English source strings -- French translations added in Localizable.xcstrings
VStack(spacing: 16) {
    Text("Dictation in progress")
        .font(.title2.weight(.semibold))
        .foregroundColor(.white)
    
    Text("We'd love to skip this step, but iOS requires switching apps to activate the microphone.")
        .font(.subheadline)
        .foregroundColor(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
    
    // Pinned at bottom
    Text("Swipe right at the bottom of your screen")
        .font(.callout.weight(.medium))
        .foregroundColor(.dictusAccent)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `_hostBundleID` private API | No replacement -- API removed | iOS 26.4 (March 2026) | Host app detection impossible from keyboard extensions |
| KeyboardKit hostApplicationBundleId | Returns nil, manual picker fallback | KeyboardKit 10.4 (April 2026) | Must use UX workarounds, not API detection |
| `sourceApplication` for cross-team | Only same-team apps since iOS 13 | iOS 13 (2019) | Cannot detect which third-party app opened yours via URL |
| Simple text overlay ("swipe back") | Visual gesture teaching (Wispr Flow style) | Industry shift 2025-2026 | Users don't know the swipe-back gesture exists |

**Deprecated/outdated:**
- `_hostBundleID`: Removed in iOS 26.4 -- no longer functional
- `LSApplicationWorkspace`: Private API, always rejected from App Store
- `application(_:open:sourceApplication:annotation:)`: Deprecated in favor of `application(_:open:options:)` since iOS 9

## Open Questions

1. **Waveform inside mockup: simplified bars vs actual Canvas?**
   - What we know: Full WaveformCanvasView reads from App Group and renders in real-time. Simplified bars would be decorative only.
   - What's unclear: Whether showing real waveform data inside the mockup adds meaningful UX value vs complexity
   - Recommendation: Use simplified animated bars. The mockup is ~180pt wide -- real waveform data would be too small to be useful. The bars communicate "app is listening" without the complexity.

2. **Exact overlay copy: how close to Wispr Flow?**
   - What we know: Wispr Flow says "We wish you didn't have to switch apps, but Apple now requires this to activate the microphone." Target tone is empathetic and honest.
   - What's unclear: Exact French phrasing that sounds natural (not literal translation)
   - Recommendation: Write English first, then craft natural French (not Google Translate). Example: EN "We'd love to skip this step, but iOS requires switching apps to activate the microphone." / FR "On aimerait eviter cette etape, mais iOS exige de changer d'app pour activer le micro."

3. **Beta bugs: what's currently known?**
   - What we know: CONTEXT.md says "estimated 1-3 known bugs from informal testing" and "beta publique not yet open"
   - What's unclear: Exact bug reports -- they'll be discovered during phase execution
   - Recommendation: Plan a flexible triage task that handles 0-5 bugs. If no bugs are reported, the task completes quickly.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual device testing (no automated test suite per TEST-01 deferred to v1.5) |
| Config file | none |
| Quick run command | Build + run on physical device |
| Full suite command | N/A -- manual testing |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COLD-01 | sourceApplication investigation documented | manual | N/A -- read ADR | N/A |
| COLD-02 | Auto-return works (if viable) | manual | Test cold start from keyboard | N/A |
| COLD-03 | Overlay teaches swipe gesture visually | manual | Visual inspection + Xcode Preview | N/A |
| BETA-01 | Critical bugs triaged and fixed | manual | Test each fix on device | N/A |

### Sampling Rate
- **Per task commit:** Xcode Preview for overlay visual changes, device test for cold start flow
- **Per wave merge:** Full cold start test: kill app, trigger from keyboard, verify overlay, swipe back
- **Phase gate:** Cold start tested on physical device, overlay renders correctly in FR + EN

### Wave 0 Gaps
None -- this phase is primarily investigation + UI redesign + bug fixes. No test infrastructure changes needed.

## Sources

### Primary (HIGH confidence)
- [KeyboardKit iOS 26.4 hostBundleID bug](https://keyboardkit.com/blog/2026/03/02/ios-26-4-host-application-bundle-id-bug) - Confirmed private API removal
- [KeyboardKit host features](https://keyboardkit.com/features/host) - Confirmed private API was the only mechanism
- [Apple: UIScene.ConnectionOptions](https://developer.apple.com/documentation/uikit/uiscene/connectionoptions) - Official docs on urlContexts
- [Apple: sourceApplication key](https://developer.apple.com/documentation/uikit/uiapplication/openurloptionskey/sourceapplication) - Official docs on sourceApplication behavior
- Existing codebase: DictusApp.swift line 164 comment confirms canOpenURL enumeration was already tried and removed

### Secondary (MEDIUM confidence)
- [Swift Forums: How do keyboard apps return to previous app](https://forums.swift.org/t/how-do-voice-dictation-keyboard-apps-like-wispr-flow-return-users-to-the-previous-app-automatically/83988) - Community confirmation no public API exists
- [Wispr Flow FAQ](https://docs.wisprflow.ai/iphone/faq) - Confirms "not all apps allow the app to reopen"
- [Wispr Flow Shortcuts](https://docs.wisprflow.ai/articles/1986921789-how-to-set-up-flow-shortcuts-for-iphone) - Shortcuts approach also requires manual swipe back on iOS 26.4

### Tertiary (LOW confidence)
- Web search claims that `sourceApplication` returns nil for cross-team apps since iOS 13 -- needs empirical verification during the investigation (Approach 1)

## Metadata

**Confidence breakdown:**
- sourceApplication investigation: HIGH -- multiple independent sources confirm no public API exists, private API removed in iOS 26.4
- Overlay redesign patterns: HIGH -- pure SwiftUI, existing patterns in codebase
- Localization: HIGH -- established pattern from Phase 23.1
- Beta triage: MEDIUM -- depends on what bugs are actually reported
- Overall: MEDIUM (weighted by the investigation uncertainty)

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable domain -- iOS API landscape won't change before WWDC 2026 in June)
