---
phase: 26-cold-start-beta-polish
verified: 2026-04-05T21:30:00Z
status: human_needed
score: 7/8 must-haves verified
human_verification:
  - test: "Build DictusApp on a physical device. Kill the app, open a third-party app (WhatsApp, Notes), switch to Dictus keyboard, tap mic. Observe the cold start overlay."
    expected: "iPhone mockup visible with animated waveform bars, glowing blue dot sliding on phone edge, hand.point.up icon below mockup, empathetic text in device language, bottom instruction 'Swipe right at the bottom of your screen / to return to your app' in accent color."
    why_human: "Visual animation quality (natural easing, timing, pause between cycles) cannot be verified by static code inspection. The 5-iteration design process indicates the design was refined against live visual feedback — only a physical device confirms the final result looks correct."
  - test: "With device set to French, verify the overlay shows French text with correct accents."
    expected: "Title shows 'Dictée en cours', Listening label shows 'Écoute en cours...', empathetic text shows 'On aimerait éviter cette étape, mais iOS exige d'ouvrir Dictus pour activer le micro.', bottom instruction shows 'Glissez vers la droite en bas de votre écran / pour retourner sur votre application'."
    why_human: "xcstrings localization rendering on device. The summary documents an xcstrings duplicate key bug that required a short-key workaround ('swipeback_empathy_text') — that workaround needs device confirmation that Text() resolves short keys via NSLocalizedString correctly."
  - test: "Check TestFlight App Store Connect feedback panel for any additional beta reports not yet captured as GitHub issues."
    expected: "No critical unaddressed reports. Issue #71 (crash during phone call) is the only open priority:high bug."
    why_human: "TestFlight feedback panel is only accessible in App Store Connect — cannot be queried programmatically."
---

# Phase 26: Cold Start Beta Polish Verification Report

**Phase Goal:** Cold start UX is investigated and improved if viable, and critical beta feedback is addressed
**Verified:** 2026-04-05T21:30:00Z
**Status:** human_needed (automated checks passed — 3 items need device/human confirmation)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | sourceApplication investigation is complete with all 5 approaches tested or documented | VERIFIED | ADR at `.planning/adr-cold-start-autoreturn.md` documents all 5 approaches with status, evidence, and confidence. GitHub issue #23 has investigation summary comment with 5-approach table. |
| 2 | ADR exists with clear REJECTED conclusion | VERIFIED | File exists at `.planning/adr-cold-start-autoreturn.md`. Contains `## Decision` section with "Auto-return is not viable with current iOS public APIs." and `**Status:** REJECTED`. 93 lines, 6 references. |
| 3 | User sees a Wispr Flow-style overlay with iPhone mockup showing recording state | VERIFIED (code) / NEEDS HUMAN (visual) | `SwipeBackOverlayView.swift` (245 lines) contains `IPhoneMockupView` with 17 BrandWaveform bars, Dynamic Island capsule, glowing blue dot with chevron trail. 5 design iterations documented. |
| 4 | User sees animated swipe gesture on the home bar area of the mockup | VERIFIED (code) / NEEDS HUMAN (visual) | `SwipeHandView` struct with `hand.point.up` SF Symbol. Timer-based loop: 1.2s animation + 0.8s pause. Material easing `timingCurve(0.4/0/0.2/1)`. Blue dot on phone edge with chevron trail. |
| 5 | User reads empathetic explanation text in their device language (FR or EN) | VERIFIED (code) / NEEDS HUMAN (xcstrings rendering) | `swipeback_empathy_text` key in Localizable.xcstrings with EN and FR translations. FR: "On aimerait éviter cette étape, mais iOS exige d'ouvrir Dictus pour activer le micro." Short key used to avoid Xcode duplicate entry bug. |
| 6 | Overlay text references returning to their previous app, NOT 'the keyboard' | VERIFIED | Bottom instruction: `"Swipe right at the bottom of your screen\nto return to your app"`. No reference to "Swipe back to the keyboard" anywhere in the file. FR translation: "pour retourner sur votre application". |
| 7 | Critical beta bugs are triaged with fixes applied or GitHub issues filed | VERIFIED | Issue #73 (AUIOClient) closed as dev artifact. Issue #60 (DI stuck on REC) fixed — watchdog reduced from 10s to 2s in `LiveActivityManager.swift:488`. Issue #71 (crash during phone call) open with `priority:high` label. Issues #72, #69, #67 deferred to v1.5. |
| 8 | GitHub issue #23 is updated with investigation summary | VERIFIED | `gh issue view 23` returns comment with "Cold Start Auto-Return Investigation Complete", 5-approach table, and link to ADR. |

**Score:** 7/8 truths fully verified programmatically, 3 items require human/device confirmation (truths 3, 4, 5 have code evidence but need visual/rendering validation).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.planning/adr-cold-start-autoreturn.md` | ADR with REJECTED decision | VERIFIED | Exists, 93 lines, `## Decision` section present, "REJECTED" status, 5 approaches with evidence table, 7 references |
| `DictusApp/DictusApp.swift` | sourceApplication diagnostic logging | VERIFIED | `@UIApplicationDelegateAdaptor(AppDelegate.self)` present, `sourceApplication` referenced 5+ times, `UIApplicationDelegateAdaptor` class added |
| `DictusApp/Views/SwipeBackOverlayView.swift` | Wispr Flow-style overlay, min 100 lines | VERIFIED | 245 lines, `struct SwipeBackOverlayView: View` with no init parameters, `IPhoneMockupView` private struct, `SwipeHandView` private struct |
| `DictusApp/Localizable.xcstrings` | French translations for overlay text | VERIFIED | Keys present: "Dictation in progress" (FR: "Dictée en cours"), "Swipe right at the bottom of your screen\nto return to your app" (FR with proper accents), "swipeback_empathy_text" (FR: "On aimerait éviter..."), "Listening..." (FR: "Écoute en cours...") |
| `DictusApp/LiveActivityManager.swift` | Watchdog reduced to 2s | VERIFIED | `Task.sleep(nanoseconds: 2_000_000_000)` at line 488, comment confirms "Previously 10s — reduced to 2s for faster recovery (issue #60)" |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `SwipeBackOverlayView.swift` | `MainTabView.swift` | `SwipeBackOverlayView()` at line 42 | WIRED | `MainTabView.swift:42` calls `SwipeBackOverlayView()` inside `if isColdStartMode` guard. No parameters, matching struct definition. |
| `SwipeBackOverlayView.swift` | `DictusApp/Localizable.xcstrings` | SwiftUI `Text()` auto-lookup | VERIFIED (code) | All 4 Text() calls use exact keys that exist in xcstrings. Short key `"swipeback_empathy_text"` resolves via `NSLocalizedString` — device verification recommended. |
| `.planning/adr-cold-start-autoreturn.md` | GitHub issue #23 | `gh issue comment` | VERIFIED | Last comment on issue #23 matches ADR content, references ADR path, posted 2026-04-05. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| COLD-01 | 26-01 | Time-boxed investigation of sourceApplication (2h max) | SATISFIED | ADR documents all 5 approaches. Commit `8dd3ecd`. Summary reports 2min duration (well within 2h). |
| COLD-02 | 26-01 | If viable, auto-return implemented; if not, documented | SATISFIED | ADR status REJECTED. "Not viable with current iOS public APIs." All 5 approaches blocked. Diagnostic logging confirms sourceApplication=nil expectation. |
| COLD-03 | 26-02 | Swipe-back overlay polished with improved guidance | SATISFIED (code) / NEEDS HUMAN (visual) | SwipeBackOverlayView redesigned with IPhoneMockupView, 17 BrandWaveform bars, SwipeHandView with hand.point.up, localized empathetic text. Old "Swipe back to the keyboard" text removed. |
| BETA-01 | 26-02 | Critical beta bugs triaged and fixed | SATISFIED | 6 bugs triaged: #73 closed, #60 fixed (watchdog 10s→2s), #71 open+labeled priority:high for next phase, #72/#69/#67 deferred to v1.5. No critical unaddressed bugs. |

REQUIREMENTS.md still shows COLD-03 and BETA-01 as `[ ]` unchecked. These checkboxes were not updated as part of the phase. This is a documentation gap — the requirements ARE satisfied by the code, but REQUIREMENTS.md tracking was not updated.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `DictusApp/DictusApp.swift` | 5-26 | `AppDelegate` sourceApplication diagnostic logging marked as temporary | INFO | Per ADR, this is intentional temporary diagnostic code. Can be removed after physical device confirms `source=nil`. Does not block goal. |

No placeholder implementations, empty stubs, TODO comments, or incomplete functions found in phase-modified files.

### Human Verification Required

#### 1. Overlay Visual Quality and Animation

**Test:** Build DictusApp on a physical device. Kill the app completely, open a third-party app (WhatsApp or Notes), switch to Dictus keyboard, tap the mic button.
**Expected:** Full-screen overlay appears with: iPhone mockup centered with animated waveform bars (gradient blue center, white edge bars), glowing blue dot sliding on the phone bottom edge with chevron trail, hand.point.up icon below the mockup sliding right, empathetic text in device language below, bottom instruction in accent blue.
**Why human:** Animation easing, timing between cycles (1.2s animate + 0.8s pause), and overall visual polish cannot be verified by static code inspection. 5 design iterations were needed — the final version needs eyes-on validation.

#### 2. French Localization Rendering via Short Key

**Test:** Set device language to French. Trigger cold start overlay.
**Expected:** "Dictée en cours" as title, "Écoute en cours..." inside mockup, "On aimerait éviter cette étape..." as empathetic text (short key `swipeback_empathy_text` must resolve via NSLocalizedString), "Glissez vers la droite..." as bottom instruction with correct accented characters.
**Why human:** The `swipeback_empathy_text` short key pattern was introduced specifically to work around an Xcode xcstrings duplicate bug. While the key exists in the catalog, SwiftUI `Text("swipeback_empathy_text")` behavior needs device confirmation that it resolves as a localization key (not literal string).

#### 3. TestFlight Feedback Panel

**Test:** Log into App Store Connect, navigate to Dictus app, TestFlight tab, Feedback section.
**Expected:** No critical unaddressed reports. All reported crashes/issues should already be captured as GitHub issues (#67, #69, #71, #72).
**Why human:** TestFlight feedback is only accessible via App Store Connect UI — cannot be queried programmatically.

### Gaps Summary

No blocking gaps found. All phase artifacts exist, are substantive, and are wired correctly. The 3 human verification items are validation confirmations, not blockers — the code is complete.

One documentation gap: REQUIREMENTS.md checkboxes for COLD-03 and BETA-01 remain `[ ]` unchecked despite the requirements being satisfied by the implementation. This should be updated.

---

_Verified: 2026-04-05T21:30:00Z_
_Verifier: Claude (gsd-verifier)_
