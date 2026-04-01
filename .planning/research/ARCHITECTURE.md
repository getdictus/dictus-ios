# Architecture Patterns

**Domain:** iOS keyboard extension prediction engine upgrade + cold start auto-return
**Researched:** 2026-04-01
**Focus:** Integration of SymSpell, n-gram prediction, autocorrect fix, and cold start auto-return into existing two-process architecture
**Overall Confidence:** MEDIUM-HIGH (prediction architecture HIGH, cold start LOW)

## Current Architecture (Baseline)

```
DictusApp (Main Process)              DictusKeyboard (Extension, ~50MB limit)
+-----------------------+              +--------------------------------------+
| WhisperKit/Parakeet   |              | KeyboardViewController               |
| DictationCoordinator  |<--Darwin--->|   +-- DictusKeyboardBridge            |
| AVAudioSession        |  Notifs     |   +-- GiellaKeyboardView (UIKit)      |
| SwipeBackOverlay      |             |   +-- KeyboardRootView (SwiftUI)      |
| ModelManager          |<--AppGrp--->|       +-- SuggestionBarView           |
+-----------------------+              |       +-- ToolbarView                 |
                                       |                                      |
                                       | TextPrediction/                      |
                                       |   +-- SuggestionState (@Published)   |
                                       |   +-- TextPredictionEngine           |
                                       |       +-- UITextChecker (system)     |
                                       |       +-- FrequencyDictionary        |
                                       +--------------------------------------+

DictusCore (Shared Framework)
+-- SharedKeys, AppGroup, DarwinNotifications
+-- FrequencyDictionary (struct)
+-- AccentedCharacters
+-- HapticFeedback, PersistentLog
+-- Design tokens, themes
```

### Current Data Flow: Keystroke to Suggestion

```
User types character
  -> GiellaKeyboardView.touchesBegan (haptic)
  -> DictusKeyboardBridge.didTriggerKey(.input(char))
  -> proxy.insertText(character)
  -> Read proxy.documentContextBeforeInput
  -> SuggestionState.updateAsync(context:)
    -> DispatchWorkItem on serial background queue (.userInitiated)
    -> extractLastWord(from: context)
    -> TextPredictionEngine.suggestions(for:) or .accentSuggestions(for:)
      -> UITextChecker.completions() -> re-rank by FrequencyDictionary
    -> Main thread: @Published suggestions + mode update
  -> SuggestionBarView re-renders via SwiftUI
```

### Current Data Flow: Autocorrect on Space

```
User taps space
  -> DictusKeyboardBridge.handleSpace()
  -> SuggestionState.performSpellCheck(currentWord)
    -> TextPredictionEngine.spellCheck()
      -> UITextChecker.rangeOfMisspelledWord + guesses()
      -> Re-rank by FrequencyDictionary
  -> If correction != original:
    -> Delete currentWord via proxy.deleteBackward() loop
    -> proxy.insertText(correction + " ")
    -> Store AutocorrectState in SuggestionState.lastAutocorrect
  -> SuggestionState.clear()
```

## Recommended Architecture (After Upgrade)

### Component Boundaries

| Component | Responsibility | Location | Status |
|-----------|---------------|----------|--------|
| **SymSpellEngine** | Spell correction via symmetric delete algorithm | DictusKeyboard/TextPrediction/ | NEW |
| **NgramPredictor** | Next-word prediction from context (trigram with bigram backoff) | DictusKeyboard/TextPrediction/ | NEW |
| **NgramTrie** | Compact binary trie data structure for trigram storage | DictusKeyboard/TextPrediction/ | NEW |
| **TextPredictionEngine** | Orchestrator: routes to SymSpell (correction) + UITextChecker (completions) + NgramPredictor (next-word) | DictusKeyboard/TextPrediction/ | MODIFIED |
| **SuggestionState** | UI-facing adapter, async dispatch, @Published state, autocorrect undo | DictusKeyboard/TextPrediction/ | MODIFIED |
| **SuggestionBarView** | Displays 3-slot suggestions across all modes | DictusKeyboard/Views/ | MODIFIED |
| **DictusKeyboardBridge** | Key event translation, autocorrect undo clearing | DictusKeyboard/ | MODIFIED |
| **FrequencyDictionary** | Word frequency ranking for UITextChecker re-ranking | DictusCore/ | UNCHANGED |
| **KeyboardViewController** | View lifecycle, language refresh | DictusKeyboard/ | UNCHANGED |

### Upgraded Architecture Diagram

```
DictusKeyboard (Extension)
+------------------------------------------------------+
| KeyboardViewController                                |
|   +-- DictusKeyboardBridge                            |
|   |     handleInputKey: clear lastAutocorrect  <- FIX #67
|   |     handleSpace: correction via engine            |
|   +-- GiellaKeyboardView (UIKit)                      |
|   +-- KeyboardRootView (SwiftUI)                      |
|         +-- SuggestionBarView (4 modes)               |
|         +-- ToolbarView                               |
|                                                       |
| TextPrediction/                                       |
|   +-- SuggestionState (@Published)                    |
|   |     mode: .idle / .completions / .accents         |
|   |           / .nextWord  <- NEW MODE                |
|   |     lastAutocorrect: cleared on any input <- FIX  |
|   |                                                   |
|   +-- TextPredictionEngine (orchestrator)             |
|   |     +-- UITextChecker (completions -- kept)       |
|   |     +-- FrequencyDictionary (ranking -- kept)     |
|   |     +-- SymSpellEngine (spell correction) <- NEW  |
|   |     +-- NgramPredictor (next-word) <- NEW         |
|   |                                                   |
|   +-- SymSpellEngine.swift <- NEW                     |
|   |     Uses: SymSpellSwift SPM package               |
|   |     Data: {lang}_symspell.txt                     |
|   |                                                   |
|   +-- NgramPredictor.swift <- NEW                     |
|   |     Uses: NgramTrie (custom Swift struct)         |
|   |     Data: {lang}_trigram.bin                      |
|   |                                                   |
|   +-- NgramTrie.swift <- NEW                          |
|         Flat sorted array, binary search, mmap        |
|                                                       |
| Resources/                                            |
|   +-- fr_frequency.json (kept)                        |
|   +-- en_frequency.json (kept)                        |
|   +-- fr_symspell.txt <- NEW (~2-3MB)                 |
|   +-- en_symspell.txt <- NEW (~2-3MB)                 |
|   +-- fr_trigram.bin <- NEW (~5-10MB)                 |
|   +-- en_trigram.bin <- NEW (~5-10MB)                 |
+------------------------------------------------------+
```

### Memory Budget

| Component | Current | After Upgrade | Notes |
|-----------|---------|---------------|-------|
| UITextChecker | 0 MB (system) | 0 MB (system) | Shared system resource, zero extension cost |
| FrequencyDictionary | ~0.3 MB | ~0.3 MB | Kept for UITextChecker completion ranking |
| SymSpell dictionary (1 lang) | -- | ~3-5 MB | Symmetric delete index in RAM |
| N-gram model (1 lang) | -- | ~5-10 MB | Trigram trie, single language loaded |
| Keyboard UI + giellakbd | ~15 MB | ~15 MB | Unchanged |
| **Total** | ~15 MB | ~25-30 MB | Well within 50 MB limit |

**Critical constraint:** Load only ONE language at a time. Switch on `SharedKeys.language` change in `viewWillAppear`. This is the existing FrequencyDictionary pattern -- SymSpell and n-gram must follow it exactly.

## New Component Designs

### Component 1: SymSpellEngine (Spell Correction)

**What it replaces:** `UITextChecker.rangeOfMisspelledWord()` + `guesses()` for spell correction.
**What it does NOT replace:** `UITextChecker.completions()` for word completions (kept -- zero memory cost, good French morphology coverage).

```swift
// DictusKeyboard/TextPrediction/SymSpellEngine.swift

import SymSpellSwift  // SPM dependency: github.com/gdetari/SymSpellSwift

/// Wraps SymSpellSwift for fast probabilistic spell correction.
///
/// WHY SymSpell over UITextChecker for correction:
/// UITextChecker returns corrections ranked by edit distance only.
/// SymSpell pre-computes deletion variants and ranks by word frequency,
/// so "helo" -> "hello" (common word) instead of "helo" -> "helons" (rare).
class SymSpellEngine {
    private var symSpell: SymSpell?
    private var currentLanguage: String = ""

    func load(language: String) {
        guard language != currentLanguage else { return }
        currentLanguage = language

        let ss = SymSpell(
            maxDictionaryEditDistance: 2,
            prefixLength: 7  // Balance: speed vs memory. 7 = good default.
        )

        if let path = Bundle.main.path(
            forResource: "\(language)_symspell", ofType: "txt"
        ) {
            ss.loadDictionary(from: path, termIndex: 0, countIndex: 1)
        }
        symSpell = ss
    }

    /// Returns the best correction, or nil if word is correct/unknown.
    func correct(_ word: String) -> String? {
        guard let ss = symSpell else { return nil }
        let results = ss.lookup(
            word,
            verbosity: .closest,
            maxEditDistance: word.count < 3 ? 1 : 2
        )
        guard let best = results.first,
              best.term.lowercased() != word.lowercased() else {
            return nil
        }
        return best.term
    }
}
```

**Key design decisions:**
- Edit distance adapts to word length: 1 for short words (<3 chars), 2 for longer words. Short words with edit distance 2 produce too many irrelevant matches.
- Prefix length 7 provides 90%+ memory reduction per SymSpell documentation while maintaining fast lookups.

### Component 2: NgramPredictor (Next-Word Prediction)

**Recommendation: Pure Swift trigram trie** over KenLM C++ because:
1. No Objective-C++ bridging header complexity
2. MIT-compatible (KenLM is LGPL -- copyleft concern for MIT project)
3. Easier to debug for a Swift learner
4. 5-10 MB binary trie is sufficient for keyboard-grade prediction quality

```swift
// DictusKeyboard/TextPrediction/NgramPredictor.swift

/// Trigram-based next-word predictor using a compact binary trie.
///
/// Given context words [W1, W2], returns probable next words sorted by frequency.
/// Uses backoff: tries trigram P(W3|W1,W2) first, falls back to bigram P(W3|W2),
/// then unigram P(W3). Same approach as Gboard and SwiftKey.
class NgramPredictor {
    private var trie: NgramTrie?
    private var currentLanguage: String = ""

    func load(language: String) {
        guard language != currentLanguage else { return }
        currentLanguage = language
        guard let url = Bundle.main.url(
            forResource: "\(language)_trigram", withExtension: "bin"
        ) else {
            trie = nil; return
        }
        trie = NgramTrie.load(from: url)
    }

    /// Returns up to `max` next-word predictions given 1-2 context words.
    func predict(context: [String], max: Int = 3) -> [String] {
        guard let trie = trie else { return [] }

        // Try trigram first (2 context words)
        if context.count >= 2 {
            let predictions = trie.query(
                w1: context[context.count - 2],
                w2: context[context.count - 1],
                limit: max
            )
            if !predictions.isEmpty { return predictions }
        }

        // Backoff to bigram (1 context word)
        if let lastWord = context.last {
            return trie.query(w2: lastWord, limit: max)
        }
        return []
    }
}
```

### Component 3: NgramTrie (Data Structure)

```swift
// DictusKeyboard/TextPrediction/NgramTrie.swift

/// Compact trigram trie stored as a flat sorted array for cache-friendly access.
///
/// Binary format (generated offline by a build tool):
/// Header: [vocabSize: UInt32, trigramCount: UInt32, bigramCount: UInt32]
/// Vocab:  [word1\0, word2\0, ...] (null-terminated UTF-8 strings)
/// Trigram entries: sorted by (w1_idx, w2_idx), each 16 bytes:
///   [w1_idx: UInt32, w2_idx: UInt32, w3_idx: UInt32, freq: UInt32]
/// Bigram entries: sorted by w1_idx, each 12 bytes:
///   [w1_idx: UInt32, w2_idx: UInt32, freq: UInt32]
///
/// WHY flat array over nested Dictionary:
/// Swift Dictionary has ~80 bytes overhead per entry.
/// A flat sorted array with binary search uses 16 bytes per trigram entry.
/// For 500K trigrams: ~8MB flat vs ~40MB nested Dictionary.
struct NgramTrie {
    private let vocab: [String]
    private let vocabIndex: [String: UInt32]
    private let trigrams: UnsafeBufferPointer<TrigramEntry>  // mmap'd
    private let bigrams: UnsafeBufferPointer<BigramEntry>    // mmap'd

    struct TrigramEntry {
        let w1: UInt32; let w2: UInt32; let w3: UInt32; let freq: UInt32
    }
    struct BigramEntry {
        let w1: UInt32; let w2: UInt32; let freq: UInt32
    }

    static func load(from url: URL) -> NgramTrie? {
        // Memory-map the file for lazy loading
        // Parse header -> build vocab table -> reference entry arrays
        // Implementation in build phase
    }

    func query(w1: String, w2: String, limit: Int) -> [String] {
        // Binary search for (w1_idx, w2_idx) prefix in trigrams
        // Collect top-N by freq, map w3_idx to vocab string
    }

    func query(w2: String, limit: Int) -> [String] {
        // Binary search for w1_idx in bigrams (bigram backoff)
    }
}
```

### Component 4: TextPredictionEngine (Modified Orchestrator)

```swift
// Changes to TextPredictionEngine.swift

class TextPredictionEngine {
    private let textChecker = UITextChecker()        // KEPT: word completions
    private var frequencyDict = FrequencyDictionary() // KEPT: completion ranking
    private let symSpell = SymSpellEngine()           // NEW: spell correction
    private let ngram = NgramPredictor()              // NEW: next-word prediction
    private var language: String = "fr"

    func setLanguage(_ lang: String) {
        language = lang
        frequencyDict.load(language: lang)
        symSpell.load(language: lang)    // NEW
        ngram.load(language: lang)       // NEW
    }

    // suggestions(for:) -- UNCHANGED
    // Still uses UITextChecker.completions() + FrequencyDictionary ranking
    func suggestions(for partialWord: String) -> [String] { /* unchanged */ }

    // spellCheck -- CHANGED: SymSpell with UITextChecker fallback
    func spellCheck(_ word: String) -> String? {
        if let correction = symSpell.correct(word) { return correction }
        return fallbackSpellCheck(word)  // UITextChecker as fallback
    }

    // NEW: next-word predictions from context
    func nextWordPredictions(context: [String]) -> [String] {
        return ngram.predict(context: context, max: 3)
    }

    // accentSuggestions -- UNCHANGED
    func accentSuggestions(for partialWord: String) -> [String]? { /* unchanged */ }

    // Fallback: original UITextChecker spell check (for graceful degradation)
    private func fallbackSpellCheck(_ word: String) -> String? {
        let nsString = word as NSString
        let range = NSRange(location: 0, length: nsString.length)
        let misspelled = textChecker.rangeOfMisspelledWord(
            in: word, range: range, startingAt: 0, wrap: false, language: language
        )
        guard misspelled.location != NSNotFound else { return nil }
        guard let guesses = textChecker.guesses(
            forWordRange: misspelled, in: word, language: language
        ), !guesses.isEmpty else { return nil }
        let ranked = guesses.sorted { frequencyDict.rank(of: $0) < frequencyDict.rank(of: $1) }
        return ranked.first
    }
}
```

### Component 5: SuggestionState (Modified)

```swift
// Changes to SuggestionState.swift

enum SuggestionMode {
    case idle
    case completions
    case accents
    case nextWord    // NEW: showing next-word predictions after space
}

// In updateAsync(context:):
// Current behavior when context ends with space/newline: clear() -> .idle
// NEW behavior: extract last 2 words, query nextWordPredictions
//   If predictions available -> mode = .nextWord, suggestions = predictions
//   If no predictions -> mode = .idle (unchanged fallback)

// Context word extraction helper:
private func extractContextWords(from text: String, max: Int = 2) -> [String] {
    var words: [String] = []
    text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { word, _, _, _ in
        if let word = word { words.append(word) }
    }
    return Array(words.suffix(max))
}
```

### Component 6: Autocorrect Undo Fix (#67)

**Root cause:** `lastAutocorrect` is never cleared when the user types new characters after a correction. The undo fires on any future backspace, corrupting text.

**Fix location:** `DictusKeyboardBridge.handleInputKey()` -- add one line:

```swift
private func handleInputKey(_ character: String) {
    suggestionState?.lastAutocorrect = nil  // FIX #67: clear undo on new input
    AudioServicesPlaySystemSound(KeySound.letter)
    // ... rest unchanged
}
```

Also clear in `handleReturn()` and `handleAdaptiveAccentKey()` for completeness -- any non-backspace input should invalidate the undo state.

## Data Flow Changes

### New Flow: Spell Correction via SymSpell

```
User taps space
  -> DictusKeyboardBridge.handleSpace()
  -> SuggestionState.performSpellCheck(currentWord)
    -> TextPredictionEngine.spellCheck()
      -> SymSpellEngine.correct(word)  <- CHANGED (was UITextChecker)
        -> SymSpell.lookup(word, verbosity: .closest, maxEditDistance: 1 or 2)
        -> Return best match ranked by corpus frequency
      -> If SymSpell returns nil: fallbackSpellCheck via UITextChecker
  -> If correction differs: replace word, store undo state (unchanged)
```

### New Flow: Next-Word Prediction After Space

```
After space insertion (word spelled correctly or after correction):
  -> Instead of SuggestionState going to .idle:
  -> Extract last 2 completed words from documentContextBeforeInput
  -> TextPredictionEngine.nextWordPredictions(context: [word1, word2])
    -> NgramPredictor.predict(context:)
    -> Trigram lookup: binary search (w1, w2) -> collect top-3 by freq
    -> If no trigram match: bigram backoff with last word only
  -> If predictions available:
    -> suggestions = predictions, mode = .nextWord
  -> If no predictions:
    -> suggestions = [], mode = .idle
```

### New Flow: Tapping a Next-Word Prediction

```
User taps suggestion in .nextWord mode
  -> KeyboardRootView.onSuggestionTap(index:)
  -> proxy.insertText(selectedWord + " ")
  -> Re-query next-word predictions with updated context
  -> Enables chained predictions:
    "Je" -> [suis, vais, peux]
    tap "suis" -> "Je suis " -> [un, en, le]
    tap "un" -> "Je suis un " -> [homme, bon, peu]
```

### Cold Start Auto-Return Analysis

```
CURRENT (working):
  Keyboard mic tap
  -> Darwin notification (warm start) OR URL scheme (cold start)
  -> DictusApp opens, starts recording
  -> User manually swipes back (guided by SwipeBackOverlayView)
  -> Keyboard shows recording overlay, waveform, stop/cancel buttons

PROPOSED AUTO-RETURN:
  The keyboard would detect the source app -> write to App Group
  -> App reads source app scheme after transcription
  -> openURL(sourceScheme://) to return automatically
```

**Research findings (LOW confidence):**

Based on research including the [Swift Forums discussion on auto-return techniques](https://forums.swift.org/t/how-do-voice-dictation-keyboard-apps-like-wispr-flow-return-users-to-the-previous-app-automatically/83988), there is NO reliable public API to accomplish this:

| Approach | Status | Problem |
|----------|--------|---------|
| `_hostBundleID` | Blocked | Private API, blocked in iOS 18+ |
| `LSApplicationWorkspace` | Rejected | Private API, confirmed App Store rejection |
| `UIApplication.suspend()` | Wrong behavior | Goes to home screen, not previous app |
| `canOpenURL` iteration | Wrong target | Opens first installed app, not source app |
| `x-callback-url` | Impractical | Requires cooperation from every host app |
| Accessibility APIs | Risky | Undocumented, App Store review risk |

**Wispr Flow** appears to achieve auto-return but the mechanism is undocumented. It may rely on a private API that Apple permits for specific apps, or a timing-based trick that is not publicly documented.

**Recommendation:** Defer auto-return (#23) to a standalone research spike. The swipe-back overlay works 100% of the time for all apps and is already polished (branded animation, bilingual text). Invest engineering effort in prediction quality -- it has vastly higher user impact per engineering hour.

## Patterns to Follow

### Pattern 1: Single-Language Loading
**What:** Load SymSpell dictionary and n-gram model for only one language at a time.
**When:** On `viewWillAppear` language refresh and on `setLanguage()` calls.
**Why:** Two languages loaded simultaneously = ~25-30 MB, leaving no headroom.
**Precedent:** FrequencyDictionary already follows this exact pattern.

### Pattern 2: Background Queue Reuse
**What:** Run SymSpell and n-gram queries on the existing `suggestionQueue` serial DispatchQueue.
**When:** On every keystroke (completions) and after every space (next-word).
**Why:** The async coalescing with `DispatchWorkItem` cancellation prevents stale results. Same queue = same guarantees, no new threading.

### Pattern 3: Async Load with Graceful Degradation
**What:** Load SymSpell/n-gram data asynchronously. Fall back to UITextChecker until loaded.
**When:** Extension launch, language change.
**Why:** SymSpell dictionary pre-computation takes ~500ms. Keyboard must be responsive immediately. UITextChecker is available instantly as the system framework.
```swift
func spellCheck(_ word: String) -> String? {
    if let correction = symSpell.correct(word) { return correction }
    return fallbackSpellCheck(word)  // UITextChecker until SymSpell loads
}
```

### Pattern 4: Offline Trie Generation
**What:** Build trigram binary trie offline (macOS CLI tool or script), bundle the `.bin` file.
**When:** During development, before each release. Not at runtime.
**Why:** Parsing corpus text takes seconds-to-minutes. Keyboard loads pre-built binary in milliseconds.
**Tool:** Swift command-line target in Xcode project or standalone script.

### Pattern 5: Edit Distance Adaptation
**What:** Use edit distance 1 for short words (<3 chars), edit distance 2 for longer words.
**When:** Every SymSpell lookup call.
**Why:** "ab" with edit distance 2 matches nearly everything. Restricting to 1 for short inputs prevents noise.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Replacing UITextChecker for Completions
**What:** Using SymSpell instead of UITextChecker for partial word completions.
**Why bad:** UITextChecker.completions() has zero memory cost (system dictionary), handles French conjugations/morphology for 100K+ words. SymSpell is designed for CORRECTION (finding the closest known word to a misspelled input), not for COMPLETION (finding all words starting with a prefix). Using SymSpell for completions would require a separate prefix-search index.
**Instead:** Keep UITextChecker for completions, use SymSpell for corrections only.

### Anti-Pattern 2: KenLM C++ Bridging
**What:** Using KenLM via Objective-C++ bridging header.
**Why bad:** Adds build complexity, LGPL license (copyleft concern for MIT project), harder to debug, and a pure Swift trigram trie is sufficient for keyboard-grade quality.
**Instead:** Pure Swift trigram trie with offline binary format.

### Anti-Pattern 3: Loading Both Languages
**What:** Pre-loading FR + EN SymSpell + n-gram data.
**Why bad:** ~25-30 MB for two languages + ~15 MB existing = 40-45 MB. iOS kills extensions at ~50 MB without warning.
**Instead:** Single language loaded. 200-500ms reload on language switch is fine (rare event).

### Anti-Pattern 4: Nested Swift Dictionaries for N-grams
**What:** Storing trigrams as `[String: [String: [String: Int]]]`.
**Why bad:** Swift Dictionary overhead is ~80 bytes per entry. 500K trigrams = ~40 MB.
**Instead:** Flat sorted array with binary search at 16 bytes/entry = ~8 MB.

### Anti-Pattern 5: N-gram Queries on Partial Words
**What:** Sending partial input ("bon") to the n-gram predictor during typing.
**Why bad:** N-grams predict NEXT words, not completions. "bon" as a bigram key returns words that follow "bon" in sentences ("jour", "appétit"), not words that start with "bon" ("bonjour", "bonheur").
**Instead:** Only query n-gram predictor after a word boundary (space/punctuation). Use UITextChecker for partial word completion.

### Anti-Pattern 6: Synchronous Dictionary Loading
**What:** Calling `symSpell.loadDictionary()` on main thread in `init()` or `viewDidLoad()`.
**Why bad:** Blocks keyboard appearance for 500ms-2s. User sees frozen keyboard.
**Instead:** Load async on background queue. UITextChecker covers the first few keystrokes.

## Scalability Considerations

| Concern | Current (v1.3) | After Upgrade (v1.4) | Future (v2+) |
|---------|----------------|----------------------|--------------|
| Languages | FR + EN (1 loaded) | FR + EN (1 loaded, richer data) | Add languages by adding dict + trie files |
| Vocabulary | ~1.2K frequency + system dict | ~80K SymSpell + ~50K trigram vocab | Scale trie vocab, same architecture |
| Prediction | Current-word only | Current-word + next-word | User-learned words, personalized n-grams |
| Memory | ~15 MB | ~25-30 MB | Approaching limit -- careful growth |
| Latency | <5ms per keystroke | <10ms target per keystroke | Profile on oldest device (iPhone 12) |
| Personalization | None | None | Append user bigrams to trie at runtime |

## Build Order (Dependency-Driven)

```
Phase 1: Autocorrect undo fix (#67)
  Dependencies: None
  Risk: Minimal (single-line fix in 1 file + same in 2 others)
  Files changed: DictusKeyboardBridge.swift
  Validation: Type after autocorrect, backspace = normal delete (not undo)

Phase 2: SymSpell integration (#68 part 1)
  Dependencies: SymSpellSwift SPM package + dictionary files
  Risk: Medium (memory profiling needed on real device)
  New files: SymSpellEngine.swift
  Modified: TextPredictionEngine.swift (spellCheck method)
  New resources: fr_symspell.txt (~2-3MB), en_symspell.txt (~2-3MB)
  Validation: "helo" -> "hello" (not "helons"), "caf" -> "cafe"

Phase 3: N-gram trie data structure + offline builder
  Dependencies: Corpus data (French Wikipedia or OpenSubtitles)
  Risk: Medium (binary format design, corpus sourcing)
  New files: NgramTrie.swift, trigram build tool (macOS CLI target or script)
  New resources: fr_trigram.bin (~5-10MB), en_trigram.bin (~5-10MB)
  Validation: Trie loads from binary, returns trigram query results correctly

Phase 4: N-gram predictor integration (#68 part 2)
  Dependencies: Phase 3 (trie data structure must exist first)
  Risk: Low (follows same wrapper pattern as SymSpellEngine)
  New files: NgramPredictor.swift
  Modified: TextPredictionEngine.swift (add nextWordPredictions method)
  Validation: After "je suis", predictions = [un, en, le] or similar

Phase 5: SuggestionState next-word mode + UI
  Dependencies: Phase 4 (predictor must produce results)
  Risk: Low (UI extension of existing mode pattern)
  Modified: SuggestionState.swift (.nextWord mode + context extraction)
             SuggestionBarView.swift (next-word mode styling)
             KeyboardRootView.swift (tap handler for next-word insertion)
  Validation: Suggestion bar shows next-word after space,
              tapping inserts word + refreshes to new predictions

Phase 6: Cold start auto-return (#23)
  Dependencies: None (independent track)
  Risk: HIGH (no known public API solution)
  Recommendation: DEFER -- swipe-back overlay already works for all apps
  If researched: standalone spike, do not block milestone

Phase 7: License update (#63)
  Dependencies: None
  Risk: Minimal
  Files: SettingsView.swift, LICENSE file
```

**Ordering rationale:**
- Bug fix first (#67): instant user value, zero risk, unblocks QA testing.
- SymSpell before n-gram: biggest quality improvement ("helo -> hello" is the most visible failure). Users feel the difference immediately.
- Trie data structure before predictor: the binary format and load mechanism must exist before the predictor wrapper can use it.
- Next-word UI last in prediction work: needs all backends working first.
- Cold start auto-return is highest risk with lowest success probability. Do not block the milestone on it.

## Sources

### HIGH Confidence
- Existing codebase: TextPredictionEngine.swift, SuggestionState.swift, DictusKeyboardBridge.swift, FrequencyDictionary.swift, KeyboardViewController.swift (direct code analysis)
- [SymSpellSwift](https://github.com/gdetari/SymSpellSwift) -- MIT license, SPM, v0.1.4 (Aug 2025), Swift implementation
- [SymSpell algorithm](https://github.com/wolfgarbe/SymSpell) -- symmetric delete documentation, prefix indexing for 90%+ memory reduction
- GitHub issues [#67](https://github.com/getdictus/dictus-ios/issues/67) (autocorrect undo bug), [#68](https://github.com/getdictus/dictus-ios/issues/68) (prediction upgrade), [#23](https://github.com/getdictus/dictus-ios/issues/23) (auto-return)
- Phase 8 research (08-RESEARCH.md) -- original prediction architecture, UITextChecker analysis

### MEDIUM Confidence
- [KenLM](https://github.com/kpu/kenlm) -- n-gram toolkit, C++, LGPL (researched, not recommended)
- [AOSP dictionaries](https://codeberg.org/Helium314/aosp-dictionaries) -- pre-built language models, corpus sourcing reference
- SymSpell memory estimate: 3-5 MB per language for 80K dictionary at edit distance 2 with prefix length 7 (based on algorithm analysis, not empirically verified on iOS)
- N-gram trie size estimate: 5-10 MB for 500K trigrams at 16 bytes/entry (needs real-device profiling)
- [Swift Package Index: SymSpellSwift](https://swiftpackageindex.com/gdetari/SymSpellSwift) -- package metadata

### LOW Confidence
- [Swift Forums: auto-return techniques](https://forums.swift.org/t/how-do-voice-dictation-keyboard-apps-like-wispr-flow-return-users-to-the-previous-app-automatically/83988) -- no public API solution found, Wispr Flow mechanism undocumented
- Cold start auto-return feasibility: no evidence of App Store-safe technique
- SymSpellSwift in iOS keyboard extension: untested in 50MB constrained environment, needs memory profiling
