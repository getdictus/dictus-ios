---
status: complete
phase: 19-complex-touch-features
source: [19-01-SUMMARY.md, 19-02-SUMMARY.md, 19-03-SUMMARY.md]
started: 2026-03-30T10:00:00Z
updated: 2026-03-30T10:15:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. French Accent Long-Press Popups
expected: Long-press any vowel (e, a, u, i, o) or c, y, n on the keyboard. A popup should appear showing accented character variants. Release on an accent to insert it.
result: pass

### 2. Uppercase Accents on Shifted/Capslock
expected: Activate Shift or Caps Lock, then long-press a vowel. The accent popup should show uppercase variants (E, A, etc.).
result: pass

### 3. Double-Space Period Insertion
expected: Type a word, then tap space twice quickly. The two spaces should be replaced with ". " (period + space), matching iOS native behavior.
result: pass

### 4. Edge Key Touch Response
expected: Tap keys at the screen edges (a, q on left; p, m on right). They should register immediately on first tap with no dead zones or missed taps. Response should feel instant (touchDown, not touchUp).
result: pass

### 5. Accelerating Backspace Delete
expected: Hold the backspace key. After a short pause (~0.5s), characters start deleting one by one. After ~10 characters, deletion accelerates to word-by-word. Haptic feedback fires on each deletion.
result: pass

### 6. Spacebar Trackpad Cursor Movement
expected: Press and hold the spacebar, then drag left/right. After a small dead zone (~8pt), the text cursor should move in the text field. Movement accelerates with drag distance. A haptic tap fires when trackpad activates.
result: pass

### 7. Adaptive Accent Key
expected: On the AZERTY layout row 3, there is an accent key. After typing a consonant, it shows an apostrophe. After typing a vowel (e, a, u, i, o), it shows the most common accent for that vowel. Tapping it replaces the vowel with the accented version.
result: pass

### 8. Keyboard Height Stability
expected: Tap keys on the top row of the keyboard. The keyboard should NOT resize or expand in height. Height remains stable regardless of which key is tapped.
result: pass

## Summary

total: 8
passed: 8
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
