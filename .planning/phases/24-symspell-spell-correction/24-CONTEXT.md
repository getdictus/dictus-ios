# Phase 24: SymSpell Spell Correction - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace UITextChecker spell correction with SymSpell for frequency-ranked corrections. Expand French and English dictionaries from ~1.3K to 30-50K words. Users get corrections that match their intent (frequency-based) instead of alphabetical guesses. Completions (partial word suggestions) stay on UITextChecker. N-gram next-word prediction is Phase 25.

Requirements: PRED-01, PRED-02, PRED-03

</domain>

<decisions>
## Implementation Decisions

### Dictionary sourcing
- **French**: Lexique 3.83 — academic French lexicon with frequency ranks from film subtitles + books. Filter to top 30-50K entries. Includes accented forms natively.
- **English**: Google 1T / COCA — well-established English frequency corpus. Pre-filtered top 30-50K words.
- **Proper nouns**: Include only common proper nouns (~500: major cities, countries, common first names). Avoids flagging "Paris" as misspelled.
- **Slang/SMS**: Include a curated list of ~50 top French texting abbreviations (mdr, stp, bcp, jsp, etc.) so they don't get autocorrected away. No extensive slang.
- **Accented forms**: Dictionary contains ONLY the correct accented forms (e.g., "cafe" is NOT in dictionary, only "cafe" with accent). Unaccented input gets corrected to accented form via SymSpell edit distance.
- **Accent homographs**: Both forms in dictionary when both are valid words (ou/ou with accent, a/a with accent). Frequency rank decides which appears first. Context-based disambiguation deferred to Phase 25 (n-grams).

### SymSpell integration
- **Scope**: SymSpell replaces UITextChecker for `spellCheck()` ONLY. UITextChecker kept for `completions()` (partial word suggestions).
- **Vendoring**: Vendor SymSpellSwift source (~500 lines) directly — no SPM dependency (French Unicode edge cases).
- **Edit distance**: Max edit distance 2 (SymSpell default). Catches 95%+ of typos including accent corrections (e to e-acute = edit distance 1).
- **Ranking**: Among SymSpell candidates within edit distance, rank by frequency (highest frequency first). "helo" -> "hello" (freq 50) beats "halo" (freq 5000).
- **Suggestion bar layout — standard mobile pattern**:
  - Slot 1 (left): verbatim word as typed
  - Slot 2 (center, bold): best correction — auto-applied on space
  - Slot 3 (right): alternative suggestion
  - When word is correctly spelled: all 3 slots show completions (current behavior)
  - This matches iOS native keyboard and Gboard standard layout.

### Autocorrect rejection (undo protection)
- **Standard behavior**: After user undoes an autocorrection (backspace after space), the original word is "accepted" for that instance. Typing space again does NOT re-apply the correction.
- **Flow**: type "helo" + space -> corrected to "hello " -> backspace undoes to "helo" -> space again -> "helo " stays as-is.
- **Current bug**: Dictus re-applies correction on every space, trapping the user. Must be fixed in this phase.
- **Reference**: Follow open-source keyboard standards (Gboard/AOSP behavior).

### Dictionary format & loading
- **Format**: Ship frequency JSON files (same format as current `fr_frequency.json` / `en_frequency.json`). SymSpell builds its internal precalculated dictionary from JSON on first load.
- **FrequencyDictionary**: Keep existing struct for UITextChecker completion ranking. SymSpell loads the same JSON source but maintains its own internal data structure. Two consumers, one source file per language.
- **Load timing**: Eager load in `TextPredictionEngine.init()` — same as current behavior. ~50-200ms one-time cost acceptable.
- **Language switch**: Same pattern as current — drop SymSpell dictionary, rebuild from new language JSON on `setLanguage()`. One language in memory at a time.
- **Memory budget**: Target 3-5MB per language for SymSpell dictionary. Must verify on physical device (memory gate requirement from STATE.md).

### Accent correction
- **Approach**: SymSpell handles accent correction naturally via edit distance. "cafe" (not in dict) -> "cafe" with accent (in dict, edit distance 1). No dedicated accent normalization pass needed.
- **Remove `accentSuggestions()`**: The single-vowel accent suggestion mode (type "e" -> bar shows "e-acute", "e-grave") is removed. Users have adaptive accent key (Phase 19) and long-press accents for quick accent access. Simplifies the suggestion bar.
- **`SuggestionMode.accents` enum case**: Remove along with accentSuggestions().

### Claude's Discretion
- SymSpellSwift source adaptation for Swift 5.9+ (Unicode handling, any needed patches)
- Dictionary curation pipeline (Python/Swift script for filtering Lexique 3.83 to top N words)
- Exact SymSpell configuration parameters (prefix length, compact level)
- How to implement autocorrect rejection state tracking in SuggestionState/bridge
- Memory profiling test methodology

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Current prediction code (to modify)
- `DictusKeyboard/TextPrediction/TextPredictionEngine.swift` — Current spellCheck() using UITextChecker + FrequencyDictionary. SymSpell replaces spellCheck(), completions() stays.
- `DictusKeyboard/TextPrediction/SuggestionState.swift` — Observable state, async coalescing, AutocorrectState for undo. Needs autocorrect rejection logic.
- `DictusKeyboard/Views/SuggestionBarView.swift` — 3-slot suggestion bar UI. Layout changes for standard pattern (verbatim/correction/alternative).
- `DictusCore/Sources/DictusCore/FrequencyDictionary.swift` — Current JSON loader, stays for UITextChecker ranking.

### Current dictionaries (to expand)
- `DictusKeyboard/Resources/fr_frequency.json` — Current French dictionary (1,288 words). Replace with 30-50K from Lexique 3.83.
- `DictusKeyboard/Resources/en_frequency.json` — Current English dictionary (1,126 words). Replace with 30-50K from Google 1T/COCA.

### Keyboard bridge (autocorrect wiring)
- `DictusKeyboard/DictusKeyboardBridge.swift` — handleSpace triggers autocorrect, handleBackspace triggers undo. Autocorrect rejection logic needed here.
- `DictusKeyboard/KeyboardViewController.swift` — View lifecycle, SuggestionState ownership.

### Prior phase decisions
- `.planning/phases/20-feature-reintegration/20-CONTEXT.md` — Prediction wiring pattern, autocorrect-on-space behavior, undo-on-backspace.

### Requirements
- `.planning/REQUIREMENTS.md` — PRED-01 (FR dict 30-50K), PRED-02 (EN dict 30-50K), PRED-03 (SymSpell replaces UITextChecker)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `FrequencyDictionary`: JSON loader for `[String: Int]` ranks — stays as-is for UITextChecker completions
- `TextPredictionEngine`: Clean separation of `suggestions()` (completions) and `spellCheck()` (corrections) — only spellCheck() changes
- `SuggestionState`: Async coalescing with DispatchWorkItem, already has `AutocorrectState` struct for undo tracking
- `AccentedCharacters.mappings`: Used by `accentSuggestions()` — will be removed along with accent suggestions mode

### Established Patterns
- JSON frequency files loaded per-language in `TextPredictionEngine.init()` and `setLanguage()`
- Background queue (`suggestionQueue`) for suggestion computation with cancellation
- `DictusKeyboardBridge` calls `SuggestionState.updateAsync(context:)` after each keystroke
- Autocorrect-on-space: bridge's `handleSpace()` calls `performSpellCheck()`, inserts correction, stores `AutocorrectState`
- Undo-on-backspace: bridge's `handleBackspace()` checks `lastAutocorrect` and restores original word

### Integration Points
- New `SymSpellEngine` class replaces UITextChecker calls inside `TextPredictionEngine.spellCheck()`
- `SuggestionBarView` layout needs reordering: verbatim | correction (bold) | alternative
- Autocorrect rejection flag needed in `SuggestionState` or `DictusKeyboardBridge` (after undo, skip next correction for that word)
- Larger JSON frequency files replace current small ones in `DictusKeyboard/Resources/`

</code_context>

<specifics>
## Specific Ideas

- "L'idee c'est vraiment de faire un truc pas exotique, je veux vraiment faire du standard" — Follow iOS/Android standard patterns for suggestion bar layout and autocorrect behavior. No exotic UX.
- Follow open-source keyboard standards (Gboard/AOSP) as reference for autocorrect flow, undo, and rejection behavior.
- accentSuggestions() removal: users already have adaptive accent key + long-press accents — the single-vowel accent bar mode is redundant.

</specifics>

<deferred>
## Deferred Ideas

- Context-based accent disambiguation (ou vs ou-with-accent) — needs n-gram context (Phase 25)
- Learned words / user dictionary (add words SymSpell doesn't know) — future feature

</deferred>

---

*Phase: 24-symspell-spell-correction*
*Context gathered: 2026-04-02*
