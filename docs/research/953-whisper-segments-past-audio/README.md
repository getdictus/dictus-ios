# Whisper segments timed after the audio (#953)

Captured 2026-11-15 on develop `3fa26bf1` plus this branch, on an M-series Mac, with
`tools/closing-phrase-bench` (see its README). Corpora are read only.

- `<engine>.tsv`: dictus-test-voices `6eeeb0f`, the 20 clips decoded with the 6 tails
  of #932 and cut inside a word at 50, 70 and 90 % of the clip (and at 14.4 s on the
  five long clips). Each decode gives two rows from one WhisperKit call: `trim` is what
  ships today, `trim+past-audio` the same results through `PastAudioSegments.text`.
- `segments-<engine>.tsv`: every segment of those decodes with its start, end, and
  whether it was dropped.
- `report.md`: `score.py` over the two TSVs.

## Findings

- On dictus-test-voices nothing changes. No segment of the 370 Turbo and Small decodes
  starts after its audio, so the two pipelines give the same text on every decode and
  the same WER in every language. The `invented endings (cuts)` column counts a last
  word that differs from the reference, mostly the half-spoken cut word misheard or a
  number written as digits; those words sit in segments that start inside the audio and
  are out of reach of this fix.
- The ElevenLabs voices do not reproduce the bug; real iPhone recordings do. On ten of
  Pierre's French recordings from dictus-asr-audio (17 to 107 s, real room), each cut
  inside a word at 5, 10, ... 95 % and at 14.4 s, 199 decodes per engine:

  | engine | decodes | with a segment starting after the audio | text changed | errors against the uncut decode, before → after |
  |---|---|---|---|---|
  | Turbo 632 MB | 199 | 5 | 5 | 186 → 95 |
  | Small 216 MB | 199 | 0 | 0 | unchanged |

  The five Turbo cases (times only: that corpus is private):

  | audio sent | dropped segments | first dropped start | last dropped end | words removed | real words among them |
  |---|---|---|---|---|---|
  | 15.23 s | 1 | 15.24 | 16.14 | 1 | 0, the #953 pattern: one short word after the cut |
  | 35.83 s | 1 | 35.84 | 36.22 | 2 | the cut word, half spoken |
  | 53.78 s | 9 | 54.70 | 63.70 | 78 | 0, a repetition loop over 10 s past the audio |
  | 61.03 s | 2 | 61.04 | 63.10 | 19 | the cut word, half spoken |
  | 85.32 s | 1 | 85.34 | 85.88 | 1 | 1, "et", spoken before the cut |

  "Real words" compares each dropped segment with the uncut recording's Turbo decode.
- Every dropped segment started 0.01 s or more after the audio. Kept segments started
  as late as 0.11 s before its end (Small, a cut word such as "voir."), so the
  tolerance is one Whisper timestamp step, 0.02 s. The runs used 0.1 s; no segment of
  any run started between 0.1 and 0.02 s before the end, so 0.02 s gives the same text.
- Small writes segments that end after the audio (47 decodes, up to 4 s past it), all
  starting inside it and carrying real words. A rule on the end of a segment would
  delete them; the rule on its start leaves them.
- Not every dropped word is invented. Turbo sometimes times the last real word, the one
  the stop cut through, after the audio: one whole word ("et") and two half-spoken ones
  were lost on 199 decodes, against 98 invented words removed.
- When nothing is dropped the text is WhisperKit's own, byte for byte (194 of 199 Turbo
  decodes, all 199 Small ones). When something is, the text kept is an exact prefix of
  WhisperKit's.
- Parakeet has no segments and is untouched.
