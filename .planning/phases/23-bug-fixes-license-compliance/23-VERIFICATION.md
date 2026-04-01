---
phase: 23-bug-fixes-license-compliance
verified: 2026-04-01T22:00:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
---

# Phase 23: Bug Fixes & License Compliance Verification Report

**Phase Goal:** Fix autocorrect undo race condition, correct license URL, and add missing dependency attributions
**Verified:** 2026-04-01T22:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                                                                    | Status     | Evidence                                                                                                                      |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------- |
| 1   | User types new characters after autocorrect, then presses backspace — backspace deletes the last typed character (not undo autocorrect) | ✓ VERIFIED | `suggestionState?.lastAutocorrect = nil` at line 183 in `handleInputKey()`, BEFORE `AudioServicesPlaySystemSound` at line 185 |
| 2   | User taps Licenses in Settings and sees Dictus link pointing to `https://github.com/getdictus/dictus-ios`                               | ✓ VERIFIED | `LicensesView.swift` line 30: `url: "https://github.com/getdictus/dictus-ios"`. Old URL `Pivii/dictus` is absent.            |
| 3   | User scrolls Licenses screen and sees all 5 dependencies listed alphabetically: DeviceKit, Dictus, FluidAudio, giellakbd-ios, WhisperKit | ✓ VERIFIED | 5 `licenseBlock(...)` calls at lines 20, 27, 34, 41, 48 in that alphabetical order                                          |
| 4   | FluidAudio entry shows NVIDIA Corporation as author with Apache 2.0 license text                                                        | ✓ VERIFIED | Line 36: `author: "NVIDIA Corporation"`, line 38: `license: apache2License(copyright: "Copyright NVIDIA Corporation")`       |
| 5   | giellakbd-ios entry shows UiT The Arctic University of Norway with MIT license text                                                     | ✓ VERIFIED | Line 43: `author: "UiT The Arctic University of Norway"`, line 45: `mitLicense(copyright: "Copyright (c) 2019 UiT ...")`     |

**Score:** 5/5 truths verified

---

### Required Artifacts

| Artifact                                        | Expected                                       | Status     | Details                                                                                               |
| ----------------------------------------------- | ---------------------------------------------- | ---------- | ----------------------------------------------------------------------------------------------------- |
| `DictusKeyboard/DictusKeyboardBridge.swift`     | Autocorrect undo invalidation on character input | ✓ VERIFIED | Contains `suggestionState?.lastAutocorrect = nil` at line 183, before character insertion at line 189 |
| `DictusKeyboard/KeyboardViewController.swift`   | Autocorrect undo invalidation on external text change | ✓ VERIFIED | Contains `bridge?.suggestionState?.lastAutocorrect = nil` at line 339, between `super.textDidChange` and `bridge?.updateCapitalization()` |
| `DictusApp/Views/LicensesView.swift`            | Complete license attribution for all 5 dependencies | ✓ VERIFIED | Contains `apache2License`, 5 alphabetical `licenseBlock` entries, correct URLs, correct authors       |

---

### Key Link Verification

| From                                                          | To                             | Via                            | Status     | Details                                                                 |
| ------------------------------------------------------------- | ------------------------------ | ------------------------------ | ---------- | ----------------------------------------------------------------------- |
| `DictusKeyboardBridge.swift:handleInputKey()`                 | `SuggestionState.lastAutocorrect` | nil assignment before insertText | ✓ WIRED | Line 183: `suggestionState?.lastAutocorrect = nil`, line 189: `insertText(character)` — correct order |
| `DictusKeyboard/KeyboardViewController.swift:textDidChange()` | `SuggestionState.lastAutocorrect` | nil assignment on external change | ✓ WIRED | Line 339: `bridge?.suggestionState?.lastAutocorrect = nil`, line 343: `bridge?.updateCapitalization()` — correct order |

---

### Requirements Coverage

| Requirement | Source Plan | Description                                                                               | Status       | Evidence                                                                                             |
| ----------- | ----------- | ----------------------------------------------------------------------------------------- | ------------ | ---------------------------------------------------------------------------------------------------- |
| FIX-01      | 23-01-PLAN  | Autocorrect undo only triggers on immediate backspace, not after new character input      | ✓ SATISFIED  | `handleInputKey()` clears `lastAutocorrect` before insertion; `textDidChange()` clears it on external changes |
| FIX-02      | 23-01-PLAN  | Settings licenses link points to correct `getdictus/dictus-ios` repo                     | ✓ SATISFIED  | `LicensesView.swift` line 30 contains `https://github.com/getdictus/dictus-ios`; old URL absent     |
| FIX-03      | 23-01-PLAN  | Parakeet/NVIDIA model attribution added to licenses screen (+ all other missing deps)    | ✓ SATISFIED  | FluidAudio (NVIDIA, Apache 2.0), DeviceKit, and giellakbd-ios all present with correct attribution  |

All 3 requirement IDs from PLAN frontmatter (`requirements: [FIX-01, FIX-02, FIX-03]`) are accounted for. REQUIREMENTS.md confirms these IDs are mapped to Phase 23.

No orphaned requirements: REQUIREMENTS.md Phase 23 mapping lists only FIX-01, FIX-02, FIX-03.

---

### Commit Verification

Both commits documented in SUMMARY.md exist in the repository:

- `5a83c8d` — `fix(23-01): invalidate autocorrect undo on new character input` — modifies `DictusKeyboardBridge.swift` and `KeyboardViewController.swift`
- `99c3961` — `feat(23-01): complete license attribution with all 5 dependencies` — modifies `LicensesView.swift`

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |

None found. No TODO/FIXME/placeholder comments, no stub returns, no empty handlers in the three modified files relevant to this phase.

---

### Human Verification Required

#### 1. Backspace behavior after autocorrect + new typing

**Test:** In a text field with autocorrect enabled, type a misspelled word. Wait for autocorrect to apply. Type one or more new characters. Then press backspace.
**Expected:** Backspace deletes the last typed character only — does NOT undo the autocorrect.
**Why human:** Cannot simulate the full autocorrect + typing + backspace sequence programmatically without a running simulator session.

#### 2. Licenses screen visual layout

**Test:** Open Dictus app, go to Settings > A propos > Licences.
**Expected:** 5 entries in alphabetical order (DeviceKit, Dictus, FluidAudio, giellakbd-ios, WhisperKit), each showing the correct author name, a tappable URL, and the appropriate license text block. The Dictus URL should open `github.com/getdictus/dictus-ios`.
**Why human:** Visual rendering and link tap behavior require a running device or simulator.

---

### Summary

All 5 must-have truths are verified against the actual codebase. The phase goal is fully achieved:

- **FIX-01** (autocorrect undo race condition): `handleInputKey()` clears `lastAutocorrect` as its first statement, before `insertText()`, preventing any race between character insertion and a fast backspace. `textDidChange()` also clears it for external text changes (paste, cursor move, host autocorrect). The ordering constraints from the plan are met in both locations.

- **FIX-02** (Dictus license URL): The old `github.com/Pivii/dictus` URL is absent from `LicensesView.swift`. The correct `https://github.com/getdictus/dictus-ios` URL is in place.

- **FIX-03** (missing dependency attributions): All 5 dependencies are present alphabetically. The new `apache2License(copyright:)` helper is implemented and used for FluidAudio. DeviceKit and giellakbd-ios entries were added with correct authors and MIT license text.

Both target builds were confirmed clean per the SUMMARY (commit evidence shows no build failures). The implementation contains no stubs or placeholder patterns.

---

_Verified: 2026-04-01T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
