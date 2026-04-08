# Phase 25: N-gram Next-Word Prediction - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Build n-gram (bigram + trigram) next-word prediction into the keyboard. After completing a word and pressing space, the suggestion bar shows 3 predicted next words based on previous context. Tapping a prediction inserts it and chains to new predictions. N-gram context also boosts spell correction ranking and resolves accent disambiguation (ou/ou, a/a, sur/sur). Data pipeline produces binary n-gram files from open-source corpora. All prediction stays under 10ms/keystroke and 20MB/language total.

Requirements: PRED-04, PRED-05, PRED-06

</domain>

<decisions>
## Implementation Decisions

### Corpus & data source
- **Claude's Discretion** for corpus selection — choose the best open-source n-gram dataset available for French and English
- Priority: leverage pre-built n-gram frequency datasets rather than processing raw corpus text
- Both French and English n-gram data shipped in this phase (same pipeline)
- Phase 24 used 70% film subtitles + 30% books for word frequencies — use similar spoken-language-biased sources if building from scratch

### Suggestion bar behavior
- **After space:** Bar shows 3 predicted next words (new `.predictions` mode in SuggestionMode enum)
- **While typing:** Bar switches back to completions/corrections (existing behavior)
- **Chaining:** Tapping a prediction inserts word + trailing space, bar refreshes with new predictions based on updated context
- **Fallback:** When no n-gram match exists (start of text, rare context), show top 3 most frequent words from FrequencyDictionary
- Standard mobile behavior matching Gboard and iOS native keyboard

### N-gram scope & memory
- **Bigrams + trigrams** — both included for quality chaining ("je" -> "suis", "je suis" -> "en")
- **Quality first, tunable down** — include as many n-grams as fit within budget. Pipeline has configurable frequency threshold to reduce data size if memory exceeds budget
- **Extend Phase 24.1 AOSP C++ trie infrastructure** — add n-gram lookup to existing C++ engine + ObjC++ bridge. The real AOSP LatinIME stores bigrams/trigrams in its trie. Reuses mmap, binary format, and proven bridge pattern. One engine for everything.
- Memory budget: 20MB total per language (PRED-06). AOSP trie spell correction uses ~0.4 MiB. Remaining ~19 MiB available for n-gram data.
- mmap approach: OS pages in only accessed data, working set much smaller than file size

### Context-aware corrections
- **N-gram context boosts spell correction ranking** — "je sui" -> "suis" ranked higher because "je suis" is a very frequent bigram. Big quality improvement for French.
- **Accent disambiguation via n-gram context** — resolves ou/ou, a/a, sur/sur ambiguity using trigram/bigram frequency. Deferred from Phase 24, now in scope.
- **Scoring strategy: Claude's Discretion** — follow AOSP LatinIME / HeliBoard open-source keyboard approach for how to blend word frequency + n-gram context. Standard, not exotic.

### Claude's Discretion
- Corpus selection and data sourcing (best available open-source n-gram data)
- N-gram binary format specification (extend AOSP .dict or separate n-gram binary)
- Exact scoring/blending weights for frequency + n-gram context + proximity
- Python pipeline implementation for n-gram data processing
- C++ n-gram trie extension design and ObjC++ bridge additions
- Frequency threshold tuning for data size vs prediction quality
- How to pass previous word context to the engine efficiently

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Current prediction code (to extend)
- `DictusKeyboard/TextPrediction/TextPredictionEngine.swift` — Orchestrator with `suggestions()` and `spellCheck()`. Needs new `predict(afterWord:)` or similar method.
- `DictusKeyboard/TextPrediction/SuggestionState.swift` — Observable state with modes (idle/completions/corrections). Needs new `.predictions` mode and prediction trigger after space.
- `DictusKeyboard/TextPrediction/AOSPTrieEngine.swift` — C++ trie wrapper via ObjC++ bridge. Extend with n-gram lookup methods.
- `DictusKeyboard/Views/SuggestionBarView.swift` — 3-slot UI. May need minor styling for prediction mode (no bold center).

### AOSP C++ engine (to extend)
- `DictusKeyboard/Vendored/AOSPTrie/` — C++ trie reader, scorer, proximity maps. Extend with n-gram trie data structures and lookup.
- ObjC++ bridge files in same directory — add n-gram query methods to bridge.

### Keyboard bridge (integration point)
- `DictusKeyboard/DictusKeyboardBridge.swift` — handleSpace() triggers autocorrect. Needs to also trigger n-gram prediction after space. handleSuggestionTap() needs chaining logic.

### Frequency data (fallback source)
- `DictusCore/Sources/DictusCore/FrequencyDictionary.swift` — JSON frequency ranks. Used as fallback when no n-gram match.
- `DictusKeyboard/Resources/fr_frequency.json` — French frequency data (10K words).
- `DictusKeyboard/Resources/en_frequency.json` — English frequency data (10K words).

### Prior phase decisions
- `.planning/phases/24.1-replace-symspell-with-aosp-style-compressed-trie-c-with-swift-interop-for-spell-correction-100k-words-edit-distance-2-3-5-mib-memory-via-mmap-based-on-heliboard-aosp-latinime-engine/24.1-CONTEXT.md` — AOSP trie C++ architecture, ObjC++ bridge pattern, binary dict format, mmap strategy. Foundation to extend.
- `.planning/phases/24-symspell-spell-correction/24-CONTEXT.md` — Suggestion bar layout (verbatim/correction/alternative), autocorrect rejection, dictionary sourcing decisions.

### Requirements
- `.planning/REQUIREMENTS.md` — PRED-04 (3 predicted next words), PRED-05 (sub-10ms), PRED-06 (under 20MB total)

### AOSP reference (external)
- HeliBoard / AOSP LatinIME native C++ source — n-gram storage in binary dictionaries, bigram/trigram scoring, context-aware correction ranking. Apache 2.0 license.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AOSPTrieEngine` + C++ trie: mmap binary dictionary, proximity scoring, ObjC++ bridge. Core infrastructure to extend with n-gram support.
- `AOSPTrieBridge`: ObjC++ bridge class. Add n-gram query methods (predictNextWord, getNgramScore).
- `SuggestionState`: Async coalescing with DispatchWorkItem, cancellation. Reuse for prediction computation.
- `FrequencyDictionary`: Top 10K words by frequency — fallback source for predictions when no n-gram match.
- `TextPredictionEngine`: Clean separation of concerns. Add prediction method alongside existing `suggestions()` and `spellCheck()`.

### Established Patterns
- Binary .dict files with mmap loading (Phase 24.1) — same pattern for n-gram binary data
- ObjC++ bridging: pure ObjC header + .mm implementation (Phase 24.1) — extend existing bridge
- Background queue computation with main-thread publishing (SuggestionState pattern)
- One language in memory at a time, reload on `setLanguage()`
- Python offline build tools for binary data generation (Phase 24.1 dict-builder)
- Vendored C++ code in `DictusKeyboard/Vendored/AOSPTrie/`

### Integration Points
- `handleSpace()` in DictusKeyboardBridge: after autocorrect, trigger n-gram prediction
- `SuggestionState.update()` / `updateAsync()`: when cursor is after a space, query n-gram engine instead of UITextChecker
- Suggestion tap handler: for `.predictions` mode, insert word + space + trigger chained prediction
- `AOSPTrieEngine.spellCheck()`: pass previous word context for n-gram-boosted correction ranking
- `SuggestionMode` enum: add `.predictions` case

</code_context>

<specifics>
## Specific Ideas

- Reuse Phase 24.1 AOSP C++ trie infrastructure as much as possible — Pierre specifically noted the C++ engine should be leveraged for n-grams, not just spell correction
- "On veut faire du standard" — follow iOS/Gboard/AOSP LatinIME standard patterns. No exotic UX.
- "Utiliser un maximum de choses qui ont deja ete faites et notamment open source" — prefer pre-built n-gram datasets and follow established open-source keyboard patterns (HeliBoard/AOSP)
- Quality first but tunable: start with maximum n-gram coverage, configurable threshold to reduce if memory is exceeded on device testing

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 25-n-gram-next-word-prediction*
*Context gathered: 2026-04-03*
