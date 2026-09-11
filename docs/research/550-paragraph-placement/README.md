# Paragraph placement (#550)

What is here, and what it is worth.

## The falsification, 2026-09-11

`align.py` maps each sentence boundary of a transcript onto a time by walking
**speech time only**, skipping the silences `ffmpeg -af silencedetect` reports,
and names the silence sitting at that boundary. `run.py` drives it over the four
controlled recordings the maintainer made on 2026-09-11: two short texts, each
dictated twice, once with deliberate pauses between ideas and once trying to
suppress them.

`alignment-output.txt` is its output at two noise floors.

**It falsifies the pause hypothesis.** Text B breaks at the boundary carrying the
least silence in one take and none at all in the other, while ignoring a clear
0.5 s pause at the earlier boundary. The full table is on the issue.

**What survives:** no break ever lands inside a sentence, seven breaks over five
recordings; the delivery does move the result, but not through pause duration;
and Typeless splits even sixteen seconds of unremarkable speech, so nothing is
being detected as *worth* a break.

## The source audio is not in the repository

Five recordings of the maintainer's voice. The measurements are committed, the
audio is not. `run.py` names the files it expects; re-running it needs them from
the maintainer.

## Reused from #437

`docs/research/437-longform-breaks/` holds the six fixtures' arms, the scorer and
the second-pass probe. Nothing there is rebuilt here.
