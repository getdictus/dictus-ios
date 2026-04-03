---
phase: 25-n-gram-next-word-prediction
plan: 02
subsystem: text-prediction
tags: [ngram, objcpp-bridge, swift-interop, suggestion-bar, mmap]

requires:
  - phase: 25-n-gram-next-word-prediction (plan 01)
    provides: C++ NgramEngine with mmap binary loading, NGRM format, fr/en n-gram binaries
provides:
  - ObjC++ bridge methods for n-gram prediction (load, predict, bigramScore)
  - Swift AOSPTrieEngine n-gram wrapper (predictNextWords, bigramScore)
  - SuggestionState .predictions mode with updatePredictions()
  - handlePredictionTap in DictusKeyboardBridge (bypasses autocorrect, chains predictions)
  - Full space-to-prediction-to-tap pipeline
affects: [25-03-context-boosted-corrections, prediction-ui, keyboard-bridge]

tech-stack:
  added: []
  patterns: [n-gram prediction pipeline, prediction tap chaining, frequency fallback]

key-files:
  created: []
  modified:
    - DictusKeyboard/Vendored/AOSPTrie/bridge/AOSPTrieBridge.h
    - DictusKeyboard/Vendored/AOSPTrie/bridge/AOSPTrieBridge.mm
    - DictusKeyboard/TextPrediction/AOSPTrieEngine.swift
    - DictusKeyboard/TextPrediction/TextPredictionEngine.swift
    - DictusKeyboard/TextPrediction/SuggestionState.swift
    - DictusKeyboard/DictusKeyboardBridge.swift
    - DictusKeyboard/KeyboardRootView.swift
    - DictusKeyboard/KeyboardViewController.swift
    - DictusKeyboard/Views/SuggestionBarView.swift
    - DictusCore/Sources/DictusCore/FrequencyDictionary.swift
    - Dictus.xcodeproj/project.pbxproj

key-decisions:
  - "Swift ObjC bridge renames predictAfterWord to predict(afterWord:) -- used Swift-generated names"
  - "Bridge reference passed to KeyboardRootView for prediction tap access"
  - "Frequency fallback: topWords(count:) filters words < 2 chars for useful predictions"
  - "N-grams auto-loaded after spellcheck dictionary on same serial queue"

patterns-established:
  - "Prediction tap chaining: handlePredictionTap -> insertText -> updatePredictions -> new bar"
  - "State machine: space -> .predictions, character -> .completions/.corrections, tap -> .predictions"

requirements-completed: [PRED-04, PRED-05]

duration: 6min
completed: 2026-04-03
---

# Phase 25 Plan 02: Swift Integration Summary

**N-gram prediction wired end-to-end: ObjC++ bridge, Swift wrapper, SuggestionState .predictions mode, handleSpace trigger, and prediction tap chaining with autocorrect bypass**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-03T13:09:16Z
- **Completed:** 2026-04-03T13:15:19Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- ObjC++ bridge extended with 6 n-gram methods (load, unload, loaded, predictAfterWord, predictAfterWord1, bigramScore)
- Full prediction pipeline: space press -> extractLastWords -> n-gram engine -> suggestion bar (.predictions mode)
- Prediction tap chaining: tapping a prediction inserts word + space and queries for the next prediction
- Prediction taps bypass autocorrect -- predicted words are inserted directly

## Task Commits

Each task was committed atomically:

1. **Task 1: ObjC++ bridge n-gram methods, Swift wrapper, and Xcode project config** - `cacda6e` (feat)
2. **Task 2: SuggestionState .predictions mode and keyboard bridge wiring** - `411583f` (feat)

## Files Created/Modified
- `AOSPTrieBridge.h` - Added loadNgramsAtPath, predictAfterWord, predictAfterWord1, bigramScoreForWord
- `AOSPTrieBridge.mm` - NgramEngine member, implemented all 6 n-gram bridge methods
- `AOSPTrieEngine.swift` - loadNgrams, predictNextWords, bigramScore, ngramsLoaded, auto-load after dict
- `TextPredictionEngine.swift` - predictNextWords with frequency fallback
- `FrequencyDictionary.swift` - topWords(count:) for fallback predictions
- `SuggestionState.swift` - .predictions case, updatePredictions(), extractLastWords()
- `DictusKeyboardBridge.swift` - handleSpace calls updatePredictions, handlePredictionTap method
- `KeyboardRootView.swift` - bridge property, .predictions handler in handleSuggestionTap
- `KeyboardViewController.swift` - Pass bridge to KeyboardRootView init
- `SuggestionBarView.swift` - Equal-weight styling for prediction mode (no bold center)
- `project.pbxproj` - dictus_ngram.cpp in Sources, headers in include, .dict binaries in Resources

## Decisions Made
- Swift ObjC bridge auto-renames `predictAfterWord:maxResults:` to `predict(afterWord:maxResults:)` -- used the Swift-generated selector names
- Added bridge reference to KeyboardRootView (was not passed before) so prediction taps can call handlePredictionTap
- FrequencyDictionary.topWords filters out single-letter words for better fallback quality
- N-grams load on the same serial loadQueue as the spellcheck dictionary (ordered, non-blocking)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift ObjC selector name mismatch**
- **Found during:** Task 1 (build verification)
- **Issue:** Plan used `bridge.predictAfterWord()` but Swift imports ObjC method as `bridge.predict(afterWord:)`
- **Fix:** Updated Swift calls to use the auto-generated selector names
- **Files modified:** AOSPTrieEngine.swift
- **Verification:** xcodebuild succeeds
- **Committed in:** cacda6e (Task 1 commit)

**2. [Rule 3 - Blocking] Bridge reference missing in KeyboardRootView**
- **Found during:** Task 2 (wiring prediction tap)
- **Issue:** KeyboardRootView had no access to DictusKeyboardBridge, needed for handlePredictionTap
- **Fix:** Added `bridge` property to KeyboardRootView, passed from KeyboardViewController
- **Files modified:** KeyboardRootView.swift, KeyboardViewController.swift
- **Verification:** xcodebuild succeeds, prediction tap path compiles
- **Committed in:** 411583f (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes necessary for correct compilation. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- N-gram prediction pipeline is fully wired from C++ engine to keyboard UI
- Plan 03 can now implement context-boosted corrections using bigramScore()
- State machine correctly transitions between predictions/completions/corrections modes

## Self-Check: PASSED

All files exist, both commits verified, all content checks pass.

---
*Phase: 25-n-gram-next-word-prediction*
*Completed: 2026-04-03*
