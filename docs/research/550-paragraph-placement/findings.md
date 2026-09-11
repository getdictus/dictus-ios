# Paragraph placement — measured (#550)

**Bars and plan:** `bars.md`, committed before the first arm call (`249ea37`).
**Instrument:** `swift run polish-harness paragraph`, committed before the first arm
call (`f5aafda`).
**Arms:** `arms/`, one JSON file each. **Raw captures:** `raw/`. **Machine capture:**
`captures/`. **Reported, never barred:** `score.py`.
**Where:** Mac, macOS 26, Apple Intelligence on, 2026-09-11.

Everything below is Apple FM on a Mac. Nothing here was confirmed on a physical
iPhone, and nothing here ran through `PolishPipeline` — see §Limits.

---

## The verdict

**No arm ships. Normal polish keeps its single block, and the round records why.**

Eight arms, **350 outputs** over seven already-polished French texts — 280 at five
samples per fixture, plus 70 more confirming the two finalists at ten.

One arm holds every declared bar, perfectly, at a seventh of the latency of writing
the text back out. It still does not ship, and the reason is the finding of this
round:

> **Arm 7 returns the same answer as a rule that calls no model at all, in 56 runs of
> 70.** Once fidelity, boundary discipline and the break count have each been moved
> out of the model and into code — which is exactly what the brief asked for, and it
> works — the model has nothing left to contribute. Asked to rank the candidate
> boundaries by how obvious they are, it lists every sentence in document order, **34
> times out of 35**. There is no ranking in the answer. Taking the first N of it is
> taking the first N sentences.

So the bars are held by arithmetic. What the bars do not measure is placement, and
placement is where the model was supposed to be.

## What this round was for

#437 asked whether Normal polish could be licensed to break paragraphs **at a change
of subject**, measured it over 432 outputs and twelve arms, and closed with no. The
maintainer's reading on 2026-09-11 is that the criterion was wrong, not the capability:

> Les paragraphes, moi je le fais naturellement. Comme je sais que Dictus fait des
> gros pavés, je m'arrête de parler, je termine la transcription, puis je recommence.
> […] C'est pas vraiment un changement de sujet, c'est quand même dans le sujet
> global, mais il y a un changement de contexte.

The issue opened on the hypothesis that followed — a silence at a sentence boundary
opens a paragraph — and **the maintainer's own four controlled recordings falsified
it** before this round started (`align.py`, `run.py`, and the comment of 19:16). Text B
breaks at the boundary carrying the least silence in one take and none at all in the
other, which no threshold produces.

What survived the falsification is what this round is built on:

1. **No break ever lands inside a sentence.** Seven breaks, five recordings.
2. **The reference is not finding a correct boundary.** It is choosing a plausible one,
   and it always chooses. Text A is the same four sentences split two different ways on
   two takes, both defensible.
3. **Nobody ever told the model how many breaks to place.** #437's isolated second pass
   held fidelity 30/30 and then put one break per sentence on one fixture and none on
   another. That is the untested variable.

So this round asks a **capability** question with the lightest possible prompts, and it
is explicitly not a prompt round: the shipping prompt is exhausted,
`PolishPromptParityTests` pins the ban, and re-wording rule 5 is a re-run.

## The round

### Every bar, scored

Five samples per fixture, seven fixtures, 35 runs per arm. Violation counts — **0 is
the bar**. `raw/round1-5runs.txt`, `captures/round1.json`.

| arm | fidelity | inSentence | listSyntax | parseFail | count = N | median ms |
|---|---|---|---|---|---|---|
| 1 `bare` | **30/35** | 0/35 | **2/35** | 0/35 | 7/35 | 4 342 |
| 2 `boundary` | **7/35** | 0/35 | 0/35 | 0/35 | 0/35 | 2 493 |
| 3 `count` | **10/35** | 0/35 | 0/35 | 0/35 | 1/35 | 2 457 |
| 4 `both` | **4/35** | 0/35 | 0/35 | 0/35 | 1/35 | 2 543 |
| 5 `presegmented` | **4/35** | 0/35 | 0/35 | 0/35 | 3/35 | 2 582 |
| 6 `index` | 0/35 | 0/35 | 0/35 | 1/35 | 0/35 | 560 |
| 6b `index-count` | 0/35 | 0/35 | 0/35 | 0/35 | 18/35 | 417 |
| 7 `index-ranked` | 0/35 | 0/35 | 0/35 | 0/35 | **35/35** | 580 |

Confirmed at ten samples per fixture on the two finalists, 70 runs each
(`raw/round2-confirm-10runs.txt`):

| arm | fidelity | inSentence | listSyntax | parseFail | count = N | median ms |
|---|---|---|---|---|---|---|
| 6b `index-count` | 0/70 | 0/70 | 0/70 | 1/70 | 35/70 | 415 |
| 7 `index-ranked` | 0/70 | 0/70 | 0/70 | 0/70 | **70/70** | 577 |

One engine error in 245 calls in the first pass of round 1 and none since:
`exceededContextWindowSize` on the **shortest** fixture, 403 characters under a
450-character prompt, reporting 4 090 tokens. It is recorded because it is
unexplained, not because it is actionable at this rate.

### Finding 1 — every text arm breaks the contract, and the lighter the prompt the worse

**Arm 1, the bare `Ajoute des paragraphes à ce texte.`, does not paragraph. It
answers.** On six of seven fixtures, 30 runs of 35, what comes back is not the input
with newlines in it — it is Apple FM replying to the speaker. Fixture 1 comes back at
up to **3.78× its input length** as an essay about product focus, addressed to the
speaker, sharing almost no words with what was dictated:

```
in : Bon alors, je pensais à un truc ce matin en marchant. C'est que, finalement, …
out: C'est vrai, la décision de ne pas faire quelque chose peut être tout aussi
     difficile que de le faire. On est souvent attirés par de nouvelles idées …
```

**The only two list-syntax violations in the whole round are here**, both on fixture
6, and they are the failure #437 feared and never once saw in 432 outputs — a
transcript turned into advice with numbered bold headings:

```
Je comprends que vous souhaitiez optimiser votre expérience avec la transcription
vocale de Type Laiss. Voici quelques suggestions …
1. **Révision Préalable** : Avant de faire un sixième test, prenez le temps de …
```

**The 6 KB "change nothing" prompt #437 called the obstacle turns out to be what
holds the contract together**: without it, the model treats a transcript as a conversational
turn. That is the opposite of what a lighter prompt was expected to buy, and it is
worth knowing before anyone proposes a light prompt again.

**Adding the fidelity clause helps and does not fix it.** Arm 2 says, in French,
*change no word, removing the line breaks must give back the input character for
character*. It still fails fidelity **7 runs of 35**, five of them on one fixture — and
the way it fails there is the defect #439 handed to #437, on the same fixture, on the
same clause:

```
in : … ces trois étapes ne coûtent pas du tout le même prix.
out: … ces trois étapes ne coûtent pas le même prix.
```

`du tout` is deleted **5 runs of 5**. #437 measured `en calcul` disappearing from
that same sentence, also 5 of 5, and named the mechanism: **words are dropped out of the clause the model
is deciding where to cut.** This round reproduces it on a different word under a
prompt whose only other instruction is *do not delete anything*.

### Finding 2 — told to stay faithful, the text arms simply refuse to split

Arms 2, 3 and 4 produced, between them, **10 breaks in 105 runs**, and **all ten are
on the same fixture** — P1, the 403-character one, which is the shortest text in the
set and the one #437 barred to zero. Per fixture, arm 2:

| Fixture | N | breaks per run |
|---|---|---|
| P1 `free-form` | 1 | 0, 0, 3, 0, 0 |
| P2 `project-update` | 2 | 0, 0, 0, 0, 0 |
| P3 `message-draft` | 1 | 0, 0, 0, 0, 0 |
| P4 `explanation` | 2 | 0, 0, 0, 0, 0 |
| P5 `rambling` | 3 | 0, 0, 0, 0, 0 |
| P6 `unscripted` | 3 | 0, 0, 0, 0, 0 |
| P7 `89 s` | 3 | 0, 0, 0, 0, 0 |

That is #437's headline reproduced on a 4-line prompt instead of a 6 KB one. **The
ban was never the obstacle.** Telling the model it may break and must not change a
word produces a wall of text, and adding the exact number does not move it: arm 3
produced **6 breaks in 35 runs** and arm 4 produced **1**. Arm 3 was told *place
exactly N line breaks*; in **3 runs of 5** on P1 it wrote that instruction into the
output as if the instruction were the text to format.

### Finding 3 — the index arms hold everything, because nothing is left to the model

Arms 6, 6b and 7 return integers and the text is reassembled in code. Fidelity **0
violations in 245 index runs**, boundary discipline 0, list syntax 0 — all three
structural. Latency drops from 2.5–4.3 s to **0.4–0.6 s median**, because a dozen
tokens come back instead of 1 200 characters.

And then, in order:

**Arm 6, no count: the model marks every sentence.** P4, 10 breaks of a possible 10,
5 runs of 5. P7, 7 of 7, 5 of 5. P5, up to 25 of 25. This is #437's second-pass
failure exactly — one paragraph per sentence — and it confirms the brief's diagnosis
that nobody had ever told it how many to place.

**Arm 6b, with the count: the model starts selecting, and obeys the count half the
time.** 18/35 at five samples, **35/70** at ten. 25 of its 35 answers are genuine
selections rather than a prefix (`[2, 6]`, `[5, 7, 10]`, `[3, 10, 17]`). It is the
only arm in the round where Apple FM exercises judgement about where a paragraph
starts.

**Arm 7, ranked then truncated in code: the count becomes perfect and the judgement
disappears.** 70/70 on the count. And:

| | |
|---|---|
| arm 7 answers listed in plain document order | **34 / 35** |
| arm 7 output identical to *"break after the first N sentences"* | **56 / 70** |
| arm 7 output identical to *"break at N evenly spaced boundaries"* | 0 / 70 |

Asked for the boundaries *de la plus évidente à la moins évidente*, the model returns
`1, 2, 3, 4, 5, 6, 7, 8`. **It is not ranking. It is enumerating.** Truncating that to
N is a positional rule wearing a model call.

### What it actually produces, on the sample the maintainer recorded

Fixture 7, 8 sentences, N = 3. The reference breaks before sentences **2, 5 and 8** —
the three positions the issue body's pause table names — giving paragraphs of 1, 3, 3
and 1 sentences. Arm 7's most common answer, 3 runs of 5, is **2, 3, 4**:

```
¶ Donc, l'idée est de faire un audio un peu long …
¶ Ce que j'ai remarqué, c'est que concrètement, avec Gicus …
¶ Alors qu'avec Tapeless, à contrario, on va avoir une sortie …
¶ Bref, on va avoir un truc qui va être beaucoup plus structuré. Le but, ce n'est
  pas forcément … Et ça sera un mode intelligent de Dictus. Mais l'idée, c'est au
  moins peut-être d'aérer les outputs … Encore une fois, si on arrive à faire un
  truc …
```

Three one-sentence paragraphs, then five sentences in one block. That is not the
problem the issue is about — it is the same wall of text, pushed to the end. Arm 6b's
most common answer on the same fixture is the same three positions.

### Placement, reported and never barred

Agreement with the Typeless reference, over the ten-run confirmation, on the three
fixtures where the reference is paragraphing rather than a list:

| arm | judged runs | reference breaks hit | extra breaks |
|---|---|---|---|
| 6b `index-count` | 30 | **27 / 60** (45 %) | 40 |
| 7 `index-ranked` | 30 | **21 / 60** (35 %) | 29 |

Per bars.md §2 this is **a number, not a verdict**: text A is the same four sentences
split two different ways on two takes of the same words, so the reference is one
acceptable answer among several, and scoring against it as truth would repeat #437's
mistake from the other side. It is reported because it is the only external check
available, and because 35 % with 29 extra breaks is not a near miss.

### Latency, reported and never barred

Median milliseconds per fixture. #437's first call, which this would sit behind, runs
2.2 s at 395 characters and 7.6 s at 1 283; its isolated second pass added 1.4–5.2 s.

| arm | P1 403 | P3 356 | P2 698 | P4 838 | P7 1 150 | P6 1 161 | P5 1 240 |
|---|---|---|---|---|---|---|---|
| text arms (2–5) | ~1 430 | ~1 330 | ~2 200 | ~2 500 | ~3 400 | ~3 200 | ~4 400 |
| 6b `index-count` | 333 | 388 | 358 | 411 | 495 | 489 | 603 |
| 7 `index-ranked` | 372 | 437 | 584 | 690 | 619 | 572 | 1 491 |

**The index route is the cheap one and it is not close** — roughly a seventh of the
second pass #437 measured, because the output is a dozen tokens. If a future attempt
finds a model that can place a boundary, this is the shape to spend the call on.
Nothing here is a device number.

### N, the break count — fitted, not settled

Ordinary least squares on the five reference points where the reference produced
prose paragraphing:

```
breaks = 0.548 + chars / 470        R² = 0.78
```

The rule the arms obeyed, `N = max(1, round(chars / 400))`, scores identically:
**4 of 5 exact**, missing fixture 3 by one break. The full table is in `score.py`'s
output.

Three things keep this from being a formula, and the round did not resolve any of
them:

- **Five points.** Two of the five character counts come from a Typeless output,
  because texts A and B have no Dictus side and none was invented for them.
- **Untested outside 246–1 150 characters**, which is most of the range a long
  dictation lives in.
- **Nearly half the paired evidence is unusable.** On four of the seven fixtures
  Typeless returned numbered lists, bullets and invented headings, so its line count
  there is list structure and not paragraphing.

N was never the binding constraint in this round, which is the one useful thing that
can be said about it: arm 7 obeyed it perfectly and the result was still wrong.

## Limits — what these numbers are not

- **No `PolishPipeline`.** Declared in bars.md §5 before the round. No guardrail, no
  acceptance contract, no `<<NL>>` round-trip. A design that held these bars would
  still have to be re-measured inside the pipeline before it could ship, and this
  round does not clear that step.
- **Mac, not iPhone.** Same foundation-model family, different revision and state.
  No latency number here is a device number.
- **Seven texts, one language, one speaker.** French only.
- **No blind rubric.** bars.md §9 named this as a risk and it stands: the judgement of
  record on placement is a human reading the outputs. This round produced the outputs
  and the agreement numbers; it did not perform a blind rubric on its own work. The
  outputs are in `raw/` for exactly that reason.
- **The sentence cut is a dependency.** `NLTokenizer(unit: .sentence)` decides what a
  boundary is for arms 5, 6, 6b and 7 and for bar 2 everywhere. It is printed once per
  fixture in the captures so it is auditable. It reads P6's 1 161 characters as **6**
  sentences and P5's 1 240 as **26**, which is a fourfold difference in granularity
  between two texts of almost the same length, and it is the reason a character-based
  N and a sentence-based cut do not sit comfortably together.

## What a future attempt should not repeat

1. **Do not lighten the prompt.** The 6 KB prompt is what keeps the model from
   answering the transcript instead of formatting it. Measured: 30 fidelity failures
   in 35 runs at the floor, two of them with invented headings.
2. **Do not ask Apple FM to rank.** It enumerates, 34 of 35. A design that truncates
   its ranking is a positional rule that pays for a model call.
3. **Structuralising a bar does not buy the judgement behind it.** Fidelity, boundary
   discipline and the count were all moved into code successfully and cheaply. The
   thing that was hard stayed hard, and it was never any of those three.
4. **The index route is the right shape for a model that can do this.** `paragraph`
   and its arms are committed and re-runnable against any future backend, the way
   #437's `probe-second-pass.json` and #439's `probe-isolated.json` are. It costs
   0.4–0.6 s and cannot violate the contract. It is answered *no* today for the same
   reason both of those are: **the model will do the operation and cannot tell where
   it belongs.** That is now three issues, three mechanisms and one conclusion.

## What is left, with its cost stated

- **Arm 6b is the only thing in this round with a pulse.** It is the one arm where the
  model genuinely chooses, it hits 45 % of the reference breaks, and it obeys the
  count half the time. Half a count and 40 extra breaks is not shippable, and nothing
  measured here suggests a prompt closes that gap — but it is the arm a different
  model would be probed with.
- **#523, the armed long-vocal mode, is unaffected.** It may transform, so the
  additive contract that makes this problem hard does not bind it.
- **The acoustic route stays dead.** The signal exists (§Timings) and the hypothesis
  that wanted it was falsified on the maintainer's own recordings before this round
  began.

## Timings — the issue body's first technical step, settled

The issue body gates its own acoustic route on one question and calls it the first
technical step: *is `ASRResult.tokenTimings` actually populated at runtime for
Parakeet, or merely declared optional in the type?* `DictusApp/Audio/ParakeetEngine.swift:169`
keeps `result.text` and drops the rest.

The pause hypothesis is dead, so nothing in this round depends on the answer. It is
settled anyway, because it is cheap and it tells any future attempt whether there is a
signal to work with. Measured headlessly on this Mac, against FluidAudio at the pinned
`0.12.3`, through the same `AsrManager.transcribe([Float])` the app calls.
`timings-probe/` is the package; it drives no Apple Foundation Model.

**It is populated. Never nil, one entry per subword token, on both code paths.**

| Clip | Seconds | Path | `tokenTimings` | Entries | Coverage |
|---|---|---|---|---|---|
| no deliberate pauses | 14.0 | single window (≤ 240 000 samples) | non-nil | **91** | 0.00 → 13.92 s |
| one 1.5 s pause | 8.8 | single window | non-nil | **45** | 0.00 → 8.72 s |
| two 1.2 s pauses | 22.1 | `ChunkProcessor` | non-nil | **130** | 0.00 → 22.08 s |
| two 1.5 s pauses | 22.7 | `ChunkProcessor` | non-nil | **133** | 0.00 → 22.64 s |

**And a deliberate silence does reach the field, as an inter-token gap.** On the 8.8 s
clip the single inserted 1.5 s pause is the **only** gap of 0.15 s or more in the
recording, at 0.80 s. On the 22.7 s clip the two inserted 1.5 s pauses are the two
largest gaps, 0.56 s and 0.72 s, both immediately after a sentence-final full stop.

Three caveats, and they matter more than the headline:

- **The gap under-reports the silence by roughly half.** 1.5 s of inserted silence
  reads as 0.56–0.80 s, because the token durations either side absorb part of it and
  the encoder frame is 80 ms. A threshold fitted on wall-clock silence would not
  transfer to this field unchanged.
- **It is noisy.** The 22.7 s clip also shows a 0.40 s gap **inside a word**
  (`ch|antiers`) and 0.16 s gaps mid-phrase. The largest gaps are the real pauses here,
  but a bare threshold would fire on neither cleanly.
- **This is `say`, not a person.** Synthetic speech settles whether the field carries
  data and whether a silence reaches it. It says nothing about how a human voice
  distributes pauses, and the acoustic route is falsified on human recordings anyway.

So: the signal exists and is thrown away on one line. That is a fact about the code,
not an argument for using it — the hypothesis that wanted it is dead.

## To test by hand

Nothing here changes an app target, so there is nothing to install on a device. What
is left to verify is a judgement this round is not entitled to make on its own work.

1. **Read what the winning arm produces.** Open
   `raw/round2-confirm-10runs.txt` and search for `7-index-ranked`. Each run prints
   the sentence cut, the indices returned, and the reassembled text. Expect the
   paragraphs to fall at the head of every fixture — three short paragraphs then one
   long block — and expect them to be identical run to run.
2. **Compare fixture 7 against your own Typeless output.** `P7-89s` is the 89 s
   sample from 2026-09-11. The Typeless paragraphing is in the issue body. Expect the
   reference to break before sentences 2, 5 and 8, and the arm to break before 2, 3
   and 4.
3. **Decide whether 45 % agreement with 40 extra breaks is worth a second call.**
   That is arm 6b, the only arm where the model chooses. The round reports the number
   and does not rule on it — bars.md §6 declares placement and latency reported, never
   barred, and the go/no-go on paying for a second call is yours.
4. **Re-run the round if you want the numbers regenerated.** Needs Apple Intelligence
   on this Mac, takes about 25 minutes for all eight arms:
   ```sh
   cd DictusCore
   swift run polish-harness paragraph Sources/polish-harness/fixtures/paragraph-fr.json \
     --runs 5 --json /tmp/capture.json \
     $(for a in ../docs/research/550-paragraph-placement/arms/*.json; do echo --arm $a; done)
   python3 ../docs/research/550-paragraph-placement/score.py /tmp/capture.json
   ```
5. **Re-run the timings probe if you want it confirmed on a real voice.** The
   committed numbers are `say`-generated speech. `timings-probe/README.md` has the
   two commands; point it at a Voice Memo exported to 16 kHz mono WAV instead and
   expect the same answer — non-nil, one entry per subword token — with the pause
   gaps distributed differently.

What the automated gates already covered, and what you do not need to repeat:
`cd DictusCore && swift test` (1 912 tests, 1 skipped, 0 failures) and
`swiftlint lint --strict` (clean). No app target was built because no app target
changed.
