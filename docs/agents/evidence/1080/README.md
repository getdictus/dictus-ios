# #1080 — the apostrophe/Return border, before and after

Simulator `fix/1080-apostrophe-return` (iPhone 17, iOS 26.5, slimmed, French device, keyboards
French AZERTY + Dictus), 2026-11-27. Field: the Settings search field. Driven with AXe 2.2.0
(`probe.py`).

## The two taps

Pierre's device log, build 2.1.0 (45), cab230d0, 26/11, `TJ TAP` #69 and #74: `k=return`,
dx −0.97 / −0.70, dy −0.42 / −0.46. In the journal (`KeyboardView.recordJournalTap`), dx and
dy are the touch's offset from **Return's keycap centre**, in key units: one-unit key widths
across (keycap + gap over the key's width in units), row pitches down (54 pt on a 6.1"/6.3"
iPhone), positive to the right and down.

On the AZERTY page (row 3: shift 1.5, w x c v b n, apostrophe, backspace 1.5; row 4: 123 1.25,
emoji 1.25, space 5.5, return 2.0) laid out by `KeyPlaneGeometry` on a 402 x 216 pt grid:

| | Return keycap centre | apostrophe slot | Return slot top | #69 | #74 |
|---|---|---|---|---|---|
| key units across | 9.00 | 7.5 to 8.5 | from 8.0 | 8.03 | 8.30 |
| grid pt | (359.0, 191.5) | x 299.75 to 339.25 | y 164.5 (row border) | (320.7, 168.8) | (331.4, 166.7) |
| screen pt (grid top 583.2) | (359.0, 774.7) | | y 747.7 | (320.7, 752.0) | (331.4, 749.9) |

Both taps are under the apostrophe's column, in Return's half of the 11 pt gap between the
rows: 4.3 and 2.2 pt below the border, 1.2 and 3.3 pt above Return's keycap. #69 is 1.2 pt
right of the apostrophe's centre line.

## Apple's French AZERTY, same points (`replay-apple.tsv`)

Apple's key frames in the accessibility tree: apostrophe x 300.7 to 340.4, y 698 to 752;
Return (« rechercher ») x 300.7 to 399.7, y 752 to 806. Its border is the gap's middle too.
Pierre's points rebuilt on Apple's keys (Return keycap centre y 779): (320.7, 756.3) and
(331.4, 754.2).

| context | tap | Apple types |
|---|---|---|
| C | #69 | Return (search runs, keyboard closes) |
| C | #74 | Return |
| Bonjour | #69 | Return |
| Bonjour | #74 | Return |
| C | Return centre | Return |
| C | apostrophe centre | `’` |

The simulator ships no French language data for Apple's keyboard (`tools/keyboard-bench/README.md`),
so a context-driven touch model of Apple's would not show here; what shows is a fixed border.

## Dictus, before (develop 0181766f) and after (fix/1080-apostrophe-return)

`replay-before.tsv`, `replay-after.tsv`, videos `dictus-before-develop.mp4` and
`dictus-after-fix.mp4` (640 px), still `after-c-tap69.png`.

| context | tap | develop | this branch |
|---|---|---|---|
| C | #69 (320.7, 752.0) | Return: `C`, search runs | **`C'`** |
| C | #74 (331.4, 749.9) | Return: `C`, search runs | **`C'`** |
| Bonjour | #69 | Return | Return |
| Bonjour | #74 | Return | Return |
| C | Return keycap centre (359.0, 774.7) | Return | Return |
| C | apostrophe keycap centre (319.5, 720.7) | `C'` | `C'` |
