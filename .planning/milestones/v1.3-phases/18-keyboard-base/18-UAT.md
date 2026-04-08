---
status: complete
phase: 18-keyboard-base
source: [18-01-SUMMARY.md, 18-02-SUMMARY.md, 18-03-SUMMARY.md]
started: 2026-03-28T12:00:00Z
updated: 2026-03-28T12:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. AZERTY Layout Display
expected: Open any text field and switch to the Dictus keyboard. The keyboard shows a French AZERTY layout with the correct key arrangement: top row AZERTYUIOP, middle row QSDFGHJKLM, bottom row WXCVBN with shift and backspace.
result: pass

### 2. Character Input
expected: Tapping letter keys inserts the correct corresponding character into the text field. Each key produces its labeled letter.
result: pass

### 3. Backspace
expected: Tapping the backspace key deletes the last character in the text field. Holding backspace should delete continuously.
result: pass

### 4. Space and Return Keys
expected: Tapping space inserts a space character. Tapping the return key inserts a newline (or submits, depending on the text field type).
result: pass

### 5. Numbers and Symbols Pages
expected: Tapping the "123" key switches to a numbers page with digits and common punctuation. A secondary "#+="-style key switches to a symbols page with less common characters. Tapping "ABC" returns to the letter layout.
result: pass

### 6. Autocapitalization
expected: After typing a sentence-ending punctuation mark (.!?) followed by a space, the keyboard automatically shifts to uppercase for the next character. The first character in an empty text field is also auto-capitalized.
result: pass

### 7. Double-Space Period
expected: Typing two spaces quickly replaces the second space with a period followed by a space (matching iOS native behavior). The keyboard then auto-capitalizes for the next word.
result: issue
reported: "ça ne marche pas, mais c'est pas très grave si ça ne le fait pas pour l'instant"
severity: minor

### 8. Shift and Capslock
expected: Single tapping shift toggles between lowercase and uppercase. Double-tapping shift within ~300ms activates capslock (all subsequent characters uppercase until shift is tapped again).
result: pass

### 9. Auto-Unshift After Character
expected: After manually tapping shift once (not capslock), typing a single character automatically returns the keyboard to lowercase.
result: pass

### 10. Haptic Feedback
expected: Key presses produce haptic feedback immediately on touchDown (when finger touches the key), not on release. The feedback timing should feel identical to the Apple native keyboard.
result: issue
reported: "les touches aux extrémités (a, q, p, m, 1, -, 0, \", [, _, =, .) ont le retour haptic et popup au touchUp au lieu de touchDown. Issue à créer, ne pas résoudre tout de suite — nécessite une grande réflexion car nous n'avons pas réussi à corriger le bug précédemment"
severity: minor

### 11. Keyboard Height
expected: The keyboard height matches Apple's native keyboard proportions (not noticeably taller or shorter than the standard iOS keyboard).
result: pass

## Summary

total: 11
passed: 9
issues: 2
pending: 0
skipped: 0

## Gaps

- truth: "Double-space inserts period followed by space, matching iOS native behavior"
  status: failed
  reason: "User reported: ça ne marche pas, mais c'est pas très grave si ça ne le fait pas pour l'instant"
  severity: minor
  test: 7
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "All keys produce haptic feedback and popup on touchDown, including edge keys"
  status: failed
  reason: "User reported: les touches aux extrémités (a, q, p, m, 1, -, 0, \", [, _, =, .) ont le retour haptic et popup au touchUp au lieu de touchDown. Nécessite une grande réflexion — bug non résolu précédemment"
  severity: minor
  test: 10
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""
