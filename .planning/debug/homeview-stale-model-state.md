---
status: diagnosed
trigger: "HomeView shows stale model state after onboarding completes"
created: 2026-03-07T00:00:00Z
updated: 2026-03-07T00:00:00Z
---

## Current Focus

hypothesis: ModelDownloadPage creates its own @StateObject ModelManager, separate from MainTabView's @StateObject ModelManager. They never share state.
test: Trace object graph from code
expecting: Two independent ModelManager instances confirmed
next_action: Return diagnosis

## Symptoms

expected: HomeView immediately reflects downloaded model after onboarding completes
actual: HomeView shows "Telecharger un modele" until app is force-quit and reopened
errors: none (visual stale state only)
reproduction: Complete onboarding including model download -> observe HomeView
started: Since onboarding was implemented

## Eliminated

(none needed -- root cause found on first hypothesis)

## Evidence

- timestamp: 2026-03-07
  checked: ModelDownloadPage.swift line 19
  found: `@StateObject private var modelManager = ModelManager()` -- creates its OWN ModelManager instance
  implication: This is a completely separate object from MainTabView's ModelManager

- timestamp: 2026-03-07
  checked: MainTabView.swift line 20
  found: `@StateObject private var modelManager = ModelManager()` -- creates ANOTHER ModelManager instance
  implication: Two independent ModelManager objects exist simultaneously

- timestamp: 2026-03-07
  checked: HomeView.swift lines 43-48, onAppear handler
  found: `modelManager.loadState()` calls loadState() on MainTabView's modelManager
  implication: loadState() DOES read from App Group UserDefaults, and the data IS there (persisted by onboarding's ModelManager). So loadState() should work IF onAppear fires.

- timestamp: 2026-03-07
  checked: DictusApp.swift line 37
  found: `.fullScreenCover(isPresented: .constant(!hasCompletedOnboarding))` -- uses .constant() binding
  implication: fullScreenCover with .constant() means SwiftUI controls presentation purely by the @AppStorage value. When hasCompletedOnboarding becomes true, the cover dismisses. But MainTabView was already mounted BEHIND the cover the entire time.

- timestamp: 2026-03-07
  checked: SwiftUI onAppear semantics
  found: HomeView's onAppear likely fired when MainTabView was first created (behind the fullScreenCover), BEFORE onboarding even started. When the cover dismisses, onAppear does NOT re-fire because the view was never removed.
  implication: This is the root cause -- onAppear fires once when the view hierarchy is first built, not when the fullScreenCover dismisses.

## Resolution

root_cause: |
  TWO ISSUES COMBINE:

  1. **Separate ModelManager instances**: ModelDownloadPage creates its own `@StateObject private var modelManager = ModelManager()` (line 19). MainTabView also creates its own `@StateObject private var modelManager = ModelManager()` (line 20). The download happens on onboarding's ModelManager. MainTabView's ModelManager never sees the download -- it's a different object.

  2. **onAppear doesn't re-fire after fullScreenCover dismissal**: MainTabView (and HomeView inside it) is mounted BEHIND the fullScreenCover from the start. HomeView's `onAppear` fires once during initial mount (before onboarding), reads empty state, and never fires again when the cover dismisses. So `modelManager.loadState()` runs too early, before any model is downloaded.

  The data IS correctly persisted to App Group UserDefaults by onboarding's ModelManager (via `persistState()`). The problem is that MainTabView's ModelManager never re-reads it at the right moment.

fix: (diagnosis only)
verification: (diagnosis only)
files_changed: []
