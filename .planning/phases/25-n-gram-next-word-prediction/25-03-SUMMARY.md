---
phase: 25-n-gram-next-word-prediction
plan: 03
subsystem: text-prediction
tags: [ngram, context-boost, spell-correction, bigram-reranking, edit-distance, device-verification]

requires:
  - phase: 25-n-gram-next-word-prediction (plan 02)
    provides: ObjC++ bridge bigramScore, Swift AOSPTrieEngine.predictNextWords/bigramScore, SuggestionState .predictions mode
provides:
  - Context-boosted spell corrections using n-gram bigram scores
  - Prediction-based correction discovery (edit distance 1 from n-gram predictions)
  - Short-word safety guard (3+ chars required for context boost)
  - Levenshtein edit distance utility in TextPredictionEngine
  - Device-verified complete n-gram prediction system (PRED-04, PRED-05, PRED-06)
affects: [prediction-engine, keyboard-extension, spell-correction]

tech-stack:
  added: []
  patterns: [prediction-based correction discovery, bigram reranking of spell candidates, edit-distance-1 guard for context boost]

key-files:
  created: []
  modified:
    - DictusKeyboard/TextPrediction/TextPredictionEngine.swift
    - DictusKeyboard/TextPrediction/SuggestionState.swift
    - DictusKeyboard/DictusKeyboardBridge.swift
    - DictusKeyboard/TextPrediction/AOSPTrieEngine.swift
    - DictusKeyboard/Vendored/AOSPTrie/bridge/AOSPTrieBridge.h
    - DictusKeyboard/Vendored/AOSPTrie/bridge/AOSPTrieBridge.mm
    - DictusApp/DictusApp.swift
    - DictusKeyboard/Resources/fr_ngrams.dict
    - DictusKeyboard/Resources/en_ngrams.dict
    - tools/ngram_builder.py

key-decisions:
  - "Prediction-based context boost: query n-gram predictions then check edit distance to typed word, instead of relying solely on reranking existing corrections"
  - "Edit distance exactly 1 guard: distance 2 is too permissive, causing false corrections like suis->vais"
  - "Short-word exclusion: words < 3 chars skip context boost to prevent false corrections on a/un/le"
  - "Combined OpenSubtitles + Google Books n-gram data for better spoken French coverage"

patterns-established:
  - "Context-boost two-strategy approach: (1) rerank existing corrections by bigram score, (2) discover new candidates from n-gram predictions within edit distance 1"
  - "Short-word safety: skip context-aware correction for words under 3 characters to avoid high false-positive rate"

requirements-completed: [PRED-04, PRED-05, PRED-06]

duration: 78min
completed: 2026-04-05
---

# Phase 25 Plan 03: Context-Boosted Corrections & Device Verification Summary

**N-gram context-boosted spell corrections with prediction-based candidate discovery, plus full device verification of the complete prediction pipeline (predictions, chaining, performance, memory)**

## Performance

- **Duration:** 78 min (including device verification)
- **Started:** 2026-04-05T15:04:29Z
- **Completed:** 2026-04-05T16:22:00Z
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint)
- **Files modified:** 10

## Accomplishments
- Context-boosted spell corrections: "je sui" now correctly boosts "suis" to top correction via bigram "je suis" score
- Two-strategy approach: rerank existing corrections by bigram score AND discover new candidates from n-gram predictions within edit distance 1
- Short-word safety guard prevents false corrections on common short words (a, un, le)
- Full prediction system verified on physical iOS device: predictions after space, tap chaining, performance (no lag), memory budget

## Task Commits

Each task was committed atomically:

1. **Task 1: N-gram context-boosted spell correction scoring** - `93a5ac1` (feat)
2. **Task 2: Device verification** - human-verify checkpoint, approved

**Post-checkpoint fixes by orchestrator:**
- `ef885e5` feat(25): combine OpenSubtitles + Google Books for n-gram data
- `89d4dfe` fix(25): prevent prediction race condition clearing suggestion bar
- `570cc1e` fix(25): trigger n-gram predictions after autocorrection
- `0f0626e` fix(25): context-boost corrections for valid-but-rare words (nearbyWords approach)
- `7277477` fix(25): use prediction-based context boost instead of nearbyWords
- `898f6df` fix(25): tighten context-boost to prevent false corrections

## Files Created/Modified
- `TextPredictionEngine.swift` - Context-aware spellCheck with bigram reranking + prediction-based candidate discovery + Levenshtein edit distance
- `SuggestionState.swift` - extractPreviousWord helper, passes previousWord context to spellCheck in update/updateAsync, context-aware performSpellCheck overload
- `DictusKeyboardBridge.swift` - handleSpace extracts previousWord from proxy context, passes to performSpellCheck for n-gram boosted autocorrect
- `AOSPTrieEngine.swift` - Additional n-gram bridge methods for prediction-based correction
- `AOSPTrieBridge.h/.mm` - Bridge methods for prediction-based correction queries
- `DictusApp.swift` - Minor adjustments for n-gram loading
- `fr_ngrams.dict` - Updated French n-gram binary (combined OpenSubtitles + Google Books)
- `en_ngrams.dict` - Updated English n-gram binary (combined sources)
- `ngram_builder.py` - OpenSubtitles integration for spoken French n-gram data

## Decisions Made
- **Prediction-based context boost**: Instead of only reranking existing spell corrections, also query the n-gram model for predictions and check if any are close (edit distance 1) to the typed word. This catches cases where the trie spell checker does not produce the contextually correct word as a candidate at all.
- **Edit distance 1 only**: Distance 2 was too permissive, causing false corrections (e.g., "suis" corrected to "vais"). Tightened to exactly distance 1.
- **Short-word exclusion (3+ chars)**: Words under 3 characters have too many neighbors at distance 1, causing false corrections like "a" to "la". These are excluded from context boost entirely.
- **Combined n-gram sources**: OpenSubtitles (spoken French) + Google Books (written French) for better coverage of conversational bigrams.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] False corrections on short words (a, un, le)**
- **Found during:** Device verification (Task 2)
- **Issue:** Context boost at edit distance 1-2 caused short valid words like "a" to be falsely corrected to "la" or other neighbors
- **Fix:** Added minimum word length check (3+ chars) to skip context boost for short words
- **Files modified:** TextPredictionEngine.swift
- **Committed in:** 898f6df

**2. [Rule 1 - Bug] Prediction race condition clearing suggestion bar**
- **Found during:** Device verification (Task 2)
- **Issue:** updateAsync could race with updatePredictions, clearing the prediction bar immediately after space
- **Fix:** Guard against clearing when mode is .predictions
- **Files modified:** SuggestionState.swift
- **Committed in:** 89d4dfe

**3. [Rule 1 - Bug] Missing predictions after autocorrection**
- **Found during:** Device verification (Task 2)
- **Issue:** After autocorrect replaced a word on space, predictions were not triggered for the corrected context
- **Fix:** Added updatePredictions call after autocorrection in handleSpace
- **Files modified:** DictusKeyboardBridge.swift
- **Committed in:** 570cc1e

**4. [Rule 1 - Bug] Context boost too permissive with edit distance 2**
- **Found during:** Device verification (Task 2)
- **Issue:** Edit distance 2 caused false corrections (suis->vais)
- **Fix:** Tightened to edit distance exactly 1
- **Files modified:** TextPredictionEngine.swift
- **Committed in:** 898f6df

---

**Total deviations:** 4 auto-fixed (4 bugs found during device testing)
**Impact on plan:** All fixes necessary for correct spell correction behavior. No scope creep -- all within the context-boost feature scope.

## Issues Encountered
None beyond the auto-fixed deviations above. All issues were discovered and resolved during device verification.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 25 (N-gram Next-Word Prediction) is now COMPLETE
- All PRED requirements verified on device: PRED-04 (predictions), PRED-05 (performance), PRED-06 (memory)
- Phase 26 (Cold Start & Beta Polish) can proceed

## Self-Check: PASSED

All files exist, all commits verified, all content checks pass.

---
*Phase: 25-n-gram-next-word-prediction*
*Completed: 2026-04-05*
