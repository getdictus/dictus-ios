# Phase 24: SymSpell Spell Correction - Research

**Researched:** 2026-04-02
**Domain:** Spell correction algorithm, frequency dictionaries, iOS keyboard extension
**Confidence:** HIGH

## Summary

Phase 24 replaces UITextChecker's `spellCheck()` with SymSpell (Symmetric Delete algorithm) for frequency-ranked spell corrections. The core work involves: (1) vendoring SymSpellSwift (~3 source files, MIT license) into DictusKeyboard, (2) expanding French and English frequency dictionaries from ~1.3K to 30-50K words, (3) rewiring the suggestion bar to the standard mobile pattern (verbatim | correction | alternative), (4) implementing autocorrect rejection (undo + re-space does not re-apply), and (5) removing the now-redundant `accentSuggestions()` mode.

SymSpellSwift by gdetari is a clean Swift implementation with 3 source files (SymSpell.swift, SuggestItem.swift, String+Extension.swift). It supports `lookup()` with verbosity levels (Top/Closest/All), `loadDictionary()` from text files, and configurable edit distance + prefix length. The algorithm pre-calculates delete candidates at dictionary load time, enabling sub-millisecond lookups at query time. Memory for 30-50K words with edit distance 2 and prefix length 7 is estimated at 3-8MB -- within the keyboard extension budget.

**Primary recommendation:** Vendor SymSpellSwift source files directly, adapt `loadDictionary` to accept `[String: Int]` JSON (matching existing format), and wrap in a `SymSpellEngine` class that `TextPredictionEngine.spellCheck()` delegates to.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **French dictionary**: Lexique 3.83 -- academic French lexicon with film subtitle + book frequencies. Filter to top 30-50K entries. Includes accented forms natively.
- **English dictionary**: Google 1T / COCA -- pre-filtered top 30-50K words.
- **Proper nouns**: ~500 common proper nouns (cities, countries, first names).
- **Slang/SMS**: ~50 top French texting abbreviations (mdr, stp, bcp, jsp, etc.).
- **Accented forms**: Dictionary contains ONLY correct accented forms. Unaccented input corrected via edit distance.
- **Accent homographs**: Both forms when both valid (ou/ou, a/a). Frequency rank decides order.
- **SymSpell scope**: Replaces UITextChecker for spellCheck() ONLY. UITextChecker kept for completions().
- **Vendoring**: Vendor SymSpellSwift source (~500 lines) directly -- no SPM dependency.
- **Edit distance**: Max 2 (SymSpell default). Covers 95%+ of typos including accent corrections.
- **Ranking**: Among candidates within edit distance, rank by frequency (highest first).
- **Suggestion bar layout**: Slot 1 (left) = verbatim word, Slot 2 (center, bold) = best correction (auto-applied on space), Slot 3 (right) = alternative.
- **Autocorrect rejection**: After undo (backspace after space), original word accepted. Space again does NOT re-apply correction.
- **Dictionary format**: Ship frequency JSON files (same format as current). SymSpell builds internal structure from JSON on first load.
- **Load timing**: Eager load in TextPredictionEngine.init(). ~50-200ms acceptable.
- **Language switch**: Drop SymSpell dictionary, rebuild from new language JSON. One language in memory at a time.
- **Memory budget**: Target 3-5MB per language. Must verify on physical device.
- **Remove accentSuggestions()**: Remove single-vowel accent suggestion mode and SuggestionMode.accents enum case.

### Claude's Discretion
- SymSpellSwift source adaptation for Swift 5.9+ (Unicode handling, patches)
- Dictionary curation pipeline (Python/Swift script for filtering Lexique 3.83)
- Exact SymSpell configuration parameters (prefix length, compact level)
- How to implement autocorrect rejection state tracking in SuggestionState/bridge
- Memory profiling test methodology

### Deferred Ideas (OUT OF SCOPE)
- Context-based accent disambiguation (ou vs ou) -- needs n-grams (Phase 25)
- Learned words / user dictionary -- future feature
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PRED-01 | French frequency dictionary expanded to 30-50K words | Lexique 3.83 TSV with `ortho`, `freqfilms2`, `freqlivres` columns; filter by combined frequency, output as JSON `{word: rank}` |
| PRED-02 | English frequency dictionary expanded to 30-50K words | Norvig's count_1w.txt (333K words, MIT license) or Google 10000-english repo; filter top 30-50K, output as JSON |
| PRED-03 | SymSpell replaces UITextChecker for spell correction | SymSpellSwift (gdetari, MIT license) -- 3 source files to vendor; `lookup()` method with Verbosity.closest for frequency-ranked results |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SymSpellSwift | 0.1.4 | Spell correction via Symmetric Delete algorithm | Only maintained Swift SymSpell implementation; MIT license; 3 files (~500 lines total) |
| Lexique 3.83 | 3.83 | French word frequency source | Academic reference lexicon for French; 140K+ words with frequency data from subtitles + books |
| Norvig count_1w.txt | N/A | English word frequency source | 333K words from Google Trillion Word Corpus; MIT license; widely used |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| UITextChecker | iOS 17+ | Word completions (partial word) | Kept for `suggestions()` method only -- SymSpell replaces `spellCheck()` only |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Lexique 3.83 | Wiktionnaire dump | Lexique has frequency ranks; Wiktionnaire does not |
| Norvig count_1w | COCA 60K | COCA requires purchase for >5K words; Norvig is free MIT |
| SymSpellSwift | Custom implementation | Unnecessary -- SymSpellSwift is clean, tested, MIT licensed |

**No installation needed** -- all sources vendored directly into the project.

## Architecture Patterns

### Recommended Project Structure
```
DictusKeyboard/
├── TextPrediction/
│   ├── TextPredictionEngine.swift    # Modified: delegates spellCheck() to SymSpellEngine
│   ├── SuggestionState.swift         # Modified: autocorrect rejection flag, remove .accents mode
│   └── SymSpellEngine.swift          # NEW: wraps SymSpell, loads JSON, provides spellCheck()
├── Vendored/
│   └── SymSpell/                     # NEW: vendored SymSpellSwift source
│       ├── SymSpell.swift
│       ├── SuggestItem.swift
│       └── String+Extension.swift
├── Views/
│   └── SuggestionBarView.swift       # Modified: reorder slots (verbatim | bold correction | alt)
├── Resources/
│   ├── fr_frequency.json             # REPLACED: 30-50K words from Lexique 3.83
│   └── en_frequency.json             # REPLACED: 30-50K words from Norvig/Google 1T
└── DictusKeyboardBridge.swift        # Modified: autocorrect rejection tracking
```

### Pattern 1: SymSpellEngine Wrapper
**What:** A thin wrapper class that owns the SymSpell instance, handles JSON loading, and exposes a simple `spellCheck(_ word: String) -> (correction: String, alternatives: [String])?` API.
**When to use:** Always -- isolates SymSpell from the rest of the codebase.
**Example:**
```swift
// SymSpellEngine.swift
class SymSpellEngine {
    private var symSpell: SymSpell?

    func load(language: String, bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "\(language)_frequency", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return
        }
        let ss = SymSpell(maxDictionaryEditDistance: 2, prefixLength: 7)
        for (word, count) in dict {
            ss.createDictionaryEntry(key: word.lowercased(), count: count)
        }
        symSpell = ss
    }

    func spellCheck(_ word: String) -> (correction: String, alternatives: [String])? {
        guard let ss = symSpell else { return nil }
        let results = ss.lookup(word.lowercased(), verbosity: .closest)
        guard !results.isEmpty else { return nil }
        // If top result matches input (correctly spelled), return nil
        if results[0].term == word.lowercased() { return nil }
        let correction = results[0].term
        let alts = results.dropFirst().prefix(2).map { $0.term }
        return (correction, Array(alts))
    }
}
```

### Pattern 2: Autocorrect Rejection State
**What:** Track when a user has undone an autocorrection so the same word is not re-corrected on the next space.
**When to use:** In `DictusKeyboardBridge.handleSpace()` and `handleBackspace()`.
**Example:**
```swift
// In SuggestionState or DictusKeyboardBridge
/// Words the user has rejected correction for (undo'd). Cleared on new word.
private var rejectedWords: Set<String> = []

// In handleBackspace (undo path):
rejectedWords.insert(autocorrect.originalWord.lowercased())

// In handleSpace (correction path):
if rejectedWords.contains(state.currentWord.lowercased()) {
    // Skip correction -- user explicitly rejected it
} else if let correction = state.performSpellCheck(state.currentWord) { ... }

// Clear rejection set when a new word starts (after space or clear)
```

### Pattern 3: Suggestion Bar Reorder (Standard Mobile Layout)
**What:** Reorder suggestion slots to: verbatim (left) | correction bold (center) | alternative (right).
**When to use:** When spellCheck returns a correction for the current word.
**Example:**
```swift
// In SuggestionState, when building suggestions for a misspelled word:
// suggestions[0] = currentWord as-is (verbatim)
// suggestions[1] = best correction (this slot gets bold in UI)
// suggestions[2] = alternative correction or completion

// In SuggestionBarView, bold the CENTER slot (index 1), not index 0:
.fontWeight(index == 1 ? .semibold : .regular)
```

### Anti-Patterns to Avoid
- **Loading SymSpell dictionary on every keystroke:** Load once in init/setLanguage, reuse. The pre-calculation is the expensive part (~50-200ms); lookups are sub-millisecond.
- **Storing unaccented forms in dictionary:** "cafe" should NOT be in the dictionary. Only "cafe" (accented). SymSpell's edit distance naturally handles unaccented->accented correction.
- **Re-correcting rejected words:** After the user undoes an autocorrect, do NOT re-apply the same correction on the next space. Track rejected words per-word.
- **Using SymSpell for completions:** SymSpell finds corrections for complete misspelled words. Use UITextChecker for partial word completions (prefix matching).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spell correction algorithm | Custom edit distance calculator | SymSpellSwift | Pre-calculated deletes make lookups O(1); custom impl would be 1000x slower |
| French frequency data | Manual word counting | Lexique 3.83 | Academic corpus with 140K+ words already frequency-ranked |
| English frequency data | Web scraping | Norvig count_1w.txt | 333K words from Google Trillion Word Corpus, MIT license |
| Dictionary curation | Manual word picking | Python script filtering Lexique/Norvig | Reproducible, scriptable, auditable |

**Key insight:** The value of SymSpell is in its pre-calculation at load time. Building a custom spell checker would either be slow (computing edit distances at query time) or complex (reimplementing the symmetric delete optimization).

## Common Pitfalls

### Pitfall 1: SymSpell Loads Dictionary in Wrong Format
**What goes wrong:** SymSpellSwift's `loadDictionary(from: URL)` expects a TSV/space-separated text file, not JSON. Dictus uses JSON `{word: rank}`.
**Why it happens:** The library was designed for text file dictionaries.
**How to avoid:** Use `createDictionaryEntry(key:count:)` in a loop over the decoded JSON dictionary instead of `loadDictionary()`. This is the programmatic entry point.
**Warning signs:** Empty lookup results despite dictionary file existing.

### Pitfall 2: Case Sensitivity in SymSpell Lookups
**What goes wrong:** SymSpell treats "Hello" and "hello" as different entries. User types "Helo" but dictionary has "hello" (lowercase).
**Why it happens:** SymSpell does not normalize case internally.
**How to avoid:** Always lowercase both dictionary entries AND lookup input. Restore original case after getting the correction (match case of user input).
**Warning signs:** Common words not being corrected when typed with capital letters.

### Pitfall 3: Accent Correction as Edit Distance
**What goes wrong:** "cafe" (no accent) might not match "cafe" (accented e) if the Unicode distance is calculated incorrectly.
**Why it happens:** In Unicode, "e" (U+0065) -> "e-acute" (U+00E9) is a substitution (edit distance 1 in Damerau-Levenshtein). SymSpell uses delete-only pre-calculation, but the lookup phase computes full Damerau-Levenshtein.
**How to avoid:** Verify with test cases that "cafe" -> "cafe" (accented) works with edit distance 2. It should -- "e" to "e-acute" is 1 edit, well within the budget.
**Warning signs:** Unaccented words not getting accent corrections.

### Pitfall 4: Memory Spike During Dictionary Load
**What goes wrong:** Loading 30-50K words into SymSpell causes a temporary memory spike that pushes the keyboard extension past 50MB.
**Why it happens:** SymSpell pre-calculates delete variants. For edit distance 2 and average 6-letter words, each word generates ~20 delete variants stored in memory.
**How to avoid:** Profile on physical device with Instruments. Start with 30K words. If memory is tight, reduce to 25K or decrease prefix length from 7 to 5 (trades lookup speed for memory). The steady-state memory should be 3-8MB per language.
**Warning signs:** Keyboard extension being killed by iOS watchdog (jetsam) after language switch.

### Pitfall 5: Autocorrect Loop (Current Bug)
**What goes wrong:** User types "helo", space corrects to "hello", backspace undoes to "helo", space corrects AGAIN to "hello" -- user is trapped.
**Why it happens:** No rejection tracking. The spellCheck always returns the same correction.
**How to avoid:** After undo, store the rejected word. On next space, check if word is in rejected set before calling spellCheck. Clear rejected set when a new word is started.
**Warning signs:** User cannot type an intentionally "misspelled" word (proper noun, slang, etc.).

### Pitfall 6: Suggestion Bar Slot Ordering
**What goes wrong:** The bold slot doesn't match what gets auto-inserted on space, confusing users.
**Why it happens:** Current code bolds index 0 (first slot). Standard mobile keyboards bold the CENTER slot (index 1), which is the auto-apply correction.
**How to avoid:** Bold index 1 in SuggestionBarView. Ensure handleSpace() auto-applies the same word shown in the bold slot.
**Warning signs:** User taps the bold suggestion expecting it to be inserted, but a different word gets inserted.

## Code Examples

### Loading SymSpell from JSON Dictionary
```swift
// Source: Adapted from SymSpellSwift API + current FrequencyDictionary pattern
func loadSymSpell(language: String, bundle: Bundle = .main) -> SymSpell? {
    guard let url = bundle.url(forResource: "\(language)_frequency", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
        print("[SymSpellEngine] Missing \(language)_frequency.json")
        return nil
    }

    let ss = SymSpell(maxDictionaryEditDistance: 2, prefixLength: 7)
    for (word, count) in dict {
        // SymSpell needs COUNTS (higher = more common), not RANKS (lower = more common)
        // If dict stores ranks, invert: count = maxRank - rank
        ss.createDictionaryEntry(key: word.lowercased(), count: count)
    }
    print("[SymSpellEngine] Loaded \(dict.count) words for \(language)")
    return ss
}
```

**CRITICAL NOTE on frequency format:** The current `fr_frequency.json` uses RANKS (1 = most common, 1288 = least common). SymSpell expects COUNTS (higher = more common). The dictionary JSON format must be changed to use frequency counts (or the `SymSpellEngine` must invert ranks to counts). Recommendation: change JSON format to `{word: frequency_count}` where higher = more common. This aligns with SymSpell's native expectation and with Lexique 3.83's `freqfilms2` column (which gives per-million frequency).

### SymSpell Lookup with Case Restoration
```swift
// Source: Standard SymSpell usage pattern
func correctWord(_ word: String) -> (correction: String, alternatives: [String])? {
    guard let ss = symSpell else { return nil }
    let lowered = word.lowercased()

    let results = ss.lookup(lowered, verbosity: .closest, maxEditDistance: 2)
    guard !results.isEmpty else { return nil }

    // If best match IS the input word, it's correctly spelled
    if results[0].term == lowered { return nil }

    // Restore case: if input was capitalized, capitalize correction
    let correction = word.first?.isUppercase == true
        ? results[0].term.capitalized
        : results[0].term

    let alts = results.dropFirst().prefix(2).map { item -> String in
        word.first?.isUppercase == true ? item.term.capitalized : item.term
    }

    return (correction, Array(alts))
}
```

### Building Suggestions Array for Standard Bar Layout
```swift
// Source: Standard mobile keyboard pattern (iOS, Gboard, AOSP)
func buildSuggestions(currentWord: String, spellResult: (correction: String, alternatives: [String])?) -> [String] {
    guard let result = spellResult else {
        // Word is correct or unknown -- show completions from UITextChecker
        return []  // Let completions path handle it
    }

    var suggestions: [String] = []
    // Slot 0 (left): verbatim word as typed
    suggestions.append(currentWord)
    // Slot 1 (center): best correction -- will be bold, auto-applied on space
    suggestions.append(result.correction)
    // Slot 2 (right): alternative
    if let alt = result.alternatives.first {
        suggestions.append(alt)
    }
    return suggestions
}
```

### Lexique 3.83 Curation Script (Python)
```python
# Source: Lexique 3.83 documentation + project CONTEXT.md decisions
# Script to generate fr_frequency.json from Lexique 3.83 TSV
import pandas as pd
import json

# Download: http://www.lexique.org/databases/Lexique383/Lexique383.tsv
df = pd.read_csv('Lexique383.tsv', sep='\t')

# Use ortho (orthographic form) and freqfilms2 (subtitle frequency per million)
# freqfilms2 is preferred because subtitles represent spoken/written French better than books
df = df[['ortho', 'freqfilms2', 'freqlivres']].copy()

# Combined frequency (weighted: 70% films, 30% books for natural spoken French)
df['freq'] = df['freqfilms2'] * 0.7 + df['freqlivres'] * 0.3

# Deduplicate: keep highest frequency for each orthographic form
# (Lexique has multiple entries per word for different POS)
df = df.groupby('ortho')['freq'].max().reset_index()

# Filter: frequency > 0 and sort descending
df = df[df['freq'] > 0].sort_values('freq', ascending=False)

# Take top 40,000 words
top = df.head(40000)

# Convert to {word: count} where count is frequency * 100 (integer for SymSpell)
freq_dict = {}
for _, row in top.iterrows():
    word = row['ortho'].strip().lower()
    count = max(1, int(row['freq'] * 100))
    if word and len(word) > 0:
        freq_dict[word] = count

# Add ~50 SMS abbreviations with moderate frequency
sms = {'mdr': 500, 'stp': 400, 'bcp': 300, 'jsp': 250, 'slt': 200,
       'tkt': 200, 'ptdr': 150, 'pk': 150, 'pcq': 150, 'dsl': 150,
       'bjr': 100, 'msg': 100, 'rdv': 100, 'tps': 100, 'bsr': 80}
# ... add ~35 more
for word, count in sms.items():
    freq_dict.setdefault(word, count)

# Add ~500 proper nouns with moderate frequency
# Paris, Lyon, Marseille, France, Europe, Pierre, Marie, etc.
# (curated list, not auto-generated)

# Save
with open('fr_frequency.json', 'w', encoding='utf-8') as f:
    json.dump(freq_dict, f, ensure_ascii=False, indent=None)

print(f"Wrote {len(freq_dict)} entries")
```

### English Dictionary Curation (Norvig count_1w.txt)
```python
# Source: https://norvig.com/ngrams/count_1w.txt (MIT license)
import json

freq_dict = {}
with open('count_1w.txt') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) == 2:
            word, count = parts[0], int(parts[1])
            freq_dict[word] = count

# Sort by count, take top 40,000
sorted_words = sorted(freq_dict.items(), key=lambda x: -x[1])[:40000]
result = {word: count for word, count in sorted_words}

with open('en_frequency.json', 'w') as f:
    json.dump(result, f)

print(f"Wrote {len(result)} entries")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UITextChecker.guesses() | SymSpell lookup() | This phase | Sub-ms lookups vs 5-50ms UITextChecker; frequency-ranked vs alphabetical |
| 1.3K word frequency dict | 30-50K word frequency dict | This phase | Dramatically better coverage for common words |
| Accent suggestions in bar | Adaptive accent key + long-press | Phase 19 | accentSuggestions() now redundant, safe to remove |
| No autocorrect rejection | Rejection tracking per-word | This phase | Fixes the correction loop bug |

**Deprecated/outdated:**
- `SuggestionMode.accents`: Replaced by adaptive accent key (Phase 19). Remove.
- `accentSuggestions()` in TextPredictionEngine: Remove entirely.
- `AccentedCharacters.mappings` usage for suggestion bar: Remove (kept for adaptive accent key).

## Open Questions

1. **SymSpellSwift Unicode behavior with French accents**
   - What we know: SymSpell treats each Unicode code point as a character. "e" -> "e-acute" is edit distance 1 (substitution).
   - What's unclear: Whether SymSpellSwift handles composed vs decomposed Unicode correctly (NFC vs NFD). Swift strings are Unicode-correct by default, but edge cases may exist.
   - Recommendation: Add explicit test cases during implementation: "cafe" -> "cafe" (accented), "francais" -> "francais" (c-cedilla), "resume" -> "resume" (two accents = edit distance 2, at the limit).

2. **Exact memory footprint with 40K words**
   - What we know: SymSpell with edit distance 2 generates ~20 delete variants per word. 40K words * 20 deletes = 800K entries. Each entry is a string hash + word reference.
   - What's unclear: Exact Swift memory overhead for SymSpell's internal dictionaries.
   - Recommendation: Profile on physical device (iPhone) with Instruments after dictionary load. If >8MB, reduce to 30K words or decrease prefix length to 5.

3. **Frequency format: ranks vs counts**
   - What we know: Current JSON uses ranks (1=most common). SymSpell needs counts (higher=more common).
   - What's unclear: Whether to change JSON format or invert in SymSpellEngine.
   - Recommendation: Change JSON format to frequency counts. This aligns with SymSpell, Lexique 3.83 raw data, and Norvig count_1w.txt. The `FrequencyDictionary` struct (for UITextChecker ranking) must be updated to work with counts too (sort descending instead of ascending).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual device testing + Instruments profiling |
| Config file | None -- keyboard extensions cannot run XCTest directly |
| Quick run command | Build & run on physical device, type test words |
| Full suite command | Memory profiling with Instruments on device |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PRED-01 | French dict 30-50K words | smoke | Count entries in fr_frequency.json after curation | Wave 0 |
| PRED-02 | English dict 30-50K words | smoke | Count entries in en_frequency.json after curation | Wave 0 |
| PRED-03 | SymSpell replaces UITextChecker for spellCheck | manual | Type "helo" -> suggestion bar shows "hello" as bold center slot | manual-only: keyboard extension requires device |
| PRED-03 | Accent correction via edit distance | manual | Type "cafe" -> bar shows accented "cafe" | manual-only |
| PRED-03 | Autocorrect rejection after undo | manual | Type "helo" + space -> "hello" -> backspace -> "helo" -> space -> "helo" stays | manual-only |
| PRED-03 | Memory under 50MB with SymSpell loaded | manual | Instruments memory profiling on physical device | manual-only |
| PRED-03 | Language switch loads correct dictionary | manual | Switch to EN, type "teh" -> "the" correction | manual-only |

### Sampling Rate
- **Per task commit:** Build & run on Simulator, verify suggestion bar behavior
- **Per wave merge:** Physical device test: memory profiling + all test scenarios
- **Phase gate:** Memory profiling confirms <50MB total with SymSpell loaded

### Wave 0 Gaps
- [ ] Python/Swift dictionary curation scripts for Lexique 3.83 and Norvig count_1w.txt
- [ ] Expanded fr_frequency.json (30-50K entries)
- [ ] Expanded en_frequency.json (30-50K entries)
- [ ] Vendored SymSpellSwift source files in DictusKeyboard/Vendored/SymSpell/

## Sources

### Primary (HIGH confidence)
- [SymSpellSwift GitHub](https://github.com/gdetari/SymSpellSwift) - API surface, source files, MIT license, version 0.1.4
- [SymSpell original (wolfgarbe)](https://github.com/wolfgarbe/SymSpell) - Algorithm design, edit distance mechanics, verbosity levels
- [Lexique 3.83](http://www.lexique.org/?page_id=790&lang=en) - French lexicon with frequency data, TSV format with ortho/freqfilms2/freqlivres columns
- [Norvig ngrams](https://norvig.com/ngrams/) - count_1w.txt English frequency data, MIT license
- Current codebase: TextPredictionEngine.swift, SuggestionState.swift, SuggestionBarView.swift, DictusKeyboardBridge.swift, FrequencyDictionary.swift

### Secondary (MEDIUM confidence)
- [Google 10000 English](https://github.com/first20hours/google-10000-english) - 20K word list from Google Trillion Word Corpus (may be too small, Norvig count_1w.txt preferred)
- [SymSpell README memory notes](https://github.com/wolfgarbe/symspell/blob/master/README.md) - Prefix indexing achieves 90%+ memory reduction

### Tertiary (LOW confidence)
- Memory estimate of 3-8MB for 40K words is extrapolated from algorithm description (20 deletes per word), not measured. Must verify empirically on device.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - SymSpellSwift is the only maintained Swift implementation, well-documented API
- Architecture: HIGH - Clean wrapper pattern, existing code has clear separation points
- Dictionary sourcing: HIGH - Lexique 3.83 and Norvig are well-established, freely available
- Pitfalls: HIGH - Based on direct code reading of current implementation + SymSpell documentation
- Memory estimates: LOW - Extrapolated, not measured; must validate on physical device

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (stable domain, no fast-moving dependencies)
