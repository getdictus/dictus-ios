# Translate renders the spoken draft word by word (#648) — the harness bench

**Issue:** [#648](https://github.com/getdictus/dictus-ios/issues/648), step 1 of the "Order of
work" in the 2026-10-05 14:14 comment. **Date:** 2026-10-05. **Machine:** macOS 27.0 (26A428),
Apple Intelligence on. **Plan and bars:** [`bars.md`](bars.md) and [`bars.json`](bars.json),
committed in `699cde71` before the first call on a fixture; round 2's prompt in `4fd6e633`
before its first call.

## Verdict

**No arm clears the bars.** Every arm, the Translation framework included, keeps the
`no longer` inversion on fixture 05 (3/3 runs) and renders plain French with the wrong sense on
four of the six fixtures. None removes the false start on fixture 00. The 14:14 comment's
reading key gives a clear answer on both axes:

- **The inversions and wrong senses are not the chat model's alone.** The Translation framework
  (C) makes the same class of errors on the same spans: `made the appointment`, `professional
  features`, `no longer`, `feel`. It also adds one the Mac's Apple FM did not make here: `always`
  for `toujours`.
- **The cleaning pass is worth almost nothing, and it breaks things.** Two prompts, 72 runs. It
  never repaired a speech-to-text slip. It kept the unmarked false start and every opener tic. It
  cut the arm's (a) failures by at most 3 runs in 18. It costs a second Apple FM call (median
  +3.1 to +3.6 s on this Mac). On #412's fixtures it **dropped a dictated line break 5/5**,
  **translated an English dictation into French 5/5** and mixed French into Italian on 8 of 20
  runs.

**Recommendation for step 3:** do not ship the cleaning pass. If step 3 ships something for
2.0.0, the only candidate is **arm C (Translation `.highFidelity`, no cleaning pass)**. It is no
worse than today on the six fixtures. It holds #412's 30 bars with 30/30. It turns #412's one
known inversion (`avancer la deadline` → `push back`, 5/5 on A) into a neutral `move` (5/5). It
runs **2.2× faster** on this Mac (median 1.7 s against 3.7 s) and is deterministic. **It does not
fix #648.** The complaint stands under every arm measured, and closing it needs something this
bench did not contain (§6).

## 1. Method

Every call runs the real `PolishPipeline` under the shipped `translate.en` mode: same pre-pass,
same `<<NL>>` encoding, same gates, and the shipped contract (`0.40–3.00`, output = English)
judging the result. Only the engine differs between arms. Command (one arm):

```sh
cd DictusCore
swift run polish-harness translate <fixtures.json> --mode translate.en --runs 3 --label C \
  --translator translation-framework --strategy highFidelity \
  --bars ../docs/research/648-translate/bars.json --bars <private bars> --redact translate-fr-05 \
  --json <private capture> --public-json runs/arm-C.json --public-log runs/arm-C.txt
```

| Arm | Pass 1 | Translator | Runs |
|---|---|---|---|
| A | none | Apple FM, shipped prompt | 6 × 3 |
| B | none | Translation `.lowLatency` | 6 × 3, **all `notInstalled`** (§5) |
| C | none | Translation `.highFidelity` | 6 × 3 |
| D | Apple FM, `clean-v1` | Translation `.highFidelity` | 6 × 3 |
| E | Apple FM, `clean-v1` | Apple FM, shipped prompt | 6 × 3 |
| D2, E2 | Apple FM, `clean-v2` (round 2, in-sample) | as D, E | 6 × 3 each |

Then #412's fixtures (`translate-en.json`, 6 × 5 = 30) on A, C, D and E.

**Fixtures:** the six device raws in `.local-corpus/648-translate/fixtures.json` (git-excluded).
Their texts appear in `runs/*.txt`, except `translate-fr-05`, a personal opinion, whose raw,
cleaned text and outputs are redacted everywhere in this folder (`TranslateScore.redacted()`,
pinned by `TranslateBarsTests`). Its counts and the two spans the issue already quotes are kept.

**Scoring:** each output is scored mechanically against `bars.json`, then **read by hand**. The
mechanical flags are candidates, not verdicts. Every place where the reading overturned one, or
added one the regexes missed, is listed in §3 and marked as judgement. The rule I applied for (a):
a disfluency counts as surviving when it is rendered as a literal calque or kept as an abandoned
clause (`I also wanted to talk, I wanted…`, `concretely`, `at that moment`, `Yes, look,`, `well
listen, uh`). Natural English discourse markers that keep the register (`Alright`, `Basically`,
`So`) do not count.

## 2. Results, six device fixtures

Runs failing each bar, out of 18, after the hand reading. **(d)** is the output language plus
register; **(e)** is a registered critical span; `no longer` is one of the two inversions the
thresholds name (the other, `skip`, never occurred on this Mac).

| Arm | Accepted | (a) | (b) | (c) | (d) | (e) | `no longer` | Mac latency, median / max | Shippable |
|---|---|---|---|---|---|---|---|---|---|
| A | 18/18 | 12 | 0 | 3 | 2 (register, mild) | 15 | 3 | 3 708 / 7 562 ms | no |
| B | **0/18** | – | – | – | – | – | – | – (`notInstalled`, 5–16 ms) | not measured |
| C | 18/18 | 12 | 0 | 3 | 0 | 12 | 3 | **1 675 / 4 445 ms** | no |
| D | 18/18 | 12 | 0 | 3 | 0 | 12 | 3 | 4 670 / 10 597 ms | no |
| E | 18/18 | 11 | 0 | 3 | 2 (register, mild) | 15 | 3 | 6 799 / 13 421 ms | no |
| D2 | 18/18 | 11 | 0 | 3 | 0 | 12 | 3 | 5 305 / 10 280 ms | no |
| E2 | 18/18 | 9 | 0 | 3 | 2 (register, mild) | 15 | 3 | 7 094 / 13 137 ms | no |

Per fixture, what fails (all arms unless named):

| Fixture | (a) | (c) | (e) |
|---|---|---|---|
| 00 | `I also wanted to talk, [I wanted]…` 3/3 in every arm; C adds `finally` 3/3 | – | – |
| 01 | `also` opener: A, C 3/3; D, E 2/3; D2, E2 0/3 | – | `professional features` 3/3 everywhere |
| 03 | `concretely` / `at that moment` 3/3 everywhere | `from the foot` for `piedus` 3/3 everywhere (E2 once `footpad`) | `the vocal was too short`: A, E, E2 3/3. C, D, D2 write `voice` and pass |
| 04 | `Yes, look/listen,` 3/3 everywhere; C keeps `uh` | – | `made the appointment` 3/3 everywhere |
| 05 | – | – | `no longer` 3/3 everywhere. The `who's the problem` grammar error: 0/3 everywhere |
| 06 | `So there you go`: D 1/3, D2 2/3 | – | `feel` for `sentir` (= `sortir`) 3/3 everywhere; `always` for `toujours`: C, D2 3/3; A, D, E, E2 0/3 |

Latency per pass for the two-pass arms (Mac): cleaning median 3.1 s (v1) to 3.6 s (v2), max
6.4 s; the Translation framework median 1.6 to 1.7 s; Apple FM translate after cleaning median
3.4 to 3.6 s.

**The cleaning pass, read on its own** (the `clean:` lines in `runs/arm-D*.txt` and
`runs/arm-E*.txt`):

| What the contract asks of step 2 | `clean-v1` | `clean-v2` |
|---|---|---|
| Drop a self-correction marked by `enfin` | 00 6/6, 01 6/6; **06 0/6** | same |
| Drop an unmarked false start (`aussi je voulais parler,`) | 0/6 | 5/6 dropped `aussi`, **0/6** dropped the clause |
| Drop opener tics (`concrètement`, `écoute`, `donc voilà`) | 0 | 0 (v2 drops `donc` before `concrètement` only) |
| Repair an obvious slip (`piedus`, `sentir`, the dropped `à` in 05) | **0/18** | **0/18** |
| Keep the register | adds the `ne` of a negation in 05 6/6 and 06 2/6 | still 6/6 in 05, against its own counter-example |

This matches what the project already measured: Apple FM cannot repair a homophone, whatever
the prompt (#439's capability probe). `clean-v2` was written after reading `clean-v1`'s outputs on
these fixtures, so it is in-sample (`bars.md` §7), and even so it did not move the slips.

## 3. Where the reading overturned or added to the mechanical flags (judgement)

- **(a) 04, arm A runs 1 and 2:** `Yes, look,` renders `bah écoute`. The regex knew `listen`
  only. Added.
- **(b) 05, arm A run 3:** `I'm not necessarily with you` still disagrees; the regex wanted
  `agree`. Overturned (the fact is kept).
- **(c) 03, every arm:** `directly from the foot` (`du piedus`, ASR for "Dictus") gives a garble
  a meaning. It is the same class as the device's `keypad`, and the 13:29 comment's bar is "not
  worse than raw". Added, 3/18 per arm.
- **(d) 01, D and D2 run 1:** `NLLanguageRecognizer` read an English output as `ca`. The
  pipeline's own contract accepted it. Overturned.
- **(d) register, 03, A, E, E2:** 2 runs in 3 drop every contraction (`I am testing… it is not
  working… we do not apply it`) on a casual note to self. Mild, counted, decides nothing (these
  arms fail (e) regardless).
- **(e) 03:** the mechanical check wanted `voice message`. `the voice was too short` (C, D, D2)
  keeps the sense, weakly, so I passed it. `the vocal was too short` (A, E, E2) is a calque and
  fails. 06's `transcribing vocals` (A, E) is a wrong sense too, inside runs that already fail on
  `feel`.
- **Not registered, reported:** 06 `je suis rendu pas trop mal` (I'm not doing badly) comes back
  as `I've gotten not too far` in A (3/3), E (1/3) and E2 (1/3), which reverses it. It was not
  in the bars, so it is not counted.

## 4. #412's bars on the arms (30 runs each)

None of the arms is shippable, so §4.2 of the plan pre-registered only arm A as the control. C,
D and E were run anyway, because step 3 needs them. They are reported here and did not change any
verdict above.

| Bar (#412) | A | C | D | E |
|---|---|---|---|---|
| A1 accepted output not English | 0/30 | 0/30 | 0/30 | 0/30 |
| A2 refused | 0/30 | 0/30 | 0/30 | 0/30 |
| A3 invented greeting / sign-off / name | 0/30 | 0/30 | 0/30 (one invented clause, below) | 0/30 |
| A4 proper noun / key term lost | 0/30 | 0/30 | 0/30 | 1/30 (`dental appointment`: meaning kept, string missed) |
| A5 `<<NL>>` leak or **lost line break** | 0/30 | 0/30 | **5/30** | **5/30** |
| T2 `avancer la deadline` (not a #412 bar; #412 reported it) | `push back` 5/5 (inverted) | `move` 5/5 (neutral) | `move` 5/5 | `push (back)` 5/5 |
| Median / max ms | 1 820 / 2 391 | 809 / 1 416 | 2 406 / 3 638 | 3 358 / 4 110 |

What the bars do not show:

- **C on T6 (already English) returns the raw untouched, unpunctuated**
  (`hey so I just got off the phone…`). The cause is the adapter: the framework refuses an
  `en → en` pair, so the engine returns its input. The shipped prompt's rule 8 asks for the
  text "polished but not otherwise changed". A shipped C has to route a same-language input to the
  free polish rather than return it raw.
- **C keeps `uh`** on T2 (`and uh I said`), as on fixture 04.
- **The cleaning pass, on D and E:** T5's line break dropped 10/10 (`On se voit demain matin
  devant l'entrée. Prends les badges au passage.`). T6, an English dictation, rewritten **in
  French** 10/10 (`Hey, je viens d'avoir parlé avec le fournisseur…`). The Italian fixtures (T3,
  T4) mixed with French on 8/20 (`Alors, tu sais, volevo dirti… parce que j'ai une chose du
  dentiste`). One of those became `So, would you tell me, I wanted to tell you…` in D's final
  output: an invented clause.

## 5. Arm B and the Translation framework on this Mac

Measured (headers of `runs/arm-*.txt` and the feasibility probe in `bars.md` §1):

- `.highFidelity` fr → en and it → en: `installed`, no download, works headless from a SwiftPM
  executable.
- `.lowLatency` fr → en: `supported, NOT installed`. Every call throws
  `TranslationError.notInstalled` in 5 to 16 ms. `canRequestDownloads` is `false` from a CLI
  process, so the model cannot be installed without UI. **Arm B is unmeasured** and is on the
  manual list.
- A session built for the wrong source **returns the text untranslated, without an error**.
  The engine therefore passes the language `PolishLanguageMix` reads. A shipped engine has to do
  the same and must not let the framework guess.
- A newline comes back as a blank line. The engine carries line breaks by splitting on `<<NL>>`,
  and T5 held 5/5 on C.
- `.highFidelity` is **deterministic** here: the 3 runs of every fixture are byte-identical. For
  C, N = 3 is one sample.

## 6. What this does not settle, and what would

- **The Mac's Apple FM is not the device's.** Arm A on this Mac did **not** reproduce the
  device's `skip the marketing phase`, `vowel`, `always`, `a tool`, `keypad` or `who's the
  problem` (0/3 each). It made other errors on the same spans (`foot`, `vocals`, `with a that will
  be available`). Mac quality transfers as a class, not span by span, and the two inversions the
  issue leads with cannot be measured as fixed here.
- **The one-prompt variant was not an arm.** The issue body's open question ("a separate first
  pass, or one prompt?") lost its one-prompt side when the 14:14 comment set arms A to E. The
  closest evidence is indirect: given the dedicated task with the contract's rules and
  disfluent worked examples, Apple FM still kept the false starts. That suggests, but does not
  measure, that the same rules folded into the translate prompt would not do better.
- **The residual errors are lexical.** `faire le rendez-vous`, `fonctionnalités pros`, `sentir`
  for `sortir`, a dropped `à`: both model families translate the words they are given, and no
  cleaning pass gave them better words. Closing #648 needs either a model that repairs a French
  homophone in context, which the project has measured Apple FM cannot do, or accepting that
  limit and saying so in the product.
- **N = 3 on six fixtures.** A 3/18 is three runs of one fixture, not a rate.

## Files

- `bars.md`, `bars.json` — the plan and the bars, pre-registered.
- `prompts/clean-v1.txt`, `prompts/clean-v2.txt`, `prompts/clean-v1-framing.txt` — the cleaning
  pass (research only; not in DictusCore, not a Smart Mode).
- `runs/arm-{A,B,C,D,E,D2,E2}.{txt,json}` — every run on the six fixtures, fixture 05 redacted.
- `runs/412-{A,C,D,E}.{txt,json}` — #412's fixtures on four arms.
- Harness: `DictusCore/Sources/polish-harness/TranslateRound.swift` (command and engines),
  `DictusCore/Sources/PolishFidelity/TranslateBars.swift` (scorer, redaction),
  `DictusCore/Tests/DictusCoreTests/TranslateBarsTests.swift`.
