# Invented closing phrases (#932)

Captured 2026-11-13 on develop `fd92aaa0` plus this branch, on an M-series Mac, with
`tools/closing-phrase-bench` (see its README for the method). The corpus is
dictus-test-voices `6eeeb0f`, read only.

- `before-<engine>.tsv`: the shipping pipeline, one row per decode (20 clips, 6 tails).
- `after-<engine>.tsv`: the same decodes through `TrailingSilence.trimmed`, as shipped
  for Whisper.
- `trim-not-shipped-parakeet-v3.tsv`: the cut applied to Parakeet, to show why it is not.
- `polish-turbo-clean.tsv`: Turbo's text for the 17 French, English, German and Spanish
  clips through the real polish pipeline (`polish-harness show --runs 3`, Apple
  Foundation Models on the Mac), 51 calls.
- `report.md`: `score.py` over all of the above.

## Findings

- The phrases come from Whisper, not polish. Turbo wrote an ending nobody said on 14 of
  100 decodes with a recorded tail ("Vielen Dank." three times on the German long clip),
  Small on 23. Parakeet wrote none. Polish added no ending in 51 calls.
- The mechanism: WhisperKit decodes the room after the last word as a window of its
  own (seek loop for a short clip, a VAD chunk for a long one), and Whisper fills an
  empty window with a subtitle-style closing line.
- With the tail cut 0.5 s after the last frame that reads as speech, Turbo and Small
  invent no ending on any of their 200 decodes with a tail, and their error rate on the clean clips is
  unchanged (1.9 % and 8.1 %). No decode was cut inside its clip.
- Cutting Parakeet's tail raises its error rate on clips with a tail from 42.8 % to
  44.0 %, for no ending removed, so Parakeet keeps the whole recording.
- Parakeet's French and Mandarin rates are high for reasons outside #932: the long French
  clip drifts into English (the #623 retry is not run by the bench), and Parakeet has no
  Mandarin.
