# A bilingual French + English keyboard with automatic language detection

Study, 2026-11-21. No product code changes here. Customers ask for one keyboard that
types French and English without a switch. Today the keyboard holds one language at a
time (`TextPredictionEngine.setLanguage`, #555), and the app has one "Keyboard
language" picker.

The failure this would fix, seen on Pierre's iPhone on 2026-11-20: he typed French on
the keyboard set to English, and `Oji` became `Oki`, `ma'qje` became `ma'que`, and
`jusge` became `judge`. Those were 3 of his 5 undos.

Everything below was measured on an iPhone 17 simulator running iOS 26.5, under
Xcode 27.2, on develop `0071440e`. The prototype lives on the local branch
`proto/bilingual-detection` (commits `90e0b0c3`, `c2dd42bf`). It was never pushed and
nothing on it is meant to ship. [What it changes](#reproduce) is listed at the end.

## In short

| Question | Answer |
|---|---|
| Memory: two languages loaded | At rest, no difference (31.8 MiB against 31.8, simulator). After typing, **+2.9 to +4.1 MiB** (43.5 against 39.9 on average, +3.6). Tries and n-grams stay 100% clean mapped file (0 KB dirty); the growth is heap, Apple's spell checker for the second language. |
| Detection: language decided right | French run 152 / 152 words, English run 154 / 155. Mixed run: 98 / 112 words in their sentence's language. 14 of 15 English inserts in French sentences do not flip the language. After a change of language between messages, the switch takes 1.3 words on average. |
| Detection: wrong words when it drives autocorrect | French 9 / 152 and English 8 / 155, identical to today's single-language keyboard. Mixed French + English: **10 / 127**, against 37 for the French keyboard, 22 for the English one, and 7 for a perfect per-word oracle. |
| Engine | Two engines (one per language) plus a window and a "keep the typed word" rule. A merged candidate pool would need a new C++ interface and a rewritten `spellCheck` to win at most 3 words on this run. |
| Cost per keystroke | Letters: unchanged as long as the bar asks the detected language only. Asking both languages multiplies the French p50 by 9 (English `UITextChecker`). Space: +0.3 ms at p50 on English text (simulator). |
| Layout | One grid, the primary language's layout: AZERTY for a French primary. English already types and autocorrects on AZERTY (#272); measured 9 wrong words on AZERTY against 8 on QWERTY. |
| UI | Keep "Keyboard language" as the primary; add "Second language" (None / English). Three of the files are #992's (Iris): `SettingsView.swift`, `SharedKeys.swift`, `Localizable.xcstrings`. Exact changes are in §4. |
| Plan | Five PRs, each with a measurable target (§5). |

## 1. Memory: both languages loaded

`phys_footprint` of `DictusKeyboard` in MiB, read with `footprint` (the figure jetsam
uses). The protocol is #555's, on a Release build with Full Access granted and the
keyboard in a Reminders title, on one simulator dedicated to this study and slimmed
with simslim.

Both configurations ran the same binary; the App Group flag `protoBilingualSecondary`
switched between them, three trials of each, alternating:

- **One language:** French only, as today.
- **French + English:** the English engine mounted when the keyboard appears, and asked
  for its completions and its correction on every letter and every space. The answers
  were thrown away.

Each trial:

1. A fresh keyboard process, shown once, then 30 s idle.
2. The last 6 French bench sentences typed with `sim_replay.py`.
3. The last 6 English sentences typed. The keyboard stays French: a bilingual keyboard
   does not switch. The English taps land on the AZERTY grid.
4. The keyboard shown again, then 30 s idle.

| | One language | French + English | Difference |
|---|---:|---:|---:|
| At rest, after 30 s | 31.6, 31.8, 32.0 | 31.8, 31.8, 31.9 | none measurable |
| After the 12 sentences, then 30 s idle | 39.5, 39.6, 40.6 | 43.6, 43.5, 43.5 | **+2.9 to +4.1** per alternating pair (means 39.9 and 43.5: +3.6) |
| Process peak (`phys_footprint_peak`) | 40.7, 41.2, 41.1 | 45.1, 45.2, 45.1 | **+4.0 to +4.4** |

**Dirty and clean.**

- **The dictionaries cost nothing dirty.** In every trial the four dictionary files are
  0 KB dirty and 0 KB swapped (`mapped-dictionaries.txt`). At rest, resident clean
  mapped files go from 17 MB with one language to 23 MB with two. Those pages are
  clean and file-backed: the system can drop them under pressure, and
  `phys_footprint` does not count them.
- **What grows is the heap.** Malloc Small dirty after typing is 17 to 18 MB with one
  language and 21 MB with two (`footprint-*-after-typing.txt`). #555 attributed the
  growth while typing to `UITextChecker.completions(…)` loading each language's data
  and keeping it. That attribution was not redone here; the +3 to +4 MB matches the
  English checker being loaded on top of the French one.
- **At rest, nothing moves.** The second frequency list (0.4 MiB) and n-gram index
  (1.2 MiB, #555's figures) sit inside a Malloc Small of the same dirty size in both
  configurations. The difference shows up as reclaimable pages: 13 MB with two
  languages against 9 MB with one.
- **Before the allocator step.** All six resting readings sit at about 32 MB, where
  #555 placed its readings taken before the allocator's deferred ~5 MB step. The
  typing phases include that step in both configurations.

**Against the budget.**

- The pair costs about +4 MB on the simulator. #555 measured the keyboard at 62 to
  68 MB on a device, and Pierre gives about 180 MB as the iPhone 15 Pro Max budget.
  Neither the device figure for the pair nor that budget was measured here.
- The +4 MB is the worst case: the prototype asks English for completions on every
  French letter. With the bar served by the detected language only (§3), a user who
  types only French never loads the English checker.
- A user who types both languages pays what today's user pays after switching
  language once. #555's session, fr then en, ended at 42 to 43 MB.
- Not measured, as in #555: dictation (+18 MB) and the emoji panel (+8 MB). The pair
  does not touch them.

## 2. Detection

### What the prototype does

At every space, the prototype scores the word just typed against each language, then
folds the score into a short window. The window's language picks the dictionary that
autocorrects the word. Suggestions come from that language too.

**Per-word score.** Each language gets an evidence value in nats, and the vote is
`evidence(fr) − evidence(en)`, clipped to ±4. The evidence is built from:

- **Lexical.** Where the word is in the language's trie, or what reaches it:
  - in the trie: its log-frequency;
  - reached by accent expansion (`tres` → `très`) or contraction expansion
    (`cest` → `c'est`): the target's log-frequency;
  - reached only by the trie's correction: the correction's log-frequency, minus
    3 nats;
  - not reachable at all: −16.
- **Context.** The bigram score of the word after the previous word, up to +2.
- **French elision.** A `c'`, `j'`, `l'`, `d'`, `n'`, `s'`, `m'`, `t'` or `qu'` prefix
  adds 3 to French.

The two tries are not on the same scale, and raw frequencies are not comparable:

- The trie stores `65535 · ln(1+count) / ln(1+max)` (`tools/dict_builder.py`).
- The French counts are subtitles, top word 2.9 million. The English counts are
  Google Books, top word 23 billion.
- An English word therefore reads about 0.15 higher than a French word of the same
  rank.
- The prototype converts both to "nats below the language's most frequent word",
  `(f/65535 − 1) · ln(1+max)`. That comparison is fair. Without the conversion,
  `projet` and `client` read as English.

**Window with hysteresis.** `score ← 0.6 · score + vote`. The language flips only when
the score crosses ±3 toward the other language. A word valid in both languages
(`table`, `train`, `a`, `on`) votes near zero. A clearly English word votes about −4,
which is not enough to flip from a French steady state. It takes two English words in
a row. The window carries over from one message to the next and starts in the
primary language.

**Keep the typed word when the other language likes it better.** The window decides
which dictionary corrects a word, so a single English word inside a French sentence is
still checked by the French dictionary. On its own, that dictionary turns `call` into
`camp`. The fix is one rule. When the active language proposes a correction for a
word it does not know, and the other language knows that word, the word stays as
typed if the other language finds it at least as likely as the active language finds
its correction. Both sides are measured in the same nats. Some examples:

| Typed | Active language | Its correction | Other language | Result |
|---|---|---|---|---|
| `call` | French | `camp` | English, `call` is common | `call` stays |
| `the`, at a sentence start | French | `thé` | English, `the` is common | `the` stays |
| `telephone` | French | `téléphone` | English, `telephone` is rarer than `téléphone` in French | becomes `téléphone` |

Without this rule, the mixed run below has 21 wrong words. With it, it has 10.

### Measured on the #954 runs and a mixed run

The replay uses the #954 bench's grid and hit test. Its rejection memory and counting
site are the shipping ones, and so is `spellCheck`, which the prototype only routes
between two engine instances. The hash seed is fixed, as in `tools/keyboard-bench`.

**The mixed run is new.** It has 20 sentences, 127 words and 626 taps, with the same
seeded touch model as #954 (`mixed.txt`, `mixed.lang` and `mixed.tsv` in this
folder):

- 10 French sentences with English inserts, among them `c'est trop cool`,
  `on se fait un call demain matin`, `le meeting est décalé à jeudi`,
  `tu peux me forward le mail` and `il faut checker les slides avant le meeting`.
- 1 English sentence with a French insert (`croissant`).
- 9 sentences that alternate between the two languages, as in a conversation.

Each word carries a gold language, and each sentence carries the language most of its
words are in.

Policies:

- `mono-fr` / `mono-en`: today, one language loaded.
- `oracle`: each word corrected in its gold language, which is the ceiling for any
  per-word choice.
- `union`: French, but nothing is corrected that English knows.
- `detect`: the design above.

Wrong words in the final text, counted per committed word, case-insensitive:

| Run | Words | `mono-fr` | `mono-en` | `oracle` | `union` | `detect` |
|---|---:|---:|---:|---:|---:|---:|
| French (#954), AZERTY | 152 | **9** | 57 | 9 | 15 | **9** |
| English (#954), QWERTY | 155 | 100 | **8** | 8 | 18 | **8** |
| English (#954), AZERTY | 155 | 98 | **9** | 9 | 18 | **9** |
| Mixed, AZERTY | 127 | 37 | 22 | 7 | 10 | **10** |

`detect` matches today's keyboard on monolingual French and English, with the same
wrong words. On mixed text it moves from 37 or 22 wrong words to 10, against a
ceiling of 7. The `mono-fr` French and `mono-en` English numbers reproduce the #954
baseline: the same nine French words (`région`, `dévaler`, `a` for `à`...) and the
same English ones (`irving`, `finish`, `hourglass`...). This bench counts committed
words, so two words joined by a missed space count once: 155 English words against
#954's 157.

Language decided per word, `detect`:

| Run | Right language |
|---|---|
| French (#954) | 152 of 152 |
| English (#954) | 154 of 155. The first word is decided French, because the window starts in the primary language. |
| Mixed, words in their sentence's language | 98 of 112 (87.5%). 13 of the 14 misses are the first word or two after the conversation changes language. 1 follows `full remote`, two English words in a row, which flipped the window for `cette`. |
| Mixed, English words inside a French sentence (and `croissant`) | 1 of 15 flipped the window; 14 did not. 13 of the 15 stayed exactly as typed. `forard` became `forage`, a typo inside an insert that French corrects. `checker` became `chercher`, because French finds `chercher` more likely than English finds `checker`. |
| Switch latency at the 10 language changes of the mixed run | 1.3 words on average (1, 1, 2, 1, 2, 1, 1, 1, 1, 2) |

The 3 wrong words `detect` has beyond the oracle are `forard` → `forage`,
`checker` → `chercher`, and `good` → `fois` (the second word of an English message,
before the window switched). Both `detect` and the oracle get `je` → `He`/`Hé` wrong,
the same typo leading to different wrong words.

**Sensitivity.** One parameter was changed at a time; the others stayed at their
defaults. The default row is listed first:

| Change | French | English | Mixed |
|---|---:|---:|---:|
| none (θ 3, λ 0.6, margin 0) | 9 | 8 | 10 |
| θ 1.5 | 9 | 9 | 9 |
| θ 4.5 | 9 | 9 | 12 |
| λ 0.4 | 9 | 10 | 9 |
| λ 0.8 | 9 | 8 | 13 |
| margin −2 (keeps more typed words) | 11 | 8 | 9 |
| margin +2 (keeps fewer typed words) | 9 | 8 | 14 |

Across all six changes, monolingual typing moves by at most 2 words, and the mixed run
stays between 9 and 14.

**What these numbers are worth.**

- One person wrote the mixed run (this study), and the same run was used to tune the
  design. The keep rule was revised twice after seeing it: first an absolute frequency
  threshold, then an exception for accents, then the comparison above.
- The French and English #954 runs are the guard that the tuning did not break
  monolingual typing. They are not a test of mixed typing.
- The first PR of the plan adds a held-out mixed corpus, ideally real sentences from
  the typing journal (#1001).

### Pierre's three words

Each word was scored alone, with no previous word. Pierre's intended words were not
recorded.

| Typed | English keyboard, device 2026-11-20 | French engine (simulator) | Vote |
|---|---|---|---|
| `Oji` | `Oki` | `oui` | +4 (French) |
| `ma'qje` | `ma'que` | `ma'que` | +4 (French) |
| `jusge` | `judge` | `juste` | +2.6 (French) |

- **`Oji`.** In a French message, `detect` writes `oui`, and so would a first word on
  its own: its vote is the maximum.
- **`jusge`.** It becomes `juste`, not `judge`. If `jusque` was meant, the French
  engine misses it too: `jusque` is 2 edits away, `juste` only 1.
- **`ma'qje`.** Both languages correct it to `ma'que`. Detection does not change it;
  the word belongs to the apostrophe handling, not to language choice.

### What others do

None of the vendors below publishes how it handles a loanword. The only mechanism in
the open is AOSP's, a per-language streak counter with a clamp, which is the same idea
as the window above.

- **Apple** (multilingual typing, iOS 10 to today):
  - Apple: "you can type in two languages without having to switch between keyboards"
    and "Your keyboard automatically switches between the two languages you use most
    often (Available for select language pairs.)"
    ([iPhone User Guide](https://support.apple.com/en-ph/guide/iphone/iph73b71eb/ios)).
  - The feature-availability page lists French and English among the multilingual
    typing languages, but not as named pairs
    ([apple.com/ios/feature-availability](https://www.apple.com/ios/feature-availability/#quicktype-keyboard-multilingual-typing)).
  - Granularity is documented only secondhand. MacStories (iOS 10): "detect languages
    on a word-by-word basis", including "Switching mid-sentence between Italian and
    English". The same review says it then worked on QWERTY keyboards only
    ([MacStories](https://macstories.net/stories/ios-10-the-macstories-review/26)).
  - Nothing official on AZERTY French plus QWERTY English. We could not test it here:
    Apple's French autocorrect does not run on a stock simulator runtime (#954).
- **Gboard:**
  - Google's paper: "users can enable on-the-fly, on-device mixing of many of Gboard's
    monolingual language models", and "it is not currently possible to enable this
    multilingual mode across languages that use different scripts"
    ([arXiv 1912.01218](https://arxiv.org/abs/1912.01218), §5.3). That means
    monolingual models mixed at decode time, with no separate language detector.
  - A layout is picked per language, and Google advises "stick to one or two active
    languages" ([Gboard help](https://support.google.com/gboard/answer/9058584)).
  - Nothing published on loanwords or on accuracy.
- **SwiftKey** ([Microsoft support](https://support.microsoft.com/en-us/swiftkey-keyboard/how-to-use-microsoft-swiftkey-keyboard-with-more-than-one-language)):
  - Up to five languages on Android, two on iOS, detected "by constantly scanning
    input text to estimate which of the enabled languages are being used".
  - Detection works only "For languages with the same alphabet/layout". With
    "QWERTY & AZERTY" you "slide left or right on the spacebar to choose your desired
    layout". This is the only vendor that answers the layout question, and the answer
    is one shared layout or a manual switch.
- **Hex** ([kitlangton/Hex](https://github.com/kitlangton/Hex)):
  - A macOS dictation app, not a keyboard.
  - One "Output Language" setting, defaulting to Auto. WhisperKit then detects the
    language once per recording (`detectLanguage: language == nil` in its source).
  - No word-level logic, so nothing to take for typing.
- **AOSP LatinIME / HeliBoard:**
  - AOSP keeps a confidence per language, "the number of times a word from this
    language has been committed in a row", and weights the other language 0.6 while
    typing, values its own comment calls "ad-hoc"
    ([DictionaryFacilitatorImpl.java](https://android.googlesource.com/platform/packages/inputmethods/LatinIME/+/refs/heads/main/java/src/com/android/inputmethod/latin/DictionaryFacilitatorImpl.java)).
  - HeliBoard caps that confidence at 2, so that one out-of-dictionary word only
    clamps it ("allows conveniently typing single words not in the dictionary without
    affecting suggestions"). Mid-sentence, it does not let a language far behind take
    over
    ([DictionaryFacilitatorImpl.kt](https://github.com/Helium314/HeliBoard/blob/main/app/src/main/java/helium314/keyboard/latin/DictionaryFacilitatorImpl.kt)).
- **Research:** code-switched language identification "is harder than you think"
  ([Burchell et al., EACL 2024](https://arxiv.org/abs/2402.01505)). We found no
  published word-level figure for French/English.

## 3. Engine: two engines, or one merged pool

**Option A: two engines.**

- Two `TextPredictionEngine` instances, each with its own trie, n-grams, frequency
  list and `UITextChecker` language. This is what the prototype runs.
- The window picks the engine for each word, and the keep rule compares the two.
- Every rule the French engine has (overrides, accent and contraction expansion, the
  elision fix, the split pass) stays as it is, because each instance runs its own
  pipeline.

**Option B: one candidate pool scored per language.**

- On space, collect candidates from both tries and rank them by trie score plus a
  language prior from the window.
- That needs the C++ bridge to return candidate scores, which it does not (it returns
  a correction and two alternatives).
- It also means rewriting `spellCheck`, whose steps are per language (overrides,
  accents, contractions, splits), as one ranking.
- Memory is the same as A, since both tries are mapped either way. The trie walk costs
  the same, two walks per word.
- What it could win is bounded by the oracle: 7 wrong words on the mixed run against
  `detect`'s 10. Of those 3, only `forard` → `forage` is a case a merged ranking
  plausibly fixes.

**Recommendation: A.** The keep rule is already the useful part of B: it compares the
two languages' likelihoods for the typed word.

Cost per keystroke, from the replay, in microseconds, Mac simulator (#591: not a
device figure). A letter runs the correction preview and the suggestions; a space
runs the autocorrect.

| Run | Policy | Letter p50 | Letter p95 | Space p50 | Space p95 |
|---|---|---:|---:|---:|---:|
| French | `mono-fr` | 102 | 535 | 84 | 485 |
| French | `detect` | 100 | 490 | 97 | 1320 |
| French | `detect`, bar from both languages | 948 | 1434 | 102 | 1343 |
| English (QWERTY) | `mono-en` | 860 | 1649 | 51 | 608 |
| English (QWERTY) | `detect` | 846 | 1545 | 340 | 1564 |
| Mixed | `mono-fr` | 109 | 601 | 104 | 601 |
| Mixed | `detect` | 261 | 1229 | 86 | 1336 |
| Mixed | `detect`, bar from both languages | 950 | 1525 | 87 | 1362 |

- **Letters.** What a letter costs depends on which `UITextChecker` language serves
  the completions:
  - English completions cost about 0.85 ms at p50, French about 0.1 ms. #954 already
    measured this eight-fold gap.
  - Detection itself adds nothing per letter.
  - Asking both languages for completions puts the English cost on every French
    letter: p50 rises nine-fold, from 0.10 to 0.95 ms. So the bar shows the detected
    language only.
- **Spaces.** Detection scores the word in both languages, which costs +0.3 ms at p50
  on English text and about +0.8 ms at p95. Scoring an English word against French
  runs the French correction.

## 4. Product and UI

### Choosing the languages

- The picker stays as it is and keeps its meaning: "Keyboard language" is the
  **primary** language. It still drives the layout, the spacebar label, transcription
  in "Follow keyboard language", and everything else that reads `dictus.language`
  today.
- A second picker below it, "Second language", offers "None" and the other keyboard
  languages.
- v1 offers the second language only for the French + English pair, in both orders.
  These are the only two languages measured here. Spanish and German follow the same
  path once #978's runs exist for a mixed bench.
- The keyboard panel (#241) shows the pair as the active row, for example
  "Français + English". Tapping a single language there turns bilingual mode off.
  Panel and Settings write the same keys.
- **Not on the spacebar.** No language indicator goes on the space bar in v1: a label
  that changes on every word moves under the thumb. The panel row says which pair is
  on. Apple's faint "EN FR" on the spacebar is reported only in an unverified forum
  thread.

### Which layout

**One grid: the primary language's layout.** A French primary means AZERTY by default,
or whatever the user chose for French.

- The grid cannot follow the detected language. The keys would move under the thumb
  between two words, and detection only knows the language after the space.
- SwiftKey supports automatic detection only when both languages share a layout.
- Dictus already types English on AZERTY with English autocorrect, since #272.
- Measured here, English on AZERTY costs one word: 9 wrong words against 8 on QWERTY,
  same engine.
- Both engines load with the active layout's proximity costs and spacebar neighbours.
  The prototype does exactly that.
- The AZERTY apostrophe key already types English contractions (`don't`), through
  `FrenchAdaptiveKey`.

### Files the product change touches

**#992's files, owned by Iris: not to be edited before #992 lands.** These are the
exact changes, so Titus can schedule them after it:

| File | Change |
|---|---|
| `DictusCore/Sources/DictusCore/SharedKeys.swift` | Add `public static let secondaryKeyboardLanguage = "dictus.secondaryKeyboardLanguage"`: a `SupportedLanguage.rawValue`, absent or equal to `language` meaning monolingual. `language` keeps its meaning (primary). |
| `DictusApp/Views/SettingsView.swift` | Below the "Keyboard language" picker (Section 2, Clavier), add a `Picker("Second language", …)` bound to `@AppStorage(SharedKeys.secondaryKeyboardLanguage)`. Its options are "None" plus the languages allowed with the primary (v1: English for French, French for English). Writes go through the new DictusCore helper below. Add a footer to the section. When the primary changes to a language the pair does not allow, the picker resets to "None". The Layout picker is unchanged: it sets the primary's layout, which is the whole keyboard's. |
| `DictusApp/Localizable.xcstrings` | New keys with fr translations: "Second language" / « Deuxième langue »; "None" / « Aucune »; footer "Dictus detects which of the two languages you are typing and corrects each word in that language. The keys follow the first language's layout." / « Dictus détecte laquelle des deux langues vous tapez et corrige chaque mot dans cette langue. Les touches suivent la disposition de la première langue. » ("vous" register, no em dash). |
| `DictusKeyboard/Localizable.xcstrings` (also in #992) | The panel row's pair label (`"%@ + %@"`), and "Second language" / « Deuxième langue » if the panel gets a toggle. |

**Files outside #992** that the change also needs:

| File | Change |
|---|---|
| `DictusCore/Sources/DictusCore/KeyboardLanguagePair.swift` (new) | Reads and writes the pair, says which pairs are allowed (v1: fr+en), and clears the second language when it equals the primary. Unit-tested. |
| `DictusCore/Sources/DictusCore/LanguageWindow.swift`, `WordLanguageVote.swift` (new) | The vote and the window, as pure functions over a small protocol (word exists, frequency, accent and contraction expansion, correction, bigram), like `FrequencyProvider`. Unit-tested with the cases `c'est trop cool`, `on se fait un call`, `le meeting`, and one English message after a French one. |
| `DictusKeyboard/TextPrediction/TextPredictionEngine.swift` | No longer one engine: one instance per language, a primary and an optional secondary, each loaded with the active layout. `isUnknownToDictionary` must answer "unknown to both". Otherwise every English word typed in a bilingual keyboard is learned as a new French word (#287's gate). |
| `DictusKeyboard/TextPrediction/AOSPTrieEngine.swift` | No functional change. The vote reads `wordFrequency`, `bigramScore`, `accentExpansion` and `contractionExpansion` from both instances. |
| `DictusKeyboard/TextPrediction/SuggestionState.swift` | The preview and the bar ask the engine of the window's language. |
| `DictusKeyboard/DictusKeyboardBridge.swift` | `autocorrectBeforeCursor`: push the vote, correct with the window's engine, apply the keep rule. |
| `DictusKeyboard/KeyboardViewController.swift` | `viewWillAppear` / `handleLanguageChange`: load the pair, not one language. Each keyboard process starts the window in the primary language. |
| `DictusKeyboard/Views/KeyboardPanelView.swift` | The pair row (see above). |
| `.claude/skills/verify-dictus-ios/features/keyboard.languages.md` and `screens.md` | In a separate doc PR after the feature, per the map rule. |

## 5. Plan

Five PRs, in order. Each one has a target that can be checked before it merges.

1. **Detection as tested logic, and a bilingual bench. No keyboard change.**
   - **What it adds.**
     - In DictusCore: `WordLanguageVote`, `LanguageWindow`, `KeyboardLanguagePair` and
       their unit tests.
     - In `tools/keyboard-bench`: a `--pair fr,en` mode that replays with two engines,
       plus the mixed corpus from this folder.
     - A held-out mixed corpus of 20 sentences, not written by whoever tunes the
       parameters.
   - **Targets.**
     - On the committed runs, the pair equals monolingual typing: French 9 / 152 and
       English 8 / 155, with the same words.
     - Mixed: at most 10 / 127.
     - Held-out mixed: at most half the wrong words of `mono-fr`, and fewer than
       `mono-en`.
     - Unit tests: `c'est trop cool`, `on se fait un call`, `le meeting` never flip
       the window, and an English message after a French one flips within 2 words.
2. **Two engines in the keyboard, behind `secondaryKeyboardLanguage`, with no UI.**
   The key is set by hand on a simulator or a device. This PR also makes the learning
   gate answer "unknown to both".
   - **Targets.**
     - With no second language, the in-process replay is byte-identical to develop
       (`taps.tsv`, `commits.tsv`, `texts.tsv`).
     - With the pair: `phys_footprint` at rest within +1 MiB of one language. After the §1 typing session, within +5 MiB with both languages typed, and within +1 MiB when only French is typed (the bar asks the detected language only). Measured on the simulator with the #555 protocol, three alternating trials each, then the same session read once on a device from the `KeyboardMemory tick` lines of the debug log.
     - Replay: French letter p95 within 0.1 ms of `mono-fr`, and space p95 at most
       1.5 ms (simulator).
     - Smoke test passes.
     - No English word of the mixed run ends up in the user dictionary.
3. **Settings and keyboard panel.** These are the #992 files listed above, so the PR
   is scheduled after #992 merges.
   - **Targets.**
     - Smoke test passes.
     - The Settings picker and the panel row are captured in French and English.
     - Label `needs-physical-test`. On device, Pierre retypes the French message of
       2026-11-20 with French + English on, and none of `Oji`, `jusge`, `ma'qje`
       becomes an English word.
4. **The verify-dictus-ios map.** `keyboard.languages`, `screens.md`. This is a doc
   PR, separate from the feature, per the project rule.
5. **One week on device with the typing journal (#1001).**
   - **Targets.**
     - The share of autocorrections undone with the pair on is no higher than with
       the monolingual French keyboard in the same journal.
     - No French word in a French message is corrected into English.

## Reproduce

On the local branch `proto/bilingual-detection` (two commits on develop `0071440e`):

- **`DictusKeyboard/TextPrediction/TextPredictionEngine.swift`.**
  - `init(initialLanguage:)` is no longer private, and a `trie` accessor is added.
  - A `secondary` English engine is loaded when the App Group flag
    `protoBilingualSecondary` is set, and mounted at keyboard appearance.
  - It is queried on every letter and every space, with its result discarded. Only
    the memory measurement uses it.
- **`tools/bilingual-bench/`.**
  - `run.sh <udid> fr:azerty,en:qwerty,mixed:azerty,en:azerty <out>` compiles the
    shipping engine sources with the bench and replays every policy.
  - `score.py <out>` prints the tables above.
  - `BI_THETA`, `BI_LAMBDA`, `BI_VETO` and the other `BI_*` variables override the
    parameters, and `BI_PROBE=word,prev|word` prints the vote for single words.
- **Memory.**
  - `setup.sh` and `memory-trials.sh` are kept outside the repository with the raw
    output. They are adapted from `docs/research/555-keyboard-memory/scripts`.
  - The English taps were replayed on AZERTY, because the bilingual keyboard types
    English on the primary layout.

Files in this folder:

| File | What |
|---|---|
| `mixed.txt`, `mixed.lang` | The mixed corpus and its gold language per word (`f`/`e`). |
| `mixed.tsv` | Its touch run, `make_runs.py --seed 954`. |
| `detection-report.md` | `score.py` output for the default parameters: every policy, every wrong word, the word-by-word decisions on the mixed run, the cost table. |
| `sensitivity.txt` | The `detect` rows of the six one-parameter changes. |
| `memory-trials.txt` | The six memory trials, one line each. |
| `footprint-mono-*.txt`, `footprint-pair-*.txt` | `footprint` with categories: one language and French + English, at rest and after typing (trials 5 and 6). |
| `mapped-dictionaries.txt` | `vmmap` lines of the dictionary files after typing: resident, dirty, swapped. |
