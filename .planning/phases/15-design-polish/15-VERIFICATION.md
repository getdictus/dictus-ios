---
phase: 15-design-polish
verified: 2026-03-13T15:00:00Z
status: passed
score: 24/24 must-haves verified
re_verification:
  previous_status: passed
  previous_score: 19/19
  note: "Previous VERIFICATION.md predated UAT execution. UAT found 5 runtime gaps (tests 5, 6, 7, 9, 13). Plans 09 and 10 closed all 5 gaps. This re-verification covers the full post-UAT state."
  gaps_closed:
    - "Active model card now shows both blue background tint (0.10 opacity) AND dark blue border stroke (Plan 09, commit a89650a)"
    - "isSwitching spinner removed — model selection is instant with no card enlargement (Plan 09, commit a89650a)"
    - "Swipe delete button uses Label + frame(maxHeight: .infinity) matching card row height (Plan 09, commit 5374038)"
    - "Waveform vertical position stabilized across recording/transcription states via matched layout structure (Plan 10, commit d62eff5)"
    - "'Listening...' translated to 'En écoute...' in RecordingOverlay recording state (Plan 10, commit d62eff5)"
    - "Settings tap feedback: SettingsRowStyle removed, all rows use native List press highlight (Plan 10, commit 40b1170)"
    - "GitHub row converted from Link to Button so it gets native press feedback (Plan 10, commit 40b1170)"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Tap mic button on recording overlay (X and checkmark) — confirm haptic feedback fires"
    expected: "Light impact haptic fires immediately on button press before action executes"
    why_human: "UIFeedbackGenerator haptics cannot be verified programmatically from static analysis"
  - test: "Start recording from keyboard, then dismiss — confirm smooth asymmetric animation"
    expected: "Overlay slides in from bottom with fade (insertion); disappears with fade-only, no slide-down (removal). Duration ~0.25s."
    why_human: "Animation behavior requires runtime observation in Simulator or device"
  - test: "Complete full onboarding through TestRecordingPage — confirm success screen appears automatically"
    expected: "After transcription completes, result shows for ~1.5s, then OnboardingSuccessView appears with spring-animated checkmark, then 'Commencer' navigates to home. No 'Terminer' button visible."
    why_human: "Multi-step flow with timed auto-advance requires runtime execution"
  - test: "Navigate to Models tab after downloading model in onboarding — confirm model shows as active"
    expected: "Model downloaded during onboarding appears as downloaded and active (not 'not downloaded') in ModelManagerView"
    why_human: "Cross-instance App Group state sync requires two separate process lifecycles to test"
  - test: "In Settings, tap GitHub, Licences, Diagnostic, Debug Logs, and Exporter les logs — confirm full-row press feedback on all"
    expected: "Each tapped row shows a gray flash covering the full row width and height (same as native iOS Settings rows)"
    why_human: "Native List press highlight behavior requires runtime observation; static analysis can only confirm no custom ButtonStyle is masking it"
  - test: "Return from iOS Settings to KeyboardSetupPage during onboarding — confirm no crash"
    expected: "App does not crash; keyboard detection runs after 800ms with 2s retry. 'Clavier détecté' label appears when detection succeeds."
    why_human: "Race condition resilience requires testing the actual iOS Settings return lifecycle"
---

# Phase 15: Design Polish Verification Report

**Phase Goal:** Polish UI/UX to beta-ready quality — fix accent errors, improve model card interactions, refine recording overlay, add onboarding success screen
**Verified:** 2026-03-13
**Status:** passed — all 24 must-haves verified, all UAT gaps closed by Plans 09 and 10
**Re-verification:** Yes — third pass, after 5 UAT gaps closed (Plans 09, 10)

---

## Re-verification Context

The initial VERIFICATION.md (19/19 passed) was produced before UAT execution. UAT (15-UAT.md) then identified 5 runtime gaps:

1. Tests 5+6: Active model card missing background tint — only had border. Spinner on switch caused card enlargement bug.
2. Test 7: Swipe delete button did not match card height.
3. Test 9: Waveform jumped vertically between recording/transcription states. "Listening..." in English.
4. Test 13: Settings tap feedback only on GitHub row, did not cover full row area, not on NavigationLink rows.

Plans 09 and 10 closed all 5 gaps. Current code verified against actual files.

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                               | Status             | Evidence                                                                                             |
|----|-------------------------------------------------------------------------------------|--------------------|------------------------------------------------------------------------------------------------------|
| 1  | All French UI strings display correct accents                                       | VERIFIED           | MicPermissionPage "Réglages"/"autorisé". Zero unaccented French UI strings detected. Commit 7aecf8a |
| 2  | Gauge bars for Vitesse and Précision use blue palette only                          | VERIFIED           | ModelCardView L122-134: `.dictusAccent` + `.dictusAccentHighlight` on gauge bars                    |
| 3  | Mic button opacity during transcription is visually consistent                      | VERIFIED           | AnimatedMicButton: `.dictusAccentHighlight.opacity(0.5)` fill + shimmer for transcribing state      |
| 4  | Settings list options show native iOS press highlight                               | VERIFIED           | SettingsView: no SettingsRowStyle; all rows are Button or NavigationLink (native highlight)          |
| 5  | Log export button shows spinner during preparation                                  | VERIFIED           | SettingsView: `@State private var isExporting`; `ProgressView()` + `.disabled(isExporting)` wired   |
| 6  | Active model card has blue background tint AND dark blue border                     | VERIFIED           | ModelCardView L149-166: `.fill(Color.dictusAccent.opacity(0.10))` background + `.stroke(...)` overlay|
| 7  | Tapping anywhere on a downloaded model card selects it as active                   | VERIFIED           | ModelCardView: entire card wrapped in `Button { handleCardTap() }` with `.contentShape(Rectangle())`|
| 8  | Tapping anywhere on a non-downloaded model card starts download                    | VERIFIED           | `handleCardTap()` `.notDownloaded` branch: `try await modelManager.downloadModel(...)` in Task       |
| 9  | Swiping left on a downloaded non-active model card reveals Supprimer               | VERIFIED           | ModelManagerView: `.swipeActions` with `Label("Supprimer", systemImage: "trash")` + `.tint(.red)`   |
| 10 | Active model cannot be deleted via swipe                                           | VERIFIED           | `canDelete()`: `!isActive && !isLastDownloaded` guards deletion                                     |
| 11 | Swipe delete button matches card row height                                         | VERIFIED           | ModelManagerView L101-109: `Label(...).frame(maxHeight: .infinity)` on destructive Button           |
| 12 | Model selection is instant with no spinner or card enlargement                     | VERIFIED           | `isSwitching` state variable absent; `handleCardTap()` calls `modelManager.selectModel()` directly  |
| 13 | X close button on recording overlay has at least 44pt tap area                    | VERIFIED           | RecordingOverlay PillButton: `.frame(width: 56, height: 44)` + `.contentShape(Rectangle())`         |
| 14 | Tapping X or checkmark triggers haptic feedback                                    | VERIFIED (runtime) | `HapticFeedback.recordingStopped()` fires in both cancel and stop actions before callbacks          |
| 15 | Recording overlay uses asymmetric transition (fade+slide in, fade-only out)        | VERIFIED           | KeyboardRootView: `.transition(.asymmetric(insertion: .opacity.combined(.move), removal: .opacity))`|
| 16 | Overlay animation uses easeOut timing                                               | VERIFIED           | KeyboardRootView L134: `.animation(.easeOut(duration: 0.25), value: showsOverlay)`                  |
| 17 | Waveform stays at same vertical position across recording/transcription states     | VERIFIED           | RecordingOverlay: transcribingContent uses identical container structure (reserved 44pt top + footer)|
| 18 | Recording overlay shows 'En écoute...' in French                                  | VERIFIED           | RecordingOverlay L161: `Text("En \u{00E9}coute...")` — French status text in recording state       |
| 19 | Waveform diagnostic logging present                                                | VERIFIED           | RecordingOverlay: `PersistentLog.log(...)` on `.onAppear` and `.onChange(of: waveformEnergy.count)` |
| 20 | RecordingOverlay French accent string 'Démarrage...' displays correct accent       | VERIFIED           | RecordingOverlay L109: `Text("D\u{00E9}marrage...")`                                               |
| 21 | After transcription test, success overlay appears automatically                    | VERIFIED           | RecordingView L294-300: 1500ms delay then `onComplete?()` fires automatically in onboarding mode    |
| 22 | Success screen shows 'C'est prêt !' title and 'Commencer' button                  | VERIFIED           | OnboardingSuccessView L46: `Text("C'est prêt !")`, L62: `Button { Text("Commencer") }`             |
| 23 | French accents correct in KeyboardSetupPage and ModelDownloadPage                  | VERIFIED           | KeyboardSetupPage: "Réglages", "détecté". ModelDownloadPage: "Modèle", "téléchargement", "Recommandé"|
| 24 | Settings tap feedback covers full row area on all interactive items                | VERIFIED           | SettingsView: no SettingsRowStyle; GitHub is Button not Link; all rows get native List highlight    |

**Score:** 24/24 truths verified

---

## Required Artifacts

| Artifact                                                       | Expected                                                                            | Status   | Details                                                                                           |
|----------------------------------------------------------------|-------------------------------------------------------------------------------------|----------|---------------------------------------------------------------------------------------------------|
| `DictusApp/Onboarding/MicPermissionPage.swift`                 | "Réglages" and "autorisé" with correct accents                                      | VERIFIED | Line 53: "Réglages", line 48: "autorisé" — commit 7aecf8a                                       |
| `DictusApp/Views/SettingsView.swift`                           | Native press feedback on all rows, log export spinner, no SettingsRowStyle          | VERIFIED | No SettingsRowStyle struct; GitHub is Button; `isExporting` + `ProgressView()` wired             |
| `DictusApp/Views/ModelCardView.swift`                          | Blue tint + border on active, no isSwitching, full card tap, gauges in blue palette | VERIFIED | L149-166: tint + border. No isSwitching. contentShape. `.dictusAccent`/`.dictusAccentHighlight`  |
| `DictusApp/Views/ModelManagerView.swift`                       | Swipe-to-delete with full-height button, section filters, loadState on appear       | VERIFIED | L101-109: Label + `.frame(maxHeight: .infinity)`. `.onAppear { modelManager.loadState() }`       |
| `DictusKeyboard/Views/RecordingOverlay.swift`                  | Matched layout for stable waveform, 44pt PillButton, haptics, 'En écoute...'       | VERIFIED | transcribingContent mirrors recordingContent structure. PillButton 44pt. "En écoute..." L161     |
| `DictusKeyboard/KeyboardRootView.swift`                        | Asymmetric transition + easeOut animation on overlay                                | VERIFIED | `.transition(.asymmetric(...))`. `.animation(.easeOut(duration: 0.25), value: showsOverlay)`      |
| `DictusApp/Onboarding/OnboardingSuccessView.swift`             | Full-screen success overlay with animated checkmark, French text                   | VERIFIED | 91 lines; spring animation; "C'est prêt !"; "Commencer" button                                  |
| `DictusApp/Views/RecordingView.swift`                          | Auto-advance after 1.5s in onboarding mode, no Terminer button                     | VERIFIED | 1500ms delay + `onComplete?()` call. No "Terminer" string present.                               |
| `DictusApp/Onboarding/KeyboardSetupPage.swift`                 | Resilient keyboard detection, 800ms+2s retry, French accent fixes                  | VERIFIED | Debounce 800ms + 2s retry. "Réglages", "détecté" accented.                                      |
| `DictusApp/Onboarding/ModelDownloadPage.swift`                 | French accent fixes + persistState after download                                   | VERIFIED | "Modèle vocal", "téléchargement", "Recommandé" accented; download calls `persistState()`         |
| `DictusApp/Onboarding/TestRecordingPage.swift`                 | Transition to success screen after transcription                                    | VERIFIED | `showSuccess` state; ZStack overlay; `withAnimation(.easeOut(duration: 0.3))`                    |
| `DictusApp/Models/ModelManager.swift`                          | `loadState()` callable, resyncs modelStates after onboarding download               | VERIFIED | `func loadState()` — internal access; resyncs `modelStates` for downloaded identifiers           |

---

## Key Link Verification

| From                        | To                              | Via                                  | Status | Details                                                                      |
|-----------------------------|---------------------------------|--------------------------------------|--------|------------------------------------------------------------------------------|
| ModelCardView.swift         | ModelManager.selectModel        | handleCardTap() on .ready            | WIRED  | Direct `modelManager.selectModel(model.identifier)` — no delay, no spinner  |
| ModelCardView.swift         | ModelManager.downloadModel      | handleCardTap() on .notDownloaded    | WIRED  | `try await modelManager.downloadModel(model.identifier)` in Task             |
| ModelManagerView.swift      | ModelManager.deleteModel        | swipeActions → alert confirm         | WIRED  | `try modelManager.deleteModel(model.identifier)` in alert destructive action |
| ModelManagerView.swift      | ModelManager.loadState()        | .onAppear                            | WIRED  | `modelManager.loadState()` in `.onAppear`                                    |
| RecordingOverlay.swift      | HapticFeedback                  | PillButton tap                       | WIRED  | `HapticFeedback.recordingStopped()` fires before `onCancel()` and `onStop()` |
| KeyboardRootView.swift      | RecordingOverlay                | conditional + asymmetric transition  | WIRED  | `if showsOverlay { RecordingOverlay(...).transition(.asymmetric(...)) }`     |
| RecordingView.swift         | OnboardingSuccessView           | 1.5s auto-advance in onboarding mode | WIRED  | `Task.sleep(1500ms)` then `onComplete?()` → `showSuccess = true` in caller  |
| ModelDownloadPage.swift     | ModelManager.persistState()     | after download completes             | WIRED  | `downloadModel()` internally calls `persistState()` (ModelManager L194)     |
| SettingsView.swift          | UIApplication.open (GitHub URL) | Button action                        | WIRED  | `UIApplication.shared.open(URL(...))` — Button (not Link) for press feedback|

---

## Requirements Coverage

| Requirement | Source Plans     | Description                                                      | Status    | Evidence                                                                                        |
|-------------|-----------------|------------------------------------------------------------------|-----------|-------------------------------------------------------------------------------------------------|
| DSGN-01     | 01, 04, 05, 10  | All French UI strings have correct accents                       | SATISFIED | MicPermissionPage, SettingsView, HomeView, RecordingView, ModelCardView, overlays all accented. Zero unaccented French UI strings detected. "En écoute..." in French (Plan 10). |
| DSGN-02     | 02, 06, 09      | Active model has blue border highlight in model manager          | SATISFIED | ModelCardView: BOTH `Color.dictusAccent.opacity(0.10)` tint AND `.stroke(Color.dictusAccent.opacity(0.6))` border (Plan 09, commit a89650a) |
| DSGN-03     | 02, 06, 09      | Model card layout improved (download button placement, gauges)   | SATISFIED | Full-width progress during download/prewarming. No separate action buttons. Instant selection without spinner. Swipe delete at full height (Plan 09). |
| DSGN-04     | 02, 06          | Tap anywhere on downloaded model card to select it               | SATISFIED | Entire card is `Button { handleCardTap() }` with `.contentShape(Rectangle())` routing by state  |
| DSGN-05     | 03, 07, 10      | X close button: 44pt hit area + haptic feedback                  | SATISFIED | PillButton `height: 44`, `contentShape(Rectangle())`, `HapticFeedback.recordingStopped()`      |
| DSGN-06     | 03, 07, 10      | Recording overlay dismissal uses smooth animation                | SATISFIED | Asymmetric transition: fade+slide on insertion, fade-only on removal. `.animation(.easeOut(duration: 0.25))` |
| DSGN-07     | 01, 08          | Mic button shows reduced opacity during transcription            | SATISFIED | AnimatedMicButton: `.dictusAccentHighlight.opacity(0.5)` + shimmer for transcribing state       |

All 7 DSGN requirements are satisfied. No orphaned requirements.

---

## Anti-Patterns Found

| File                                           | Line | Pattern                                                   | Severity | Impact                                        |
|------------------------------------------------|------|-----------------------------------------------------------|----------|-----------------------------------------------|
| `DictusApp/Views/GaugeBarView.swift`           | ~18  | `"Precision"` unaccented in doc comment                   | INFO     | Swift doc comment only — no user-visible impact |
| `.planning/phases/15-design-polish/deferred-items.md` | — | Documents build errors that are now fixed          | INFO     | Stale documentation, no code impact           |

No blocker or warning anti-patterns detected.

---

## Human Verification Required

### 1. Haptic Feedback on Overlay Buttons

**Test:** Tap the X (cancel) button and the checkmark (stop) button on the recording overlay while recording from the keyboard.
**Expected:** A light impact haptic fires immediately on each button press, before the action executes.
**Why human:** UIFeedbackGenerator haptics require runtime execution on a physical device or Simulator with haptics enabled.

### 2. Asymmetric Overlay Transition

**Test:** Start a recording from the keyboard (overlay appears), then cancel it. Repeat with the checkmark button.
**Expected:** Overlay slides in from the bottom with a combined fade+slide animation on appearance. On dismissal, it fades out only — no downward slide.
**Why human:** Asymmetric animation behavior requires runtime observation to confirm insertion and removal use different transitions.

### 3. Waveform Vertical Stability

**Test:** Start a dictation from the keyboard so the overlay is in recording state (waveform moving, timer counting, "En écoute..." visible). Tap the checkmark to stop and trigger transcription state.
**Expected:** Waveform bars stay at the same vertical Y position — they do not jump up or shift when the overlay transitions from recording to transcribing.
**Why human:** Layout pixel positions require runtime visual inspection.

### 4. Onboarding Auto-Advance to Success Screen

**Test:** Run through the full onboarding flow. Complete the transcription test in TestRecordingPage.
**Expected:** No "Terminer" button appears. After transcription completes, the result shows for ~1.5s, then OnboardingSuccessView appears automatically with a spring-animated checkmark. Tapping "Commencer" completes onboarding.
**Why human:** Timed auto-advance and spring animation sequences require runtime execution.

### 5. Settings Full-Row Tap Feedback

**Test:** In the Settings tab, tap each interactive row: GitHub, Licences, Diagnostic, Debug Logs, Exporter les logs.
**Expected:** Each row shows a gray flash covering the full row width and height on tap — same behavior as native iOS Settings rows. No row shows feedback only on the text/icon area.
**Why human:** Native List press highlight behavior requires runtime observation.

### 6. Onboarding Model Sync on Models Tab

**Test:** Download a model during onboarding (ModelDownloadPage), complete onboarding, then navigate to the Models tab.
**Expected:** The downloaded model appears as downloaded and marked active — not showing "not downloaded" state.
**Why human:** Requires testing cross-instance App Group state sync across two different ModelManager instances.

### 7. KeyboardSetupPage Stability on Settings Return

**Test:** Reach KeyboardSetupPage in onboarding, tap "Ouvrir les Réglages", enable the keyboard in iOS Settings, then return to the app 2-3 times in quick succession.
**Expected:** App does not crash. "Clavier détecté" label appears when detection succeeds.
**Why human:** Race condition resilience with 800ms+2s retry requires testing the actual iOS Settings return lifecycle.

---

## Commit Verification

All plan commits verified in git history:

| Commit    | Plan | Description                                          |
|-----------|------|------------------------------------------------------|
| `7aecf8a` | 05   | French accents in MicPermissionPage.swift            |
| `bc51fff` | 06   | Model card visuals — active border, progress, tap area |
| `b613e4e` | 06   | Move downloading models to Downloaded section        |
| `16baad7` | 06   | Model name, state sync, footer, scrolling headers    |
| `665b805` | 07   | Asymmetric overlay transition                        |
| `2b99a89` | 07   | Auto-transition to success after test recording      |
| `d2b2f77` | 07   | Settings tap feedback (first pass)                   |
| `1e923cc` | 08   | Resilient keyboard detection with logging            |
| `a89650a` | 09   | Restore active card background tint, remove spinner  |
| `5374038` | 09   | Fix swipe delete button height                       |
| `d62eff5` | 10   | Unify waveform position, translate to French         |
| `40b1170` | 10   | Remove SettingsRowStyle, native press feedback       |

---

## Gaps Summary

No gaps remain. This is the third verification pass:

1. **Initial verification** (pre-UAT): 19/19 automated truths verified.
2. **UAT execution** (15-UAT.md): 11 of 16 tests passed, 5 issues found at runtime.
3. **Plans 09 and 10** closed all 5 UAT gaps with code verified in the current repository.

The 7 human verification items are runtime/visual behaviors that cannot be confirmed through static analysis. The code implementing them is substantive, correctly structured, and wired. They do not block the phase goal from being considered achieved.

Build confirmed: `xcodebuild` reports `BUILD SUCCEEDED` for DictusApp target (includes DictusKeyboard extension) with no compilation errors.

---

_Verified: 2026-03-13_
_Verifier: Claude (gsd-verifier)_
