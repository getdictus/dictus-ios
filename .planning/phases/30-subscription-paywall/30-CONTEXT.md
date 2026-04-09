# Phase 30: Subscription + Paywall - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

StoreKit 2 subscription infrastructure with feature gating, paywall UI, restore purchases, and beta override. Users can subscribe to Dictus Pro and access gated features, with a smooth beta experience where everything is free. Covers SUB-01 through SUB-06 and PAY-01 through PAY-06.

</domain>

<decisions>
## Implementation Decisions

### Paywall screen design
- Full-screen dedicated page pushed via NavigationStack (not a modal sheet)
- Pro benefits displayed as feature cards with SF Symbol icons, title, and one-line description (3 cards: Smart Mode, History, Vocabulary)
- Price embedded directly in the CTA button: "Subscribe — 4.99€/month"
- "Cancel anytime" reassurance text below the button
- Restore purchases + Terms of Service + Privacy Policy links at the bottom
- Paywall accessible from two entry points: Settings "Dictus Pro" row AND compact Home screen banner

### Home screen Pro banner
- Compact gradient card at the bottom of HomeView
- "Unlock Dictus Pro" with a brief tagline
- Tapping opens the paywall
- Disappears after subscribing (not shown to Pro users)

### Beta messaging
- During beta: subscribe button replaced by a prominent banner "All Pro features free during beta" — no purchase flow at all
- Small "BETA" pill badge on the Dictus Pro row in Settings showing "BETA Active"
- Beta messaging only on paywall + Settings row (not scattered everywhere)

### Beta-to-paid transition
- Simple `isBeta` Bool flag in code — flip to `false` and ship an update
- TestFlight builds always have `isBeta = true` (testers keep free access permanently)
- App Store builds have `isBeta = false` → features lock, paywall shows purchase flow
- No server-side flag, no grace period — consistent with 100% offline architecture
- App Group data persists across TestFlight → App Store transition (settings, history preserved)

### Pro feature indicators (in-app)
- Lock icon + colored "PRO" pill badge on locked features in Settings
- Dedicated "Pro Features" section in Settings (separate from Transcription and Keyboard sections)
- Pro features visible to free users but tapping opens the paywall

### Keyboard lock UX
- Free users see the exact same keyboard as today — NO Pro-specific UI on the keyboard
- All feature gating happens in the app Settings, not in the keyboard extension
- Pro features (e.g., Smart Mode button) only appear on the keyboard when Pro is active AND the feature is enabled in Settings
- This redefines PAY-05: instead of "keyboard shows upgrade prompt", the keyboard simply doesn't show Pro features to free users

### Pro status sync (keyboard ↔ app)
- Pro status stored in App Group SharedKeys (same pattern as language, layout, haptics)
- New SharedKeys: `proActive` (Bool), plus per-feature toggles (e.g., `smartModeEnabled`)
- Keyboard reads Pro status from App Group UserDefaults at launch — no network needed

### Claude's Discretion
- Exact Liquid Glass styling for paywall cards and banner
- SF Symbol choices for each Pro feature card
- StoreKit 2 product ID naming convention
- Transaction.updates listener architecture
- FeatureGate/ProFeature enum design
- Restore purchases flow details
- Error handling for failed purchases

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Subscription & Paywall requirements
- `.planning/REQUIREMENTS.md` — SUB-01 through SUB-06 and PAY-01 through PAY-06 acceptance criteria
- `.planning/ROADMAP.md` — Phase 30 success criteria and dependency info

### Existing architecture
- `DictusCore/Sources/DictusCore/AppGroup.swift` — App Group container setup (shared UserDefaults + file container)
- `DictusCore/Sources/DictusCore/SharedKeys.swift` — All cross-process UserDefaults keys (pattern for new Pro keys)
- `DictusApp/Views/SettingsView.swift` — Settings screen structure (@AppStorage with App Group, grouped List)
- `DictusApp/Views/HomeView.swift` — Home screen layout (for Pro banner placement)

### Design system
- `DictusCore/Sources/DictusCore/Design/DictusColors.swift` — Color palette including accent (#3D7EFF), surface (#161C2C)
- `DictusCore/Sources/DictusCore/Design/DictusTypography.swift` — Typography scale
- `assets/brand/dictus-brand-kit.html` — Full brand kit with gradients and logo specs

### Project context
- `.planning/PROJECT.md` — Open Core model decision, single Pro tier, offline-only constraints

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AppGroup.swift` + `SharedKeys.swift`: Established pattern for cross-process data sharing via App Group UserDefaults — extend with Pro status keys
- `SettingsView.swift`: Grouped List with @AppStorage pattern — add new "Pro Features" section
- `HomeView.swift`: Main app screen — add compact Pro banner at bottom
- `DictusColors`, `DictusTypography`: Liquid Glass design tokens for consistent paywall styling
- Onboarding flow (`OnboardingView.swift`): Multi-page NavigationStack pattern reusable for paywall page

### Established Patterns
- @AppStorage with App Group store for settings that keyboard extension reads
- NavigationStack-based page navigation (onboarding, settings)
- SF Symbols throughout the UI for icons
- Grouped List style for settings screens

### Integration Points
- `SettingsView.swift` — Add "Dictus Pro" row at top + "Pro Features" section
- `HomeView.swift` — Add compact gradient Pro banner at bottom
- `SharedKeys.swift` — Add `proActive`, `smartModeEnabled` keys
- `KeyboardViewController.swift` / `KeyboardRootView.swift` — Read Pro status from App Group to conditionally show Pro keyboard features (in future phases)

</code_context>

<specifics>
## Specific Ideas

- Paywall should feel premium — feature cards with icons, not a plain list
- The keyboard must stay "clean" for free users — no locked buttons, no upgrade prompts, no clutter
- Pro features only appear on the keyboard when Pro is active AND individually enabled in Settings
- Beta testers (TestFlight) should always have free access even after App Store launch
- "Cancel anytime" messaging to reduce subscription anxiety

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 30-subscription-paywall*
*Context gathered: 2026-04-09*
