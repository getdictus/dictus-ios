# #996: a local language model reranks the space bar's correction and predicts the next word

iOS 26.5 simulator (iPhone 17, slimmed), 2026-11-21. llama.cpp `4783b114`, CPU only, built
by `tools/keyboard-lm/build-llama.sh`. Models in `~/dev/swipe-models/`:
`qwen2.5-0.5b-instruct-q4_k_m.gguf` (491 MB) and `SmolLM2-135M.Q4_K_M.gguf` (105 MB).
Nothing here was measured on a device.

## Verdict

- **Target not met on pierre-device.** At the chosen weight the model fixes 1 of the 16
  words today's keyboard gets wrong (`j'ak` → `j'ai`) and keeps the 11 guards. The target
  was 8 of 16.
- **#954 target met.** 0 broken words and no new miscorrection in fr, en, en-typos, es and
  de. No autocorrect outcome changes on those runs.
- **Next word in the bar's top 3**, Qwen2.5-0.5B: fr 17.4% → 33.3%, en 20.7% → 45.9%,
  en-typos 27.5% → 47.7%, es 22.5% → 36.7%, de 18.0% → 19.7%. The issue asks for 35% in
  fr and en: en passes, fr misses by 1.7 points.
- **SmolLM2-135M is not usable outside English.** At the smallest weight it adds a
  miscorrection in es and de, and its next words drop fr to 12.1% and de to 4.9%.
- **Memory**, Debug build in the simulator: Qwen adds 42 MB once loaded and 41 MB after
  typing (two runs of three; the third read 48 / 49). The issue's budget is 45 MB.
- **Time**, simulator on a loaded Mac: the model takes 13.6 to 37 ms (p50) per letter it
  scores and 14 ms (p50) per space. The 15 ms budget is met at the median of a space, not
  at p95. The issue's < 10 ms p95 on a device is not shown here and is unlikely.

## How it works

The trie and `CorrectionRanking` decide as before. When they replace the typed word, the
model scores their five best candidates as the space bar would write them (casing and
`j'` included), after the paragraph so far: the log-probability of each candidate's
tokens. Each candidate's score gets `w × (its log-probability − the best one's)`, and
`CorrectionRanking.rerank` decides again. A word the ranking keeps stays kept.

After a space, the bar shows the model's likeliest next words that the dictionary or
the user knows, then the n-gram words.

The model runs on its own queue. A caller waits 15 ms at most. The suggestion bar asks
at every keystroke, so the space bar usually finds the finished word's answer in the
cache. A request still waiting is replaced by a newer one. A secure, password, URL or
one-time-code field gives the model no text (`HostFieldPolicy.languageModelAllowed`).

## Choosing w (`sweep-qwen.md`, `sweep-qwen-fine.md`)

The rule: the largest number of fixed words on #954 with 0 broken words and no new
miscorrection. On #954 the rerank fixes nothing new at any weight, so the rule reduces to
"no new miscorrection":

| w | first new miscorrection on #954 |
|---|---|
| ≤ 0.015 | none |
| 0.0175 | es `estaea`: `estará` → `estaba` |
| 0.08 | also fr `Ul` → `Je`, en `Shr` → `Str`, de `Wor` → `Dir` |
| 0.12 | also en `atill` → `will`, es `Td` → `De` |

Every weight up to 0.015 ties on #954. **w = 0.01** keeps a margin below 0.0175. The
pierre-device table was read at every weight and did not pick w: at 0.015 it gives 3
fixes and loses the `sats` guard.

## pierre-device (`compare-final.md`)

27 cases, typed on the French AZERTY page from the words of Pierre's sessions of
2026-11-20 and 2026-11-21 (`tools/keyboard-bench/corpus/fr-pierre-device.*`). Taps land on
the key centres. The journals themselves were not on disk. Where the brief gives no
previous word, the case starts the field, which capitalises it and gives the model no
context at all. `sôt` gets the previous word `ils`: at the start of a field, today's
keyboard keeps `Sôt`, while the brief says it writes `sont`.

| typed | before it | meant | off | Qwen w=0.01 | why the model cannot fix it at this weight |
|---|---|---|---|---|---|
| `trouce` | Je | trouve | trouvé | trouvé | `trouve` and `trouvé` are close readings; the pick goes by frequency, and the model would need w ≥ 0.015 |
| `triuce` | Je | trouve | trouvé | trouvé | same |
| `j'aa` | | j'ai | j'la | j'as | `ai` is not among the five candidates scored |
| `j'ak` | | j'ai | j'au | **j'ai** | |
| `lz` | | la / le | l'z | l'z | the contraction rule writes it, not the trie |
| `Lnction` | | fonction | onction | onction | from w = 0.03 the model picks `section`, never `fonction`, with no previous word to go on |
| `pasqueil` | | parce qu'il | pasque | pasque | the trie offers only `pasque` |
| `J'ainhate` | | j'ai hâte | kept | kept | no candidate |
| `J'aintrouve` | | j'ai trouvé | kept | kept | no candidate |
| `integté` | | intégré | kept | kept | the ranking keeps it; the model never turns a kept word into a correction |
| `Fràvhelent` | | franchement | kept | kept | same |
| `ma'qje` | | manque | ma'que | ma'que | the trie corrects `qje` after `ma'` |
| `dizcitd` | | discord | discute | discute | needs w ≥ 0.08 |
| `we` | Bon | we | de | de | the model never keeps a word the ranking corrects |
| `honetre` | | honnête | monstre | contre | `honnête` is not among the candidates |
| `qur` | Passai | que | sur | sur | needs w ≥ 0.12 |
| 11 guards | | | right | right | |

The typed text from the real keyboard in the simulator is the replay's, word for word,
on the first eight cases with the model off and on (`keyboard-in-simulator/cases-*.tsv`):
`J'aa` → `J'as` and `J'ak` → `J'ai` with Qwen, `J'la` and `J'au` without.

## What was tried and not kept

| variant | #954 at its smallest weight | pierre-device | file |
|---|---|---|---|
| shipped: rerank a correction, w = 0.01 | unchanged | 1 of 16, 11 of 11 guards | `sweep-qwen-fine.md` |
| the model may also turn a kept word into a correction (scores against the typed word) | fr `decalee` → `déclaré`, de `heisa` → `beide`: 2 new miscorrections at w = 0.01 | | `sweep-qwen-promoting.md` |
| the model picks among close readings first | unchanged at w = 0.0001; en-typos +1 miscorrection at 0.005 | 4 of 16, 10 of 11 guards (`sats` → `Sans`) | `sweep-qwen-close-readings.md` |
| SmolLM2-135M, shipped rule | es +1 and de +1 miscorrection at w = 0.01 | 0 of 16, 10 of 11 | `sweep-smollm2.md` |
| a word-boundary term per candidate | | | dropped for time: one more output row per candidate, about 5 ms each for Qwen |
| next words extended token by token | fr top 3 38.6% instead of 33.3% | | 40 to 60 ms per space: dropped |

The close-readings variant is the one to try on the device. It fixes `trouce`, `triuce`,
`j'ak` and `qur` and leaves #954 unchanged, at the cost of `sats` at the start of a
field, a case whose real context was a previous word.

## What reaching 8 of 16 would take

1. **Candidates.** 7 of the 16 words cannot be fixed by any rerank: the answer is not
   among the trie's candidates (`pasqueil`, `J'ainhate`, `J'aintrouve`, `honnête`,
   `ma'qje`, `j'aa` in the top five), or a rule writes the word (`lz`). A model that
   generates candidates from the keys touched, rather than reranking the trie's, is the
   architecture that can.
2. **A calibrated model score.** Qwen's log-probability gaps between candidates run to 5
   to 20 nats, so the weight at which they decide close readings (≥ 0.015) is the one at
   which they start overriding sound corrections (0.0175). The sweep shows no weight that
   separates the two on #954.
3. **The real context.** 12 of the 27 cases start the field here. A sentence start gives
   the model a unigram prior and nothing else, which is where it is weakest
   (`Ul` → `Je`, `Boir` → `Noir` at higher weights).
4. **A larger model.** Not measured. Qwen2.5-1.5B would be about three times the time
   per output row, which the 15 ms budget does not allow on the CPU.

## Memory (`memory.tsv`)

`tools/keyboard-lm/sim-memory.sh`, Debug build (the switch is Debug-only), the keyboard's
`phys_footprint` from `footprint -p`: 8 s after it appears, then after typing five French
sentences.

| model | after appearing | after typing | added, appearing / typing |
|---|---|---|---|
| off | 33, 33, 33 MB | 41, 40, 41 MB | |
| Qwen2.5-0.5B | 75, 75, 81 MB | 82, 82, 90 MB | +42 to +48 / +41 to +49 |
| SmolLM2-135M | 52, 52, 59 MB | 57, 55, 64 MB | +19 to +26 / +15 to +23 |

The weights are memory-mapped and not counted. What is counted: the compute buffer
(about 19 MB for Qwen, set by `n_ubatch` 32 and the 152k vocabulary), the logit rows,
the KV cache. A first version used 57 MB for Qwen: it kept a table of every token's text
(152k small arrays) and 16 logit rows per decode.

## Time

One replay per model, machine load 5 to 28 on 14 cores: a ballpark, not a device number.
Model time per request, from the bench's `lm_ms`:

| | Qwen p50 / p95 | SmolLM2 p50 / p95 |
|---|---|---|
| per letter it scores, fr | 13.6 / 62 ms | 12.0 / 31 ms |
| per letter, es | 37 / 85 ms | 19 / 39 ms |
| per space (next words), fr | 13.9 / 36 ms | 8.2 / 12 ms |

The limiter is the output layer: one pass per logit row costs about 5 ms on the Mac's CPU
for Qwen's 152k-token vocabulary. A throwaway probe on the Mac scored 1, 3, 5 and 10
readings of `trouv…` after a cached context in 0.1, 0.1, 8.8 and 30 ms (median of 7): the
first three are one token each and need no row beyond the context's. Each further token
of a reading costs a row.

## Build and size

llama.cpp enters through `DictusCore/Package.swift`: a binary target when
`DictusCore/LocalLlama/llama.xcframework` exists (gitignored, written by
`build-llama.sh`), nothing otherwise. CI and every other checkout build as before, and the
model code compiles out (`#if canImport(llama)`).

| Release, iOS device | without llama.cpp | with |
|---|---|---|
| DictusKeyboard binary | 11.9 MB | 16.6 MB |
| DictusApp binary | 53.8 MB | 58.3 MB |
| app bundle | 126 MB | 144 MB |

DictusCore links into every target, so the app, the widgets and the share extension carry
llama.cpp too when it is present. A build cut from a checkout that ran `build-llama.sh`
would ship it, unused: the switch is Debug-only.

Xcode caches the manifest's evaluation per package path (observed: a worktree resolved
before the xcframework existed did not pick it up, and one resolved with it failed to
resolve once it was removed). Run `build-llama.sh` before the first package resolution of
a worktree.

## Reproduce

```bash
tools/keyboard-lm/build-llama.sh
xcrun simctl boot <udid>
tools/keyboard-bench/run.sh --udid <udid> --langs fr,en,en-typos,es,de,fr-pierre-device --out build/996/off
tools/keyboard-bench/run.sh --udid <udid> --langs fr,en,en-typos,es,de,fr-pierre-device \
    --lm ~/dev/swipe-models/qwen2.5-0.5b-instruct-q4_k_m.gguf --lm-weights 0.01,0,0.0125,0.015,0.0175,0.02 \
    --out build/996/qwen
python3 -I tools/keyboard-lm/compare.py --cases off=build/996/off qwen=build/996/qwen/w0.01
```

Two replays must never run on one simulator at once: the bench writes the language,
the layout and the learned words to its App Group.

`swift test` with `KEYBOARD_LM_MODEL=<model.gguf>` runs `LlamaLanguageModelTests` against
the real model; without it they are skipped.

## After merging develop (#1005, `a06e3e11`)

`c3cdf635`, same simulator and recipe. The model-off replay (`off-report.md`) and Qwen at
w = 0.01 (`qwen-w0.01-report.md`) give the numbers above, word for word: no change on
#954 beyond the next word, 1 of 16 pierre-device cases and 11 of 11 guards. On that tree:
`swift test` 3741 tests, 0 failures, 8 skipped (the five model tests among them, no
`KEYBOARD_LM_MODEL`); `swiftlint lint --strict` clean; DictusApp builds for the simulator
in Debug and Release; `scripts/simulator-smoke-test.sh` passed on `b6c4edb1`.
