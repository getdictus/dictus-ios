# Phase 26: Cold Start & Beta Polish - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Investigate cold start auto-return feasibility (2h timebox), polish the swipe-back overlay UX based on real user feedback, and triage/fix critical bugs from beta testers. This is the final phase of milestone v1.4.

Requirements: COLD-01, COLD-02, COLD-03, BETA-01

</domain>

<decisions>
## Implementation Decisions

### sourceApplication investigation (2h timebox)
- Full 2h investigation -- exhaust all options (UIScene sourceApplication, pasteboard tricks, Shortcuts integration, etc.) before concluding "not viable"
- Viability bar: must work reliably for top 15-20 apps (not just the 10 in KnownAppSchemes -- extend to Safari, Mail, Gmail, Notion, Bear, etc.)
- If it doesn't work reliably across the extended app list, it's not viable -- no partial shipping
- Document findings in ADR (`.planning/adr-cold-start-autoreturn.md`) AND update GitHub issue #23 with summary pointing to the ADR
- Already confirmed out of scope: `LSApplicationWorkspace` (private API, App Store rejection), `_hostBundleID` (private API)

### Swipe-back overlay redesign (Wispr Flow style)
- **Style:** Wispr Flow approach -- NOT the current simple mockup. Large iPhone mockup showing actual Dictus recording state (waveform + "Listening"), animated finger/circle on the home bar showing the swipe-right gesture
- **Layout (2-zone):** Title at top ("Swipe right to speak" or similar), large iPhone mockup in center with animated swipe gesture on home bar, empathetic explanation text below mockup, "Swipe right at the bottom" instruction pinned at bottom
- **Mockup content:** Show Dictus waveform canvas + recording state inside the iPhone outline. User should understand the app is recording while they're looking at this screen
- **Swipe animation:** Animated circle/finger sliding right on the home bar area of the mockup -- recreating the iOS swipe-back gesture visually so users who don't know the gesture can learn it
- **Text tone:** Empathetic, Wispr Flow-inspired. Adapted for Dictus: something like "Nous aimerions ne pas avoir a changer d'app, mais iOS l'exige pour activer le micro." Honest, explains WHY the user has to do this, de-guilt the user
- **Text must be localized:** FR + EN via String Catalog (existing localization pattern)
- **Key fix:** Current text says "Swipe back to the keyboard" which is wrong/confusing -- users need to return to their PREVIOUS APP, not "the keyboard". Text must reference the previous app, not the keyboard
- **Problem to solve:** Real user tested and didn't know the iOS swipe-back gesture existed. The overlay must TEACH the gesture, not just mention it

### Beta feedback triage
- Claude triages based on user impact: if the user can't dictate or correct text -> critical. Cosmetic or edge cases -> filed as GitHub issues for later
- Feedback sources: TestFlight feedback + GitHub Issues (consolidate and deduplicate)
- Estimated 1-3 known bugs from informal testing (beta publique not yet open)
- No per-fix TestFlight builds -- all fixes accumulate and ship as a single build at the end of milestone v1.4
- Bug fixes are scoped to what's reported, not proactive bug hunting

### Claude's Discretion
- Exact approaches to try during sourceApplication investigation (UIScene API, pasteboard, Shortcuts, etc.)
- Waveform rendering inside the mockup (simplified or actual Canvas waveform)
- Exact French + English copy for the overlay (following the empathetic tone decision)
- Animation timing, easing, and visual details for the swipe gesture
- Bug severity assessment for each reported issue
- Whether to extend KnownAppSchemes during investigation or use a different detection approach

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Cold start architecture
- `DictusApp/DictusApp.swift` -- Cold start URL handling, `coldStartActive` flag management (lines 81, 144, 153)
- `DictusApp/DictationCoordinator.swift` -- Cold start retry logic, `coldStartActive` cleanup (lines 179, 503, 684)
- `DictusKeyboard/KeyboardState.swift` -- Cold start grace period, Darwin fallback (lines 73, 173, 255-266)
- `DictusCore/Sources/DictusCore/SharedKeys.swift` -- `coldStartActive` shared key (line 60)
- `DictusCore/Sources/DictusCore/KnownAppSchemes.swift` -- URL scheme registry for top 10 messaging apps (extend to 15-20)

### Swipe-back overlay (to redesign)
- `DictusApp/Views/SwipeBackOverlayView.swift` -- Current overlay implementation (replace with Wispr Flow-style design)
- `DictusApp/Views/MainTabView.swift` -- Where SwipeBackOverlayView is conditionally shown (lines 39-42)

### Competitor references (screenshots captured during discussion)
- Super Whisper: Simple hand icon under iPhone mockup, same "Swipe back to the keyboard" text
- Wispr Flow: Large iPhone mockup with real app content, animated circle on home bar, empathetic text explaining Apple's microphone requirement, "Swipe right at the bottom" instruction. THIS IS THE TARGET STYLE.

### Localization
- `DictusApp/Localizable.xcstrings` -- App String Catalog (add overlay text here)
- `DictusKeyboard/Localizable.xcstrings` -- Keyboard String Catalog

### Requirements
- `.planning/REQUIREMENTS.md` -- COLD-01 (sourceApplication investigation), COLD-02 (auto-return if viable), COLD-03 (overlay polish if not viable), BETA-01 (beta bug triage)

### Brand
- `assets/brand/dictus-brand-kit.html` -- Brand colors, gradients, logo specs for overlay styling

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SwipeBackOverlayView`: Existing overlay with SwipeAnimationView -- needs full redesign but file/integration point stays the same
- `KnownAppSchemes`: 10 app URL schemes -- extend to 15-20 during investigation
- `Color.dictusAccent`, brand gradient colors -- reuse for overlay redesign
- Cold start flag system (`SharedKeys.coldStartActive`) -- working infrastructure
- `PersistentLog` cold start events -- logging already in place
- String Catalog localization pattern -- established in Phase 23.1

### Established Patterns
- SwiftUI animation with `@State` + `withAnimation` + `.repeatForever` (current SwipeAnimationView)
- Full-screen overlay replacing MainTabView content when cold start active
- Brand gradient background: `LinearGradient(colors: [0x0D2040, 0x071020])`
- Darwin notifications + URL scheme for cross-process IPC

### Integration Points
- `MainTabView` line 42: `SwipeBackOverlayView()` shown conditionally -- same integration point for redesigned overlay
- `DictusApp.swift` `handleIncomingURL`: where sourceApplication detection would hook in
- GitHub issue #23: update with investigation findings

</code_context>

<specifics>
## Specific Ideas

- Wispr Flow's overlay is the gold standard to match -- large iPhone mockup with real app content, animated swipe gesture on home bar, empathetic "Apple requires this" text
- A real user (Pierre's colleague) didn't know the iOS swipe-back gesture existed -- the overlay must TEACH the gesture visually, not assume users know it
- Current text "Swipe back to the keyboard" is wrong -- the user returns to their previous app, not "the keyboard". This confused the tester.
- Wispr Flow's text "We wish you didn't have to switch apps, but Apple now requires this to activate the microphone" is the right tone -- honest, empathetic, transparent about the iOS limitation
- TestFlight build only at end of milestone v1.4, not per-fix

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 26-cold-start-beta-polish*
*Context gathered: 2026-04-05*
