# Paragraph placement (#550)

What is here, and what it is worth. **Start with `findings.md`.**

## Two things happened here, in order

### 1. The pause hypothesis was falsified, 2026-09-11

`align.py` maps each sentence boundary of a transcript onto a time by walking
**speech time only**, skipping the silences `ffmpeg -af silencedetect` reports, and
names the silence sitting at that boundary. `run.py` drives it over the four
controlled recordings the maintainer made: two short texts, each dictated twice, once
with deliberate pauses between ideas and once trying to suppress them.
`alignment-output.txt` is its output at two noise floors.

**It falsifies the hypothesis the issue body opened on.** Text B breaks at the
boundary carrying the least silence in one take and none at all in the other, while
ignoring a clear 0.5 s pause earlier. The full table is on the issue.

What survives: no break ever lands inside a sentence, seven breaks over five
recordings; delivery does move the result, but not through pause duration; and the
reference splits even sixteen seconds of unremarkable speech, so nothing is being
detected as *worth* a break.

**The source audio is not in the repository.** Five recordings of the maintainer's
voice. The measurements are committed, the audio is not — `run.py` names the files it
expects.

### 2. The capability round, same day

`bars.md` is the plan, committed before the first arm call. `arms/` holds the eight
prompt arms, one JSON file each, from a bare `Ajoute des paragraphes à ce texte.` to
an index-only arm where the model returns sentence numbers and the text is
reassembled in code. `raw/` holds the human captures, `captures/` the machine ones,
`references.json` where the competitor put its breaks, `score.py` the three
quantities the harness does not score.

The instrument is `swift run polish-harness paragraph`, documented in
`DictusCore/Sources/polish-harness/README.md`.

**The answer is in `findings.md` and it is no.** One arm holds all four bars 70 of 70
and returns the same answer as a rule that calls no model at all in 56 of those 70.

### 3. The pause hypothesis, re-measured against the speaker, 2026-09-12

`pauses/` holds the round that answers the question the falsification left open. The
first round killed *pauses explain Typeless*; this one tests *pauses serve the speaker*,
with his own paragraph marks as the reference instead of the competitor's output.

Five new fixtures, each with its audio, its Dictus raw and polished text, and the breaks
the maintainer wants, collected from the numbered text **before any measurement was shown
to him**. Sixteen sentence boundaries, each carrying a silence measured by cutting the
audio at the pauses and transcribing every speech segment on its own, so nothing is
interpolated from a speaking rate.

**It holds on the three spontaneous dictations and breaks on the two read-aloud ones.**
The half-second rule the issue body opened on invents as many breaks as it finds. Start
with `pauses/findings.md`.

### And one thing settled on the side

`timings-probe/` answers the issue body's first technical step — is
`ASRResult.tokenTimings` populated at runtime for Parakeet — headlessly, against the
pinned FluidAudio, driving no Apple Foundation Model. It is. `findings.md` §Timings
has the numbers and the three caveats.

## Reused from #437, not rebuilt

`docs/research/437-longform-breaks/` holds the six fixtures' arms, the scorer and the
second-pass probe. The seven texts this round runs on are six of its second-pass texts
verbatim plus fixture 7, and its `findings.md` is the measurement this one stands on.
