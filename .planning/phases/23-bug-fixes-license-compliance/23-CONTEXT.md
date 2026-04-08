# Phase 23: Bug Fixes & License Compliance - Context

**Gathered:** 2026-04-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the autocorrect undo race condition (FIX-01), update the Dictus license link to the correct repo (FIX-02), and add Parakeet/NVIDIA attribution plus all missing dependency licenses (FIX-03). No new features -- cleanup before prediction engine changes.

</domain>

<decisions>
## Implementation Decisions

### Autocorrect undo invalidation (FIX-01)
- Clear `lastAutocorrect` on ANY new character input in `handleCharacter()` -- only the very next backspace after autocorrect triggers undo (matches iOS native behavior)
- Also clear `lastAutocorrect` on cursor movement (detected via `textDidChange` / `selectionDidChange` in KeyboardViewController) -- undo is nonsensical if user tapped elsewhere
- The fix is in `DictusKeyboardBridge.handleCharacter()` (add `suggestionState?.lastAutocorrect = nil`) and in `KeyboardViewController` for cursor change detection

### Parakeet attribution format (FIX-03)
- Full Apache 2.0 license text block, same layout as existing WhisperKit entry (name, author, URL, full license text)
- Name: Claude's Discretion -- pick the most appropriate name based on FluidAudio SDK's own branding (FluidAudio vs Parakeet vs NVIDIA)
- Author: NVIDIA Corporation (or as specified in their repo)
- URL: https://github.com/FluidInference/FluidAudio.git
- Need an `apache2License()` helper alongside existing `mitLicense()` in LicensesView

### License screen structure (FIX-02 + FIX-03)
- List ALL open-source dependencies, not just legally required ones -- user wants full legal compliance
- Dependencies to list: DeviceKit (MIT), Dictus (MIT), FluidAudio/Parakeet (Apache 2.0), giellakbd-ios (BSD-3), WhisperKit (MIT)
- Order: alphabetical by name
- Fix Dictus repo URL from `github.com/Pivii/dictus` to `github.com/getdictus/dictus-ios`
- giellakbd-ios is vendored (not SPM) -- still needs attribution with correct BSD-3 license text
- Need a `bsd3License()` helper for giellakbd-ios

### Claude's Discretion
- Exact FluidAudio/Parakeet display name (based on SDK branding research)
- Copyright years and holder names for each dependency (read from actual LICENSE files)
- Whether to add a section header or keep the flat list of license blocks
- Cursor change detection approach in KeyboardViewController (textDidChange vs selectionDidChange vs documentContextBeforeInput comparison)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Bug fix
- GitHub issue #67 — Autocorrect undo race condition (FIX-01 specification)
- `DictusKeyboard/DictusKeyboardBridge.swift` lines 207-245 — Current handleBackspace() with autocorrect undo logic
- `DictusKeyboard/DictusKeyboardBridge.swift` lines 175-205 — handleCharacter() where lastAutocorrect must be cleared
- `DictusKeyboard/DictusKeyboardBridge.swift` lines 292-331 — handleSpace() where lastAutocorrect is set
- `DictusKeyboard/TextPrediction/SuggestionState.swift` — AutocorrectState struct and lastAutocorrect property

### License compliance
- GitHub issue #63 — License link + Parakeet attribution (FIX-02, FIX-03 specification)
- `DictusApp/Views/LicensesView.swift` — Current licenses screen (only WhisperKit + Dictus, wrong repo URL)
- `DictusKeyboard/Vendored/` — giellakbd-ios vendored files (need BSD-3 attribution)
- FluidAudio repo: https://github.com/FluidInference/FluidAudio.git — Check LICENSE file for exact Apache 2.0 text and copyright
- DeviceKit repo: https://github.com/devicekit/DeviceKit.git — Check LICENSE file for MIT text and copyright

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LicensesView.licenseBlock(name:author:url:license:)` — Generic license block component, reusable for all new entries
- `LicensesView.mitLicense(copyright:)` — MIT template, reusable for DeviceKit entry

### Established Patterns
- License blocks are VStack with name (subheading font), author (caption), link, monospaced license text in a rounded background
- All license text is inline (no external file loading)
- Navigation title is "Licences" (French)

### Integration Points
- `DictusKeyboardBridge.handleCharacter()` — Add `lastAutocorrect = nil` early in the method
- `KeyboardViewController.textDidChange()` (or equivalent) — Clear lastAutocorrect on external text changes
- `LicensesView.body` — Add 3 new `licenseBlock()` calls in alphabetical order
- `KeyboardRootView.swift:251` — Already clears lastAutocorrect in one place (suggestion tap)

</code_context>

<specifics>
## Specific Ideas

- User explicitly wants to be "legit au niveau de la loi" -- complete legal compliance, not minimum viable
- All dependencies should be listed even if their license doesn't technically require in-app display (MIT)

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 23-bug-fixes-license-compliance*
*Context gathered: 2026-04-01*
