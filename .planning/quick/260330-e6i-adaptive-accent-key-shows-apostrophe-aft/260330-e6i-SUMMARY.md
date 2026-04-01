---
phase: quick-260330-e6i
plan: 260330-e6i
subsystem: ui
tags: [keyboard, accent-key, adaptive, french, azerty, bigram]

requires:
  - phase: 19-03
    provides: "Adaptive accent key, lastInsertedCharacter tracking"
provides:
  - "Apostrophe on accent key after 'qu' bigram instead of ù"

key-files:
  modified:
    - DictusKeyboard/AccentedCharacters.swift
    - DictusKeyboard/DictusKeyboardBridge.swift

key-decisions:
  - "apostropheOverrides static set for extensible bigram matching"
  - "secondToLastInsertedCharacter tracker for 2-char context"
  - "precedingChar parameter with nil default for backward compatibility"

duration: ~5min
completed: 2026-03-30
---

# Quick Task 260330-e6i: Adaptive Accent Key Shows Apostrophe After "qu"

**After typing "qu", the accent key shows apostrophe instead of ù for easy typing of qu'il, qu'elle, etc.**

## Performance

- **Duration:** ~5 min
- **Tasks:** 2 (1 implementation + 1 human verification)
- **Files modified:** 2

## Accomplishments

- Added `apostropheOverrides` set in AccentedCharacters containing "qu" bigram
- Extended `adaptiveKeyLabel`, `shouldReplace`, and `adaptiveKeyVowel` with optional `precedingChar` parameter
- When bigram (precedingChar + lastChar) matches an override, apostrophe is returned instead of accent
- Added `secondToLastInsertedCharacter` tracker in DictusKeyboardBridge for 2-char context detection
- Verified on device: qu→apostrophe, Qu→apostrophe, u alone→ù, e→é, a→à all working correctly

## Task Commits

1. **Task 1: Add preceding-char context to adaptive methods** - `5abb2a7` (feat)
2. **Task 2: Human verification** - approved, all 9 test steps passed

## Files Modified

- `DictusKeyboard/AccentedCharacters.swift` - Added apostropheOverrides set, precedingChar parameter to all 3 adaptive methods
- `DictusKeyboard/DictusKeyboardBridge.swift` - Added secondToLastInsertedCharacter tracker, passes both chars to AccentedCharacters

## Deviations from Plan

None.

## Issues Encountered

None.

---
*Quick Task: 260330-e6i*
*Completed: 2026-03-30*
