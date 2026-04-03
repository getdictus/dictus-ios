---
phase: 24-symspell-spell-correction
verified: 2026-04-02T00:00:00Z
status: human_needed
score: 10/10 must-haves verified
re_verification: false
human_verification:
  - test: "French misspelled word correction"
    expected: "Typing 'helo' shows suggestion bar with 'helo' (left) | 'hello' bold (center) | alternative (right). Pressing space autocorrects to 'hello '"
    why_human: "Requires live keyboard extension interaction on device or simulator"
  - test: "Accent correction for unaccented French word"
    expected: "Typing 'cafe' shows 'café' as bold center correction. Pressing space autocorrects to 'café '"
    why_human: "Requires keyboard interaction and SymSpell dictionary lookup at runtime"
  - test: "Autocorrect rejection (undo protection)"
    expected: "Type 'helo' + space (corrected to 'hello') → backspace (restored to 'helo') → space again → stays as 'helo ', not re-corrected"
    why_human: "Stateful interaction requiring keyboard session"
  - test: "Single-vowel no longer shows accent suggestions"
    expected: "Typing 'e' alone shows word completions starting with 'e', NOT accent variants like é/è/ê"
    why_human: "Requires observing suggestion bar behavior during typing"
  - test: "English spell corrections after language switch"
    expected: "Switching to English and typing 'teh' corrects to 'the', 'recieve' corrects to 'receive'"
    why_human: "Requires language switch and keyboard interaction"
  - test: "Memory usage on physical device"
    expected: "Keyboard extension stays under 50MB during normal use. Note: Summary reports 58 MiB transient peak during recording — needs re-confirmation with final 10K dictionary"
    why_human: "Requires Instruments profiling on a physical device. Summary measured 29 MiB (FR only), 41 MiB (after EN switch), 58 MiB transient peak during dictation recording — the 58 MiB peak exceeds the 50 MB limit and needs verification with the final 10K word dictionary"
  - test: "User dictionary learning via repetition"
    expected: "Typing an unknown word twice across two separate words causes it to be learned (no more spell correction for that word)"
    why_human: "Requires multi-word session with persistence to UserDefaults"
---

# Phase 24: SymSpell Spell Correction Verification Report

**Phase Goal:** Replace dictionary-based spell correction with SymSpell algorithm for frequency-ranked corrections, standard mobile suggestion bar layout, autocorrect rejection, and user dictionary learning.
**Verified:** 2026-04-02
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | fr_frequency.json contains 30,000-50,000 French words with frequency counts | ✓ VERIFIED | 40,292 entries, {word: int} format, min=15, max=2,933,327 |
| 2  | en_frequency.json contains 30,000-50,000 English words with frequency counts | ✓ VERIFIED | 40,000 entries, {word: int} format, "the" = 23,135,851,162 |
| 3  | SymSpellSwift source files are vendored and compile in DictusKeyboard target | ✓ VERIFIED | 3 files in DictusKeyboard/Vendored/SymSpell/, all with MIT license headers, added to project.pbxproj PBXBuildFile + PBXSourcesBuildPhase |
| 4  | SymSpellEngine loads JSON dictionary and returns frequency-ranked corrections | ✓ VERIFIED | SymSpellEngine.swift: load() with async background queue, spellCheck() returns (correction:, alternatives:) tuple |
| 5  | spellCheck() delegates to SymSpellEngine instead of UITextChecker | ✓ VERIFIED | TextPredictionEngine.spellCheck() calls symSpellEngine.spellCheck(). UITextChecker retained only for suggestions(for:) completions |
| 6  | Suggestion bar layout is standard mobile: verbatim (left) | correction bold (center) | alternative (right) | ✓ VERIFIED | SuggestionBarView.swift line 47: `.fontWeight(index == 1 ? .semibold : .regular)`. Correction mode puts original at index 0, correction at index 1 |
| 7  | Autocorrect rejection tracking prevents re-correction after undo | ✓ VERIFIED | SuggestionState.rejectedWords: Set<String>. Bridge inserts on undo (line 236), checks on space (line 332), clears on new word (lines 187, 377) |
| 8  | Accent suggestions removed — no .accents case in SuggestionMode | ✓ VERIFIED | SuggestionState.swift SuggestionMode has only .idle, .completions, .corrections. No accentSuggestions() method in TextPredictionEngine |
| 9  | FrequencyDictionary updated for count format (higher = more common) | ✓ VERIFIED | FrequencyDictionary.swift: property named `counts`, rank(of:) returns `?? 0`. TextPredictionEngine.suggestions() sorts descending (>) |
| 10 | User dictionary learning persists learned words via App Group | ✓ VERIFIED | UserDictionary.swift in DictusCore: rejection+repetition learning, threshold=2, cap=1000, stored in AppGroup.defaults |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `DictusKeyboard/Resources/fr_frequency.json` | French frequency dictionary 30-50K words | ✓ VERIFIED | 40,292 words, has "mdr", "paris", "café"-form |
| `DictusKeyboard/Resources/en_frequency.json` | English frequency dictionary 30-50K words | ✓ VERIFIED | 40,000 words, "the" has highest count as expected |
| `DictusKeyboard/Vendored/SymSpell/SymSpell.swift` | SymSpell algorithm implementation | ✓ VERIFIED | `public class SymSpell`, MIT license header |
| `DictusKeyboard/Vendored/SymSpell/SuggestItem.swift` | SymSpell suggestion result type | ✓ VERIFIED | MIT license header, in DictusKeyboard target |
| `DictusKeyboard/Vendored/SymSpell/StringExtension.swift` | Damerau-Levenshtein string distance | ✓ VERIFIED | MIT license header, in DictusKeyboard target |
| `DictusKeyboard/TextPrediction/SymSpellEngine.swift` | Wrapper class with load() and spellCheck() | ✓ VERIFIED | `final class SymSpellEngine`, async load, tuple spellCheck return, French overrides, user word injection |
| `DictusKeyboard/TextPrediction/TextPredictionEngine.swift` | spellCheck() delegates to SymSpellEngine | ✓ VERIFIED | `private let symSpellEngine = SymSpellEngine()`, loaded in init() and setLanguage() |
| `DictusKeyboard/TextPrediction/SuggestionState.swift` | Autocorrect rejection tracking, no .accents mode | ✓ VERIFIED | rejectedWords: Set<String>, SuggestionMode has .corrections not .accents |
| `DictusKeyboard/Views/SuggestionBarView.swift` | Standard bar layout with bold center slot (index 1) | ✓ VERIFIED | `index == 1 ? .semibold : .regular`, displayText wraps index-0 in quotes in correction mode |
| `DictusKeyboard/DictusKeyboardBridge.swift` | Autocorrect rejection logic in handleBackspace/handleSpace | ✓ VERIFIED | rejectedWords.insert on undo, rejectedWords.contains check before space correction, result.correction tuple usage |
| `DictusCore/Sources/DictusCore/FrequencyDictionary.swift` | Updated to work with count format | ✓ VERIFIED | `private var counts`, rank(of:) returns `?? 0` |
| `DictusCore/Sources/DictusCore/UserDictionary.swift` | User dictionary learning with App Group persistence | ✓ VERIFIED | Created in Plan 02, rejection + repetition learning, threshold=2, cap=1000 |
| `scripts/curate_fr_dictionary.py` | Reproducible French dictionary curation script | ✓ VERIFIED | Exists in scripts/ |
| `scripts/curate_en_dictionary.py` | Reproducible English dictionary curation script | ✓ VERIFIED | Exists in scripts/ |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| SymSpellEngine.swift | SymSpell.swift | `SymSpell(maxDictionaryEditDistance: 1, prefixLength: 7)` | ✓ WIRED | Line 102: `let ss = SymSpell(maxDictionaryEditDistance: 1, prefixLength: 7)` |
| SymSpellEngine.swift | fr_frequency.json | `bundle.url(forResource: "\(language)_frequency", withExtension: "json")` | ✓ WIRED | Lines 84-86: URL lookup + JSONDecoder decode |
| TextPredictionEngine.swift | SymSpellEngine.swift | `symSpellEngine.spellCheck()` | ✓ WIRED | Line 89: `return symSpellEngine.spellCheck(word)` |
| DictusKeyboardBridge.swift | SuggestionState.swift | `rejectedWords` tracking on undo + check on space | ✓ WIRED | Line 236 (insert on undo), line 332 (check on space), line 377 (clear after space) |
| SuggestionBarView.swift | SuggestionState.swift | `fontWeight` bolds index 1 | ✓ WIRED | Line 47: `index == 1 ? .semibold : .regular` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PRED-01 | 24-01-PLAN.md | French frequency dictionary expanded to 30-50K words | ✓ SATISFIED | fr_frequency.json: 40,292 words in count format |
| PRED-02 | 24-01-PLAN.md | English frequency dictionary expanded to 30-50K words | ✓ SATISFIED | en_frequency.json: 40,000 words in count format |
| PRED-03 | 24-02-PLAN.md | SymSpell replaces UITextChecker for spell correction with sub-millisecond lookups | ? NEEDS HUMAN | Implementation is complete and wired. Runtime latency and memory within budget requires device validation. Note: REQUIREMENTS.md still shows PRED-03 as `[ ]` (unchecked) — this must be updated after human verification passes |

**Note on PRED-03 in REQUIREMENTS.md:** The traceability table marks PRED-03 as "Pending" and the checkbox remains unchecked. The implementation is code-complete but the requirement explicitly includes "sub-millisecond lookups" — runtime latency and the 58 MiB transient peak (Summary line 54) need human device verification before the requirement can be marked complete.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| SymSpellEngine.swift | 102 | `maxEditDistance: 1` instead of standard 2 | ℹ️ Info | Intentional trade-off: 4x memory reduction, catches ~80% of typos. Phase 25 planned for AOSP trie to restore edit distance 2. Documented in SUMMARY |

No TODO/FIXME/placeholder comments or empty implementations found in any modified files.

### Human Verification Required

#### 1. French Spell Correction Quality

**Test:** In any app with a text field, enable Dictus keyboard (French). Type "helo" (no space). Observe suggestion bar. Then press space.
**Expected:** Suggestion bar shows three slots: `"helo"` (quoted, left) | `hello` (bold, center) | nothing or alternative (right). Space autocorrects to "hello ".
**Why human:** Requires live keyboard extension rendering and SymSpell runtime lookup.

#### 2. Accent Correction

**Test:** Type "cafe" (no accent on e). Observe suggestion bar. Press space.
**Expected:** Bar shows `"cafe"` | `café` (bold) | alternative. Space inserts "café ".
**Why human:** Requires runtime SymSpell lookup against loaded French dictionary.

#### 3. Autocorrect Rejection (undo + re-space)

**Test:** Type "helo" + space (autocorrected to "hello ") → press backspace (should restore "helo") → press space again.
**Expected:** "helo " is inserted, NOT "hello " again.
**Why human:** Stateful interaction across three distinct key events with persistent rejected-word tracking.

#### 4. Accent Suggestions Removed

**Test:** Type a single "e" in a text field.
**Expected:** Suggestion bar shows word completions (e.g., "en", "est", "elle"), NOT accent variants (é, è, ê).
**Why human:** Requires observing suggestion bar behavior in real UI.

#### 5. English Language Switch

**Test:** Switch keyboard language to English (via Dictus settings). Type "teh". Observe bar. Press space.
**Expected:** Bar shows `"teh"` | `the` (bold). Space autocorrects to "the ". Also test "recieve" → "receive".
**Why human:** Requires language switch and en_frequency.json runtime lookup.

#### 6. Memory Ceiling Under 50 MB

**Test:** Attach Instruments (Allocations) to the DictusKeyboard extension process. Type normally for 2+ minutes, including a dictation recording session. Note peak memory.
**Expected:** Peak memory stays under 50 MB with the final 10K word dictionary. The Plan 02 Summary reports a 58 MiB transient peak "during recording" — this must be re-verified with the final 10K dictionary commit (99b7777). A sustained value of 29-41 MiB (FR/EN) is documented but the recording peak is a risk.
**Why human:** Requires physical device and Instruments profiling. Cannot be verified statically.

### Gaps Summary

No code gaps found — all 10 observable truths are verified in the codebase. The phase is code-complete.

The one open item is human verification of runtime behavior (spell correction quality, rejection UX, memory ceiling). The memory peak of 58 MiB observed mid-session during recording (before the final 10K trim commit 99b7777) is the highest-priority human test — if the recording session still pushes over 50 MB, an additional memory reduction iteration may be needed.

REQUIREMENTS.md traceability table must be updated to mark PRED-03 as complete once human verification passes. Both the checkbox (`[ ]` → `[x]`) and the status column (`Pending` → `Complete`) need updating.

---

_Verified: 2026-04-02_
_Verifier: Claude (gsd-verifier)_
