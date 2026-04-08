---
phase: 24-symspell-spell-correction
plan: 02
subsystem: text-prediction
tags: [symspell, autocorrect, suggestion-bar, user-dictionary, memory-optimization]

requires:
  - phase: 24-symspell-spell-correction
    plan: 01
    provides: SymSpellEngine wrapper, FR/EN frequency dictionaries
provides:
  - SymSpell wired into prediction pipeline with autocorrect on space
  - Standard mobile suggestion bar (original | bold correction | alternative)
  - User dictionary learning (repetition + rejection, threshold=2)
  - Memory-optimized SymSpell (10K words, edit distance 1, async loading)
---

## Summary

Wired SymSpellEngine into the keyboard prediction pipeline with autocorrect-on-space, standard mobile suggestion bar layout, user dictionary learning, and memory optimizations to stay within iOS keyboard extension limits.

## Key Changes

### Pipeline Integration
- SymSpell replaces UITextChecker for spell corrections (completions still use UITextChecker)
- Autocorrect fires on space: replaces misspelled word with correction + stores undo state
- Autocorrect rejection: backspace after correction restores original, space doesn't re-correct

### Suggestion Bar Sync
- Bar shows SymSpell correction in center bold slot (matches what space will do)
- Original word shown in quotes (index 0) — tapping keeps as-is + rejects correction
- Correction mode: [\"original\" | **correction** | alternative]
- Completion mode: UITextChecker completions ranked by frequency

### French Safeguards
- "ca" → "ça" hardcoded (never a valid French word)
- Apostrophe handling: "qu'il" → checks "il" only, not whole contraction
- French overrides work even before dictionary finishes loading

### User Dictionary Learning
- **Rejection learning**: backspace after autocorrect counts as usage signal (threshold=2)
- **Repetition learning**: unknown word typed 2 times → learned permanently
- Storage: App Group UserDefaults (shared app + keyboard), capped at 1000 words
- Learned words injected into SymSpell at moderate frequency (15000)
- Mid-session injection: learned words take effect immediately
- Least-used words evicted when cap reached

### Memory Optimizations
- Async dictionary loading (prevents main thread blocking on keyboard init)
- Edit distance 2→1 (~4x fewer delete entries, catches 80%+ of real typos)
- Dictionary trimmed from 40K to 10K most frequent words
- FrequencyDictionary also trimmed to 10K words
- Old dictionary freed before loading new on language switch
- **Measured: 29 MiB (FR), 41 MiB (after EN switch), 58 MiB transient peak during recording**

## Commits

| Commit | Description |
|--------|-------------|
| 77922e0 | Wire SymSpell into prediction pipeline with autocorrect rejection |
| 55fc429 | Async SymSpell loading, French safeguards, suggestion bar sync |
| 2dad6c1 | Re-enable spell correction for short words |
| 69c885c | Add user dictionary learning (rejection + repetition) |
| 50cb8a4 | Use repetition-based learning for rejection too |
| 988cdad | Moderate user word frequency and cap dictionary size |
| 854035a | Increase user dictionary cap to 1000 words |
| 385e603 | Reduce SymSpell memory — editDistance 2→1, top 20K, free old on switch |
| 99b7777 | Reduce further — 10K words + trim FrequencyDictionary |

## Deviations

- **User dictionary** added beyond original plan scope — Pierre requested it during checkpoint
- **Memory optimizations** required multiple iterations based on Instruments measurements
- **Edit distance reduced to 1** (from standard 2) due to SymSpell memory constraints — Phase 25 will migrate to AOSP-style compressed trie for proper edit distance 2 support

## Self-Check: PASSED

key-files:
  created:
    - DictusCore/Sources/DictusCore/UserDictionary.swift
  modified:
    - DictusKeyboard/TextPrediction/SymSpellEngine.swift
    - DictusKeyboard/TextPrediction/TextPredictionEngine.swift
    - DictusKeyboard/TextPrediction/SuggestionState.swift
    - DictusKeyboard/Views/SuggestionBarView.swift
    - DictusKeyboard/DictusKeyboardBridge.swift
    - DictusKeyboard/KeyboardRootView.swift
    - DictusCore/Sources/DictusCore/FrequencyDictionary.swift
