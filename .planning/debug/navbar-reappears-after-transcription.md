---
status: diagnosed
trigger: "Nav bar reappears after transcription completes on recording screen, shifting content upward. Also: processing animation uses logo bars instead of continuing waveform."
created: 2026-03-07T00:00:00Z
updated: 2026-03-07T00:00:00Z
---

## Current Focus

hypothesis: Nav bar reappears because coordinator.status transitions to .idle 2s after .ready, which removes the RecordingView overlay entirely — then NavigationStack's nav bar from HomeView becomes visible again before user dismisses.
test: Traced status flow in DictationCoordinator.stopDictation()
expecting: Confirmed via code reading
next_action: Return diagnosis to user

## Symptoms

expected: Navigation bar stays hidden on recording screen until user taps "Terminer" or "Nouvelle dictee"
actual: Nav bar reappears ~2 seconds after transcription result is shown, shifting content upward
errors: None (visual/UX bug)
reproduction: Record -> stop -> wait for transcription -> observe nav bar reappearing after ~2s
started: Current behavior

Secondary issue:
expected: Waveform continues but animates sinusoidally during processing
actual: Waveform is replaced by ProcessingAnimation (3 pulsing logo-inspired bars)

## Eliminated

(none needed — root cause identified on first pass)

## Evidence

- timestamp: 2026-03-07
  checked: DictationCoordinator.stopDictation() lines 278-283
  found: After transcription completes, status is set to .ready, then after a 2-second Task.sleep, status is set back to .idle
  implication: This is the trigger that removes the RecordingView overlay

- timestamp: 2026-03-07
  checked: MainTabView.swift line 65
  found: RecordingView overlay is shown with condition `if coordinator.status != .idle` — when status returns to .idle, the entire overlay is removed
  implication: The overlay disappears, revealing the underlying NavigationStack with its nav bar

- timestamp: 2026-03-07
  checked: RecordingView.swift line 153
  found: `.navigationBarHidden(true)` is applied to RecordingView, but this only hides the nav bar WITHIN RecordingView's own navigation context
  implication: When RecordingView is shown as a ZStack overlay (MainTabView path), .navigationBarHidden works. But when shown via NavigationLink from HomeView (TestDictationView path), it's INSIDE HomeView's NavigationStack — and the 2s auto-idle removes the overlay, revealing HomeView's nav bar.

- timestamp: 2026-03-07
  checked: Two presentation paths for RecordingView
  found: PATH 1 (ZStack overlay in MainTabView): triggered when coordinator.status != .idle — overlay covers everything. PATH 2 (NavigationLink in HomeView): "Tester la dictee" pushes TestDictationView onto HomeView's NavigationStack.
  implication: The bug manifests differently depending on entry path. Both paths have the auto-idle problem.

- timestamp: 2026-03-07
  checked: ProcessingAnimation.swift
  found: Uses 3 RoundedRectangle bars (logo-inspired) pulsing with brand gradient. Completely different visual from BrandWaveform.
  implication: The transition from waveform to logo bars creates a visual discontinuity during processing.

## Resolution

root_cause: |
  TWO interacting issues cause the nav bar to reappear:

  1. **Auto-idle timer in DictationCoordinator.stopDictation() (lines 280-283):**
     After transcription completes, the coordinator sets status to `.ready`, waits 2 seconds,
     then automatically sets status back to `.idle`. This was intended as a "checkmark flash"
     delay for the keyboard workflow, but it has a destructive side effect on RecordingView.

  2. **MainTabView overlay condition (line 65):**
     The RecordingView overlay is shown with `if coordinator.status != .idle`. When the
     auto-idle timer fires after 2 seconds, the overlay is removed from the ZStack, revealing
     the underlying TabView with its NavigationStack and nav bar.

  The RecordingView has its own internal state (`showResult`, `transcriptionResult`) that
  persists the result text and action buttons. But the PARENT (MainTabView) doesn't know
  about this internal state — it only watches `coordinator.status`. So after 2 seconds,
  the parent rips the overlay away even though RecordingView is still showing results.

  For the NavigationLink path (HomeView -> TestDictationView), the same auto-idle doesn't
  remove the view, but RecordingView's `.navigationBarHidden(true)` may not fully suppress
  the NavigationStack's nav bar when status changes cause SwiftUI to re-evaluate the view
  hierarchy.

fix: (not applied — diagnosis only)
verification: (not applied — diagnosis only)
files_changed: []
