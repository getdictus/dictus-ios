---
status: diagnosed
trigger: "Mic button in keyboard toolbar opens DictusApp instead of showing RecordingOverlay in-keyboard"
created: 2026-03-06T00:00:00Z
updated: 2026-03-06T00:00:00Z
---

## Current Focus

hypothesis: ToolbarView mic button uses SwiftUI Link(destination: "dictus://dictate") which opens the main app via URL scheme, instead of updating KeyboardState to trigger in-keyboard recording
test: Read ToolbarView.swift line 55
expecting: Confirmed — Link opens app, should be a Button that sets state
next_action: Report root cause

## Symptoms

expected: Mic button tap triggers KeyboardState to change to .recording, causing KeyboardRootView to swap from KeyboardView to RecordingOverlay — all within the keyboard extension
actual: Mic button opens the DictusApp (via dictus://dictate URL scheme) and recording starts in the main app
errors: None (functional bug, not crash)
reproduction: Tap mic button in keyboard toolbar
started: Phase 2 flow was URL-scheme-based; Phase 3 was supposed to replace it with in-keyboard recording but the toolbar was never rewired

## Eliminated

(none needed — root cause found on first hypothesis)

## Evidence

- timestamp: 2026-03-06
  checked: ToolbarView.swift lines 52-57
  found: The mic button for idle/ready/failed states is a SwiftUI `Link(destination: URL(string: "dictus://dictate")!)` — this is a URL scheme that opens the main DictusApp
  implication: This is the Phase 2 flow. It was never replaced with a Button that updates KeyboardState

- timestamp: 2026-03-06
  checked: KeyboardState.swift
  found: KeyboardState has no method to START recording — only requestStop() and requestCancel(). It has markRequested() (line 174) which writes .requested status but this is designed to be called BEFORE the Link opens the app. The entire recording lifecycle is driven by DictusApp via Darwin notifications.
  implication: The architecture still assumes DictusApp does all recording. KeyboardState is purely an observer of app state, not a controller of local recording.

- timestamp: 2026-03-06
  checked: KeyboardRootView.swift lines 41-55
  found: Conditional rendering logic is correct — it checks `state.dictationStatus == .recording || .transcribing` to show RecordingOverlay. But dictationStatus is only updated via Darwin notifications FROM the app.
  implication: The view layer is ready for in-keyboard recording, but the data flow still goes through the main app

- timestamp: 2026-03-06
  checked: KeyboardViewController.swift
  found: No URL scheme handling or redirect logic here — it's clean. The redirect happens purely in ToolbarView via SwiftUI Link.
  implication: Fix is isolated to ToolbarView + KeyboardState

## Resolution

root_cause: ToolbarView.swift line 55 uses `Link(destination: URL(string: "dictus://dictate")!)` for the mic button tap action. This is the Phase 2 URL-scheme flow that opens the main DictusApp to perform recording. Phase 3 was supposed to replace this with in-keyboard recording, but the ToolbarView mic button was never rewired from a Link to a Button that triggers local recording via KeyboardState. Additionally, KeyboardState has no method to initiate recording locally — it only observes state changes from the app via Darwin notifications.
fix: (not applied — diagnosis only)
verification: (not applicable)
files_changed: []
