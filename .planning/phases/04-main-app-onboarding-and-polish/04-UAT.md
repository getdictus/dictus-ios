---
status: complete
phase: 04-main-app-onboarding-and-polish
source: [04-01-SUMMARY.md, 04-02-SUMMARY.md, 04-03-SUMMARY.md]
started: 2026-03-07T10:00:00Z
updated: 2026-03-07T09:10:00Z
---

## Current Test

[testing complete]

## Tests

### 1. App Launch — 3-Tab Navigation
expected: Open DictusApp. You should see a tab bar at the bottom with 3 tabs: Home, Models, Settings. Home tab is selected by default. Tab bar tint is blue (brand accent).
result: pass

### 2. Home Dashboard
expected: Home tab shows the brand waveform (multi-bar logo), a model status card indicating which Whisper model is loaded/available, and a "Test Dictation" link or button to start recording.
result: pass

### 3. Onboarding Flow — First Launch
expected: On first launch (or after resetting hasCompletedOnboarding), a full-screen onboarding appears with 5 steps: Welcome (animated waveform + wordmark), Mic Permission, Keyboard Setup (with deep link to Settings), Model Download (downloads whisper-small with progress), Test Recording. Each step validates before you can advance. Completing onboarding dismisses it and shows the main app.
result: issue
reported: "Welcome page waveform is static (not animated). Text/button contrast is poor — text on buttons barely visible in both light and dark mode. Returning from Settings after keyboard setup (step 3) resets onboarding to step 1. In light mode, white waveform bars are invisible on light background — need gray bars. Test recording waveform also invisible on white background (same white/blue color issue)."
severity: major

### 4. Settings Screen — 3 Sections
expected: Settings tab shows a grouped list with 3 sections: Transcription (language, filler words toggle), Clavier (haptics toggle), and A propos (licenses link, version). Toggling a switch persists the preference (survives app restart).
result: pass

### 5. Licenses View
expected: In Settings > A propos, tapping Licenses shows MIT attributions for WhisperKit and Dictus.
result: pass

### 6. Glass Effect on App Surfaces
expected: Card surfaces, backgrounds, and UI elements throughout the app have a frosted glass/material appearance. On iOS 26 devices this would be Liquid Glass; on older iOS it's a regular material blur.
result: issue
reported: "Home card has Liquid Glass and looks great. Models tab has regular cards without glass effect. Settings also regular cards. Would be better if Models cards matched the Home card glass style. Buttons and animations are ok."
severity: cosmetic

### 7. Recording View — Brand Waveform
expected: Start a test dictation from Home. The recording screen shows a multi-bar waveform (30 bars) that animates with audio energy. Uses brand blue gradient in center and white opacity on edges. Result card also has glass styling.
result: pass

### 8. Keyboard — Glass Keys and Animated Mic
expected: Open the Dictus keyboard in any app. Keys have glass background styling. The toolbar shows an AnimatedMicButton (replaces plain mic icon). Tapping the mic button shows recording state with pulse animation. The FullAccessBanner (if shown) uses glass background and blue accent link.
result: issue
reported: "Tapping mic shifts everything up — cancel/validate buttons at top left/right get clipped. Keyboard overall too short compared to standard iOS keyboard, keys too small. FullAccessBanner barely visible (too small/compressed). Banner 'Activer' link opens iOS Settings app instead of opening Dictus app directly (ideally deep-link to keyboard settings for full access toggle)."
severity: major

### 9. Keyboard — Recording Overlay with Brand Waveform
expected: While recording via keyboard, the overlay covers the full keyboard area and shows the BrandWaveform (multi-bar) animating with audio energy, replacing the old simple bar waveform.
result: issue
reported: "Works but same layout shift bug as test 8 (buttons clipped at top). Waveform too small — not tall enough, not reactive enough to audio, should be wider (nearly full keyboard width) and more impressive/dynamic."
severity: minor

### 10. Dynamic Type in Keyboard
expected: Go to iOS Settings > Accessibility > Display & Text Size > Larger Text and increase text size. Open the Dictus keyboard. Key labels, timer text, and icon sizes should scale up proportionally (not clip or overflow).
result: issue
reported: "Key labels scale way too much with Dynamic Type — at max size letters are huge and overflow. Standard iOS keyboard does NOT scale key labels with Dynamic Type. Our keyboard should match that behavior — key letter sizes should be fixed like the native keyboard."
severity: major

### 11. Light/Dark Mode
expected: Switch between light and dark mode (iOS Settings > Display). All screens (Home, Models, Settings, Onboarding, Recording, Keyboard) adapt colors correctly — no white-on-white or black-on-black text, glass effects look appropriate in both modes.
result: pass

## Summary

total: 11
passed: 6
issues: 5
pending: 0
skipped: 0

## Gaps

- truth: "Onboarding flow: animated waveform on welcome, readable text/buttons, keyboard setup doesn't reset progress, waveform visible in light mode"
  status: failed
  reason: "User reported: Welcome page waveform is static (not animated). Text/button contrast is poor — text on buttons barely visible in both light and dark mode. Returning from Settings after keyboard setup (step 3) resets onboarding to step 1. In light mode, white waveform bars are invisible on light background — need gray bars. Test recording waveform also invisible on white background (same white/blue color issue)."
  severity: major
  test: 3
  artifacts: []
  missing: []
- truth: "Glass effect applied to all card surfaces throughout the app"
  status: failed
  reason: "User reported: Home card has Liquid Glass and looks great. Models tab has regular cards without glass effect. Settings also regular cards. Would be better if Models cards matched the Home card glass style. Buttons and animations are ok."
  severity: cosmetic
  test: 6
  artifacts: []
  missing: []
- truth: "Keyboard glass keys, animated mic button without layout shift, visible FullAccessBanner, deep link to Dictus keyboard settings"
  status: failed
  reason: "User reported: Tapping mic shifts everything up — cancel/validate buttons at top left/right get clipped. Keyboard overall too short compared to standard iOS keyboard, keys too small. FullAccessBanner barely visible (too small/compressed). Banner 'Activer' link opens iOS Settings app instead of opening Dictus app directly (ideally deep-link to keyboard settings for full access toggle)."
  severity: major
  test: 8
  artifacts: []
  missing: []
- truth: "Keyboard recording overlay waveform is large, reactive, and visually impressive"
  status: failed
  reason: "User reported: Works but same layout shift bug as test 8 (buttons clipped at top). Waveform too small — not tall enough, not reactive enough to audio, should be wider (nearly full keyboard width) and more impressive/dynamic."
  severity: minor
  test: 9
  artifacts: []
  missing: []
- truth: "Keyboard key labels scale appropriately with Dynamic Type without overflow"
  status: failed
  reason: "User reported: Key labels scale way too much with Dynamic Type — at max size letters are huge and overflow. Standard iOS keyboard does NOT scale key labels with Dynamic Type. Our keyboard should match that behavior — key letter sizes should be fixed like the native keyboard."
  severity: major
  test: 10
  artifacts: []
  missing: []
