# Technology Stack -- v1.4 Prediction & Stability

**Project:** Dictus v1.4
**Researched:** 2026-04-01
**Scope:** Stack additions for probability-based text prediction (SymSpell + n-gram), cold start auto-return, autocorrect bug fix, and license updates. Existing stack (Swift 5.9+, SwiftUI, WhisperKit, FluidAudio, giellakbd-ios, DeviceKit, DictusCore) is validated and unchanged.

---

## Critical Finding: One New SPM Dependency + Two Custom Data Files

The v1.4 prediction upgrade requires **SymSpellSwift** (SPM) for fast spell correction, plus two custom data files: a French frequency dictionary (~50K words) for SymSpell and a custom French n-gram (bigram/trigram) binary file for next-word prediction. No other new dependencies are needed.

KenLM was considered but rejected -- it is a C++ library with no Swift binding, requires CMake/Boost build infrastructure, and produces model files that are far too large (50-500MB) for a 50MB keyboard extension. A custom lightweight n-gram lookup is the correct approach.

Cold start auto-return requires **no new dependencies** -- it is a UX/architecture problem, not a library problem.

---

## Recommended Stack Changes

### New Dependency

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| [SymSpellSwift](https://github.com/gdetari/SymSpellSwift) | 0.1.4 | Fast spelling correction via symmetric delete algorithm | Replaces UITextChecker for spell correction. UITextChecker sorts completions alphabetically (not by probability) and has no edit-distance control. SymSpell provides O(1) lookup for corrections within edit distance 2, language-independent, no system dictionary dependency. MIT license, zero sub-dependencies, iOS 15.0+ minimum. 12 commits, 5 releases, last updated August 2025. Small library -- pure Swift, no C/ObjC bridging. |

**Confidence:** MEDIUM -- SymSpellSwift is a small, relatively new library (9 months old, 5 releases). The algorithm is proven (wolfgarbe/SymSpell has 3K+ stars, used in production worldwide), but the Swift port has limited community adoption. Mitigation: the library is <500 lines of Swift, fully readable, and could be vendored if maintenance stops.

### New Data Files (bundled, not dependencies)

| File | Size (est.) | Format | Purpose | Source |
|------|-------------|--------|---------|--------|
| `fr_symspell_50k.txt` | ~1.5MB | TSV (word\tfrequency) | French frequency dictionary for SymSpell | Build from [Lexique 3.83](http://www.lexique.org/) or [OpenSubtitles French](https://en.wiktionary.org/wiki/Wiktionary:Frequency_lists/French) -- top 50K words by frequency. CC BY-SA or similar open license. |
| `fr_ngram.bin` | ~2-3MB | Custom binary | French bigram/trigram frequency data for next-word prediction | Build from French Wikipedia/OpenSubtitles corpus. Custom binary format: sorted arrays with binary search, or trie with varint encoding. |

**Memory budget:** SymSpell dictionary (50K words, edit distance 2, prefix length 7) uses ~3-5MB in memory after pre-calculation. N-gram binary loaded via memory-mapped file (mmap) adds ~0MB resident until queried. Total prediction system budget: ~5MB, well within the 50MB keyboard extension limit.

### Why 50K Words (Not 80K or 100K)

SymSpell pre-calculates delete variants for every dictionary word. With edit distance 2 and a 50K-word dictionary:
- Each word generates ~25 delete variants
- 50K x 25 = ~1.25M dictionary entries
- At ~40 bytes per entry = ~50MB pre-calculated index

This is tight for the keyboard extension. Options to reduce memory:
1. **Prefix length = 7** (default is full word) -- reduces index by ~90% per SymSpell docs
2. **Edit distance = 1** instead of 2 -- reduces index dramatically, still catches most typos
3. **30K words** instead of 50K -- covers 98%+ of typed French text

**Recommendation:** Start with 30K words, edit distance 2, prefix length 7. Profile on device. Increase to 50K if memory allows.

---

## Custom N-gram Implementation (DO NOT Use KenLM)

### Why Not KenLM

| Factor | KenLM | Custom Implementation |
|--------|-------|----------------------|
| Language | C++ | Swift |
| iOS integration | Requires C++ bridging header, CMake build, Boost dependency | Native Swift, zero bridging |
| Model size (French trigram) | 50-500MB (probing) or 20-100MB (trie) | 2-3MB (pruned, top-50K vocab) |
| Memory | Maps entire model file | Memory-mapped, lazy loading |
| Maintenance | External C++ dependency to keep building | Owned code, trivially maintainable |
| Build complexity | CMake + Boost + C++ flags in Xcode | Zero additional build config |

### Recommended N-gram Architecture

Build a simple `NgramPredictor` in Swift:

```
Input: last 1-2 words typed
Output: top 3 predicted next words, ranked by frequency

Data structure: Dictionary<String, [(word: String, freq: UInt32)]>
- Key = "w1" (unigram context) or "w1 w2" (bigram context)
- Value = sorted array of (next_word, frequency) pairs, capped at top 20 per context

Lookup: trigram first (backoff to bigram, backoff to unigram frequency)
```

**Data preparation (offline, not in app):**
1. Process French Wikipedia + OpenSubtitles corpus
2. Count bigrams and trigrams
3. Prune: keep only entries where context words AND predicted word are in the top 30K vocabulary
4. Prune: keep only top 20 predictions per context
5. Serialize to compact binary (varint-encoded frequencies, null-terminated strings, sorted for binary search)
6. Target file size: 2-3MB

**Memory at runtime:**
- Load binary via `Data(contentsOf:)` or `mmap`
- Parse into `[String: [(String, UInt32)]]` on first query (lazy)
- Estimated memory: 2-4MB resident
- Total prediction budget (SymSpell + n-gram): ~5-8MB

### Integration with Existing TextPredictionEngine

```
Current flow:
  keystroke -> extractLastWord -> UITextChecker.completions -> FrequencyDictionary.rank -> top 3

New flow:
  keystroke -> extractLastWord
    if partialWord.count >= 2:
      SymSpell.lookup(partialWord, maxEditDistance: 2) -> rank by frequency -> top 3 completions
    if lastWordComplete (after space):
      NgramPredictor.predict(context: last1or2Words) -> top 3 next-word predictions
    fallback:
      UITextChecker.completions (keep as fallback for edge cases)
```

**Key change:** SymSpell replaces UITextChecker for spell correction AND word completion. UITextChecker is kept as a fallback only. N-gram predictor activates after word boundaries (space typed) for next-word prediction -- a capability the current engine lacks entirely.

---

## Cold Start Auto-Return: No New Dependencies

### What the Research Shows

Based on the thorough analysis in `assets/reference/issue-23-report.md` and Apple DTS responses (January 2026):

1. **No public API exists** to programmatically return to the previous app (Apple DTS confirmed explicitly)
2. **`_hostBundleID` is private API** and broken in iOS 26.4 beta (returns empty per KeyboardKit bug report FB22247647)
3. **`sourceApplication`** in `application(_:open:options:)` MAY contain the host app bundle ID when the keyboard extension opens the container app via URL scheme -- this needs on-device testing
4. **Competitors (Wispr Flow)** use "session" model + system back arrow, not true auto-return
5. **Known app schemes** already exist in `KnownAppSchemes.swift` (10 apps)

### Recommended Approach (No New Libraries)

| Component | Implementation | New Code? |
|-----------|---------------|-----------|
| Detect source app | Test `sourceApplication` in `application(_:open:options:)` on device | Modify `DictusApp.swift` |
| Store source app | Write bundle ID to App Group `UserDefaults` | Trivial |
| Return to source | `UIApplication.shared.open(URL(string: scheme)!)` using `KnownAppSchemes` whitelist | Already exists |
| Fallback UX | "Tap Back arrow to return" guidance overlay | New SwiftUI view |
| Expand whitelist | Add 5-10 more popular French apps to `KnownAppSchemes` | Extend existing |

**Out of scope:** LSApplicationWorkspace (private API, confirmed App Store rejection in PROJECT.md).

### sourceApplication Testing Priority

Before building any auto-return feature, test on a physical device:
1. From Notes, tap mic in Dictus keyboard -> opens DictusApp via URL scheme
2. In `application(_:open:options:)`, print `options[.sourceApplication]`
3. If it returns the keyboard extension's bundle ID (not Notes), this approach fails
4. If it returns nothing, this approach fails

This test takes 5 minutes and determines the entire strategy. Do it in Wave 0.

---

## Autocorrect Bug Fix (#67): No New Dependencies

The bug (autocorrect undo triggers after typing new characters) is a state management issue in `SuggestionState.lastAutocorrect`. The fix:

```swift
// In DictusKeyboardBridge.handleInputKey(), after inserting any character:
suggestionState?.lastAutocorrect = nil  // Clear undo state after any new input
```

This is a one-line fix. The `lastAutocorrect` state should only persist for exactly one keystroke (the immediate backspace after autocorrect). Any other input commits the correction permanently.

---

## License Updates (#63): No New Dependencies

Update `SettingsView.swift` to:
1. Fix repo link URL
2. Add Parakeet/NVIDIA attribution line
3. Add SymSpellSwift attribution (MIT license, if adopted)

Pure text changes, no libraries needed.

---

## Unchanged Stack (validated, DO NOT modify)

| Technology | Version | Target | Notes |
|------------|---------|--------|-------|
| Swift | 5.9+ | All | No change |
| SwiftUI | iOS 17+ | DictusApp, overlays | No change |
| UIKit (giellakbd-ios) | Vendored | DictusKeyboard | No change |
| WhisperKit | 0.16.0+ | DictusApp | No change |
| FluidAudio (Parakeet) | via SPM | DictusApp | No change |
| DeviceKit | 5.8.x | DictusKeyboard | No change |
| DictusCore | Local SPM | Shared | No change |
| UITextChecker | System | DictusKeyboard | Kept as fallback, no longer primary |
| FrequencyDictionary | Custom JSON | DictusKeyboard | Replaced by SymSpell frequency dict for ranking, may keep for accent mode fallback |
| iOS minimum | 17.0 | All | No change |

---

## What NOT to Add

| Temptation | Why Not |
|------------|---------|
| KenLM | C++ library, requires CMake/Boost, model files 50-500MB, impossible in 50MB keyboard extension. Custom n-gram is 100x smaller. |
| Core ML n-gram model | Overkill for simple frequency lookup. Core ML adds framework overhead. Dictionary-based lookup is faster and lighter. |
| KeyboardKit | $299/year commercial framework. We already have giellakbd-ios vendored. Only useful info is their `hostApplicationBundleId` approach (private API, broken in iOS 26.4). |
| NaturalLanguage framework (NLLanguageRecognizer) | Only useful for language detection, not word prediction. We already know the language (user setting). |
| Apple Foundation Models | Requires iPhone 15 Pro+ and iOS 26.1+. Explicitly out of scope in PROJECT.md. |
| Presage (C++) | Another C++ library for text prediction. Same C++ bridging problems as KenLM. |
| Any cloud API | Contradicts privacy/offline identity. |
| SQLite/GRDB for n-gram storage | Adds database dependency for simple key-value lookup. A sorted binary file with binary search is faster and simpler for read-only data. |

---

## Installation

```bash
# Add SymSpellSwift via SPM in Xcode:
# File > Add Package Dependencies
# URL: https://github.com/gdetari/SymSpellSwift.git
# Version: Up to Next Minor (0.1.4)
# Target: DictusKeyboard (keyboard extension only)
```

### Data file preparation (offline, pre-build)

```bash
# 1. Download French word frequency list (Lexique 3.83 or OpenSubtitles)
# 2. Convert to SymSpell format: word\tfrequency (TSV)
#    Keep top 30-50K words only
#    Save as fr_symspell_50k.txt

# 3. Build n-gram binary from French corpus:
#    - Process French Wikipedia dump + OpenSubtitles French
#    - Count bigrams/trigrams
#    - Prune to 30K vocabulary, top 20 predictions per context
#    - Serialize to fr_ngram.bin
#    - Script: scripts/build_ngram.py (Python, runs on dev machine only)
```

### Bundle in Xcode

Add `fr_symspell_50k.txt` and `fr_ngram.bin` to DictusKeyboard target (Copy Bundle Resources).

---

## Memory Budget Impact

| Component | Current (v1.3) | After v1.4 | Delta |
|-----------|----------------|------------|-------|
| UITextChecker | ~0MB (system) | ~0MB (kept as fallback) | 0 |
| FrequencyDictionary (1.3K words JSON) | ~0.1MB | ~0.1MB (keep for accent mode) | 0 |
| SymSpell dictionary (30-50K words) | N/A | ~3-5MB | +3-5MB |
| N-gram binary (pruned trigrams) | N/A | ~2-4MB | +2-4MB |
| SymSpellSwift library code | N/A | <0.1MB | +0.1MB |
| **Total prediction system** | ~0.1MB | ~5-9MB | +5-9MB |
| **Remaining headroom** (of 50MB) | ~35-40MB | ~26-35MB | Adequate |

**Risk:** If SymSpell pre-calculation with 50K words exceeds 5MB, reduce to 30K words. Profile on device during implementation.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Spell correction | SymSpellSwift (SPM) | UITextChecker (current) | UITextChecker returns alphabetical completions, no edit-distance control, no probability ranking. SymSpell is O(1) with frequency-based ranking built in. |
| Spell correction | SymSpellSwift (SPM) | Custom trie + Levenshtein | Massive implementation effort for what SymSpell already solves. Would need to reimplement the symmetric delete trick. |
| Spell correction | SymSpellSwift (SPM) | Vendor SymSpell source directly | SymSpellSwift is only ~500 lines. SPM is cleaner for now; vendor if library goes unmaintained. |
| Next-word prediction | Custom n-gram binary | KenLM | C++ bridging, Boost dependency, 50-500MB models. Impossible in keyboard extension. |
| Next-word prediction | Custom n-gram binary | Core ML transformer | ~50-200MB model size, slow inference on older devices, overkill for top-3 word prediction. |
| Next-word prediction | Custom n-gram binary | Apple NLModel | No public API for custom n-gram language models. NLModel is for classification, not text prediction. |
| French corpus | OpenSubtitles + Wikipedia | Google n-grams | Google n-gram files are 24GB+ for French. OpenSubtitles reflects conversational language (better for a dictation keyboard). |
| Auto-return | sourceApplication + KnownAppSchemes | _hostBundleID private API | Broken in iOS 26.4, App Store rejection risk. |
| Auto-return | sourceApplication + KnownAppSchemes | LSApplicationWorkspace | Confirmed private API, explicitly rejected in PROJECT.md out of scope. |

---

## Confidence Assessment

| Area | Confidence | Reasoning |
|------|------------|-----------|
| SymSpellSwift as dependency | MEDIUM | Algorithm is proven (wolfgarbe/SymSpell). Swift port is young (9 months, 5 releases) but code is small and readable. Fallback: vendor the ~500 lines. |
| SymSpell memory in 50MB extension | MEDIUM | No published iOS benchmarks. 30K-word dict with prefix=7 and editDistance=2 should be ~3-5MB based on algorithm analysis. Must profile on device. |
| Custom n-gram feasibility | HIGH | Dictionary-based bigram/trigram lookup is a well-understood data structure. Pruned to 30K vocab, file size stays 2-3MB. Many production keyboard apps use this approach. |
| French corpus availability | HIGH | Multiple open-source French frequency lists available (Lexique 3.83, OpenSubtitles, Wiktionary). All verified to exist. |
| Cold start auto-return via sourceApplication | LOW | No confirmation that `sourceApplication` returns the host app (not the keyboard extension bundle ID). Requires on-device testing before committing to this approach. Apple DTS explicitly says no public API exists for auto-return. |
| Autocorrect bug fix | HIGH | Root cause identified from code analysis (lastAutocorrect not cleared after new input). One-line fix. |
| License updates | HIGH | Pure text changes, no technical risk. |

---

## Sources

### Primary (HIGH confidence)
- [SymSpell algorithm (wolfgarbe)](https://github.com/wolfgarbe/SymSpell) -- original algorithm, memory optimization docs
- [SymSpellSwift (gdetari)](https://github.com/gdetari/SymSpellSwift) -- Swift port, v0.1.4, MIT license
- [SymSpellSwift on Swift Package Index](https://swiftpackageindex.com/gdetari/SymSpellSwift) -- version verification
- [Apple DTS on keyboard auto-return](https://developer.apple.com/forums/thread/118709) -- "No API for this"
- Codebase analysis: TextPredictionEngine.swift, SuggestionState.swift, FrequencyDictionary.swift, KnownAppSchemes.swift
- `assets/reference/issue-23-report.md` -- comprehensive cold start auto-return research

### Secondary (MEDIUM confidence)
- [KenLM](https://github.com/kpu/kenlm) -- evaluated and rejected for iOS
- [edugp/kenlm on HuggingFace](https://huggingface.co/edugp/kenlm) -- pre-built French models (too large for mobile)
- [KeyboardKit iOS 26.4 hostApplicationBundleId bug](https://keyboardkit.com/blog/2026/03/02/ios-26-4-host-application-bundle-id-bug) -- confirms private API broken
- [Wiktionary French frequency lists](https://en.wiktionary.org/wiki/Wiktionary:Frequency_lists/French) -- corpus source option
- [Lexique 3.83](http://www.lexique.org/) -- French psycholinguistic database with word frequencies

### Tertiary (LOW confidence)
- [N-gram language model overview (Stanford)](https://web.stanford.edu/~jurafsky/slp3/3.pdf) -- textbook reference for n-gram architecture
- [SymSpell memory optimization (GitHub issue #16)](https://github.com/wolfgarbe/SymSpell/issues/16) -- prefix length optimization discussion
