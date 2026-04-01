# Phase 23: Bug Fixes & License Compliance - Research

**Researched:** 2026-04-01
**Domain:** iOS keyboard extension bug fix + SwiftUI license view updates
**Confidence:** HIGH

## Summary

Phase 23 addresses three small, well-scoped requirements: fixing an autocorrect undo race condition in the keyboard bridge, correcting the Dictus repo URL on the licenses screen, and adding missing dependency attributions (FluidAudio, DeviceKit, giellakbd-ios). All three are isolated changes with no cross-cutting architectural impact.

The autocorrect fix is a one-line addition (`lastAutocorrect = nil`) in `handleInputKey()` plus a matching clear in `textDidChange()` for external cursor changes. The license work is purely additive: two new license text helpers (`apache2License()`, `bsd3License()`) and three new `licenseBlock()` calls in the existing `LicensesView`.

**Primary recommendation:** Implement all three fixes in a single plan -- they touch different files, have zero interdependency, and can be verified independently.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Clear `lastAutocorrect` on ANY new character input in `handleCharacter()` -- only the very next backspace after autocorrect triggers undo (matches iOS native behavior)
- Also clear `lastAutocorrect` on cursor movement (detected via `textDidChange` / `selectionDidChange` in KeyboardViewController)
- The fix is in `DictusKeyboardBridge.handleCharacter()` (add `suggestionState?.lastAutocorrect = nil`) and in `KeyboardViewController` for cursor change detection
- Full Apache 2.0 license text block for FluidAudio, same layout as existing WhisperKit entry
- Author: NVIDIA Corporation (or as specified in their repo)
- URL: https://github.com/FluidInference/FluidAudio.git
- Need an `apache2License()` helper alongside existing `mitLicense()` in LicensesView
- List ALL open-source dependencies: DeviceKit (MIT), Dictus (MIT), FluidAudio/Parakeet (Apache 2.0), giellakbd-ios (BSD-3/MIT dual), WhisperKit (MIT)
- Order: alphabetical by name
- Fix Dictus repo URL from `github.com/Pivii/dictus` to `github.com/getdictus/dictus-ios`
- giellakbd-ios is vendored (not SPM) -- still needs attribution with correct license text
- Need a `bsd3License()` helper for giellakbd-ios (NOTE: giellakbd-ios is dual-licensed Apache-2.0/MIT; user requested BSD-3 but actual license is MIT -- see Open Questions)

### Claude's Discretion
- Exact FluidAudio/Parakeet display name (based on SDK branding research)
- Copyright years and holder names for each dependency (read from actual LICENSE files)
- Whether to add a section header or keep the flat list of license blocks
- Cursor change detection approach in KeyboardViewController (textDidChange vs selectionDidChange vs documentContextBeforeInput comparison)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FIX-01 | Autocorrect undo only triggers on immediate backspace, not after new character input (#67) | Exact code locations identified: `handleInputKey()` line 180+, `textDidChange()` line 336. One-line fix + cursor detection. |
| FIX-02 | Settings licenses link points to correct getdictus/dictus-ios repo (#63) | Current wrong URL found at LicensesView.swift line 28. Simple string replacement. |
| FIX-03 | Parakeet/NVIDIA model attribution added to licenses screen (#63) | License types and copyright holders verified from upstream repos. Three new entries + two new license helpers needed. |
</phase_requirements>

## Standard Stack

No new dependencies. This phase modifies existing Swift/SwiftUI code only.

### Files Modified
| File | Target | Change |
|------|--------|--------|
| `DictusKeyboard/DictusKeyboardBridge.swift` | DictusKeyboard | Add `lastAutocorrect = nil` in `handleInputKey()` |
| `DictusKeyboard/KeyboardViewController.swift` | DictusKeyboard | Clear `lastAutocorrect` in `textDidChange()` |
| `DictusApp/Views/LicensesView.swift` | DictusApp | Fix URL, add 3 entries, add 2 license helpers |

## Architecture Patterns

### FIX-01: Autocorrect Undo Invalidation

The current `handleBackspace()` (line 213-245) checks `suggestionState?.lastAutocorrect` and, if non-nil, undoes the autocorrect instead of deleting a character. The bug: `lastAutocorrect` is only cleared on successful undo or suggestion tap -- it persists across new character input.

**Fix pattern:**
```swift
// In handleInputKey(), BEFORE inserting the character:
suggestionState?.lastAutocorrect = nil

// In KeyboardViewController.textDidChange(), after super call:
bridge?.suggestionState?.lastAutocorrect = nil
```

**Why `textDidChange()`:** This UIInputViewController callback fires when text changes externally (paste, cursor tap, host app autocorrect). If the user taps to move the cursor after an autocorrect, the undo context becomes invalid. The existing `textDidChange()` already calls `bridge?.updateCapitalization()` -- adding the lastAutocorrect clear follows the same pattern.

**Why NOT `selectionDidChange`:** UIInputViewController does not expose `selectionDidChange` as an override. The `textDidChange(_:)` is the correct callback for keyboard extensions detecting external text changes.

### FIX-02 + FIX-03: License View Updates

The existing `LicensesView` uses a reusable `licenseBlock(name:author:url:license:)` component and a `mitLicense(copyright:)` helper. Pattern to follow:

1. Add `apache2License(copyright:)` private method (full Apache 2.0 text)
2. Add `mitLicense(copyright:)` is already present -- reuse for DeviceKit
3. For giellakbd-ios: use `mitLicense(copyright:)` since the project offers MIT as one of its dual-license options (Apache-2.0 OR MIT)
4. Add entries in alphabetical order: DeviceKit, Dictus, FluidAudio, giellakbd-ios, WhisperKit

### Anti-Patterns to Avoid
- **Don't add `bsd3License()` helper:** giellakbd-ios is dual-licensed Apache-2.0/MIT (not BSD-3). The CONTEXT.md mentions BSD-3, but upstream repo confirms Apache-2.0 OR MIT. Use MIT for simplicity since the helper already exists.
- **Don't clear `lastAutocorrect` in `handleSpace()`:** Space is where autocorrect is SET -- clearing it there would prevent undo entirely.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| License text | Custom license text from memory | Copy exact text from upstream LICENSE files | Legal accuracy matters |
| Cursor detection | Custom timer-based cursor polling | `textDidChange()` override | Apple's official callback for external text changes |

## Common Pitfalls

### Pitfall 1: Clearing lastAutocorrect Too Late
**What goes wrong:** If `lastAutocorrect = nil` is placed AFTER `insertText(character)`, there is a brief window where a fast backspace could still trigger undo.
**How to avoid:** Clear `lastAutocorrect` as the FIRST action in `handleInputKey()`, before any text insertion.

### Pitfall 2: Bridge Access from KeyboardViewController
**What goes wrong:** `bridge?.suggestionState` might be nil if bridge is not yet initialized.
**How to avoid:** Use optional chaining (`bridge?.suggestionState?.lastAutocorrect = nil`) which safely no-ops if bridge is nil. This matches existing patterns in the codebase.

### Pitfall 3: Apache 2.0 License Text Length
**What goes wrong:** Apache 2.0 is significantly longer than MIT (~175 lines vs ~20 lines). The monospaced text block could create a very tall scroll area.
**How to avoid:** This is acceptable -- the existing layout uses ScrollView and the license text is inside a rounded background card. No special handling needed.

### Pitfall 4: giellakbd-ios License Confusion
**What goes wrong:** CONTEXT.md says BSD-3, but the actual repo is dual-licensed Apache-2.0/MIT.
**How to avoid:** Use MIT license for giellakbd-ios attribution (copyright: "Copyright (c) 2019 UiT The Arctic University of Norway, Samediggi"). Flag this discrepancy to the user in the plan.

## Code Examples

### FIX-01: handleInputKey() Fix
```swift
// DictusKeyboard/DictusKeyboardBridge.swift, in handleInputKey()
// Add as FIRST line of the method body:
private func handleInputKey(_ character: String) {
    // Invalidate autocorrect undo — any new character input means the user
    // accepted the correction. Only immediate backspace should undo.
    suggestionState?.lastAutocorrect = nil

    AudioServicesPlaySystemSound(KeySound.letter)
    // ... rest of existing code unchanged
}
```

### FIX-01: textDidChange() Enhancement
```swift
// DictusKeyboard/KeyboardViewController.swift, in textDidChange()
override func textDidChange(_ textInput: UITextInput?) {
    super.textDidChange(textInput)
    // Invalidate autocorrect undo on external text changes (paste, cursor move).
    bridge?.suggestionState?.lastAutocorrect = nil
    bridge?.updateCapitalization()
}
```

### FIX-02: URL Correction
```swift
// Change in LicensesView.swift:
// FROM: url: "https://github.com/Pivii/dictus"
// TO:   url: "https://github.com/getdictus/dictus-ios"
```

### FIX-03: Dependency Entries (Verified)

**DeviceKit:**
- Name: DeviceKit
- Author: Dennis Weissmann
- URL: https://github.com/devicekit/DeviceKit
- License: MIT, Copyright (c) 2015 Dennis Weissmann

**FluidAudio:**
- Name: FluidAudio (display name -- the SDK branding, not "Parakeet" which is just one model it uses)
- Author: NVIDIA Corporation
- URL: https://github.com/FluidInference/FluidAudio
- License: Apache 2.0 (template -- no specific copyright line in their LICENSE file; use "Copyright NVIDIA Corporation")

**giellakbd-ios:**
- Name: giellakbd-ios
- Author: UiT The Arctic University of Norway, Samediggi
- URL: https://github.com/divvun/giellakbd-ios
- License: MIT (dual-licensed Apache-2.0/MIT; choosing MIT for consistency), Copyright (c) 2019 UiT The Arctic University of Norway, Samediggi

### Apache 2.0 License Helper
```swift
private func apache2License(copyright: String) -> String {
    """
    Apache License, Version 2.0

    \(copyright)

    Licensed under the Apache License, Version 2.0 (the "License"); \
    you may not use this file except in compliance with the License. \
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software \
    distributed under the License is distributed on an "AS IS" BASIS, \
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. \
    See the License for the specific language governing permissions and \
    limitations under the License.
    """
}
```

**Note:** The short-form Apache 2.0 notice (NOTICE file style) is legally sufficient for attribution. The full 175-line Apache 2.0 text is NOT required in-app -- only the notice above. This is confirmed by Apache 2.0 Section 4(d) which requires reproducing the NOTICE file, not the full license. However, user decision says "full Apache 2.0 license text block, same layout as existing WhisperKit entry" -- if user wants the complete text, include it. Recommend asking during implementation.

## Open Questions

1. **giellakbd-ios License Type Discrepancy**
   - What we know: CONTEXT.md says BSD-3, but the actual repo is dual-licensed Apache-2.0/MIT (verified from GitHub).
   - What's unclear: Whether user specifically wants BSD-3 text or was mistaken about the license type.
   - Recommendation: Use MIT (one of the two actual license options). Flag to user during implementation. If user insists on BSD-3, that would be legally incorrect.

2. **FluidAudio Copyright Line**
   - What we know: The LICENSE file in the FluidAudio repo is a template Apache 2.0 with placeholder `[yyyy] [name of copyright owner]`. No specific copyright line.
   - What's unclear: The exact copyright holder text NVIDIA wants displayed.
   - Recommendation: Use "Copyright NVIDIA Corporation" based on user decision and the fact that NVIDIA is the parent organization of FluidInference.

3. **Apache 2.0 Full Text vs Short Notice**
   - What we know: User requested "full Apache 2.0 license text block." Full Apache 2.0 is ~175 lines.
   - Recommendation: Use the short-form notice (Section 4d compliant, ~15 lines) which is the standard practice for in-app attribution. The full text adds significant scroll but no legal value. Let the planner decide.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode built-in) |
| Config file | DictusCore/Package.swift (SPM test target) |
| Quick run command | `cd DictusCore && swift test` |
| Full suite command | `xcodebuild test -project Dictus.xcodeproj -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FIX-01 | Backspace after new char deletes char, not undo autocorrect | manual-only | Manual: type word, get autocorrect, type char, press backspace | N/A -- requires keyboard extension runtime |
| FIX-02 | License link points to getdictus/dictus-ios | manual-only | Manual: Settings > A propos > Licences, tap Dictus link | N/A -- UI verification |
| FIX-03 | All 5 dependencies listed with correct licenses | manual-only | Manual: Settings > A propos > Licences, scroll through all entries | N/A -- UI verification |

**Justification for manual-only:** All three requirements involve keyboard extension runtime behavior or SwiftUI view rendering that cannot be unit-tested without the full app context. FIX-01 requires UITextDocumentProxy interaction; FIX-02/03 require visual verification of rendered license text.

### Sampling Rate
- **Per task commit:** `cd DictusCore && swift test` (verify no regressions in core)
- **Per wave merge:** `xcodebuild build -project Dictus.xcodeproj -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` (verify compilation)
- **Phase gate:** Build succeeds + manual verification of all 3 success criteria on simulator

### Wave 0 Gaps
None -- no new automated tests needed. All requirements are manual-only verification.

## Sources

### Primary (HIGH confidence)
- LicensesView.swift -- read directly, current structure and patterns verified
- DictusKeyboardBridge.swift lines 175-340 -- read directly, handleInputKey/handleBackspace/handleSpace logic verified
- SuggestionState.swift -- read directly, lastAutocorrect property and clear() method verified
- KeyboardViewController.swift lines 330-342 -- read directly, textDidChange() existing implementation verified

### Secondary (MEDIUM confidence)
- DeviceKit LICENSE (GitHub raw): MIT, Copyright (c) 2015 Dennis Weissmann -- verified via WebFetch
- giellakbd-ios LICENSE-MIT (GitHub raw): MIT, Copyright (c) 2019 UiT The Arctic University of Norway, Samediggi -- verified via WebFetch
- FluidAudio LICENSE (GitHub raw): Apache 2.0, template (no specific copyright) -- verified via WebFetch
- FluidAudio README (GitHub): SDK name is "FluidAudio", not "Parakeet" -- verified via WebFetch

### Tertiary (LOW confidence)
- FluidAudio copyright holder (assumed NVIDIA Corporation based on user decision and FluidInference org)

## Metadata

**Confidence breakdown:**
- Autocorrect fix (FIX-01): HIGH -- code read directly, fix is mechanical and well-understood
- License URL fix (FIX-02): HIGH -- current wrong URL confirmed, correct URL known
- License additions (FIX-03): HIGH for DeviceKit/giellakbd-ios (verified from repos), MEDIUM for FluidAudio (copyright holder unconfirmed in LICENSE file)
- Overall: HIGH -- all changes are small, isolated, and well-specified

**Research date:** 2026-04-01
**Valid until:** 2026-05-01 (stable domain, no version-sensitive findings)
