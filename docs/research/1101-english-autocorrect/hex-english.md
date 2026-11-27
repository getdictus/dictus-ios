# How Hex does English autocorrect, and what Dictus can take (#1101)

Part of the [#1101 study](README.md). Research only: Hex was read, never built or run. Where this page says "not measured", the study's [README](README.md) measures what it could (the model swap, the context choice, Apple's own dictionary).

## 0. What was read

- **Hex, `dev` tip: `2f8c3b70a8b4ba90dc67e118e19a7f1864b4821c`** (2026-11-27 13:48 -0800, "fix(ui): constrain modal sheets…", #2988). Read from a fresh shallow clone of `dev`; the copy on Pierre's Mac (`4f3a45e0`, 2026-11-21) is older.
- **Dictus**: the worktree `study/1101-english-autocorrect` at `a5ef8a71`, read only.
- **Scope.** Hex has two keyboards. This report covers **iOS** (`ios/HEXShared/FullKeyboard/…`), the one Dictus ports from. Android (`android/…`) is mentioned where its files, benchmarks or licences are the source of a claim. Unless marked `android/…`, all Hex paths are relative to the Hex checkout at `2f8c3b70`.
- Abbreviations used for Hex files below:
  - `AE` = `ios/HEXShared/FullKeyboard/Autocorrect/AutocorrectEngine.swift`
  - `AE+Dict` = `…/Autocorrect/AutocorrectEngine+Dictionaries.swift`
  - `AE+Dist` = `…/Autocorrect/AutocorrectEngine+Distance.swift`
  - `TD` = `ios/HEXShared/FullKeyboard/TypingDecoder.swift`
  - `BTM` = `ios/scripts/build-typing-model.py`

### The one-paragraph picture

Hex's iOS English autocorrect has three layers:

1. **Apple's own `UITextChecker`** decides what counts as a word, gives one-edit guesses and gives completions. Hex ships **no English validity list on iOS** (`ios/HEXKeyboard/TypingModel/` has `en.hextm` and `en.spellings` only).
2. **About 125 hand-written English rules**: contractions without their apostrophe, common transpositions, a shorthand allowlist, the lone "i" made "I", and two-letter fixes.
3. **A memory-mapped 3.6 MB unigram + bigram model (`en.hextm`)**. It drives the spatial noisy-channel decoder, which is on by default in Hex now. It also drives a context model that picks between same-letter words ("id"/"I'd", "its"/"it's", "your"/"you're", "there"/"their"/"they're", "then"/"than"), using the word before and then the word after.

Your own words take priority over all three: text replacements, Contacts via `UILexicon`, the vocabulary, words kept twice, and typos fixed twice.

### The single most important finding

**Dictus ships an outdated Hex English model.** Its `DictusKeyboard/Resources/en.hextm` has SHA-256 `14370569…c4028`. Hex's own README names that hash as the earlier model, from before its contraction and chat-word rebuild (`android/benchmark/typing/README.md:245`).

| | Dictus `en.hextm` (= Hex before #2408) | Hex tip `en.hextm` (#2408 + #2973) |
|---|---|---|
| Words / pairs | 86,133 / 417,480 | 100,357 / 370,951 |
| `don't`, `can't`, `won't` (cost) | 13.50 / 14.62 / 15.75 nats | 7.25 / 7.88 / 8.75 nats |
| `it's`, `we're`, `let's` (cost) | 15.25 / 15.12 / 16.38 nats | 6.75 / 8.62 / 10.12 nats |
| `i'm`, `i'll`, `i'd` | **absent** | 8.50 / 9.12 / 9.00 nats |
| `lol`, `tbh`, `ok` | absent | 10.0 / 12.0 / 10.0 nats |
| `chatgpt`, `tiktok`, `nvidia`, `wellbeing` | absent | present (≈10–11 nats) |
| Names and days (`mary`, `monday`, `london`) | absent | present, lowercase, from SCOWL proper names |

Read from both files with a read-only parser of the HXTM v3 format. "Absent" means no entry, so the decoder scores the word at the 22-nat unknown cost.

The two Hex PRs are:
- **#2408** (2026-11-22): "English typing model: contractions as common as their words, and Hex's chat and tech words".
- **#2973** (2026-11-27): "names, days, places and newer words".

The file format is the same HXTM v3, so Dictus's `SpatialDecoderModel` reads the new file unchanged. With the old model, the decoder sees "don't" as about as rare as the 100,000th word, and it cannot produce "I'm" at all.

---

## 1. Rules and hand-written special cases

### Hex

**Unambiguous fixes** (`AE+Dict:37-164`, about 125 entries; English only, gated by `usesEnglishFixes`, `KeyboardLanguage.swift:803`):
- The pronoun: `i` → `I`.
- 49 contractions without their apostrophe, including `im`, `ive`, `dont`, `cant`, **`wont`** → `won't`, `youre`, `thats`, `yall` → `y'all`, `oclock`, `cmon`, `wouldve`…
- About 75 high-frequency transpositions and misspellings, including `teh`, `hte`, `adn`, `jsut`, `becuase`, `recieve`, `definately`, `realy`, `tomorow`, `iphnoe` → `iPhone`…

Applied in `ownReplacement` at `AE:1078-1081`. All caps keeps its case (`DONT` → `DON'T`), but an all-caps token under 3 letters is never fixed (`AE:1079`).

**Suggest-only contractions** (`AE+Dict:6-16`): `ill`, `id`, `were`, `wed`, `well`, `its`, `lets`, `hell`, `shell`. These are offered in the strip (`AE:757-758`) and never applied by space unless the context model chooses them (see §4).

**Shorthand allowlist** (`AE+Dict:27-34`): about 70 tokens that are never rewritten:
- `ok`, `ty`, `thx`, `pls`, `tbh`, `idk`, `imo`, `lol`, `lmao`, `omg`, `brb`, `btw`, `fyi`, `nvm`, `rn`, `jk`, `np`, `smh`, `ikr`, `ngl`, `fr`, `gg`, `dm`
- tech words: `pr`, `ui`, `api`, `url`, `json`, `sql`, `ssh`, `cli`, `gpu`, `sdk`…
- `gonna`, `wanna`, `gotta`, `kinda`, `sorta`, `yeah`, `yep`, `nope`, `nah`, `hey`, `yo`

It is checked before any fix, both in the strip (`AE:688-691`) and on space (`AE:859`), and it also counts as "a word" (`AE:982-986`, `AE:1215`).

**Abbreviations** (`AE+Dict:20-24`): `approx`, `etc`, `dr`, `mr`, `vs`… A period after one of these never triggers a correction.

**Two-letter fixes** (`AE:1112-1115`, `AE:1190-1198`): a two-letter non-word one adjacent key (cost ≤ 0.65) or one swap away from a common two-letter word becomes that word. The list is in `KeyboardLanguage.swift:808-812`: `to of in it is be as at so we he by or on do if me my up an go no us am`. Example: `tk` → `to`.

**Pronoun capital with an apostrophe typed** (`AE+Dict:207-218`): `i'm`, `i'll`, `i've`, `i'd`, with a straight or curly apostrophe, become `I'm`… This runs on space before anything else (`AE:851`).

**Token guards** (`AE:508-533`): no correction when the token touches `@ / . # _ - :` or a digit (URLs, handles, paths, numbers). camelCase and other internal capitals are left alone (`AE:1063-1064`).

**Offensive words** (`ios/HEXShared/FullKeyboard/OffensiveWords.swift`, `never-suggest.tsv`, LDNOOBW-derived):
- Slurs are never suggested or corrected to.
- Swear words are offered only with a setting on.
- A blocked word that is typed in full is never "corrected" away (`AE:292-296`, `AE:1051-1053`).

**Learning:**
- `LearnedWordsStore` (`AE:38-151`): a word kept explicitly twice is never touched again. Capped at 2,000 words and 64 KB in the App Group.
- `TypingLearning` (`ios/HEXShared/FullKeyboard/TypingJournalLearning.swift:154-166`): a typo you fixed the same way twice becomes an auto-fix (`AE:1056`). A word you undid twice goes into `rejected`.

### Dictus today

- `englishProfile.overrides` (`DictusCore/Sources/DictusCore/Languages/English.swift:14-55`) has 35 contractions. It **leaves out `wont`** as a valid word and **writes `"im": "i'm"` in lowercase** (`English.swift:20`). `applyOverride` only capitalises when the typed word was capitalised (`DictusCore/Sources/DictusCore/TextCorrection/OverrideLookup.swift:26-31`), and the test `OverrideLookupTests.swift:71` asserts `i'm`.
- `KnownMisspellings.swift` (Wikipedia-derived, CC BY-SA 4.0 per its header) covers part of Hex's misspelling list (`adn`, `becuase`, `definately`…).
- **No shorthand allowlist. No `i` → `I` rule.** Every `"i"` literal in `DictusKeyboard` and `DictusCore/Sources`, read: none is a casing rule. **No two-letter neighbour rule for English.** `LoneLetterCorrection` is French-only in practice.
- **What Dictus could take:** Hex's `unambiguousFixes` and `shorthandAllowlist` tables, which are pure data under Hex's MIT licence. Specifically: `i` → `I`; `I'm`/`I've` capitalised; `wont` → `won't` (Hex treats it as unambiguous); `yall` → `y'all`; the transpositions Dictus lacks (`teh`, `hte`, `jsut`, `knwo`, `waht`…); and the commonTwoLetterWords fix.

## 2. Candidate generation and scoring

### Hex: what space does (`replacementOnSpace`, `AE:841-862` → `cautiousReplacement`, `AE:873-932` → `ownReplacement`, `AE:1042-1146`)

The steps run in this order; the first that applies wins.

1. A text replacement (`AE:1045`). Then the vocabulary term, accent restoration, and the bilingual partner logic (`AE:874-932`).
2. A blocked word is left as typed (`AE:1051`).
3. A typo learned twice is applied, unless what was typed is a real word (`AE:1056-1058`).
4. All caps and internal capitals are left alone (`AE:1061-1064`).
5. The context choice between same-letter words (`AE:1069-1074`); see §4.
6. `unambiguousFixes` (`AE:1078-1081`).
7. **When spatial autocorrect is on (the default now), the decoder decides alone** (`AE:1086-1108`). If it gives no replacement, a lowercase name the dictionary knows only capitalised gets its capital (`AE:1107`).
8. Without the decoder (`AE:1110-1145`):
   - the two-letter neighbour fix;
   - accent restoration;
   - French elisions;
   - then for words of **at least 3 letters that `UITextChecker` rejects**, the first 8 of its guesses, each priced by `singleEditKeyboardCost` plus `rank × 0.08`. The best is applied **only if its total is ≤ 1.35** (`AE:1144`).

The edit costs (`AE+Dist:109-184`; one Damerau-Levenshtein edit at most, otherwise no candidate):

| Edit | Cost |
|---|---:|
| Accent-only difference | 0.15 |
| Substitution, adjacent key (≤ 1.6 key units apart, `AE+Dist:216-227`) | 0.65 |
| Substitution, far key | 1.15 |
| Adjacent transposition | 0.60 |
| Insertion or deletion next to a neighbouring key | 0.70 |
| Insertion or deletion otherwise | 0.90 |

A guess may add only letters or an apostrophe. A split guess (`up to`) is used only if it uses exactly your letters, both parts are words, and the checker offers the spaced form itself (`AE:1445-1472`).

### Hex: the spatial noisy-channel decoder (`TD:342-598`)

- **Parameters** (`TD:348-401`), tuned on a held-out benchmark of Tatoeba sentences with synthetic taps:
  - σx = 0.29, σy = 0.26 of the key pitch;
  - **`lmWeight` = 1.25, and 1.5 for English** (`TD:396`);
  - deletion 7.0, insertion 7.0, transposition 5.0, space omission 6.0 nats;
  - `maxEdits` 1, beam 48;
  - **`autoMargin` 2.0 nats** (what was typed is no word) and **`validMargin` 7.0 nats** (what was typed is a word);
  - `accentMargin` 2.0;
  - **`unknownValidCost` 15** (a word the dictionary, your words or the shorthand list accept but the model lacks) and **`unknownCost` 22** (a word nothing knows);
  - `userWordCost` 11; `oneLetterWordCost` 7.
- **Score** = Σ tap Gaussian costs + `lmWeight` × LM cost (`TD:540-556`). The LM cost is `-ln P(w | prev)` with backoff 0.92 + unigram (`TD:610-612`, `TD:151-158`).
- **Replacement rule:** the best reading replaces the typed word only if `literalCost − best ≥ margin` (`TD:573-580`).
- **Fallback for a non-word:** a missed-space reading, with a slip in the second word or 3–6 words run together, can replace a token of 5 letters or more that nothing knows (`TD:586-596`).
- **When the decoder applies:** the token must have at least 2 letters, no apostrophe, and one tap per letter (`AE:1204-1207`). What counts as "valid" includes the shorthand allowlist, learned words, `UILexicon` terms, `UITextChecker`, and a proper noun known only capitalised (`AE:1215-1217`).
- **Adaptive touch:** with personal key centres in use, a reading is applied only if the stock centres would also clear the margin (`AE:1220-1235`).

### Hex: the strip (`suggestions`, `AE:640-732`; `candidates`, `AE:742-811`)

- The slots are `"typed"` | primary | secondary.
- Candidates come in this order:
  1. the auto-fix;
  2. a learned fix or suggest-only contraction;
  3. a vocabulary completion;
  4. for tokens of 3 letters or fewer, the model's completion given the previous word (`TD` `completions`);
  5. the decoder's other readings;
  6. `UITextChecker` guesses re-ranked by keyboard cost (`AE:1474-1499`);
  7. `UITextChecker` completions, kept in Apple's frequency order, with names last unless you typed a capital (`AE:820-837`).
- After a space, the model's next words fill the slots (`AE:664-680`). At a sentence start the slots are `I`, `the`, `I'm` (`AE:552-554`); after a comma, `I`, `but`, `and` (`AE:578-580`).

### When Hex keeps the typed word

- It is a word to `UITextChecker` and nothing clears the 7-nat valid margin.
- It is in the shorthand list, learned, rejected or kept in this session.
- It is all caps or mixed case.
- It contains an apostrophe (except French elisions).
- It is 1 letter, or 2 letters with no neighbouring common word.
- No guess costs ≤ 1.35.

### Dictus today

- Dictus has a trie-first pipeline (`DictusKeyboard/TextPrediction/TextPredictionEngine.swift:353-585`):
  1. lexicon;
  2. overrides;
  3. user dictionary;
  4. accents;
  5. **already valid if in the trie** (`:455`);
  6. contractions;
  7. proper-noun guard;
  8. learned near-miss;
  9. curated names;
  10. split;
  11. the trie's ranked candidates (`CorrectionRanking`);
  12. a bigram rerank limited to candidates no farther in edit distance (`:756-910`).
- The trie's English vocabulary is only **39,944 words** (`en_frequency.json`). A correctly spelled word outside it is treated as a typo. Hex asks Apple's system dictionary instead.
- The ported spatial decoder (`DictusCore/Sources/DictusCore/SpatialDecoder/SpatialDecoder.swift`) has Hex's parameters, including English `lmWeight` 1.5 (`:63`). It is behind an Experiments switch, off in App Store builds (`DictusKeyboard/TextPrediction/SpatialAutocorrect.swift:11-27`).
  - It leaves out your own words, never-suggest, space-as-letter merge and adaptive touch (header at `SpatialDecoder.swift:7-10`).
  - It also lacks the missed-space-with-slip fallback (`TD:586-596`; Hex #2244). `grep missedSpace` finds nothing.
- **What Dictus could take:**
  - the new `en.hextm` (§0);
  - Hex's ≤ 1.35 keyboard-cost gate on one-edit guesses, as a confidence floor for the trie path;
  - the missed-space fallback (#2244), ported the way the rest of `TD` was.

## 3. Dictionaries and frequency lists

| File (Hex) | Size on disk | What it is | How built | Memory |
|---|---:|---|---|---|
| `ios/HEXKeyboard/TypingModel/en.hextm` (= `android/…/typing/en.hextm`, SHA-256 `98c8da8f…`) | 3,599,997 B | 100,357 lowercase words, 370,951 pairs, costs in 1/8 nat | `BTM` (`BTM:380-500`): Google Books Ngram v3 counts for 1980–2019; vocabulary filtered by SCOWL ≤ 70 (`BTM:227-247`); contractions at their expansion's count (`BTM:96-108`, `410-429`); `en-extra-words.tsv` at tier costs (`BTM:109-110`, `366-377`); SCOWL names of 4+ letters (`BTM:71-74`, `243-246`); Leipzig news words used by ≥ 100 sites (`BTM:75-91`, `276-353`, `436-439`); pairs kept by information gain under a 3.6 MB budget (`BTM:459-473`) | **`mmap` read-only** (`TD:5-35`): clean file-backed pages that iOS can drop |
| `ios/HEXKeyboard/TypingModel/en.spellings` | 4,588 B (299 lines) | `word<TAB>Spelling` for capitals the lowercase model cannot hold (`chatgpt` → `ChatGPT`, `github` → `GitHub`, `aidan` → `Aidan`) | `BTM:430-446`, from SCOWL internal-capital spellings and the Leipzig news | `mmap` (`ios/HEXShared/Spelling/HexWordList.swift:15-27`), bisection in place |
| `ios/scripts/en-extra-words.tsv` | 166 words | Chat and tech words, "written for Hex by its developers" (header lines 1-6) | Hand-written; MIT as part of Hex | Baked into `en.hextm` |
| `ios/HEXShared/FullKeyboard/never-suggest.tsv` | 11,534 B (iOS) / 17,077 B (Android) | Slurs and swear words, by layout | LDNOOBW, curated by Hex | Parsed into a dictionary |
| Apple `UITextChecker` (system) | 0 B in the app | iOS's validity, guesses and completions | Apple | System process |
| *Android only:* `en.valid` | 323,701 B (31,416 words) | SCOWL words outside the model | `android/benchmark/typing/build-valid-words.py` | `mmap` |
| *Android only:* `en.capitals` | 236,102 B (20,581 words) | Share of each word that Google Books writes capitalised | `android/benchmark/typing/build-capitals.py` | `mmap` |

- **iOS ships neither `en.valid` nor `en.capitals`.** `ios/docs/keyboard.md:253-254`: "English, Spanish and German keep `UITextChecker`: their own lists moved a gate number the wrong way."
- **Build cost** (`BTM:46-48`): about 240 GB of n-grams downloaded for English, 7 GB of free disk, deterministic and resumable.

### Dictus today

- `en_frequency.json` (708,687 B, 39,944 words) feeds `en_spellcheck.dict` (406,189 B, a patricia trie, `tools/dict_builder.py`).
- `en_ngrams.dict` (6,154,536 B) comes from `tools/ngram_builder.py`, built from orgtre's `google-books-ngram-frequency` plus `top-open-subtitles-sentences` (`tools/ngram_builder.py:40-43`).
- `en.hextm` (3,600,000 B, the old Hex model).
- **English on disk: about 10.9 MB in Dictus, against 3.6 MB of app data in Hex.**
- **What Dictus could take:** the model swap. It is the same size, so there is no new memory cost. Optionally also `en.spellings` (4.6 KB).

## 4. Contractions without an apostrophe

### Hex

- **Unambiguous** (`dont`, `im`, `youre`, `cant`, `wont`, …): a lookup table, applied on space (`AE+Dict:39-89`, `AE:1078`).
  - Bilingually, these stay "sure fixes" even when the partner dictionary knows the token: French "dont", German "im" (`AE:897-899`, `AE:960-962`).
  - At a sentence start they are revised once the next word leans English: "Im going" → "I'm going", while German "Im Haus" stays (`AE:968-977`).
- **Ambiguous real words** are decided by the **context model** (`AE:1268-1383`):
  - The groups are `[id, I'd]`, `[ill, I'll]`, `[hell, he'll]`, `[shell, she'll]`, `[wed, we'd]`, `[lets, let's]`, `[well, we'll]`, `[its, it's]`, `[your, you're]`, `[there, their, they're]`, `[then, than]` (`AE:1272-1276`). **`were`/`we're` is deliberately left out**: the pairs cannot tell them apart, so "we're" is only suggested (`AE:1269-1271`).
  - A contraction is scored as its expansion's words, e.g. `i'd` = `i would` or `i had` (`AE:1280-1285`). The reason is that Google Books splits "I'd" into "I" + "'d".
  - The cost is `-ln P(w | prev) + -ln P(next | w)`, with 15 nats for a word the model lacks (`AE:1299`, `1318-1335`).
  - There is a 3-nat bonus for a contraction at a sentence start (`AE:1302`).
  - There is a 5-nat penalty when `will`, `would`, `had` or `us` never precedes the next word in the pairs (`AE:1307-1308`). Example: "till hell freezes" stays.
  - **Margins** (`AE:1296-1297`), "tuned on Tatoeba sentences outside the benchmark's held-out ones":
    - same letters (an apostrophe only): 3.0 nats with the previous word only, 1.5 once the next word is known;
    - different letters (`your`/`you're`, `there`/`their`): 6.0, then 3.0.
  - Applied on space (`AE:1069-1074`), and again as a **revision of the previous word when the next word is typed** (`AE:1370-1383`). Example: "well see" → "we'll see".
  - This is never applied to a word you kept, learned, or have in `UILexicon` (`AE:1344-1345`).
- Without the model there is no fallback: these words stay as typed and the contraction is offered in the strip (`AE+Dict:6-16`).

### Dictus today

- Dictus has hand-written `ContextualContraction` rules for `ill`, `its` and `were` only (`English.swift:59-111`; `DictusCore/Sources/DictusCore/TextCorrection/ContextualContraction.swift:57-97`):
  - `ill` → `I'll` except after a curated list of words;
  - `its` → `it's` at a sentence start, or when the next word is in a curated list;
  - `were` → `we're` only after `afraid`, `glad`, `hope`, …
- There are no rules for `id`, `lets`, `well`, `hell`, `shell`, `wed`, `your`/`you're`, `there`/`their`/`they're` or `then`/`than`.
- `wont` is not fixed. `en_frequency.json` holds `wont` (3,978,693) and `yall`.
- **What Dictus could take:**
  - Hex's LM-based `contextChoice` (`AE:1268-1365`): about 100 lines of logic plus the two group tables, MIT. It needs the new `en.hextm`: with the old one `i'd`/`i'll` are absent and `it's` costs 15.25 nats, so the context model would never choose them.
  - Dictus could keep its curated `ill`/`its`/`were` rules as a fallback, or compare the two on the #1101 sentence set.

## 5. Proper nouns and brands

### Hex

- **Contacts and text replacements:** `UILexicon`, via `loadLexicon` at `AE:303-325`. Entries are kept as typed, offered for completion after dictionary words, and fed to the decoder as user words at cost 11 (`AE:1427-1437`, `TD:558-563`).
- **The vocabulary list:** `AE+Vocabulary.swift:9-44`. Typing a vocabulary word applies its casing: `github` → `GitHub`.
- **Lowercase names:**
  - a word `UITextChecker` knows only capitalised gets its capital: `mary` → `Mary`, `monday` → `Monday` (`AE:1243-1248`, `AE:1258-1264`, `AE:1107`);
  - a word with its own spelling in the model gets it: `chatgtp` → `ChatGPT` (`ios/HEXShared/FullKeyboard/Autocorrect/AutocorrectEngine+Spellings.swift:11-25`).
- **A stray capital is removed:** a Contacts name that is also a common word ("Will", "Bell") is written lowercase mid-sentence (`AE+Dist:75-82`).
- **The other dictionary's guess of a name** is never applied: "Zuri" for "Ziri" (`AE:916-918`, `AE:936-941`).
- **Unknown words:**
  - Without the decoder, a non-word of 3 letters or more is fixed only if a guess costs ≤ 1.35; otherwise it is kept.
  - With the decoder, a non-word costs 22 nats, so even a 2-nat margin can rewrite it. Your own words and the model's names guard against this.

### Dictus today

- `SupplementaryLexicon` (`requestSupplementaryLexicon`, `DictusKeyboard/TextPrediction/SuggestionState.swift:430-433`).
- `ProperNounGuard`: an unknown capitalised word of 3 letters or more mid-sentence is kept, and so is ALL CAPS (`DictusCore/Sources/DictusCore/ProperNounGuard.swift:33-48`).
- `CuratedNames` (17 brands: `DictusCore/Sources/DictusCore/TextCorrection/CuratedNames.swift:18-27`).
- **Missing:** lowercase `monday` and `mary` are in `en_frequency.json`, so they stay lowercase (no capitalisation rule). Dictus also has no model or spellings for the news-era brands outside its 17 curated names.
- **What Dictus could take:** `en.spellings`, which is 299 spellings. Note that its Leipzig-derived rows carry a CC BY 4.0 attribution duty (§12). Dictus could also take Hex's capitalisation of lowercase names, but on iOS Hex relies on `UITextChecker`'s capitalised-only check, which Dictus would have to call.

## 6. Casing

### Hex

- **Lone `i`:** becomes `I` through `unambiguousFixes` (`AE+Dict:39`), and inside a split reading ("iwant" → "I want", `AE:1089-1092`). It is not applied bilingually beside another language for a one-letter token (`AE:894-896`).
- **`i'm`, `i'll`…** typed with an apostrophe become `I'm` (`AE+Dict:207-218`).
- **Sentence start:** shift auto-capitalises (`ios/HEXShared/FullKeyboard/ShiftStateMachine.swift:136-161`). The context model carries the capital over (`AE:1361-1365`).
- **ALL CAPS:** acronyms are left alone (`AE:1059-1083`), except 3+-letter unambiguous fixes, and `matchCase` keeps all caps (`AE+Dist:11-27`).
- **The Auto-Capitalization setting:** when it is off, nothing adds a capital you did not type: "i" stays "i", "im" becomes "i'm" (`AE:268-274`, `AE:1171-1175`, `ios/docs/keyboard.md:180-192`).

### Dictus today

- **No `i` → `I`**, and **`im` → `i'm` in lowercase** mid-sentence (`English.swift:20`; `OverrideLookup.swift:26-31`; asserted by `DictusCore/Tests/DictusCoreTests/OverrideLookupTests.swift:71`).
- The #1101 run confirms it (README, casing row). If it holds, it is a likely, very visible source of "weird" for US users: Apple writes "I" and "I'm" there.
- ALL CAPS is kept by `ProperNounGuard`.
- **What Dictus could take:** the `i` → `I` and `I'm` casing rules, gated on the keyboard's auto-capitalisation setting as Hex does.

## 7. Slang and shorthand (gonna, lol, tbh, u, ur)

- **Hex:**
  - `gonna`, `lol`, `tbh` and about 70 more are in the never-rewrite allowlist (`AE+Dict:27-34`) and are in the model at tier costs (`ios/scripts/en-extra-words.tsv`).
  - **`u`** is a single letter: `UITextChecker` takes every letter and the decoder needs 2+ letters, so it is kept.
  - **`ur`** is not on the list and not in the model. If `UITextChecker` rejects it, the two-letter rule could change it to a neighbouring common word (`AE:1112-1115`). Not run.
  - "lmk", "omw", "wyd", "hbu", "ttyl" are in the model (`en-extra-words.tsv`) but **not** in the allowlist. They are protected only if `UITextChecker` knows them or the decoder margin keeps them. Not verified.
- **Dictus:**
  - In `en_frequency.json`, so kept: `lol`, `gonna`, `u`, `ur`, `imo`, `smh`, `rn`, `btw`, `fyi`, `jk`, `thx`, `pls`, `lmao`, `omg`, `wanna`, `gotta`, `kinda`, `yep`, `nope`, `nah`.
  - **Absent**, so they go to the trie and may be "corrected": `tbh`, `idk`, `brb`, `omw`, `lmk`, `ngl`, `wyd`, `hbu`, `ttyl`, `nvm`, `ikr`, `tmrw`, `emoji`, `selfie`.
- **What Dictus could take:** Hex's allowlist as a keep rule (MIT), and `en-extra-words.tsv` as additions to `en_frequency.json` (MIT, written by Hex's developers).

## 8. Single letters and very short words

- **Hex:**
  - Decoder: needs 2+ letters (`AE:1207`). One-letter words stand alone in a split only if cheaper than 7 nats (`TD:384`).
  - `UITextChecker` path: 3+ letters (`AE:1128`).
  - Two letters: only the common-two-letter neighbour fix (`AE:1112-1115`, list at `KeyboardLanguage.swift:808-812`).
  - One letter: only `i` → `I`.
  - `im` → `I'm` (table).
  - "a" and "i" are the only one-letter split parts allowed (`AE:1466-1472`).
- **Dictus:**
  - `LoneLetterCorrection` (`DictusCore/Sources/DictusCore/TextCorrection/LoneLetterCorrection.swift`) only works with a language's one-letter word set; the English profile defines none, so it is off for English.
  - The bigram rerank skips words under 3 letters (`TextPredictionEngine.swift:796`).
  - `r`, `n` and `u` are in the word list, so they are kept.
- **What Dictus could take:** the English `commonTwoLetterWords` list plus the ≤ 0.65 neighbour gate.

## 9. After an unknown word or a typo (context fallback)

- **Hex:**
  - `previousWord` (`AE+Dist:86-96`) is the raw previous token, lowercased; `nil` after punctuation.
  - If the model lacks it, `model.index(of:)` is nil, so the decoder backs off to the unigram (`TD:538`, `TD:610-612`). The context model scores the pair at the unknown cost of 15 (`AE:1323-1324`).
  - Since the same 15 applies to every candidate in a group, the margin cannot be reached from the previous side alone. The choice waits for the next word, which is the revision path (`AE:1370-1383`).
  - Previous-word revision works on what is now in the text, i.e. after any correction.
- **Dictus:**
  - The bigram rerank requires a non-empty previous word and n-grams loaded (`TextPredictionEngine.swift:765-768`).
  - With an unknown previous word there is no bigram evidence, so the trie result is kept (`:839-851`).
  - This is the same in spirit; nothing to take.

## 10. Small local language model or reranker

- Hex uses **no neural model for typing**.
  - The LM is the HXTM unigram + bigram table (Google Books plus news), quantised to 1/8 nat with stupid backoff 0.92 (`TD:151-158`, `TD:609-612`).
  - The `CleanupTagger` under `ios/HEXKeyboard/CleanupTagger/` is for **dictation** cleanup, not the keys. It is only referenced from dictation tests.
  - The only other rankers are `UITextChecker`'s own order and the keyboard-distance cost.
- Dictus already has the same class of model: its own n-grams plus the ported decoder. Nothing new to take here.

## 11. Latency and memory numbers Hex states

- `ios/HEXShared/FullKeyboard/TextChecking.swift:35`: `UITextChecker` is warmed after the first frame "so cold open stays < 12 ms".
- The models are memory-mapped; "a 5 MB list costs only the clean pages its lookups touch, which iOS can drop under pressure" (`ios/HEXShared/Spelling/HexWordList.swift:8-10`; `TD:5-7`). English is "about 3.6 MB" (`ios/docs/keyboard.md:222`).
- **Time per letter, Android, on a Pixel 8 emulator** (API 35, 4 cores, 2 GB), full strip + decoder (`android/benchmark/typing/README.md:84-95`):
  - English letter: median 0.088 ms, p95 0.27 ms;
  - space: median 0.022 ms, p95 0.29 ms;
  - with adaptive touch: +0.02 ms median.
- **Swipe decode:** English 1.00 ms median, 3.82 ms p95 (`README.md:110`).
- **No iOS per-keystroke timing** is stated in the files read.
- **Quality** (held-out 2,000 Tatoeba sentences, synthetic taps; `README.md:135-145`):
  - iOS English 798 word errors (5.75% WER);
  - iOS at `fc867484` (with #2244): 768 (5.54%);
  - Android best: 707 (5.10%).
  - Bilingual English+French on iOS: 7.56% → 5.79% (`AE:871-872`).

## 12. Licences of every word list, dictionary, frequency or n-gram source

All of these are permissive (attribution at most), none is non-commercial, and none is share-alike — except Hex's Spanish source, which Hex uses under its MPL 1.1 option. "Primary page" means the page was fetched on 2026-11-27 for this study.

| Source | What Hex uses it for | Licence on the primary page | Licence URL | Paid closed-source iOS app? | Size cost (English) |
|---|---|---|---|---|---|
| **Google Books Ngram v3** (2020-02-17) | Unigram and bigram counts for `en.hextm` (also es, de, fr, it); Android `en.capitals` | "This compilation is licensed under a Creative Commons Attribution 3.0 Unported License" — [datasetsv3.html](https://storage.googleapis.com/books/ngrams/books/datasetsv3.html), verified | <http://creativecommons.org/licenses/by/3.0/> | **Yes**, with attribution and a change notice (Hex's are in `ios/HEXMobile/AcknowledgementsView.swift:47-52` and `android/…/licenses/credits.txt`). Dictus already credits it for `en_ngrams.dict`. | Ships as part of `en.hextm`: 3.6 MB on disk, memory-mapped (only touched pages are resident) |
| **SCOWL 2020.12.07, sizes ≤ 70** (Kevin Atkinson; with VarCon) | Vocabulary filter; names, days and places; internal-capital spellings (`en.spellings`); Android `en.valid` | "Permission to use, copy, modify, distribute and sell these word lists … for any purpose is hereby granted without fee, provided that the above copyright notice appears in all copies and that both that copyright notice and this permission notice appear in supporting documentation" — [SCOWL v1 README](http://wordlist.aspell.net/scowl_v1-readme/) and [Copyright](https://raw.githubusercontent.com/en-wl/wordlist/master/scowl/Copyright), verified | Same pages (custom permissive notice) | **Yes**. Ship the SCOWL, VarCon, Ispell (BSD-style: keep notice, mark modifications) and WordNet 1.6 (keep Princeton notice) notices; Hex ships `android/…/licenses/scowl.txt`. Other components ≤ 70 (Moby, 12Dicts, Kelk UK list) are public domain. Sizes above 70 add UKACD, which has stricter verbatim-notice terms; Hex uses ≤ 70 only. The README gives no source for the 35/40 name lists or the abbreviations (not verified). | Only as a filter in `en.hextm` (0 extra); `en.spellings` 4.6 KB; Android's `en.valid` would be 0.32 MB |
| **Leipzig Corpora Collection**, `eng_news_2023/2024/2025_1M` | Words newer than the books (ChatGPT, TikTok, Nvidia, wellbeing) and their spellings, in `en.hextm` and `en.spellings` (#2973) | Primary pages behind a bot check. A search on the [usage page](https://wortschatz.uni-leipzig.de/en/usage) shows: corpora offered for download are "made available under the Creative Commons licence CC BY"; web services and applications are "CC BY-NC". **Version not stated on the page**; Hex says CC BY 4.0. **Partly verified.** `eng_news_2023_1M.tar.gz` exists, 287,898,033 B (HTTP HEAD), matching Hex's pin. | <https://creativecommons.org/licenses/by/4.0/> (per Hex; version not verified) | **Yes** for the downloads (attribution, cite Goldhahn/Eckart/Quasthoff LREC 2012). **Do not use their website or API** (non-commercial). | Inside `en.hextm` and `en.spellings` (0 extra) |
| **LDNOOBW** (Shutterstock and contributors) | `never-suggest.tsv`: slurs and swear words never offered | "This work is licensed under a Creative Commons Attribution 4.0 International License", "© 2012–2020 Shutterstock, Inc." — [repo](https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words) and LICENSE, verified | <http://creativecommons.org/licenses/by/4.0/> | **Yes**, with attribution and a modification notice. Dictus does not ship it yet. | 11.5 KB (iOS file), parsed in memory |
| **Hex's `en-extra-words.tsv`** | 166 chat and tech words in the model | "written for Hex by its developers: ours, not copied from any corpus" (file header); Hex is MIT | Hex `LICENSE` (MIT) | **Yes**, MIT credit | Inside `en.hextm` |
| **Hex's hand-written tables** (`unambiguousFixes`, `shorthandAllowlist`, context groups, `commonTwoLetterWords`) | Rules | Hex MIT | Hex `LICENSE` | **Yes**, MIT credit (Dictus already credits Hex in source headers) | A few KB of code |
| **Apple `UITextChecker`** | iOS validity, guesses and completions | System API | — | Yes. Not shippable data; usable in a keyboard extension (Dictus already calls it for completions). | 0 MB in the app |
| **Tatoeba** | Not shipped: the held-out benchmark and the tuning of the context margins (`AE:1294-1295`, `README.md:29-31`) | "Tatoeba's technical infrastructure uses the default Creative Commons Attribution 2.0 France license (CC-BY 2.0 FR)"; part of it is CC0 — [terms](https://tatoeba.org/en/terms_of_use), [downloads](https://tatoeba.org/en/downloads), verified | <https://creativecommons.org/licenses/by/2.0/fr/> | Only matters if sentences are shipped. Benchmark use with attribution is fine. Some sentences carry SA or ND conditions chosen by their contributors. | 0 |
| *Non-English, for completeness* | | | | | |
| RLA-ES (es_ES/es_MX Hunspell) | Spanish filter | Triple licence: GPL v3+, LGPL v3+ or MPL 1.1+, user's choice — [rla-es LICENSE.md](https://github.com/sbosio/rla-es/blob/master/LICENSE.md), verified | <https://www.mozilla.org/en-US/MPL/1.1/> | Yes under MPL 1.1, as Hex does: a file-level weak copyleft that applies only if you ship the dictionary files themselves (Hex ships only a filtered model and the notice). | Spanish only |
| NKJP n-grams | Polish counts | "NKJP ngrams are made available on CC-BY licence" (no version) — [NKJPNGrams](http://zil.ipipan.waw.pl/NKJPNGrams), verified | CC BY (version not stated) | Yes, with attribution | Polish only |
| PoliMorf | Polish filter | BSD 2-Clause — [handle 11321/577](http://hdl.handle.net/11321/577), verified | <https://opensource.org/licenses/BSD-2-Clause> | Yes, with the notice | Polish only |
| ParlaMint 5.0 PL | Polish diacritics and capitals | CC BY 4.0 — [handle 11356/2004](http://hdl.handle.net/11356/2004), verified | <https://creativecommons.org/licenses/by/4.0/> | Yes, with attribution | Polish only |
| NB N-gram 2026 / Norsk ordbank 2005 | Bokmål | CC0 / CC BY 4.0 — [data.norge.no](https://data.norge.no/nb/datasets/f2eebe8b-bd83-34e4-bcf3-c0c5e37a77f8/n-grammer-fra-nasjonalbiblioteket-2026), [ordbank](https://data.norge.no/en/datasets/f0db926d-a154-3a12-82b8-6573b57f6dbb/norsk-ordbank-norwegian-bokmal-2005), verified | CC0 1.0 / CC BY 4.0 | Yes | Bokmål only |
| ParlaIbero BR/PT | Portuguese | CC BY 4.0 per Hex's `credits.txt` | — | **Not verified** | Portuguese only |
| Unicode emoji-test / CLDR | Emoji suggestions (not autocorrect) | Unicode License v3 per Hex's `credits.txt` | — | **Not verified** (out of scope) | — |

These are not Hex's sources, but they come up in the comparison, so they were checked too:
- Dictus's `orgtre/google-books-ngram-frequency` is "licensed under the Creative Commons Attribution 3.0 Unported License" (verified).
- `orgtre/top-open-subtitles-sentences` says its lists "come with the same license as the underlying corpus" (OPUS OpenSubtitles2018). **The OPUS terms were not verified.** Dictus should check them separately, since its `en_ngrams.dict` uses them.

---

## 13. What Dictus could take for English, ranked

| # | What | From Hex | Licence | Size cost per language |
|---|---|---|---|---|
| 1 | **Replace `en.hextm` with Hex tip's model.** Gives contractions at real frequency, `i'm`/`i'll`/`i'd`, chat words, names and days, news words. Makes the decoder and any context model able to choose `I'm`, `don't`, `it's`. | `ios/HEXKeyboard/TypingModel/en.hextm` (SHA-256 `98c8da8f…`), built by `BTM` | Google Books CC BY 3.0 + SCOWL notice + Leipzig CC BY (4.0 per Hex) + Hex MIT; add the Leipzig attribution to Dictus's acknowledgements | **0 MB net**: 3,599,997 B replaces 3,600,000 B; memory-mapped |
| 2 | **English casing and contraction table:** `i` → `I`, `im` → `I'm` (not `i'm`), `I've`/`I'm` with an apostrophe typed, `wont` → `won't`, `yall` → `y'all`, plus the missing transpositions (`teh`, `hte`, `jsut`, `knwo`, `waht`, `iwth`…) | `AE+Dict:37-164`, `AE+Dict:207-218` | MIT | A few KB of code |
| 3 | **Shorthand allowlist** (never rewrite `tbh`, `idk`, `brb`, `ngl`, `nvm`, `ikr`, `tmrw`… which Dictus's word list lacks), plus `en-extra-words.tsv` into `en_frequency.json` | `AE+Dict:27-34`, `ios/scripts/en-extra-words.tsv` | MIT | < 5 KB |
| 4 | **LM context choice for same-letter words** (`id`/`I'd`, `ill`/`I'll`, `well`/`we'll`, `lets`/`let's`, `its`/`it's`, `your`/`you're`, `there`/`their`/`they're`, `then`/`than`): previous-word choice on space plus next-word revision, with margins of 3/1.5 nats (apostrophe only) and 6/3 nats (letters). Needs #1. | `AE:1268-1383` | MIT (the margins were tuned on Tatoeba, CC BY 2.0 FR, which is not shipped) | 0 MB (reads `en.hextm`); about 100 lines |
| 5 | **`en.spellings`** (`chatgpt` → `ChatGPT`, `github` → `GitHub`, names in the news), and with it the lowercase-name capital rule (`monday` → `Monday`, via `UITextChecker`'s capitalised-only check as Hex does) | `ios/HEXKeyboard/TypingModel/en.spellings`, `AutocorrectEngine+Spellings.swift`, `AE:1243-1264` | SCOWL notice + Leipzig CC BY + Hex MIT | 4.6 KB, memory-mapped |

Runners-up:
- the ≤ 1.35 keyboard-cost confidence gate on one-edit guesses (`AE:1131-1145`);
- the English two-letter neighbour fix (`KeyboardLanguage.swift:808-812`);
- the missed-space-with-slip fallback (#2244, `TD:586-596`);
- LDNOOBW never-suggest (CC BY 4.0, 11.5 KB).

Hex's numbers suggest none of these would change keyboard latency measurably: 0.09 ms median per letter on Android for the whole decoder. Hex states no iOS timing; the study's README gives the simulator numbers for the parts it could run.
