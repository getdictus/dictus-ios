# Evidence for #502 (PR #1092): the suggestion bar drawn as Apple's

Simulator only: iPhone 17 Pro, iOS 27.2 (24B8117), French device, status bar at 09:41,
captured 2026-11-26/27 with AXe 2.2.0 (official release binary). Dictus build: branch
`feature/502-suggestion-bar`, Debug, "Nouvelle barre de suggestions" switched off for
"before" and on (through Réglages › Clavier › Expériences) for "after". Nothing here is a
device validation.

## Comparison grids

- [`502-light.png`](502-light.png): light, three states × Apple | Hex | Dictus before | Dictus after
- [`502-dark.png`](502-dark.png): dark, same

States: (a) suggestions after a word, (b) a word about to be autocorrected, (c) the undo
after a correction.

**Apple** was typed in Rappels with Apple's **English** keyboard: the iOS 27.2 simulator
runtime ships no French prediction data, so Apple's French bar stays empty there (the
keyboard bench README notes the same). Typos: `goinf` (light), `yesterdsy` (dark).
State (c): Apple's simulator keyboard draws no revert bubble. In light, a backspace after
the correction brought back the original word, offered plain in the left slot (`goinf`);
in dark the same steps offered the corrected word in quotes. Both are what iOS showed.

**Hex** was not run: building it needs `xcodegen` (not installed here) and a second full
iOS build on a shared Mac. Its repository ships two captures of its bar, both dark, both
used as is: `ios/HEXMobile/Assets.xcassets/WhatsNew/emoji.imageset/emoji.jpg` (state a)
and `key-colors.imageset/key-colors.jpg` (state b), from
https://github.com/anomalyco/hex/tree/bfa25200aef7bce802c6c87aa9914dfd83626c69/ios/HEXMobile/Assets.xcassets/WhatsNew
(MIT, Copyright (c) 2026 Christopher Langton). There is no light capture and no undo
capture of Hex's bar to show.

**Dictus** was typed in Rappels with the Dictus AZERTY keyboard: `je suis ` (a),
`bonjout` (b), then space (c).

## Single captures

`apple-<light|dark>-<a|b|c>.png`, `dictus-<off|on>-<light|dark>-<a|b|c>.png`: the
keyboard half of each screenshot. `dictus-experiments-switch.png`: the Experiments page
with the switch on.

## Measurements (3x screenshots, 1 pt = 3 px)

| | Apple | Dictus before | Dictus after |
| --- | --- | --- | --- |
| Bar | 44 pt, words centred 25.5 pt below the keyboard's edge | 52 pt toolbar, 36 pt slots | unchanged |
| Words | SF 17 regular; light (74,74,76), dark (162,162,162) | SF 15, `label` (black / white); bold centre | SF 17 regular (shrinks to 15 before truncating); light (74,75,76), dark (161,161,161) |
| Word about to be corrected | capsule as wide as its cell (134 pt), 37 pt (112 px), round ends; light fill (235,237,240) under (44,46,49), dark (115,115,115) under white | semibold, no fill | capsule as wide as its slot (~100 pt), 36 pt, round ends; light fill (236,236,240) under (44,44,45), dark (115,115,115) under white |
| Dividers | 1 × 24 pt; light (211,212,217), dark (49,49,51); hidden beside the capsule | 0.5 × 20 pt `systemGray3`; light (199,199,204), dark (72,72,74) | 1 × 24 pt; light (211,212,217), dark (49,49,49); hidden beside a capsule, place kept |
| Undo | no bubble on the simulator | rounded rectangle (r 8), 30 pt, accent 12 %, semibold 15 | capsule, 36 pt, as wide as its slot, accent 12 %: light (206,215,235), dark (35,43,59); arrow + word in #3D7EFF, 17 regular |

Dictus's capsule is 36 pt rather than Apple's 37: that is the slot's tap target and the
height of the mic pill beside it in the same bar.

## Logic untouched

`tools/keyboard-bench/run.sh --langs fr,en,en-typos` on `origin/develop` (3ea25a16), on
this branch with the switch off, and on this branch with the switch on (written in the
simulator's App Group): `texts.tsv`, `commits.tsv` and `register.tsv` byte-identical in
all three. See [`bench.txt`](bench.txt).
