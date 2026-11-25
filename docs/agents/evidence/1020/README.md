# #1020: the bilingual check obeys its Experiments switch

Simulator proof for PR #1020 at head `0bb3fdeb` (Debug build), captured on 2026-11-25.

- Simulator: iPhone 17, iOS 26.5, French UI, slimmed with `simslim`, created for this run and deleted after it.
- Driving: `axe` v2.2.0 (official release binary), the `verify-dictus-ios` skill's scripts.
- Field: a Rappels reminder title. Keyboard: Dictus, French (AZERTY), Full Access on. « Correction spatiale » stays off throughout.
- Every word was typed key by key on the Dictus keys and followed by a space.

## Files

| file | what it shows |
|---|---|
| `a-experiments-bilingual-on.png` | Réglages → Clavier → Expériences: « Correction bilingue » on, « Deuxième langue » English. |
| `b-typed-bilingual-on.png` | Switch on. The second row is `its raining franchement its a good idea`, which reads `Ils raining fra cement it's a good idea`: `its a` became `it's a`. |
| `c-experiments-bilingual-off.png` | The same page with « Correction bilingue » off again. |
| `d-typed-bilingual-off.png` | Switch off. The third row is the same words, which read `Ils raining franchement ils a good idée`, the monolingual French keyboard's result. |
| `keyboard-log.txt` | The `TJ SWITCHES` and `APPLIED` lines of the keyboard's Debug log for the whole run, in order. |

## Reading the log

- `TJ SWITCHES … bilingual=off source=default`: first appearances, switch never touched.
- `TJ SWITCHES … bilingual=on source=appGroup`: after the switch was turned on (capture a). Then `APPLIED orig="its a" → "it's a"` (capture b).
- `TJ SWITCHES … bilingual=off source=appGroup`: after it was turned off again (capture c). Then `APPLIED orig="its" → "ils"` and `orig="idea" → "idée"` (capture d).

## Why the sentence is not `its a good idea` alone

The field capitalises the first word, and a capitalised `Its` at a sentence start becomes `Ils` even with the check on (`APPLIED orig="Its" → "Ils"` with `bilingual=on`). That limitation is already listed in the PR. So the contraction is shown mid-sentence, as in the PR body's `franchement its a good idea`.

With the switch off the French keyboard does not leave the words as typed: it writes `ils a good idée`. « Off » means the monolingual keyboard, not raw text.

The PR's « Limites connues » covers `franchement` → `fra cement` in capture b (`split-boundary`, the same result on `ac528041`).
