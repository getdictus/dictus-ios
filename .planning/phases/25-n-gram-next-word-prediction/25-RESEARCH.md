# Phase 25: N-gram Next-Word Prediction - Research

**Researched:** 2026-04-03
**Domain:** N-gram language modeling, binary data structures, keyboard prediction UX
**Confidence:** MEDIUM-HIGH

## Summary

This phase adds bigram/trigram next-word prediction to the Dictus keyboard by extending the existing Phase 24.1 AOSP C++ trie infrastructure. After the user completes a word and presses space, the suggestion bar shows 3 predicted next words based on n-gram context. The core technical challenge is threefold: (1) sourcing and processing n-gram frequency data for French and English, (2) designing a compact binary format for n-gram lookup via mmap, and (3) integrating n-gram context into the existing spell correction scoring pipeline.

The existing AOSP trie infrastructure (C++ with ObjC++ bridge, mmap loading, proximity scoring) provides the foundation. The n-gram data will be stored in a separate binary file (not embedded in the spell-check trie) using a flat hash-map or sorted-array format optimized for two lookups: "given word W, return top-3 next words" (bigram) and "given words W1 W2, return top-3 next words" (trigram). The AOSP/HeliBoard .combined wordlist format stores bigrams inline with word entries, but Dictus already has a custom DTRI binary format -- extending with a separate n-gram binary is cleaner than adopting the AOSP binary dict format wholesale.

**Primary recommendation:** Build a separate `{lang}_ngrams.dict` binary file per language using a Python pipeline that processes OpenSubtitles + Google Books n-gram data. Use a simple sorted-array format with mmap for O(log n) lookup. Implement Stupid Backoff scoring for blending trigram > bigram > unigram. Keep the n-gram engine as a new C++ module in `Vendored/AOSPTrie/` with bridge methods added to `AOSPTrieBridge`.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Suggestion bar behavior:** After space shows 3 predicted next words (new `.predictions` mode). While typing switches back to completions/corrections. Tapping prediction inserts word + trailing space and chains. Fallback to top 3 most frequent words from FrequencyDictionary.
- **N-gram scope:** Bigrams + trigrams both included. Quality first, tunable down via configurable frequency threshold.
- **Extend Phase 24.1 AOSP C++ trie infrastructure:** Add n-gram lookup to existing C++ engine + ObjC++ bridge. Reuses mmap, binary format, and proven bridge pattern. One engine for everything.
- **Memory budget:** 20MB total per language (PRED-06). AOSP trie spell correction uses ~0.4 MiB. Remaining ~19 MiB available for n-gram data.
- **Context-aware corrections:** N-gram context boosts spell correction ranking. Accent disambiguation via n-gram context (ou/ou, a/a, sur/sur).
- **Both French and English** n-gram data shipped in this phase.
- **Standard mobile UX:** Match Gboard and iOS native keyboard behavior.

### Claude's Discretion
- Corpus selection and data sourcing (best available open-source n-gram data)
- N-gram binary format specification (extend AOSP .dict or separate n-gram binary)
- Exact scoring/blending weights for frequency + n-gram context + proximity
- Python pipeline implementation for n-gram data processing
- C++ n-gram trie extension design and ObjC++ bridge additions
- Frequency threshold tuning for data size vs prediction quality
- How to pass previous word context to the engine efficiently

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PRED-04 | N-gram next-word prediction suggests top 3 words based on previous context (bigram/trigram) | N-gram data sourcing, binary format design, Stupid Backoff scoring, SuggestionMode.predictions integration |
| PRED-05 | Prediction engine stays under 10ms per keystroke with no typing fluidity regression | mmap with O(log n) binary search on sorted arrays; working set fits in cache; async computation on background queue |
| PRED-06 | Total prediction memory (dictionaries + models) stays under 20MB per language | Current spell-check dict ~0.4 MiB + frequency JSON ~0.7 MiB = ~1.1 MiB. Leaves ~18.9 MiB for n-gram binary. Size estimates below. |

</phase_requirements>

## Standard Stack

### Core
| Component | Details | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| C++ n-gram module | New files in `Vendored/AOSPTrie/` | N-gram storage and lookup | Extends proven Phase 24.1 infrastructure |
| ObjC++ bridge | Extend `AOSPTrieBridge.h/.mm` | Expose n-gram queries to Swift | Same pattern as spell-check bridge |
| Python pipeline | New `tools/ngram_builder.py` | Process corpus data into binary | Same pattern as `tools/dict_builder.py` |
| Binary .dict format | Custom sorted-array with mmap | O(log n) n-gram lookup | Proven mmap pattern from Phase 24.1 |

### Data Sources
| Source | Language | Type | License | Why |
|--------|----------|------|---------|-----|
| OpenSubtitles 2018 (OPUS) | FR + EN | Raw corpus for n-gram extraction | Open/free | Spoken language bias (matches Phase 24 philosophy: 70% subtitles) |
| Google Books Ngram v3 | FR + EN | Pre-computed n-gram frequencies | Public domain | Written language supplement; pre-computed saves processing time |
| HeliBoard aosp-dictionaries | FR + EN | .combined wordlists with bigrams | Apache 2.0 | Pre-curated bigram data for AOSP keyboards; can bootstrap pipeline |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom binary format | AOSP binary dict format | AOSP format bundles unigrams+bigrams together; Dictus already has separate spell-check trie; separate n-gram file is cleaner |
| OpenSubtitles corpus processing | Google Books n-grams only | Google Books is written language, less natural for keyboard; OpenSubtitles has spoken-language patterns |
| Stupid Backoff | Katz Backoff / Kneser-Ney | Stupid Backoff is simpler (one constant lambda=0.4), comparable quality on large data, much faster, no need for true probabilities |

## Architecture Patterns

### Recommended Project Structure
```
DictusKeyboard/
  Vendored/AOSPTrie/
    include/
      dictus_ngram.h          # NEW: n-gram lookup API
      dictus_ngram_format.h   # NEW: binary format constants
    src/
      dictus_ngram.cpp        # NEW: n-gram engine (mmap, lookup, scoring)
    bridge/
      AOSPTrieBridge.h        # EXTEND: add n-gram methods
      AOSPTrieBridge.mm       # EXTEND: implement n-gram bridge
  TextPrediction/
    AOSPTrieEngine.swift      # EXTEND: add predictNextWords() method
    SuggestionState.swift     # EXTEND: add .predictions mode, prediction trigger
    TextPredictionEngine.swift # EXTEND: add prediction method, context-boosted spellCheck
  Resources/
    fr_ngrams.dict            # NEW: French n-gram binary (~5-15 MiB)
    en_ngrams.dict            # NEW: English n-gram binary (~5-15 MiB)
tools/
  ngram_builder.py            # NEW: Python pipeline for n-gram binary generation
```

### Pattern 1: Separate N-gram Binary File
**What:** N-gram data lives in its own `{lang}_ngrams.dict` file, separate from the spell-check trie `{lang}_spellcheck.dict`.
**When to use:** When n-gram data has different structure than word-level trie data.
**Why:** The spell-check trie is a patricia trie optimized for edit-distance traversal. N-gram lookup is fundamentally different: given a key (word or word-pair), return top-N next words with scores. A sorted array or hash map is more appropriate than a trie for this access pattern.

### Pattern 2: Sorted Array with Binary Search (N-gram Lookup)
**What:** N-gram entries stored as sorted arrays by key hash, with mmap for zero-copy access.
**Why:** O(log n) lookup via binary search on mmap'd data. No dynamic allocation. CPU cache friendly for sequential scanning of results.

**Binary format design:**

```
Header (32 bytes):
  magic[4]: "NGRM"
  version: uint16
  flags: uint16
  bigram_count: uint32
  trigram_count: uint32
  bigram_offset: uint32   // absolute offset to bigram section
  trigram_offset: uint32   // absolute offset to trigram section
  reserved[8]

Bigram Section (sorted by key_hash):
  For each bigram entry (variable length):
    key_hash: uint32      // hash of previous word (lowercased)
    result_count: uint8   // number of predicted next words (max 8)
    For each result:
      word_offset: uint16 // offset into string table
      score: uint16       // normalized frequency (0-65535)

Trigram Section (sorted by key_hash):
  For each trigram entry (variable length):
    key_hash: uint32      // hash of word pair "w1\0w2" (lowercased)
    result_count: uint8
    For each result:
      word_offset: uint16
      score: uint16

String Table:
  Packed null-terminated UTF-8 strings (all predicted words)
```

**Size estimate for French:**
- 50K bigram entries x ~25 bytes avg = ~1.2 MiB
- 50K trigram entries x ~25 bytes avg = ~1.2 MiB
- String table for ~30K unique predicted words x ~10 bytes avg = ~300 KB
- Total: ~2.7 MiB per language (well within 19 MiB budget)
- With 200K bigrams + 100K trigrams (quality-first): ~7.5 MiB per language (still within budget)

### Pattern 3: Stupid Backoff Scoring
**What:** Cascading n-gram lookup: try trigram first, fall back to bigram, fall back to unigram frequency.
**When to use:** For all next-word predictions and context-boosted corrections.
**Implementation:**

```
score(w3 | w1, w2):
  if trigram(w1, w2) has w3:
    return trigram_score(w1, w2, w3)
  if bigram(w2) has w3:
    return 0.4 * bigram_score(w2, w3)    // lambda = 0.4
  return 0.4 * 0.4 * unigram_score(w3)   // double backoff
```

The constant 0.4 is the standard Stupid Backoff discount factor (Brants et al., 2007). No smoothing needed because we only need relative ranking, not true probabilities.

### Pattern 4: Context Passing for N-gram Boosted Corrections
**What:** Pass previous 1-2 words alongside the current misspelled word to boost correction ranking.
**Example:** "je sui" -- "sui" is misspelled. Bigram "je suis" has very high frequency. The correction "suis" gets a boost from n-gram context, ranking it above "sui" (a word in some dictionaries).
**Implementation:** Scorer.correct() receives optional previous words. For each candidate correction, multiply the edit-distance score by the n-gram score of (context + candidate). This is the AOSP LatinIME approach.

### Anti-Patterns to Avoid
- **Embedding bigrams in the spell-check trie:** The trie is optimized for edit-distance traversal, not key-value lookup. Mixing concerns makes both slower.
- **Loading all n-gram data into Swift dictionaries:** Swift Dictionary overhead is ~80 bytes/entry. 200K bigrams = 16 MiB in Swift vs ~5 MiB in binary. Plus allocation time.
- **Computing n-grams at runtime from raw text:** Must be pre-computed offline. Runtime extraction from corpus would take seconds.
- **Using word strings as keys:** Hash the keys to uint32 for compact binary storage. FNV-1a or similar fast hash. Collisions are acceptable at keyboard suggestion quality level.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| N-gram corpus processing | Custom tokenizer from scratch | NLTK / spaCy for tokenization + custom pipeline for binary output | French tokenization has edge cases (l'homme, aujourd'hui, c'est) that NLP libraries handle correctly |
| Hash function | Custom hash | FNV-1a (32-bit) | Standard, fast, good distribution, trivial to implement in both Python and C++ (~10 lines) |
| French elision handling | Regex-based splitter | Standard NLP tokenizer + custom post-processing | French contractions (l', d', n', j', qu') need language-aware splitting |
| Backoff scoring | Complex probability model | Stupid Backoff (lambda=0.4) | Google proved comparable to Kneser-Ney on large data, dramatically simpler |

**Key insight:** The hard part is data pipeline and binary format, not the prediction algorithm. Stupid Backoff is trivially simple. The engineering is in getting clean n-gram data, building compact binaries, and integrating with the existing bridge pattern.

## Common Pitfalls

### Pitfall 1: French Tokenization Elisions
**What goes wrong:** French contractions like "l'homme", "j'ai", "c'est", "qu'il" contain apostrophes that naive word splitting breaks on. If you split on apostrophe, "l'" and "homme" become separate tokens, destroying bigram context.
**Why it happens:** English-centric tokenizers treat apostrophe as word boundary.
**How to avoid:** In the n-gram pipeline, handle French elisions explicitly: keep "l'homme" as one token for frequency counting, but also generate bigrams for the expanded form. For prediction context, treat text after apostrophe as the "word" (matching existing AOSPTrieEngine behavior).
**Warning signs:** N-gram data has entries like ("l", "homme") instead of ("l'homme", ...) or missing common French bigrams.

### Pitfall 2: Hash Collisions in N-gram Keys
**What goes wrong:** Two different word pairs hash to the same uint32, returning wrong predictions.
**Why it happens:** 32-bit hash space (4B values) with 200K+ entries has low collision probability (~0.5% by birthday paradox), but it can happen.
**How to avoid:** Store the actual key string (or a portion) alongside the hash for verification. Or use 64-bit hashes. Alternatively, accept rare collisions -- wrong predictions are cosmetically bad but not functionally broken.
**Warning signs:** Prediction shows irrelevant words for common contexts.

### Pitfall 3: Memory Reporting vs. mmap Reality
**What goes wrong:** Measuring memory with Xcode Instruments shows the full file size as "mapped memory", scaring developers into thinking the budget is blown.
**Why it happens:** mmap maps the entire file into address space, but the OS only pages in accessed portions. Xcode shows virtual memory (mapped) separately from resident memory (paged in).
**How to avoid:** Measure resident memory (RSS), not virtual memory. Use `mach_task_basic_info` or Instruments "Real Memory Usage" for accurate measurement. The working set for n-gram lookup is typically <1 MiB even with a 15 MiB file.
**Warning signs:** Xcode memory gauge shows 20MB+ but the app runs fine without memory warnings.

### Pitfall 4: Suggestion Bar State Machine Complexity
**What goes wrong:** Adding `.predictions` mode to SuggestionMode creates new state transitions that conflict with existing `.completions`/`.corrections` logic, causing the bar to show wrong content or flicker.
**Why it happens:** The current flow is: typing chars -> completions/corrections, space -> idle. Adding predictions after space means: space -> predictions, then typing -> completions/corrections. The transition from predictions to typing needs careful handling.
**How to avoid:** Clear state machine: `space pressed -> clear bar -> compute predictions -> show predictions`. `any char typed -> cancel predictions -> compute completions/corrections`. `prediction tapped -> insert + space -> compute new predictions (chain)`.
**Warning signs:** Bar shows stale predictions while typing, or flickers between predictions and completions.

### Pitfall 5: Prediction Chaining Loop
**What goes wrong:** Tapping a prediction inserts word + space, which triggers handleSpace(), which triggers autocorrect, which replaces the just-inserted prediction.
**Why it happens:** handleSpace() does autocorrect before inserting space. If prediction tap goes through the same path, autocorrect may "correct" the predicted word.
**How to avoid:** Prediction tap must bypass autocorrect. Insert the predicted word directly, then trigger prediction update -- do NOT go through handleSpace(). Use a separate code path: `insertPrediction(word) -> proxy.insertText(word + " ") -> triggerPredictionUpdate()`.
**Warning signs:** Tapping "suis" after "je" inserts something different.

## Code Examples

### Extending AOSPTrieBridge.h (ObjC header)
```objc
// Add to AOSPTrieBridge.h

/// Load n-gram binary file for the given language.
- (BOOL)loadNgramsAtPath:(NSString *)path;

/// Unload n-gram data.
- (void)unloadNgrams;

/// Predict top-N next words given one previous word (bigram lookup).
/// Returns array of NSString, sorted by score descending.
- (NSArray<NSString *> *)predictAfterWord:(NSString *)word maxResults:(NSUInteger)max;

/// Predict top-N next words given two previous words (trigram + bigram backoff).
/// Returns array of NSString, sorted by score descending.
- (NSArray<NSString *> *)predictAfterWord1:(NSString *)word1 word2:(NSString *)word2 maxResults:(NSUInteger)max;

/// Get n-gram score for a specific word following context (for correction boosting).
/// Returns 0.0 if no n-gram match found.
- (float)ngramScoreForWord:(NSString *)word afterWord:(NSString *)prevWord;
```

### SuggestionMode Extension
```swift
// Extend SuggestionMode in SuggestionState.swift
enum SuggestionMode {
    case idle
    case completions
    case corrections
    case predictions  // NEW: after space, showing n-gram predicted next words
}
```

### Prediction Trigger in handleSpace()
```swift
// In DictusKeyboardBridge.swift, after existing handleSpace() logic:

// After space insertion and autocorrect, trigger n-gram prediction
let context = controller?.textDocumentProxy.documentContextBeforeInput
suggestionState?.updatePredictions(context: context)
```

### Prediction Update in SuggestionState
```swift
// New method in SuggestionState.swift
func updatePredictions(context: String?) {
    guard let context = context, !context.isEmpty else {
        clear()
        return
    }
    
    // Extract last 1-2 words for n-gram context
    let words = extractLastWords(from: context, count: 2)
    guard !words.isEmpty else {
        clear()
        return
    }
    
    // Cancel any in-flight work
    currentSuggestionWork?.cancel()
    
    let work = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        
        let predictions = self.engine.predictNextWords(after: words)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard !(self.currentSuggestionWork?.isCancelled ?? true) else { return }
            
            if predictions.isEmpty {
                // Fallback: top 3 most frequent words
                self.suggestions = self.engine.topFrequentWords(count: 3)
            } else {
                self.suggestions = Array(predictions.prefix(3))
            }
            self.mode = .predictions
        }
    }
    
    currentSuggestionWork = work
    suggestionQueue.async(execute: work)
}
```

### Prediction Tap Handler (separate from regular suggestion tap)
```swift
// In keyboard bridge or suggestion tap handler:
func handlePredictionTap(word: String) {
    // Insert predicted word + trailing space (bypass autocorrect)
    controller?.textDocumentProxy.insertText(word + " ")
    lastInsertedCharacter = " "
    
    // Chain: trigger new predictions based on updated context
    let context = controller?.textDocumentProxy.documentContextBeforeInput
    suggestionState?.updatePredictions(context: context)
    
    updateCapitalization()
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Katz Backoff / Kneser-Ney smoothing | Stupid Backoff (lambda=0.4) | 2007 (Google) | 10x simpler, comparable quality on large data, no need for true probabilities |
| KenLM (C++ ARPA n-gram) | Custom compact binary + mmap | N/A (KenLM rejected in REQUIREMENTS.md) | KenLM is LGPL, 50-500MB models, C++ complexity. Custom binary fits in <15 MiB |
| AOSP combined dict (unigrams + bigrams in one file) | Separate spell-check trie + n-gram binary | Dictus architecture decision | Cleaner separation, independent optimization, reuses existing DTRI format for spell-check |

**Deprecated/outdated:**
- KenLM: Explicitly out of scope per REQUIREMENTS.md (LGPL, too large for 50MB keyboard extension)
- Neural/ML prediction models: Explicitly out of scope (too large for keyboard extension memory)
- SymSpell: Removed in Phase 24.1, replaced by AOSP trie

## Data Pipeline Design

### Source Data Strategy

**Recommended approach:** Blend multiple sources for quality, biased toward spoken language.

1. **HeliBoard aosp-dictionaries** (Apache 2.0): Pre-curated .combined wordlists with bigram entries for French and English. These provide a strong baseline of manually curated bigrams that keyboard experts have validated. Use as primary bigram source.

2. **OpenSubtitles 2018** (OPUS, open): French and English monolingual subtitle text. Process into bigram/trigram frequency counts. Spoken-language bias matches the Phase 24 philosophy (70% subtitles + 30% books).

3. **Google Books Ngram v3** (public domain): Pre-computed n-gram frequencies via `orgtre/google-books-ngram-frequency` GitHub repo. CSV format with frequency counts. Use as supplement for written-language coverage. The repo provides top 5,000 bigrams and top 3,000 trigrams per language -- a good starting point.

### Pipeline Steps

```
1. Download HeliBoard .combined files (FR/EN) -- extract bigram entries
2. Download Google Books 2grams_french.csv, 3grams_french.csv (+ english)
3. Optionally: download OpenSubtitles FR/EN mono, tokenize, count n-grams
4. Merge all sources with weighted blending (subtitle bias)
5. Normalize frequencies to 0-65535 range (log scale, matching dict_builder.py)
6. Apply frequency threshold (configurable) to control output size
7. Sort by key hash for binary search
8. Serialize to NGRM binary format
9. Output: fr_ngrams.dict, en_ngrams.dict
```

### Size Budget Calculation

| Component | French | English |
|-----------|--------|---------|
| Spellcheck trie (.dict) | 0.4 MiB | 0.4 MiB |
| Frequency JSON | 0.6 MiB | 0.7 MiB |
| **N-gram binary (target)** | **5-15 MiB** | **5-15 MiB** |
| **Total per language** | **6-16 MiB** | **6-16 MiB** |
| Budget | 20 MiB | 20 MiB |

With the configurable frequency threshold, start with maximum coverage (quality first), then tune down if file size exceeds ~15 MiB on device testing.

## Context-Aware Correction Boosting

### How It Works

When spell-checking "sui" with previous context "je":
1. AOSPTrieEngine.spellCheck() finds candidates: ["suis", "sui", "six", ...]
2. For each candidate, query n-gram score: ngramScore("suis", afterWord: "je") -> HIGH
3. Blend: `final_score = edit_distance_score * (1 + ngram_boost_factor * ngram_score)`
4. "suis" gets massive boost from bigram "je suis", wins decisively

### Accent Disambiguation

For "ou" after "bien": bigram "bien ou" (conjunction "or") vs "bien ou" (where) -- context resolves the accent. The n-gram engine returns the score for both accented and unaccented forms, and the highest-scoring form wins.

Implementation: In the Scorer::correct() method, when evaluating accent substitutions, also check the n-gram score of (previous_word, candidate). High n-gram score = boost the accent variant.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode) + manual device testing |
| Config file | Dictus.xcodeproj (no separate test config) |
| Quick run command | `xcodebuild test -project Dictus.xcodeproj -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DictusCoreTests` |
| Full suite command | Manual device testing (keyboard extension cannot be unit-tested in simulator for proxy interactions) |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PRED-04 | 3 predicted next words after space | manual + unit | Python pipeline unit tests + device verification | No -- Wave 0 |
| PRED-05 | Sub-10ms per keystroke | manual | Device profiling with Instruments Time Profiler | No -- manual |
| PRED-06 | Under 20MB total per language | manual | `ls -la *.dict *.json` + device memory profiling | No -- manual |

### Sampling Rate
- **Per task commit:** Build succeeds (`xcodebuild build -scheme DictusKeyboard`)
- **Per wave merge:** Device testing on physical iPhone
- **Phase gate:** All 3 PRED requirements verified on device before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tools/test_ngram_builder.py` -- unit tests for n-gram pipeline (frequency counting, binary serialization, round-trip verification)
- [ ] C++ unit tests for n-gram lookup (optional, manual verification via bridge is sufficient)
- [ ] Device testing checklist for PRED-04/05/06

## Open Questions

1. **Optimal n-gram count per language**
   - What we know: Budget allows 5-15 MiB. At ~25 bytes per entry, that's 200K-600K n-gram entries.
   - What's unclear: What's the quality threshold? Is 50K bigrams + 30K trigrams enough for good French predictions, or do we need 200K+?
   - Recommendation: Start with maximum data (quality first per CONTEXT.md decision). Pipeline has configurable threshold. Tune down based on device testing.

2. **HeliBoard French bigram quality**
   - What we know: HeliBoard has curated French dictionary with bigrams. Available on Codeberg. Apache 2.0 license.
   - What's unclear: How many bigrams are included? Are they comprehensive enough, or do we need to supplement from corpus processing?
   - Recommendation: Download and inspect the HeliBoard French .combined file first. If it has >10K bigrams, use as primary source. Supplement with Google Books n-grams for trigrams (HeliBoard likely only has bigrams).

3. **Hash collision handling**
   - What we know: 32-bit FNV-1a hash with 200K entries has ~0.5% collision probability.
   - What's unclear: Whether collisions cause noticeable quality degradation.
   - Recommendation: Use 32-bit hash for compactness. If collisions are problematic, switch to storing first 4 bytes of key string as verification. Cost: ~4 bytes per entry (~800 KB for 200K entries).

## Sources

### Primary (HIGH confidence)
- Existing codebase: `DictusKeyboard/Vendored/AOSPTrie/` -- C++ trie, ObjC++ bridge, mmap loading pattern
- Existing codebase: `tools/dict_builder.py` -- Python binary serialization pipeline
- Existing codebase: `DictusKeyboard/TextPrediction/` -- SuggestionState, TextPredictionEngine, AOSPTrieEngine
- Phase 24.1 CONTEXT.md -- AOSP architecture decisions, binary format, bridge pattern

### Secondary (MEDIUM confidence)
- [HeliBoard aosp-dictionaries](https://codeberg.org/Helium314/aosp-dictionaries) -- Pre-curated AOSP wordlists with bigrams, Apache 2.0
- [Google Books Ngram Frequency](https://github.com/orgtre/google-books-ngram-frequency) -- Pre-computed n-gram frequencies for French and English
- [AOSP DictionaryTool](https://github.com/remi0s/aosp-dictionary-tools) -- .combined format documentation and bigram syntax
- [OpenSubtitles 2018 (OPUS)](https://opus.nlpl.eu/legacy/OpenSubtitles-v2018.php) -- French and English monolingual subtitle corpus
- [Stupid Backoff (Brants et al. 2007)](https://serdioa.github.io/DataScienceCapstone/ImplementationReport.html) -- Scoring algorithm description and lambda=0.4 constant

### Tertiary (LOW confidence)
- N-gram binary size estimates: calculated from format design, not empirically verified. Need pipeline output to confirm.
- Hash collision rates: theoretical birthday paradox calculation. Need to verify with actual data.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- extends proven Phase 24.1 infrastructure with same patterns
- Architecture: MEDIUM-HIGH -- binary format design is sound but untested; sorted array + mmap is well-established technique
- Data sourcing: MEDIUM -- HeliBoard bigrams confirmed available, Google Books confirmed, OpenSubtitles confirmed; actual data quality/quantity needs inspection
- Pitfalls: HIGH -- based on direct codebase analysis of existing handleSpace(), SuggestionState, bridge patterns
- Scoring algorithm: HIGH -- Stupid Backoff is well-documented, trivially simple, standard choice

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (stable domain, no fast-moving dependencies)
