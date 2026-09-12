# Pause placement — measured on five paired samples (#550)

**Instrument:** `detect.py`. **Measured table:** `boundaries.json`. **Scoring:** `score.py`,
reported and never barred. **Fixtures:** `transcripts.md`. **Reference:** `reference.md`.
**Where:** Mac, 2026-09-12, on audio exported from the device.

Nothing here ran inside the app. The measurement uses an external voice-activity
detector over exported audio, not `ASRResult.tokenTimings`. What it establishes is
that the signal carries the information, which is what was in doubt.

---

## The verdict

**The rule holds on the three spontaneous dictations and breaks on the two read-aloud
ones.** On C, D and E a threshold on the silence sitting at a sentence boundary finds
all four wanted breaks and invents none. Pooled over all five fixtures no threshold
separates the two classes, because in fixture A the speaker paused at every boundary
and wants a break at one, and the one he wants is the shortest of the three.

**All six wanted breaks carry a real pause.** None is at zero. The first pass reported
zero at two of them and that was an instrument failure, corrected below.

## Method

The time-to-text mapping that limited fixture 7 is gone. Nothing is interpolated from
a constant speaking rate.

1. Decode to 16 kHz mono. Frame at 10 ms with a 25 ms window, take RMS in dB.
2. Per file, put the silence threshold at the 10th percentile of frame energy plus
   55 % of the distance to the 95th. The five files span 20,0 dB to 33,7 dB of dynamic
   range; one absolute threshold in dB does not work across them.
3. Merge two silence runs separated by a gap under 250 ms whose peak sits more than
   10 dB below speech level. Without this a single pause is reported as two.
4. **Cut at the surviving silences and transcribe each speech segment separately**
   (whisper.cpp `ggml-small`, `-l fr`). Every pause is then bracketed by its exact text
   on both sides.
5. Map segments onto the Dictus polished sentences. For each sentence boundary report
   the silence on it, zero when the boundary falls inside a segment.

### The instrument failure, recorded

The first pass placed the threshold at 25 % of the dynamic range and reported **zero**
silence at the boundaries wanted in A and in B, which would have read as a falsification.
It was the detector. Cutting at the candidate positions and transcribing the halves
shows the pause in both:

```
A_left  : J'ai pris un café, puis j'ai regardé rapidement mes messages.
A_right : Ensuite, je me suis mis au travail.        silence 9,45 -> 10,60 s
B_left  : alors que parfois prendre quelques minutes pour réfléchir permet
          simplement de mieux faire les choses.
B_right : [Ce n'est] pas forcément plus long, c'est juste une autre manière
          de travailler.                            silence 12,66 -> 13,52 s
```

The two quiet recordings, A and B, are also the two with the narrowest dynamic range,
20,0 dB and 21,2 dB against 29,3 dB to 33,7 dB for the others. A voice-activity
detector calibrated on loud spontaneous speech under-reports on them.

## The measurement

Sixteen sentence boundaries. Full data in `boundaries.json`.

| Fixture | Boundary | Silence | Wanted |
|---|---|---:|---|
| A | after 1 | 1,29 s | no |
| A | after 2 | 1,15 s | **yes** |
| A | after 3 | 1,35 s | no |
| B | after 1 | 0,86 s | **yes** |
| C | after 1 | 0,00 s | no |
| C | after 2 | 1,96 s | **yes** |
| C | after 3 | 0,00 s | no |
| D | after 1 | 2,00 s | **yes** |
| D | after 2 | 0,30 s | no |
| D | after 3 | 0,54 s | no |
| D | after 4 | 0,91 s | no |
| D | after 5 | 1,44 s | **yes** |
| D | after 6 | 0,86 s | no |
| E | after 1 | 1,60 s | **yes** |
| E | after 2 | 0,74 s | no |
| E | after 3 | 0,48 s | no |

**Spontaneous only.** Wanted breaks are 1,44 / 1,60 / 1,96 / 2,00 s; unwanted boundaries
top out at 0,91 s. Any threshold in [0,95 s ; 1,40 s] gives four found, none missed,
none invented.

**Fixture A.** Three boundaries at 1,29 / 1,15 / 1,35 s, one break wanted, and it is the
shortest. No threshold exists. In read-aloud speech his pauses do not encode his
paragraph intent.

**Fixture B.** The wanted break is 0,86 s, equal to the centisecond to the unwanted
D-after-6. Pooled, the two classes overlap and no absolute threshold separates them.

## The sentence-boundary condition is the robust part

Speaker-independent by construction, and it holds on all five.

| Fixture | Duration | Position | Outcome |
|---|---:|---|---|
| D | 2,59 s | mid-sentence | correctly rejected |
| D | 1,47 s | mid-sentence | correctly rejected |
| E | 1,40 s | mid-sentence | correctly rejected |
| B | 1,04 s | mid-sentence | correctly rejected |
| C | 1,01 s | mid-sentence | correctly rejected |

The longest silence in the corpus, 2,59 s, is a hesitation inside a sentence of fixture
D and is longer than every wanted break. Five such silences would be false positives
without the boundary condition. This reproduces fixture 7's counter-example on five new
instances.

## Speaker calibration

Raised by the maintainer: a threshold in seconds cannot suit every human.

He is right that a per-**user** setting is wrong, and his own data shows why. One
speaker, two registers, a factor of 2,2 apart:

| Fixture | Register | Characters per second of speech |
|---|---|---:|
| A | read | 22,1 |
| B | read | 28,6 |
| C | spontaneous | 13,1 |
| D | spontaneous | 14,7 |
| E | spontaneous | 20,9 |

**But normalising by the dictation's own median silence makes the separation worse.**
On short fixtures the median is carried by the very pauses being detected, so the ratio
collapses. The absolute threshold wins on this data. One speaker cannot settle the
question; the obvious normalisation is measured and it loses.

## Two candidate rules, compared on the same sixteen points

Both constants in both rules were chosen after seeing the table. **Neither is a result.**
What follows is a comparison, not a score.

Run `score.py` to reproduce.

| Rule | All five | Spontaneous only |
|---|---|---|
| silence ≥ 0,50 s at a boundary | 6 found, 6 invented, 0 missed | 4 found, 4 invented, 0 missed |
| silence ≥ 1,00 s | 5 found, 2 invented, 1 missed | 4 found, 0 invented, 0 missed |
| silence ≥ 1,40 s | 4 found, 0 invented, 2 missed | 4 found, 0 invented, 0 missed |
| floor 1,00 s and contrast ×1,5 | 4 found, 0 invented, 2 missed | 4 found, 0 invented, 0 missed |

The half-second rule the body of this issue opened on **invents as many breaks as it
finds**. It is dead as stated.

The absolute threshold and the contrast rule reach the same confusion matrix. **They
differ in how precisely the constant has to be known.**

- *Absolute*: zero false positives requires a threshold above 1,35 s, and catching
  D-after-5 requires it at or below 1,44 s. **A window 0,09 s wide.**
- *Contrast* — a boundary fires when its silence clears a floor and exceeds the median
  of the other sentence-boundary silences of the same dictation by a factor: the
  highest false positive sits at ×1,11 and the lowest true positive at ×1,67.
  **A window half as wide again as the value itself**, and it holds with the floor
  anywhere from 0,80 s to 1,00 s.

Contrast ratios, all sixteen boundaries:

| Fixture | Boundary | Silence | Contrast | Wanted |
|---|---|---:|---:|---|
| C | after 2 | 1,96 s | ∞ | **yes** |
| E | after 1 | 1,60 s | 2,62 | **yes** |
| D | after 1 | 2,00 s | 2,33 | **yes** |
| D | after 5 | 1,44 s | 1,67 | **yes** |
| A | after 3 | 1,35 s | 1,11 | no |
| D | after 4 | 0,91 s | 1,06 | no |
| A | after 1 | 1,29 s | 1,03 | no |
| D | after 6 | 0,86 s | 0,95 | no |
| A | after 2 | 1,15 s | 0,87 | **yes**, missed |
| E | after 2 | 0,74 s | 0,71 | no |
| D | after 3 | 0,54 s | 0,59 | no |
| E | after 3 | 0,48 s | 0,41 | no |
| D | after 2 | 0,30 s | 0,33 | no |
| C | after 1 | 0,00 s | 0,00 | no |
| C | after 3 | 0,00 s | 0,00 | no |
| B | after 1 | 0,86 s | undefined | **yes**, missed |

Both rules turn the two read-aloud fixtures into misses rather than wrong breaks, which
is the cheap direction: a miss leaves today's single block. The contrast rule reaches it
with margin; the absolute threshold reaches it by landing inside a 0,09 s window that
this corpus happens to define.

## Limits

- **One speaker, four wanted breaks over three spontaneous fixtures.** A clean separation
  on four positives and eight negatives can be luck.
- Every constant was chosen after seeing this table. Nothing here is scored.
- The register split into read and spontaneous was declared by the maintainer before the
  audio was touched, so the stratification is not post-hoc. The **exclusion** of A and B
  from the spontaneous column is still a choice made while looking at the numbers, and it
  is reported both ways above for that reason.
- Measured on exported `.m4a`, not on what the app holds. The `tokenTimings` question is
  untouched and still gates the implementation.
- The audio is not committed. It is the maintainer's voice on a public repository, and
  the transcripts carry everything the measurement needs. SHA-256 digests are in
  `reference.md` so the same files can be identified if they are ever needed again.
