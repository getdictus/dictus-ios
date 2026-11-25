# Key-target resizing: the measured spike (#949)

Step 1 of #949: does choosing each letter from where the finger landed *and* from the
letter the word needs next, as in Gunawardana, Paek and Meek (*Usability Guided
Key-Target Resizing for Soft Keyboards*, IUI 2010), type fewer wrong letters than the
Dictus keyboard's plain hit test, without new errors on rare words, in under 1 ms per
tap? Measured 2026-11-17 with the #954 keyboard bench, on develop at `2e280b7f`, iPhone 17
simulator, iOS 27.2. No app code changes; the model lives in `tools/keyboard-bench/`.

## Verdict: go, for step 2

- **Wrong letters halve.** On 13 000 held-out letter taps: French 199 → 91, English
  190 → 92. A sloppier typist: −30 % in both languages.
- **Wrong words in the final text go down too, less**: French 144 → 137, English
  72 → 50 of about 1 550 words. Autocorrect already repaired most of the letters the model
  now gets right. In French, half the remaining wrong words are a missing accent, which
  no key choice can fix.
- **Rare words: net better, not zero new errors.** On words the dictionary lacks or ranks
  low, the model fixes 21 French and 16 English letters and breaks 3 and 12 that today's
  hit test got right. Wrong words: 105 → 104 and 91 → 90. Read literally, the issue's
  bar "without new errors on deliberately typed rare words" is not met. It is met read
  as *no net increase in errors*. **Pierre decides which reading holds** before step 2.
- **Time: under 20 µs per tap at p95 on the simulator; the slowest single tap varies
  from run to run, up to 283 µs.** The device was not measured. The device-independent cost is at most 3 941 trie nodes visited per tap; a
  frequency sum stored per node in the dictionary file would bring that to the length of
  the word.
- **The top-row dead bands disappear by construction**, as long as step 2 takes the raw
  touch point, not `indexPathForItem(at:)`. Of the 30 taps across all sets that land in
  a band measured in #954, where the real keyboard types nothing today, the model types
  the intended letter for 23.
- **The n-grams add nothing measurable.** The trie alone carries the gain. Step 2 should
  not read the n-grams on the keystroke path.

## The model

For a tap at point *p*, while the word typed so far is *w*:

```
score(k) = −½ · ((dx_k / σx)² + (dy_k / σy)²)  +  λ · log P(k | w)

P(k | w) = (M(w + k) + f · M) / (M · (1 + f · n))
```

- `dx_k`, `dy_k`: distance from *p* to the centre of letter key *k*, in key widths and
  row heights. σx = σy = 0.25.
- `M(w + k)`: summed corpus frequency of every dictionary word that starts with *w* + *k*,
  accents folded (`tres` counts toward `très`). Read from the same
  `<lang>_spellcheck.dict` the keyboard ships: the trie stores `65535·ln(1+count)/ln(1+max)`
  per word, which the model turns back into a count. M is the sum over the *n*
  candidates.
- λ = 1, floor *f* = 0.1.
- **Guardrails.** A tap within 0.25 key of the centre of the key under it types that key,
  whatever the model says. The floor also bounds the language term at
  λ · ln((1 + f) / f), so no boundary between two keys moves by more than
  σx² · λ · ln((1 + f) / f) = **0.15 key width**. A tap within 0.35 of a key's centre is
  therefore always that key: with these values the 0.25 core is redundant (measured: a
  0.35 core with floor 0.1 gives the same letters on the committed, held-out and rare
  sets). It stays as the stated guarantee should the parameters change.
- **Scope.** Candidates are the letter keys within 1.5 key widths and 1 row of the tap. A
  tap on space, shift, delete, return, 123 or the AZERTY accent key keeps today's
  behaviour. A tap in a gap between two keys, where today's hit test finds no cell, goes
  to the model. Language data missing → M = 0 → the touch term alone, i.e. the nearest key centre.
- **Cost.** The prefix sum walks the trie under *w* + *k* for each candidate. The sums for
  one-letter prefixes are computed once when the dictionary loads (about 30 numbers);
  without them, the first letter of every word walked up to 18 000 nodes.

Code: `tools/keyboard-bench/KeyTargetModel.swift`. `run.sh --hit model` swaps it in for
the plain hit test; everything downstream (accent key, suggestions, autocorrect at each
space) is the shipping code, as in every #954 replay.

## Runs

| Set | What | Letter taps fr / en |
|---|---|---:|
| committed | the #954 runs, seed 954: **the parameters were chosen on this set** | 669 / 629 |
| held-out | same 20 sentences per language, seed 949, 10 passes: **the verdict is read here** | 6 690 / 6 290 |
| sloppy | same sentences, seed 950, 5 passes, landing spread 0.30 × 0.25 key instead of 0.22 × 0.18 | 3 345 / 3 145 |
| rare | `corpus-rare/`: 20 sentences per language built around words the dictionary lacks (`yuzu`, `figma`, `quokka`, `dictus`) or holds past its 5 000 most frequent (`fjord`, `lynx`, `pyjama`), seed 949, 5 passes | 1 745 / 1 565 |

The touch model of every set is the #954 one: Gaussian landing offsets, chosen, not
measured (`docs/keyboard-measurement.md`).

## Results

Full output, broken taps and dead-band taps listed: [`comparison.md`](comparison.md).
Parameter sweep: [`sweep.md`](sweep.md).

| Set | lang | Wrong letters, today → model | Fixed | **Broken** | Letter changed | Wrong words, today → model | Same, accents ignored |
|---|---|---|---:|---:|---:|---|---|
| committed | fr | 13 → 6 | 8 | **1** | 1.3 % | 9 → 9 of 152 | 2 → 2 |
| committed | en | 21 → 12 | 9 | **0** | 1.4 % | 9 → 7 of 157 | 9 → 7 |
| held-out | fr | 199 → 91 (−54 %) | 116 | **8** | 1.9 % | 144 → 137 of 1 520 | 77 → 69 |
| held-out | en | 190 → 92 (−52 %) | 107 | **9** | 1.9 % | 72 → 50 of 1 570 | 72 → 50 |
| sloppy | fr | 495 → 345 (−30 %) | 161 | **11** | 5.3 % | 244 → 227 of 760 | 212 → 195 |
| sloppy | en | 425 → 293 (−31 %) | 155 | **23** | 5.9 % | 204 → 191 of 785 | 204 → 191 |
| rare | fr | 55 → 37 | 21 | **3** | 1.4 % | 105 → 104 of 455 | 105 → 104 |
| rare | en | 53 → 49 | 16 | **12** | 1.8 % | 91 → 90 of 425 | 91 → 90 |

- **Broken** is a tap today's hit test typed right and the model typed wrong. Letter
  changed is the share of letter taps whose letter differs between the two.
- Wrong words are counted after autocorrect, as `score.py` counts them.
- **Autocorrect never breaks a correctly typed common word in either mode** (0 in every
  set). On the rare set it changes 73 French and 51 English correctly typed words in
  both modes: that is autocorrect against words it does not know (#498), not this
  model. English miscorrections on the rare set go from 15 to 21.

### Time per tap

`hit_ns`: today's hit test plus the model, around the pick only, on the replay's thread.
Simulator on an Apple-silicon Mac, from `comparison.md`. The max moves between runs: across
the four full runs made for this report, the slowest single tap was 283 µs (rare set,
French), the held-out max ranged from 56 to 168 µs.

| Set | lang | today p50 | model p50 | model p95 | model max | trie nodes p95 | nodes max |
|---|---|---:|---:|---:|---:|---:|---:|
| held-out | fr | 0.2 µs | 0.5 µs | 14.5 µs | 56.0 µs | 772 | 3 941 |
| held-out | en | 0.3 µs | 0.7 µs | 14.0 µs | 80.8 µs | 626 | 2 913 |
| sloppy | fr | 0.2 µs | 0.7 µs | 17.1 µs | 58.8 µs | 937 | 3 941 |
| sloppy | en | 0.4 µs | 1.1 µs | 16.8 µs | 53.9 µs | 816 | 2 913 |

More than half the taps visit no trie node: a tap inside the core, a space, or the first
letter of a word (the load-time table). The slowest taps are the
second letter of a word: four candidates, each walking every word under a two-letter
prefix. **The 1 ms budget on the slowest supported device is not demonstrated here**:
nothing measured here says how much slower than this Mac an A12 is.
Step 2 measures it on a device, and can remove the walk altogether: store each trie
node's frequency sum in the `.dict` file (`tools/dict_builder.py` and the C++ reader),
and the lookup becomes as long as the word.

### Top-row dead bands (#954)

#954 measured, on the real keyboard, bands of 0.2 to 0.6 pt on 4 of the 9 top-row
boundaries where a tap types nothing (`top-row-boundaries.txt`). The replay's grid has no
such bands, so `compare_hits.py --bands` counts the taps that land in one:

| Set | Taps in a band | Model types the intended letter |
|---|---:|---:|
| committed | 2 of 1 607 | 2 |
| held-out | 10 of 16 070 | 9 |
| sloppy | 15 of 8 035 | 11 |
| rare | 3 of 4 190 | 1 |

That is about one tap in a thousand that today types nothing on the real keyboard. The
model scores letter keys by distance to their centres, which is defined everywhere,
so a band cannot exist under it, provided step 2 feeds it the raw touch point.
`indexPathForItem(at:)` can stay for non-letter keys. The bands' cause was not
established: the replay's own gaps between cells are 1/9 pt, the measured bands are wider.

### What did not help

- **N-grams** (the words predicted after the previous word, added to the trie's mass):
  held-out English 50 → 47 wrong words, French 137 → 136, rare unchanged
  ([`sweep.md`](sweep.md)). Three words in 3 090, for a 50-word n-gram lookup per word on
  the keystroke path. Not worth it.
- **A stronger language term** (floor 0.01): slightly fewer wrong letters on held-out
  (85 / 86), but 23 and 24 broken rare-word letters, as many as it fixes. The floor is
  the parameter that keeps rare words typable.
- **A weaker one** (λ = 0.5, floor 0.1): fewest broken taps (4 / 4 held-out, 1 / 7 rare)
  but about a third less gain. It still breaks 1 French and 7 English rare-word
  letters, so it lowers the regression without removing it: no setting tried meets the
  bar read literally, and meeting it would take another approach.

## Limits

- **Synthetic touches.** Every tap is drawn from a Gaussian around the key centre, and the
  model's own touch term is a Gaussian of similar spread (0.25 against the runs' 0.22 ×
  0.18). That flatters the model. Real thumbs have per-key and per-hand biases (Gunawardana
  et al. fit theirs from recorded touches). A device run typed by hand (`score.py --typed`,
  `docs/keyboard-measurement.md`) is the check.
- **Small corpus.** 20 sentences per language, replayed with other seeds: the held-out set
  has new touch noise, not new words.
- **fr and en only.** de and es ship a trie of the same format and should behave the
  same; not measured.
- **Parameters chosen on the committed set and the rare constraint, not fitted.** Eight
  settings were tried ([`sweep.md`](sweep.md)); the held-out set was not used to choose.
- **Simulator timing**, as above.

## For step 2

1. Do the hit test from the raw touch point: plain cell for non-letter keys, the model for
   letter keys and gaps.
2. Walk the trie the engine already maps (a bridge method on the C++ `Trie`), with the
   first-letter table built at load. No second copy of the dictionary, no n-grams.
3. Measure the pick on the slowest supported device with the `KeyPress` signposts (#591).
   If over budget, add per-node frequency sums to the `.dict` format.
4. Replay with `tools/keyboard-bench/key_targets.sh` before and after, then a device run
   typed by hand, Apple's keyboard and Dictus back to back.

## Reproduce

```bash
xcrun simctl boot <udid>                                 # your own simulator, headless
tools/keyboard-bench/key_targets.sh --udid <udid>        # ~5 min: comparison.md
tools/keyboard-bench/key_targets.sh --udid <udid> --no-build --sets committed,held-out,rare \
    --model w=1,floor=0.01,core=0.25                     # one row block of sweep.md
```

The runs are drawn by `make_runs.py` with fixed seeds into `build/key-targets/`; the
replay is deterministic (two runs gave identical `taps.tsv`, `commits.tsv` and
`texts.tsv`, timings aside). `run.sh --hit plain` still reproduces the #954 baseline
byte for byte.
