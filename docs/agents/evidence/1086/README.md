# #1086 (refs #1071): the bilingual check no longer splits a word the other language has

Simulator proof for the #1071 fix at `5116dd72` (the PR head `19f8a76e` adds only a line to the feature map) (branch `fix/1071-bilingual-split`, on top of #1020 `4f661f78`), Debug build, captured on 2026-11-25.

- Simulator: iPhone 17, iOS 26.5, French UI, slimmed with `simslim`, created for this run (verify-dictus-ios) and deleted after it. Status bar 9:41.
- Driving: AXe v2.2.0 (official release binary, `/private/tmp/axe-1020.yIu2/x/axe`), the verify-dictus-ios scripts. Full Access granted in Réglages → Apps → Dictus → Claviers (Général → Clavier stays blank on this runtime).
- Bilingual on with `-DictusDebugBilingualAutocorrect YES`; second language English (the default for French). « Correction spatiale » off.
- Field: a Rappels reminder title. Keyboard: Dictus, French (AZERTY). Every word typed key by key on the Dictus keys, followed by a space.

## Files

| file | what it shows |
|---|---|
| `b-typed-bilingual-on.png` | `its raining franchement its a good idea` reads `Ils raining franchement it's a good idea`: `franchement` kept (it read `fra cement` in #1020's capture b), `its a` became `it's a`. |
| `keyboard-log.txt` | The `TJ SWITCHES`, `AUTOCORRECT branch` and `APPLIED` lines of the keyboard's Debug log. |

## Reading the log

- `TJ SWITCHES … bilingual=on source=appGroup`.
- `AUTOCORRECT branch=split-boundary orig="franchement" corr="fra cement"`, then `branch=bilingual.keptUnsplit.en orig="franchement" corr="franchement"`: the English engine still proposes the split, and the bilingual check keeps the word because French has it.
- `APPLIED orig="Its" → "Ils"`: the sentence-start `Its` in a French window (case 2 of #1071, now #1077) is not fixed by this PR; it has another cause (the frequency rule prefers French `ils`, with no words before to lean English).
