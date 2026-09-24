# #575 fix — plan, written before any code

**Brief:** the "Decision (Pierre, 2026-09-24)" section of #575. The bar is meaning, not
wording: a dictated word replaced by a different word, or a meaning-bearing word deleted,
is refused; a register lift or a dropped politeness formula / sign-off is tolerated.
**Shape:** `findings.md` candidate B (D-lost), with an allow-list, on short input only.

## Where it runs (consumers mapped)

`PolishPipeline.transform` is the only place output checks run. The app
(`PolishService`, both the per-language and the auto path) and the keyboard (#361,
same `PolishService`) reach it. Which checks run is decided by the task's
`PolishAcceptanceContract`, one per task:

| task | contract | gets the new check |
|---|---|---|
| `.polish(.natural)` | `.natural` | **yes** |
| `.polish(.auto)` | `.auto` | **yes** |
| `.polish(.repair)` | `.repair` | no — it reconstructs words by design (ADR 0002) |
| `.smart(*)` | `SmartMode.contract` | **no** — the field defaults off, and no mode sets it |

So the switch is a new contract field, `refusesLostWords`, default `false`, set `true`
on `.natural` and `.auto` only. Same pattern as `refusesFabricatedIncompleteness`
(#587): decoded with a default of `false` so a snapshot written by an older build
never gains a refusal nobody measured.

## Ordered changes

1. **`PolishLostWords`** (new, DictusCore/Polish): `lostWords(polished:raw:languageCode:)`
   returns the dictated words missing from the output, after the licences below; empty
   means accept. Model-free, deterministic, no `NaturalLanguage` call except the
   off-language reading in step (g).
   - (a) Tokens: `PolishLexicon.fold` (case, diacritics), split on non-letter/digit,
     then split again at letter↔digit boundaries so `18h30` and `18 h 30` agree;
     `œ`/`æ` fold to two letters (amendment A1's fix).
   - (b) Rule 6: an immediately repeated word **or phrase of up to four words**
     collapses once in the input (`dès que dès que dès que`, `le comptable le
     comptable`). This is the shape of all 10 short-input false refusals in
     `findings.md` §5.
   - (c) Not counted: French function words (D-lost's `STOP`, **minus the negations
     `pas`, `plus`, `non` and the answer `oui`**, which carry meaning — the brief
     refuses a dropped negation), rule-7 fillers, the verbal-punctuation words, and
     single-letter tokens (elisions: `t'as` → `tu as` loses `t`).
   - (d) Rule 3: spoken numbers and their units (`deux`, `heures`, `euros`) may vanish
     when the output gained a digit.
   - (e) **The allow-list** (French, `PolishLostWordsLexicon.french`):
     - politeness formulas and sign-offs may vanish outright: `s'il te plaît`,
       `s'il vous plaît`, `stp`, `svp`, `merci` (+ `beaucoup`, `bien`, `d'avance`),
       `bisous`, `bises`, `à plus`, `à bientôt`, `bonne journée/soirée/…`,
       `cordialement`, `amicalement`, `je t'embrasse`, … Never a date-bearing one
       (`à demain`, `à lundi`): those carry meaning.
     - register pairs may vanish **only when their standard form appears in the
       output**: listed anglicism → French (`checker` → `vérifi…`, `mail` → `email`,
       `settings` → `paramètres`, `hello` → `bonjour`, the prompt's PRESERVE list of
       tech anglicisms), oral contraction → full form (`chuis` → `suis`, `p'tit` →
       `petit`, `ouais` → `oui`).
     - an abbreviation → its full form: a lost word of ≥ 4 letters is tolerated when
       the output gained a word that begins with it (`dispo` → `disponible`,
       `déborder` → `débordera`, `honnête` → `honnêtement`). Never for a negation.
     - `-aye`/`-aie` spellings are one word (`essaye`/`essaie`, both correct).
     - joins and splits: `type less` ↔ `typeless`, `Chat GPT` ↔ `ChatGPT`.
     - `ne` insertion and `comment tu vas` → `comment vas-tu` lose no word, so they
       pass by construction.
   - (f) **Short input only**: the check applies when the pre-passed input is at most
     **500 characters**. Justification from the numbers: every #575 device capture and
     probe is ≤ 346 characters (D4, row 2's device dictation, is 346, so the
     findings' *estimated* ~300 would have excluded the row it exists for); the
     longform corpus where D-lost refused 21 % starts at 353, and its refusals sit on
     fixtures of 838, 1159 and 1283 characters plus `3-message-draft` (353), whose
     four are rule-8 English-clause repairs handled by (g), not by length. No fixture
     in any corpus lies between 395 and 637 characters, so every threshold in that
     band classifies the corpora identically; 500 is its middle. Above it, long
     dictations stay unprotected against substitutions.
   - (g) **Off-language stand-down**: when the lost words form a run of ≥ 3 in the
     input that reads confidently as a language other than the input's, the output is
     rule 8 (and ADR 0003's 2026-09-02 amendment) bringing a code-switched clause back
     to the target, and a bag-of-words check cannot referee that (#466). The check
     accepts. This is the shape of every false refusal on `freepolish.json`
     (`5-erreur-parakeet`, 257 characters: short input, so length does not save it)
     and of the prompt's own rule-8 example.
   - (h) **French only.** `languageCode` must be `fr`: the prompt language on Natural,
     the input's detected language on Auto. Every other language passes untested: the
     function-word list and the allow-list are French, and the false-refusal cost was
     only ever measured on French. A check nobody measured on a language must not
     start refusing on it — the same rule the contract flags follow. Adding a language
     is adding a lexicon plus a measured corpus.
2. **`PolishGuardrail.Check.lostWord`** (wire value `lostWord`), and the pipeline runs
   it **last**, after `segmentOverlap`, so every shape an older check already refuses
   keeps being counted under that check's name (#466's reasoning). On refusal the
   existing path applies: `rejectedGuardrail` → `resolvedOutput` inserts the floor
   (pre-passed raw + typography) for the free polish, `logGuardrailRejection` writes
   `check=lostWord`, and the metrics event carries it into the debug export.
3. **Contract field** `refusesLostWords` (see above).
4. **ADR 0003 amended**: Preserve keeps meaning; register, politeness and sign-off
   items move to "tolerated, not encouraged"; prompts unchanged.
5. **Harness replay**: `polish-harness lostword <pairs.jsonl>` runs the shipped Swift
   check on committed pairs; `harness/replay.py` builds the pairs from `raw/`, the #439
   longform captures and `freepolish.json`, runs it, and prints the tables.

## Risks

- Every false refusal costs the polish, never the words (B9: on short Parakeet
  input the floor equals the accepted output in 216/261).
- A rule-8 repair of a single French word on a short message is refused (`honnête`
  is licensed by (e), but a homophone repair is not). #439 measured Apple FM at 0/5 on
  homophone repair, so the loss is bounded by a capability the engine barely has.
- The allow-list's pairs are fitted to what this round showed plus the prompt's
  PRESERVE list. A register lift outside it is refused; the list grows by PR.
- The off-language stand-down is a hole: a French word lost in the same dictation
  as a translated English clause passes.
- Nothing about the phone: rows 2 and 3 do not reproduce on macOS 27, so catch on
  device is a manual validation.

## How each acceptance criterion is verified

| criterion | evidence |
|---|---|
| row-2/3/5 substitutions refused, register/politeness accepted, on `fixtures.json` | `replay.py`: every substitution in `raw/` refused; every register-only / politeness-only output accepted; plus unit cases on rows 1–5 verbatim |
| false-refusal rate per length bucket | `replay.py` table over the three corpora, faithful outputs only |
| `swift test` covers each table row | `PolishLostWordsTests` + pipeline tests (Natural, Auto refuse; Repair and Smart Modes do not run it) |
| ADR 0003 amended | the diff |
| device validation | manual list in the PR |
