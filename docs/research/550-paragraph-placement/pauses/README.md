# Pause placement — the deterministic route (#550)

The second half of #550. The model half is `../findings.md`, closed by PR #551. This
folder is the pause half: does a silence in the speaker's own delivery say where he
wants a paragraph.

**Read `findings.md` first.** It carries the verdict, the method and the limits.

| File | What it is |
|---|---|
| `findings.md` | The round: method, the sixteen-boundary table, two candidate rules, limits |
| `reference.md` | The speaker's own paragraph marks and how they were collected before any measurement |
| `transcripts.md` | The five fixtures, Dictus raw and Dictus polished |
| `boundaries.json` | The measured table, machine-readable |
| `detect.py` | Silence detection and speech segmentation |
| `score.py` | Scores candidate rules against `boundaries.json`. Reported, never barred |

## Re-running

`detect.py` needs the source audio, which is not committed; see `reference.md` for the
digests.

```
mkdir wav
ffmpeg -i "Texte A - Pause.m4a" -ac 1 -ar 16000 "wav/Texte A - Pause.wav"   # and the rest
python3 detect.py            # writes segments.json
python3 score.py             # needs only boundaries.json
```

Mapping the silences onto sentence boundaries means cutting the audio at the reported
silences and transcribing each speech segment on its own, then reading which Dictus
sentences each segment covers. `whisper.cpp` with `ggml-small` and `-l fr` was used. That
step is manual on purpose: it is the step that makes the table trustworthy, and it is
where an automated alignment would reintroduce the interpolation error that limited
fixture 7.

## Status

No code ships from this round. The bars are in the issue, declared before any Swift is
written, and they are to be scored on a fixture set that does not include A through E and
that includes a second speaker.
