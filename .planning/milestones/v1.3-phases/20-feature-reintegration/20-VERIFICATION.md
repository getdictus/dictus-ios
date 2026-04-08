---
phase: 20-feature-reintegration
verified: 2026-03-30T10:30:00Z
status: human_needed
score: 15/15 automated must-haves verified
re_verification: false
human_verification:
  - test: "Full UAT on physical device — DICT-01 through DICT-04"
    expected: |
      DICT-01: Mic button tap starts recording overlay
      DICT-02: Waveform visible and responsive during recording
      DICT-03: Transcription auto-inserts at cursor; suggestion bar updates after insert
      DICT-04: Full Access banner shows when permissions are missing
    why_human: >
      Plan 02 Task 2 is a blocking human-verify checkpoint. The summary documents
      that UAT was performed and 4 bugs were found and fixed (commit f1f4713), but
      the summary does not contain an explicit "approved" signal and no human
      approval record exists in the phase directory. DICT-01 through DICT-04 also
      remain marked Pending / [ ] in REQUIREMENTS.md, indicating they were never
      formally checked off.
  - test: "Prediction quality — autocorrect produces useful corrections"
    expected: >
      Typing a misspelled word and pressing space produces a plausible correction
      (e.g., "helo " -> "hello ", not "helons ")
    why_human: >
      The Phase 20-02 summary explicitly notes: "Prediction quality is poor (e.g.,
      'helo' -> 'helons' instead of 'hello'). Deferred to a future phase."
      The autocorrect pipeline is wired (PRED-03 code is present), but the
      underlying spell-check engine quality is unresolved and user-observable.
  - test: "Emoji picker layout on device — no clipping, correct height"
    expected: >
      Emoji picker shows full-width with no left-edge clipping; does not overflow
      into toolbar; toolbar + mic button remain visible during browsing
    why_human: >
      The safeAreaRegions fix (iOS 16.4+) and .clipped() were applied in
      commit f1f4713 based on UAT feedback, but the fixes are conditional
      (#available iOS 16.4) and rendering correctness cannot be verified
      statically.
---

# Phase 20: Feature Reintegration — Verification Report

**Phase Goal:** Reintegrate features disconnected during Phase 18 UIKit keyboard rebuild — text prediction pipeline, autocorrect, emoji picker, dictation flow validation, default layer setting.
**Verified:** 2026-03-30
**Status:** HUMAN_NEEDED — all automated checks pass, 3 items require device testing
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Typing characters causes suggestion bar to show completions | VERIFIED | `suggestionState?.updateAsync(context:)` called in `handleInputKey` (DictusKeyboardBridge.swift:204) |
| 2 | Typing a single vowel causes suggestion bar to show accent variants | VERIFIED | `SuggestionState.updateAsync` handles single-vowel accent mode; `mode: SuggestionMode` drives ToolbarView display |
| 3 | Tapping a suggestion inserts it and adds a space (completion mode) | VERIFIED | `handleSuggestionTap` in KeyboardRootView.swift:228 calls `replaceCurrentWord` with `addSpace: true` in `.completions` mode |
| 4 | Tapping an accent suggestion replaces the vowel without a space | VERIFIED | Same function with `addSpace: false` when `mode == .accents` |
| 5 | Typing a misspelled word and pressing space auto-replaces with correction | VERIFIED | `handleSpace()` in DictusKeyboardBridge.swift:308 calls `state.performSpellCheck(state.currentWord)` and replaces on match |
| 6 | Pressing backspace immediately after autocorrect restores the original word | VERIFIED | `handleBackspace()` checks `suggestionState?.lastAutocorrect` and calls `proxy?.insertText(autocorrect.originalWord)` (line 225) |
| 7 | Setting default layer to numbers causes keyboard to open on numbers page | VERIFIED | `viewWillAppear` reads `DefaultKeyboardLayer.active` and sets `giellaKeyboard?.page = .symbols1` (KeyboardViewController.swift:207-209) |
| 8 | Tapping emoji button hides keyboard grid and shows emoji picker | VERIFIED | Bridge detects `character == "\u{1F600}"` → `handleEmojiToggle()` → `onEmojiToggle?()` → `toggleEmojiPicker()` → posts `.dictusToggleEmoji` → `showingEmoji.toggle()` in RootView |
| 9 | Tapping ABC in emoji picker returns to the keyboard grid | VERIFIED | `onDismiss` closure in EmojiPickerView call sets `showingEmoji = false` and posts `.dictusToggleEmoji` (KeyboardRootView.swift:111-113) |
| 10 | Toolbar with mic button stays visible during emoji browsing | VERIFIED | `showingEmoji` branch in body renders `ToolbarView` before `EmojiPickerView` (KeyboardRootView.swift:88-98) |
| 11 | Tapping mic button during emoji browsing starts recording | VERIFIED | `onMicTap` in emoji branch sets `showingEmoji = false` then calls `state.startRecording()` (line 92-94) |
| 12 | Recording overlay replaces keyboard area during dictation | VERIFIED | `showsOverlay` branch is first in body; `handleDictationStatusChange` expands `hostingHeightConstraint` to full height when recording |
| 13 | Transcription text is inserted at cursor after recording completes | VERIFIED | `handleTranscriptionReady()` in KeyboardState.swift calls `controller?.textDocumentProxy.insertText(transcription)` — both primary (line 332) and retry (line 361) paths |
| 14 | After transcription insert, suggestion bar shows completions for last word | VERIFIED | `KeyboardState.shared.onTranscriptionInserted` closure in KeyboardViewController.swift:161 calls `suggestionState.updateAsync(context: context)` |
| 15 | Full Access banner shows when permissions are missing | VERIFIED | `ToolbarView(hasFullAccess: controller.hasFullAccess, ...)` — hasFullAccess passed in all three body branches; ToolbarView handles the banner display |

**Score:** 15/15 truths verified (code-level)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `DictusKeyboard/DictusKeyboardBridge.swift` | SuggestionState integration, autocorrect-on-space, undo-on-backspace | VERIFIED | Contains `weak var suggestionState: SuggestionState?`, `updateAsync` calls in 5 handlers, full autocorrect logic |
| `DictusKeyboard/KeyboardViewController.swift` | SuggestionState ownership, bridge injection, default layer setting | VERIFIED | `private let suggestionState = SuggestionState()`, `keyBridge.suggestionState = suggestionState`, `DefaultKeyboardLayer.active` in `viewWillAppear` |
| `DictusKeyboard/KeyboardRootView.swift` | ObservedObject for externally-created SuggestionState, 3-mode body, showingEmoji | VERIFIED | `@ObservedObject var suggestionState: SuggestionState`, `@State private var showingEmoji = false`, 3-branch body, `.onReceive` for toggle |
| `DictusKeyboard/FrenchKeyboardLayouts.swift` | Emoji key in bottom row | VERIFIED | `lettersBottomRow` has 4 keys: `.symbols`, `.input(key: "\u{1F600}", alternate: nil)`, `.spacebar`, `.returnkey` |
| `DictusKeyboard/KeyboardState.swift` | Post-transcription callback | VERIFIED | `var onTranscriptionInserted: (() -> Void)?` at line 46; called in both insert paths |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `KeyboardViewController.swift` | `DictusKeyboardBridge.swift` | `bridge.suggestionState = suggestionState` | WIRED | Line 82: `keyBridge.suggestionState = suggestionState` |
| `DictusKeyboardBridge.swift` | `SuggestionState.swift` | `suggestionState?.updateAsync(context:)` | WIRED | Present in handleInputKey, handleBackspace, handleSpace, handleAdaptiveAccentKey, handleWordDelete |
| `KeyboardViewController.swift` | `KeyboardRootView.swift` | `KeyboardRootView(controller:controllerID:suggestionState:)` | WIRED | Line 90: `KeyboardRootView(controller: self, controllerID: controllerID, suggestionState: suggestionState)` |
| `KeyboardState.swift` | `KeyboardViewController.swift` | `onTranscriptionInserted` closure | WIRED | `KeyboardState.shared.onTranscriptionInserted = { [weak self] in ... self.suggestionState.updateAsync(context: context) }` |
| `KeyboardViewController.swift` | `SuggestionState.swift` | `suggestionState.updateAsync` after transcription | WIRED | Inside `onTranscriptionInserted` closure at line 164 |
| `KeyboardRootView.swift` | `EmojiPickerView.swift` | `EmojiPickerView` rendered when `showingEmoji` is true | WIRED | Line 101: `EmojiPickerView(onEmojiInsert:onDelete:onDismiss:)` — init signature adapted from plan assumption to actual API |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PRED-01 | 20-01 | User sees 3-slot suggestion bar with French autocorrect suggestions | SATISFIED | Bridge triggers `updateAsync` on every keystroke; RootView displays `suggestionState.suggestions` in ToolbarView |
| PRED-02 | 20-01 | User can tap suggestion to insert it | SATISFIED | `handleSuggestionTap` in KeyboardRootView wires tap → `replaceCurrentWord` + `addSpace` logic |
| PRED-03 | 20-01 | User can undo autocorrect by pressing backspace immediately after | SATISFIED | `handleSpace` stores `AutocorrectState`; `handleBackspace` checks and restores original word |
| SET-01 | 20-01 | User can select default opening layer (letters or numbers) with live preview | SATISFIED | `DefaultKeyboardLayer.active` read in `viewWillAppear`, sets `.symbols1` page for numbers preference |
| DICT-01 | 20-02 | User can tap mic button in toolbar to start recording | SATISFIED (code) | `ToolbarView(onMicTap: { state.startRecording() })` in all 3 body branches; REQUIREMENTS.md still shows `[ ]` Pending — tracking file not updated |
| DICT-02 | 20-02 | User sees recording overlay with waveform replacing keyboard during dictation | SATISFIED (code) | `RecordingOverlay` rendered in `showsOverlay` branch; `hostingHeightConstraint` expanded; `giellaKeyboard` hidden |
| DICT-03 | 20-02 | User gets transcription auto-inserted at cursor after recording | SATISFIED (code) | `handleTranscriptionReady` inserts via `textDocumentProxy`; `onTranscriptionInserted` triggers `updateAsync` |
| DICT-04 | 20-02 | User sees Full Access banner when permissions needed | SATISFIED (code) | `hasFullAccess: controller.hasFullAccess` passed to ToolbarView in all branches |

**Note on REQUIREMENTS.md:** DICT-01 through DICT-04 remain marked `[ ]` (incomplete) and "Pending" in the phase tracking table despite the implementation being present. PRED-01/02/03 and SET-01 are correctly marked `[x]` / "Complete". The DICT requirements were wired in Phases 18/19 and reconnected/validated in Phase 20 UAT — the tracking file was not updated. This is a documentation gap, not a code gap.

**Note on prediction quality:** Phase 20-02 summary explicitly defers prediction quality improvement ("helo" → "helons" instead of "hello") to a future phase. PRED-03 is structurally wired correctly but the autocorrect behavior may produce poor corrections in practice.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `DictusKeyboard/KeyboardViewController.swift` | 383 | Comment "Wired by Plan 02" (outdated) | Info | No functional impact; Plan 02 is complete and the comment is stale |
| `DictusKeyboard/FrenchKeyboardLayouts.swift` | 114 | Comment "Row 4: 123 + space + return" on qwertyNormal (not updated) | Info | Stale comment; actual layout correctly uses `lettersBottomRow` which includes emoji key |

No blocker or warning-level anti-patterns found.

---

### Human Verification Required

#### 1. Full UAT — DICT-01 through DICT-04 dictation flow

**Test:** Build and install on a physical device. Open a text field (Notes, Messages). Tap the mic button — verify recording overlay appears with waveform. Speak a sentence, tap stop — verify transcription inserts at cursor and suggestion bar shows completions for the last word. If Full Access is disabled, verify the toolbar shows the Full Access banner instead of the mic button.

**Expected:**
- DICT-01: Mic tap starts recording, overlay replaces keyboard grid
- DICT-02: Waveform animation visible and responsive to voice
- DICT-03: Transcription appears at cursor; suggestion bar updates after insert
- DICT-04: Full Access banner visible when `hasFullAccess == false`

**Why human:** Plan 02 Task 2 is a `checkpoint:human-verify` gate. UAT was performed (4 bugs fixed in commit f1f4713) but no explicit "approved" signal is recorded. DICT-01 through DICT-04 remain `[ ]` Pending in REQUIREMENTS.md. The dictation flow involves cross-process IPC (Darwin notifications), real microphone input, and URL scheme app switching — none of which can be verified statically.

---

#### 2. Autocorrect quality — real-word corrections

**Test:** Type misspelled French words ("helo ", "bonjuor ", "slt ") and verify autocorrect produces plausible corrections.

**Expected:** Words replaced with correct French spelling on space press.

**Why human:** Phase 20-02 summary explicitly notes this issue: "helo" → "helons" instead of "hello". The prediction engine quality (TextPredictionEngine + UITextChecker) cannot be assessed without running the keyboard on a real device with real text input.

---

#### 3. Emoji picker rendering on device

**Test:** Tap the emoji button (smiley face in bottom row). Verify the picker is full-width with no left-edge clipping and does not overflow into the toolbar area. Test on both iPhone SE (small screen) and a standard device.

**Expected:** Picker fills keyboard area cleanly; toolbar with mic stays visible above it.

**Why human:** The `safeAreaRegions = []` fix is conditional on `#available(iOS 16.4, *)`. Rendering correctness depends on the iOS version and device screen size. The `.clipped()` fix was applied based on UAT feedback and cannot be verified statically.

---

### Gaps Summary

No code gaps were found. All 15 observable truths are verified against the codebase. All artifacts exist with substantive implementations. All key links are wired and active.

Three items remain for human verification:
1. The Phase 20-02 blocking UAT checkpoint has no recorded approval signal
2. Autocorrect quality is acknowledged as poor and deferred to a future phase
3. Emoji picker rendering correctness depends on device/OS version

The REQUIREMENTS.md tracking table for DICT-01 through DICT-04 should be updated from "Pending" / `[ ]` to "Complete" / `[x]` once UAT is formally approved.

---

_Verified: 2026-03-30_
_Verifier: Claude (gsd-verifier)_
