# Realistic typo sets for the en / es / de keyboard bench

Research date: 2026-11-19. Goal: on top of the Gaussian touch model, replay the
mistakes people really make when typing English, Spanish and German. This page lists
the public corpora that were checked, what they show per language, and how
`typos-en.tsv`, `typos-es.tsv` and `typos-de.tsv` were built.

Notation used throughout: **measured** = counted by a script on the downloaded data
(scripts were kept outside the download folders and run with `python3 -I`; downloads
are in the git-ignored `build/typo-sources/`). **Read** = stated on the source's own
page. **Assumption** = not checked.

## 1. Sources

| Source | Link | Langs | What it is | Licence (read on the primary page) | Redistributable in this repo? | Used? |
|---|---|---|---|---|---|---|
| GitHub Typo Corpus (Hagiwara & Mita, LREC 2020) | [repo](https://github.com/mhagiwara/github-typo-corpus), [paper](https://aclanthology.org/2020.lrec-1.835) | 15+ (en 339k edits; de 700, es 578 edits) | Edits mined from GitHub commits (README/doc text, typed on a computer). Typo labels exist only for en/zh/ja; de/es edits are unlabelled and include non-typo edits. | No licence. README: copyright "follow[s] the terms of the repositories they belong to", published under GitHub's Acceptable Use Policy. | **No** (per-commit licences unknown) | No. Measured: the v1.0.0 S3 download URL returns HTTP 404. de/es too small and unlabelled anyway. |
| Birkbeck spelling error corpus (Mitton) | [Mitton's page](https://titan.dcs.bbk.ac.uk/~ROGER/corpora.html) | en | 36,133 misspellings of 6,136 words; spelling tests and free writing by schoolchildren, students, adult-literacy students, **mostly handwritten**. | None on Mitton's page. The Oxford Text Archive record (item 0643) is reported by a search result as CC BY-NC-SA 3.0; the OTA page itself refused connection, so **not verified**. | **No** (no licence stated, or NC-SA if the OTA record is right; Dictus is a paid app) | No |
| Holbrook / Aspell / "wikipedia" test files (same page) and Norvig's `spell-testset1/2` | [Mitton's page](https://titan.dcs.bbk.ac.uk/~ROGER/corpora.html), [Norvig](https://norvig.com/spell-correct.html) | en | Holbrook: 1,791 misspellings from 1960s schoolchildren's handwriting. Aspell: 531. "wikipedia": 2,455 from the Wikipedia list. Norvig's test sets are drawn from Birkbeck. | None stated | **No** | No |
| Wikipedia: Lists of common misspellings / For machines | [page](https://en.wikipedia.org/wiki/Wikipedia:Lists_of_common_misspellings/For_machines) (rev 1199637275) | en | 4,310 `typo->correct` lines found by editors in typed article text. No frequencies. | CC BY-SA 4.0 (Wikipedia `rightsinfo`, read through the API) | **Yes, under CC BY-SA 4.0** (attribution + share-alike on the extract) | Yes, as confirmation and for 3 keyboard-slip pairs |
| Wikipedia: AutoWikiBrowser/Typos (RegExTypoFix) | [page](https://en.wikipedia.org/wiki/Wikipedia:AutoWikiBrowser/Typos) | en | Regex rules (540 kB). | CC BY-SA 4.0 | Yes (CC BY-SA) | No: regexes, not pairs; not parsed |
| es.wikipedia: Corrector ortográfico / Listado | [page](https://es.wikipedia.org/wiki/Wikipedia:Corrector_ortogr%C3%A1fico/Listado) (rev 176204563) | es | About 21,000 `typo\|params\|suggestion` lines. Mostly missing accents, plus "descuido" (slip) typos. No frequencies. | CC BY-SA 4.0 | Yes (CC BY-SA) | Yes, as confirmation only |
| de.wikipedia: Helferlein/Rechtschreibprüfung/Wortliste | [page](https://de.wikipedia.org/wiki/Wikipedia:Helferlein/Rechtschreibpr%C3%BCfung/Wortliste) (rev 271038106) | de | About 5,750 `typo\|params\|correct` lines; `ch` marks forms that are correct in Switzerland (`strasse`, `weiss`). No frequencies. `Wikipedia:Liste von Tippfehlern` is only a hub page; the old `/Für Maschinen` subpage no longer exists (measured). | CC BY-SA 4.0 | Yes (CC BY-SA) | **Yes**, the main redistributable de source |
| de.wikipedia: Häufige Falschschreibungen | [page](https://de.wikipedia.org/wiki/Wikipedia:H%C3%A4ufige_Falschschreibungen) | de | Policy page with a short list. | CC BY-SA 4.0 | Yes | No (too short) |
| TOEFL-Spell (Flor, Fried & Rozovskaya 2019) | [repo](https://github.com/EducationalTestingService/TOEFL-Spell) (commit 252ee893b7) | en | 6,121 type-M non-word misspellings annotated in 883 TOEFL iBT essays by non-native writers. TOEFL iBT is computer-based, so the text is keyboard-typed, but on a desktop keyboard (assumption: from what TOEFL iBT is, not from the README). | `LICENSE.md`: "Creative Commons Attribution-ShareAlike 4.0" | **Yes, under CC BY-SA 4.0** | **Yes**, the main en source with counts |
| MultiLexNorm (W-NUT 2021) | [site](https://noisy-text.github.io/2021/multi-lexnorm.html), [data](https://bitbucket.org/robvanderg/multilexnorm/) (commit e58e946375) | en, de, es (+10 more) | Tweets normalised word by word. en = LexNorm2015 (73,806 tokens), de = Sidarenka et al. 2013 (25k), es = Tweet-Norm 2013 (13.8k). Native, typed, mostly on phones (assumption: Twitter in 2013–2015). | No licence for the collection; the README only asks for citation. en (LexNorm2015): none on the [W-NUT 2015 page](https://noisy-text.github.io/2015/norm-shared-task.html). de: none found. es: see next row. | **en, de: No.** es: yes (see Tweet-Norm) | en, de: **counts only, as evidence**. No pair copied into a TSV. |
| Tweet-Norm_es (Alegría et al. 2013) | [announcement](https://listserv.linguistlist.org/pipermail/corpora/2013-November/023300.html) | es | Spanish tweets in which only **out-of-vocabulary** words are normalised. Read through the MultiLexNorm `spa` files. | "released under the Creative Commons License (CC BY)" (version not stated) | **Yes, with attribution** | Yes |
| COWS-L2H (UC Davis) | [repo](https://github.com/ucdaviscl/cowsl2h) (commit ebb11724f2) | es | 2,881 essays by university learners of Spanish, 747k tokens. Courses SPA 31–33 are heritage speakers (97k tokens). Holistic instructor corrections (`corrected1`). Whether essays were typed is **not stated** in the README (assumption: typed). | Apache-2.0 (`LICENSE`) | **Yes, with attribution** | **Yes**, the main es source with counts |
| MERLIN | [platform](https://www.merlin-platform.eu/C_mcorpus.php) | de (+cs, it) | Learner exam texts, CEFR A1–C1. About 340k tokens across all three languages. | CC BY-SA 4.0 (page footer) | Yes | No. Learner exam errors are mostly grammatical; whether the texts were typed is not stated. |
| Litkey | [access page](https://www.linguistics.rub.de/litkeycorpus/access.html) | de | 1,922 picture-story texts by primary-school children (grades 2–4), handwritten, with aligned target tokens. | "Creative Commons Attribution-ShareAlike 4.0 license (CC BY-SA 4.0)" | Yes | No. Seven-year-olds' phonological errors in handwriting are not phone typos. |
| CLEAR | — | — | No typo corpus of that name was found. | — | — | No |

**Licence of the TSV files.** They mix rows from CC BY-SA 4.0 sources (TOEFL-Spell,
Wikipedia), Apache-2.0 (COWS-L2H), CC BY (Tweet-Norm_es) and rule-generated rows
(our own). The conservative reading is that `typos-*.tsv` are distributed under
**CC BY-SA 4.0**, as data files separate from the MIT-licensed code, with the
attribution below. Whether single word pairs are copyrightable at all is doubtful,
but nothing here relies on that. This is not legal advice.

**Attribution.** TOEFL-Spell © Educational Testing Service, CC BY-SA 4.0 (Flor, Fried
& Rozovskaya, BEA 2019). COWS-L2H © UC Davis, Apache-2.0 (Davidson et al., 2020).
Tweet-Norm_es, CC BY (Alegría et al., SEPLN 2013), read through MultiLexNorm (van der
Goot et al., W-NUT 2021). Wikipedia lists © Wikipedia contributors, CC BY-SA 4.0 (en, es
and de pages at the revisions given in the table).

## 2. Categories per language, with evidence

### English

| Category | Measured evidence | Notes |
|---|---|---|
| Missing apostrophe in contractions | MultiLexNorm-en: 878 of 5,592 normalised tokens. `im→i'm` 334, `dont→don't` 149, `thats` 54, `didnt` 31, `ive` 27, `cant` 25, `ill` 16, `youre` 15, `theyre` 14, `doesnt` 14, `its→it's` 12. TOEFL-Spell: 130 of 6,121 (`dont` 63 is its single most frequent misspelling). | The largest real-typing category that is not deliberate shorthand. `its`, `ill`, `wont`, `id`, `were` and `lets` are real words, so they need context. |
| Omitted letter | TOEFL 1,821 (`belive` 30, `peole` 16, `wich` 17); MLN-en 1,045, mostly dropped-g slang (`goin`, `doin`) | |
| Transposition | TOEFL 561 (`thier` 36, `poeple` 29, `becuase` 16, `teh` 6, `hte` 4); MLN-en 25 | Wikipedia-en is full of core-word slips: `adn`, `wtih`, `tihs`, `ahve`, `mroe` |
| Doubled / undoubled letter | TOEFL doubled 381 (`untill`, `beeing`), undoubled 339 (`realy`, `sucess`) | |
| Missing space (fused words) | TOEFL: `alot` 31, `everytime` 11, `donot` 11, `atleast` 9, `ofcourse` 8 | In the classifier output `alot` is counted as an omitted letter |
| Deliberate shorthand (not typos) | MLN-en: 2,007 (`u→you` 562, `n`, `pls`, `ur`, `ppl`) | Excluded from the TSV. An autocorrect should probably leave these alone. |
| Expressive lengthening | MLN-en 94 (`soooo`) | Excluded |

### Spanish

| Category | Measured evidence | Notes |
|---|---|---|
| **Missing accent** | COWS-L2H: 7,718 corrections, 10.3 per 1k tokens; heritage speakers 15.7 per 1k. Tweet-Norm: 208 of 1,034 normalised tokens (`tambien` 12, `despues` 11, `aqui` 8). | By far the largest category. |
| **…on a real word** (diacritical accent) | COWS-L2H: `mi→mí` 530, `mas→más` 515, `el→él` 335, `esta→está` 180, `como→cómo` 155, `que→qué` 150, `se→sé` 93, `si→sí` 67, `mama→mamá` 433, `papa→papá` 129, `tenia→tenía` 131 | **Invisible in Tweet-Norm**, which only normalises out-of-vocabulary words. These cannot be fixed without context, and a bench must also check that the keyboard does *not* turn `esta` into `está` everywhere. |
| Missing ñ | COWS-L2H 752 (1.0 per 1k): `anos` 234, `espanol` 97, `ano` 79, `ninos` 44, `manana` 33. Tweet-Norm: 1 | `ano`/`anos` are real words, with an embarrassing meaning. |
| Superfluous or misplaced accent | COWS-L2H 687: `sólo→solo` 67 (`sólo` was the pre-2010 norm), `mí→mi` 40, `tambíen` 31 | |
| Slip typos (transposition, doubling) | COWS-L2H: transposition 196 (`cuidad→ciudad` 22, `queiro` 6, `caundo` 4, `proque` 3), doubled 182 (mostly English interference: `intelligente`, `classes`), undoubled 90 (`terible`) | Small next to accents |
| Shorthand / tweet spelling (not typos) | Tweet-Norm: `pa→para` 16, `q`/`ke→que`, `tb→también`, `xq`; expressive `jajaja`, `siii` | Excluded |

Learner caveat (assumption): COWS-L2H writers are learners, so `mi→mí` and `el→él`
partly reflect not knowing the rule. The heritage subset, the closest to native
writers here, shows the same top pairs at a higher accent-omission rate (measured
above), and Tweet-Norm confirms the non-real-word ones in native tweets.

### German

| Category | Measured evidence | Notes |
|---|---|---|
| **Lowercased noun mid-sentence** | MultiLexNorm-de: 779 case fixes mid-sentence (`nacht` 8, `spass` 7, `zeit` 5, `leute` 5, `handy` 5, `essen` 4, `abend` 4, `woche` 3, `geld` 3) | Some are real words when lowercase (`essen`, `weg`). |
| Lowercase sentence start | MLN-de: 670 (`ich→Ich` 109, `ja`, `aber`, `das`) | Auto-capitalisation territory, not autocorrect |
| Umlaut as digraph | MLN-de 103: `fuer→für` 24, `spaeter` 5, `waere` 4, `moechte` 4, `duerfen` 4, `schoen` 3 | Also listed in Wikipedia-de (`fuer`, `ueber`, `haette`) |
| Umlaut as plain vowel | MLN-de 53: `fur→für` 12, `uber`, `gepruft`, `Munchen` | `schon`/`schön`, `wurde`/`würde`, `mochte`/`möchte` and `zahlen`/`zählen` are real-word pairs: **no measured counts** (assumption that they occur). |
| ß typed as ss / s | **Not measurable** in MLN-de: its annotators keep `ss` (`Spass`, `Scheisse`, `süss` are *targets*). Wikipedia-de lists `weis→weiß` and `weiss`/`strasse`/`gross`/`heisst` with the `ch` flag. | Assumption: common on phones. `ss` is correct in Swiss German, so it must not be "fixed" for a de-CH user. |
| `das` / `dass` | MLN-de: `das→dass` 18 | Real-word, context-only |
| Slip typos | MLN-de: transposition 19 (`nciht` 3, `mcih`, `cih`, `sidn`), omitted letter (`ic`); Wikipedia-de: 63 transpositions on everyday words (`udn`, `dsa`, `auhc`, `ncoh`, `mher`) | |
| Colloquial apocope (not typos) | MLN-de: `hab→habe` 68, `nich` 46, `is→ist` 28, `grad` 60, `nen→einen` 32, `gibts` 24 | Excluded: deliberate spoken style |

## 3. Extracted pairs

The selection rules were the same for all three languages:

- Keep a pair only if the correct word ranks in the top 3,000 of the shipped
  `DictusKeyboard/Resources/<lang>_frequency.json`, which is a measured proxy for
  "everyday word".
- Rank by measured count in the redistributable sources.
- Drop learner grammar errors: real-word swaps such as `un→una` or `muchos→muchas`
  in COWS-L2H, and `lifes`/`informations` in TOEFL.
- Drop deliberate shorthand and lengthening.
- Keep a few pairs per category so the bench covers each category.

The source column names where the row comes from. `rule` means we wrote the pair from
the category; its evidence is in section 2, often from MultiLexNorm-en/de, which may
not be redistributed. The per-pair counts are printed by `build/typo-scripts/build_tsv.py`, which lives in
the git-ignored `build/` and is not committed. That script also refuses to write a row
whose stated source does not contain it.

- `typos-en.tsv`: 36 pairs. 25 from TOEFL-Spell (counts 4–63), 3 from Wikipedia-en,
  and 8 rule pairs for contractions (MLN-en counts 7–334).
- `typos-es.tsv`: 33 pairs, all from COWS-L2H and/or Tweet-Norm_es (counts 6–530).
  14 are tagged `-real-word`.
- `typos-de.tsv`: 33 pairs. 16 from Wikipedia-de, 17 rule pairs: umlauts, `das→dass`
  and lowercased nouns. Lowercased nouns and some umlaut pairs have MLN-de counts 3–24.
  `konnen`, `mussen`, `schon→schön` and `wurde→würde` have **no** measured count.

The `-real-word` category suffix marks pairs where the typo is itself a valid word.
The bench should score those differently: either the keyboard leaves them alone, or
it uses context.

## 4. Side observations on the Dictus word lists (measured on the JSON files only)

- None of the three `*_frequency.json` files has an entry with an apostrophe or a
  capital letter (en 40,000 entries, es 49,585, de 40,000).
- `en_frequency.json` contains `im` (rank 2,170), `dont` (3,669), `thats`, `cant`,
  `alot`, `teh` (19,421), `thier`, `recieve` and `definately`.
- `es_frequency.json` contains `tambien` (1,951), `despues`, `aqui` and `ano`/`anos`.
- `de_frequency.json` has no `fur`/`fuer`/`uber`, and does have `straße`, `weiß`, `groß`.

The typo runs answer whether this stops autocorrect (README, "Typo runs"): it does.
`teh`, `recieve`, `definately`, `becuase`, `beleive`, `adn`, and every unaccented
Spanish form in the es-typos run, were committed as typed.
