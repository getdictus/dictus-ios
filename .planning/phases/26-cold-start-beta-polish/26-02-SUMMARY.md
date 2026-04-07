---
phase: 26-cold-start-beta-polish
plan: 02
subsystem: ios-overlay-ui
tags: [swipe-back, overlay, waveform, localization, beta-triage, dynamic-island, watchdog]

# Dependency graph
requires:
  - phase: 26-01
    provides: ADR confirming auto-return not viable — overlay must teach gesture
provides:
  - Wispr Flow-style SwipeBackOverlayView with iPhone mockup, BrandWaveform bars, hand animation
  - French translations for all overlay strings
  - Beta bug triage with watchdog fix (#60) and investigation closure (#73)
affects: [beta UX, Dynamic Island reliability]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Timer-based animation loop with pause between cycles (avoids jarring .repeatForever jump-back)
    - timingCurve(0.4, 0, 0.2, 1) for natural swipe acceleration (Material "emphasized" easing)
    - Short xcstrings key to avoid Xcode auto-generated duplicate bug
    - Fixed-height waveform container to prevent text bouncing during bar animation

key-files:
  created: []
  modified:
    - DictusApp/Views/SwipeBackOverlayView.swift
    - DictusApp/Localizable.xcstrings
    - DictusApp/LiveActivityManager.swift

key-decisions:
  - decision: "Use hand.point.up SF Symbol with chevron trail on blue dot, not circle animation"
    why: "User testing showed circle didn't communicate 'swipe gesture' — pointing finger is universal"
  - decision: "Position hand below phone mockup, blue dot on phone edge"
    why: "Competitor reference (Wispr Flow) places hand below device — avoids clip issues with rounded corners"
  - decision: "Use short key 'swipeback_empathy_text' instead of English text as xcstrings key"
    why: "Xcode auto-generates duplicate entries when English text is used as key, breaking FR translation"
  - decision: "Reduce recording watchdog from 10s to 2s"
    why: "Normal .recording→.transcribing transition takes <1s. 10s left users seeing phantom REC for too long"
---

## Summary

Redesigned SwipeBackOverlayView with Wispr Flow-style visual gesture teaching. Iterated through 5 rounds of design feedback with mockup validation in Pencil.dev before final implementation.

## What was built

### Overlay redesign (COLD-03)
- **iPhone mockup** (180x390pt) with Dynamic Island, 17 BrandWaveform-style bars (gradient blue center, white opacity edges), "Écoute en cours..." label
- **Swipe animation**: hand.point.up icon sliding left→right with Material "emphasized" easing (timingCurve 0.4/0/0.2/1) — natural acceleration, not linear
- **Glowing blue dot** on phone bottom edge with chevron trail, sliding in sync with hand — shows WHERE to swipe
- **Timer-based loop**: 1.2s animation + 0.8s pause between cycles (no jarring jump-back)
- **Localized text**: "Dictée en cours", "Écoute en cours...", empathetic explanation, instruction with "pour retourner sur votre application"

### Beta bug triage (BETA-01)
- **#73 (Cold start AUIOClient_StartIO)**: Investigated — dev/build artifact from CoreML recompilation. Commented and closed.
- **#60 (Dynamic Island stuck on REC)**: Recording watchdog reduced 10s→2s. Commented with full explanation of why it's safe.
- **#71 (Crash during phone call)**: Critical — filed for next phase
- **#72 (AirPods hijacked)**: Deferred to v1.5
- **#69 (Keys shrink on popup)**: Deferred to v1.5
- **#67 (Autocorrect undo)**: Deferred to v1.5

## Deviations

- Design required 5 iteration rounds (more than planned) due to: Dynamic Island positioning, waveform style matching, hand icon shape, chevron placement, xcstrings localization bug
- Pencil.dev MCP integration didn't work for live preview — fell back to PNG export workflow
- xcstrings duplicate key issue required switching from English-text-as-key to short key pattern

## Self-Check: PASSED
- [x] SwipeBackOverlayView.swift contains Wispr Flow design with IPhoneMockupView
- [x] BrandWaveform-style bars (17 bars, gradient center, white edges)
- [x] Hand animation with natural easing
- [x] All overlay text localized FR + EN
- [x] Beta bugs triaged (6 bugs, 1 fixed, 1 closed, 4 deferred)
- [x] Recording watchdog reduced to 2s
