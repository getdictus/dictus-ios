# `a` / `à`: Dictus against Apple's French keyboard

Research only, no product code (refs #501, #971, #954). Question: how far is Dictus
from Apple's French keyboard on `a` / `à`, is #971 worth merging as it is, and does
Dictus need a step that fixes a word **after** the next one is typed to get close?

All runs: iPhone 17 simulator, iOS 26.5, Xcode 27.2, macOS 27.0, my own simulator
(`docs/research-a-grave-vs-apple`), 2026-11-19. Dictus develop = `13c134a1`,
#971 = `09c4bb0a`.

## Result in one table

124 scored tokens (`a`, `à`, `m'a`, `qu'à`, `jusqu'à`…) in 117 sentences, typed
lowercase, without accents, a space after every word.

| Case | Tokens | Expected | Apple | Dictus develop | #971 |
|---|---:|---|---:|---:|---:|
| Sentence start (`à demain`) | 9 | `à` | **9** | 0 | 0 |
| Start of a sentence, a longer one (`À deux on ira plus vite`) | 6 | `à` | **6** | 0 | 0 |
| After a noun, verb (`le problème a été réglé`) | 10 | `a` | 10 | 10 | 10 |
| After a noun, preposition (`une machine à laver`) | 10 | `à` | **9** | 0 | 0 |
| After an adjective (`facile à faire`) | 5 | `à` | **5** | 0 | 4 |
| After a verb or infinitive (`je pense à toi`) | 15 | `à` | **15** | 0 | 13 |
| Set phrases (`à pied`, `à cause`, `à peine`) | 12 | `à` | **12** | 0 | 10 |
| `il a` + noun / adverb / participle | 12 | `a` | 12 | 12 | 12 |
| Pronoun subject (`ça a marché`, `chacun a`) | 5 | `a` | 5 | 5 | 5 |
| Relative clause (`ce que tu as fait a marché`) | 7 | `a` | 7 | 7 | 7 |
| Names (`Marie a`, `écrit à Marie`) | 6 | both | 6 | 4 | 5 |
| Elisions (`m'a`, `jusqu'à`, `qu'à`) | 11 | both | 11 | 6 | 10 |
| `y a` | 6 | both | 6 | 5 | 6 |
| Questions (`à qui tu parles`, `qui a appelé`) | 8 | both | **8** | 3 | 6 |
| `a` inside a sentence of another case (`on a une maison à vendre`) | 2 | `a` | 2 | 2 | 2 |
| **Total** | **124** | | **123** | **54** | **90** |

- **Apple: 123 of 124.** The one miss is `un fer a repasser` (left `a`, the bar
  offered `avant`, `avec`).
- **Split by the right form:** 54 tokens should stay `a`, and all three keyboards keep
  all 54. 70 should become `à`: Apple writes 69, #971 36, develop 0 (develop never
  writes `à`, so its 54 is exactly the tokens that needed no change).
- **#971: 90 of 124, 36 more than develop, 0 broken.** No `a` that should stay `a`
  became `à`.
- **The 34 tokens #971 still misses**: 17 at the start of a sentence (`à demain`,
  `à qui`), 10 after a noun (`machine à laver`, `sac à dos`), and 7 scattered (`jouer
  à deux`, `penser à tout`, `la première à arriver`, `le livre à moitié`, `là à huit
  heures`, `Thomas à midi`, `qu'à demander`).

## When Apple decides

| When the word changed | Tokens |
|---|---:|
| At the space after it | 68 |
| At the space, then changed back after the next word (retroactive) | 5 |
| Never (no change was needed, or the miss above) | 51 |
| Never, but the bar offered `à` (suggestion only) | 0 |

Apple decides `à` **at the space**, from the words before, in every case, including
after a noun (`une machine à`, `un sac à`) and at the start of a sentence. It never
needed the next word to write an `à`.

The 5 retroactive changes all go the other way: Apple wrote `à` at the space, then put
`a` back once the next word showed a verb. All 5 follow a noun or a relative clause:

| Typed | At the space | After the next word |
|---|---|---|
| `la boulangerie a` | `la boulangerie à` | `la boulangerie a fermé` |
| `ce que tu as fait a` | `… fait à` | `… fait a marché` |
| `ce qu'il a dit a` | `… dit à` | `… dit a choqué` |
| `la maison où j'habite a` | `… j'habite à` | `… j'habite a un` |
| `l'homme qui parle a` | `… parle à` | `… parle a raison` |

So Apple guesses eagerly at the space and uses the next word as a safety net. #971
does the opposite: it writes `à` only when the words before prove it, and never has
anything to take back.

## Recommendation

1. **Merge #971 as it is.** On this corpus it takes Dictus from 54 to 90 of 124 with
   no token broken, which matches its Tatoeba measurement (0.02% of real verbs turned
   into `à`). Nothing here argues for changing it first.
2. **The next gap does not need the next word.** Half of what #971 misses (17 of 34)
   is a sentence that starts with `a`. Apple corrects all of them at the space. A
   sentence-initial `a` followed by a space is the preposition in every sentence of
   this corpus; the verb at the start of a sentence is mostly the inverted `A-t-il`,
   which has a hyphen. That is a left-context rule, the same shape as #971's, and cheap.
3. **The next-word step is the way to the noun cases without Apple's risk.** The 10
   `noun + à` tokens are where Apple uses a language model at the space and Dictus has
   no signal on the left. The next word is a strong one there: 5 of 10 are followed by
   an infinitive (`laver`, `manger`, `repasser`, `faire`, `vendre`), which the verb
   `a` is not followed by in written French. A retroactive rule (`a` + infinitive → `à`) would reach those
   without guessing at the space, which is exactly what costs Apple its 5 take-backs.
   It is worth a measured step, after the sentence-start rule, not before: see
   [`../retroactive-correction/`](../retroactive-correction/README.md) for what it
   takes in a keyboard extension.

## Can Apple's French autocorrect run on the simulator?

**Yes, after installing its language asset by hand.** Out of the box it does not (#962
was right about the stock simulator). Everything below was done on my own simulator.

| # | What I tried | Result |
|---|---|---|
| 1 | Stock iOS 26.5 simulator, `AppleLanguages` = `fr-FR`, `AppleLocale` = `fr_FR`, `AppleKeyboards` = `fr_FR@sw=AZERTY` first, `KeyboardAutocorrection` on, typed `tres prendrr je vais a paris ` on Apple's AZERTY in Reminders | `Tres prendrr je vais a paris`: nothing corrected, #962 reproduced |
| 2 | Looked inside every installed iOS runtime (26.5, 27.0, 27.1, 27.2) | `System/Library/LinguisticData/RequiredAssets_fr.bundle/AssetData` is **empty** in all of them; the English one holds 50 to 54 files (lexicon, `en.lm`). The watchOS 27.2 runtime does ship French lexicon files |
| 3 | `simslim off` (the slim profile disables `mobileassetd`), then streamed the logs while the French keyboard came up | `kbd` asks MobileAsset (through DataDeliveryServices) for `com.apple.MobileAsset.LinguisticData`, `AssetLocale = fr`, `_CompatibilityVersion = 18`, `_SupportedPlatforms = "iOS Simulator"`. It downloads Apple's live catalog (455 assets) and finds **0** matching. `LinguisticDataAuto`: "Auto asset is not supported" |
| 4 | Read that catalog (the device's local copy) | French assets exist for iOS, macOS, watchOS, and one for **"iOS Simulator", at compatibility 17** (February 2026 build, content version 449, 144 MB, lexicon + `fr.lm`). None at 18 |
| 5 | Relabelled that asset to compatibility 18 in the local catalog, restarted `mobileassetd` and `kbd` | The query now finds it (1 asset), but `kbd` does not start the download by itself |
| 6 | Downloaded the asset's zip from Apple's public CDN, unzipped it as `<hash>.asset` next to the catalog, relabelled its `Info.plist` to 18, restarted both daemons | `tres prendrr je vais a paris ` → **`très prendre je vais à Paris`**. French autocorrect runs |
| – | Not tried: the iOS 27.x runtimes with this asset, and the Settings app's keyboard screens | |

Steps 5 and 6 are [`tools/install-apple-french-sim.sh`](tools/install-apple-french-sim.sh).

**Limit of this measurement.** The asset is Apple's February 2026 French simulator
build relabelled, not the one an iPhone on iOS 26.5 has downloaded. The behaviour may
differ on a phone. [`device-protocol.md`](device-protocol.md) is a 15-minute check on
Pierre's iPhone: 25 of these sentences, one per line in Notes, with the moment each `a`
changed noted by hand.

## Method

- **Corpus**: [`corpus.tsv`](corpus.tsv), 117 sentences in 14 cases, each written as
  it should end up. Every token that is `a` or `à`, alone or after an elision, is
  scored (124 tokens; a few sentences hold two).
- **Typing**: lowercase, accents folded (`a` for `à`), apostrophes typed, a space after
  every word, the last one included. Taps on key centres (no touch noise): this
  measures the decision, not the key hits.
- **Dictus**: the #954 replay (`tools/keyboard-bench/run.sh --corpus … --runs …`),
  which runs the shipping engine and records each word as committed at its space, then
  the next word. Runs generated with `make_runs.py --sigma-x 0 --sigma-y 0`
  ([`data/runs-fr.tsv`](data/runs-fr.tsv)). Run once on develop and once on a detached
  worktree at #971's head, whose bench passes the text before the cursor to
  `spellCheck` as the keyboard does. Dictus never changes a word after its space, so
  "at the space" is final.
- **Apple**: [`tools/apple_ag.py`](tools/apple_ag.py) types each sentence word by word
  with `axe` on Apple's French AZERTY in a new Reminders title, reads the title after
  every space, and before the space that commits each `a` takes a screenshot and reads
  the prediction bar with Vision OCR ([`tools/ocr/`](tools/ocr/)), because the bar is
  not in the accessibility tree. The apostrophe comes from the `123` page. One
  sentence that a second process typed into at the same time was discarded and
  retyped alone.
- **Scoring**: [`tools/score_ag.py`](tools/score_ag.py) compares each token with the
  expected form, case and the typographic apostrophe ignored, and classifies when
  Apple changed it. Output: [`data/results.tsv`](data/results.tsv); raw runs in
  [`data/`](data/).

## Limits

- Auto-capitalisation is not compared: Reminders capitalised the first word only on
  some runs. Tokens are compared lowercased.
- "Suggestion only" relies on OCR of a single character in the bar's middle slot; it
  read `à` correctly whenever Apple then applied it, and found no case where it was
  offered and not applied.
- One keyboard state: no learned words, no contacts lexicon (#971's lexicon ordering is
  not exercised here), no undo.
- Apple's asset caveat above.

## Reproduce

```bash
# Apple's French asset on your own (un-slimmed) simulator, French keyboard shown once
docs/research/a-grave-vs-apple/tools/install-apple-french-sim.sh <udid> build/agrave/dl

# OCR helpers that apple_ag.py calls (binaries next to the sources, not committed)
T=docs/research/a-grave-vs-apple/tools
xcrun swiftc -O $T/ocr/slots.swift -o $T/ocr/ocr && xcrun swiftc -O $T/ocr/band.swift -o $T/ocr/band

# Apple: word by word in Reminders (about 30 s a sentence; the last argument resumes)
python3 -I $T/apple_ag.py <udid> docs/research/a-grave-vs-apple/corpus.tsv build/agrave/apple-fr.jsonl 0

# Dictus: zero-noise runs, then the #954 replay on develop and on #971's head
grep -v '^#' docs/research/a-grave-vs-apple/corpus.tsv | tail -n +2 | cut -f2 > build/agrave/corpus/fr.txt
python3 -I tools/keyboard-bench/make_runs.py --corpus build/agrave/corpus --out build/agrave/runs \
    --langs fr --sigma-x 0 --sigma-y 0
tools/keyboard-bench/run.sh --udid <udid> --langs fr --corpus build/agrave/corpus \
    --runs build/agrave/runs --out build/agrave/out-develop

# Score
python3 -I $T/score_ag.py docs/research/a-grave-vs-apple/corpus.tsv \
    build/agrave/out-develop build/agrave/out-971 build/agrave/apple-fr.jsonl > results.tsv
```

## Every token

| # | Case | Sentence | Expected | Apple | Apple: when | Dictus develop | #971 |
|---:|---|---|---|---|---|---|---|
| 1 | start | à demain | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 2 | start | à bientôt | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 3 | start | à plus tard | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 4 | start | à tout à l'heure | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 4 | start | à tout à l'heure | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 5 | start | à vendredi alors | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 6 | start | à ce soir chez toi | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 7 | start | à mon avis c'est trop cher | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 8 | start | à quelle heure tu arrives | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 9 | cap-start | à deux on ira plus vite | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 10 | cap-start | à midi je mange avec paul | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 11 | cap-start | à la maison tout va bien | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 12 | cap-start | à table les enfants | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 13 | cap-start | à part ça tout va bien | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 14 | cap-start | à partir de lundi je travaille | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 15 | noun-a | le problème a été réglé | `a` | `a` | no change | `a` | `a` |
| 16 | noun-a | ma voiture a calé ce matin | `a` | `a` | no change | `a` | `a` |
| 17 | noun-a | le chien a aboyé toute la nuit | `a` | `a` | no change | `a` | `a` |
| 18 | noun-a | mon frère a appelé hier | `a` | `a` | no change | `a` | `a` |
| 19 | noun-a | la réunion a commencé sans moi | `a` | `a` | no change | `a` | `a` |
| 20 | noun-a | le train a du retard | `a` | `a` | no change | `a` | `a` |
| 21 | noun-a | le médecin a dit de rester au lit | `a` | `a` | no change | `a` | `a` |
| 22 | noun-a | la boulangerie a fermé plus tôt | `a` | `a` | at space, then back after next word | `a` | `a` |
| 23 | noun-a | mon téléphone a encore planté | `a` | `a` | no change | `a` | `a` |
| 24 | noun-a | le colis a bien été livré | `a` | `a` | no change | `a` | `a` |
| 25 | noun-à | une machine à laver | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 26 | noun-à | un sac à dos | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 27 | noun-à | une brosse à dents | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 28 | noun-à | la salle à manger | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 29 | noun-à | un verre à vin | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 30 | noun-à | une cuillère à soupe | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 31 | noun-à | un fer à repasser | `à` | `a` ✗ | no change | `a` ✗ | `a` ✗ |
| 32 | noun-à | j'ai un cours à midi | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 33 | noun-à | il reste du travail à faire | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 34 | extra-a | on a une maison à vendre | `a` | `a` | no change | `a` | `a` |
| 34 | noun-à | on a une maison à vendre | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 35 | adj-à | c'est facile à faire | `à` | `à` | at space | `a` ✗ | `à` |
| 36 | adj-à | je suis prêt à partir | `à` | `à` | at space | `a` ✗ | `à` |
| 37 | adj-à | c'est difficile à dire | `à` | `à` | at space | `a` ✗ | `à` |
| 38 | adj-à | c'est bon à savoir | `à` | `à` | at space | `a` ✗ | `à` |
| 39 | adj-à | elle est la première à arriver | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 40 | verb-à | je pense à toi | `à` | `à` | at space | `a` ✗ | `à` |
| 41 | verb-à | jouer à deux mains | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 42 | verb-à | il faut penser à tout | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 43 | verb-à | j'ai du mal à dormir | `à` | `à` | at space | `a` ✗ | `à` |
| 44 | verb-à | je commence à comprendre | `à` | `à` | at space | `a` ✗ | `à` |
| 45 | verb-à | elle apprend à nager | `à` | `à` | at space | `a` ✗ | `à` |
| 46 | verb-à | on arrive à la gare | `à` | `à` | at space | `a` ✗ | `à` |
| 47 | verb-à | je vais à paris demain | `à` | `à` | at space | `a` ✗ | `à` |
| 48 | verb-à | il habite à lyon | `à` | `à` | at space | `a` ✗ | `à` |
| 49 | verb-à | j'ai parlé à ta mère | `à` | `à` | at space | `a` ✗ | `à` |
| 50 | verb-à | tu as répondu à son message | `à` | `à` | at space | `a` ✗ | `à` |
| 51 | verb-à | je joue à la console | `à` | `à` | at space | `a` ✗ | `à` |
| 52 | extra-a | elle a réussi à le convaincre | `a` | `a` | no change | `a` | `a` |
| 52 | verb-à | elle a réussi à le convaincre | `à` | `à` | at space | `a` ✗ | `à` |
| 53 | verb-à | je t'invite à dîner | `à` | `à` | at space | `a` ✗ | `à` |
| 54 | verb-à | on s'est mis à courir | `à` | `à` | at space | `a` ✗ | `à` |
| 55 | phrase | je rentre à pied | `à` | `à` | at space | `a` ✗ | `à` |
| 56 | phrase | il habite à côté | `à` | `à` | at space | `a` ✗ | `à` |
| 57 | phrase | c'est à cause de la pluie | `à` | `à` | at space | `a` ✗ | `à` |
| 58 | phrase | j'ai à peine dormi | `à` | `à` | at space | `a` ✗ | `à` |
| 59 | phrase | on passe à travers le parc | `à` | `à` | at space | `a` ✗ | `à` |
| 60 | phrase | je viens à vélo | `à` | `à` | at space | `a` ✗ | `à` |
| 61 | phrase | il est arrivé à l'heure | `à` | `à` | at space | `a` ✗ | `à` |
| 62 | phrase | c'est à peu près fini | `à` | `à` | at space | `a` ✗ | `à` |
| 63 | phrase | j'ai lu le livre à moitié | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 64 | phrase | on se voit à la fin du cours | `à` | `à` | at space | `a` ✗ | `à` |
| 65 | phrase | je serai là à huit heures | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 66 | phrase | on travaille à deux sur ce projet | `à` | `à` | at space | `a` ✗ | `à` |
| 67 | il-a | il a faim | `a` | `a` | no change | `a` | `a` |
| 68 | il-a | elle a froid | `a` | `a` | no change | `a` | `a` |
| 69 | il-a | il a beaucoup mangé | `a` | `a` | no change | `a` | `a` |
| 70 | il-a | elle a déjà fini | `a` | `a` | no change | `a` | `a` |
| 71 | il-a | il a toujours raison | `a` | `a` | no change | `a` | `a` |
| 72 | il-a | on a gagné le match | `a` | `a` | no change | `a` | `a` |
| 73 | il-a | il a dit oui | `a` | `a` | no change | `a` | `a` |
| 74 | il-a | elle a vingt ans | `a` | `a` | no change | `a` | `a` |
| 75 | il-a | il a bien dormi | `a` | `a` | no change | `a` | `a` |
| 76 | il-a | elle a une voiture rouge | `a` | `a` | no change | `a` | `a` |
| 77 | il-a | il a peur du noir | `a` | `a` | no change | `a` | `a` |
| 78 | il-a | on a cours demain | `a` | `a` | no change | `a` | `a` |
| 79 | pronoun-a | tout le monde a compris | `a` | `a` | no change | `a` | `a` |
| 80 | pronoun-a | ça a marché du premier coup | `a` | `a` | no change | `a` | `a` |
| 81 | pronoun-a | cela a pris trois heures | `a` | `a` | no change | `a` | `a` |
| 82 | pronoun-a | chacun a son avis | `a` | `a` | no change | `a` | `a` |
| 83 | pronoun-a | personne n'a répondu | `n'a` | `n'a` | no change | `n'a` | `n'a` |
| 84 | relative | ce que tu as fait a marché | `a` | `a` | at space, then back after next word | `a` | `a` |
| 85 | relative | ce qu'il a dit a choqué tout le monde | `a` | `a` | no change | `a` | `a` |
| 85 | relative | ce qu'il a dit a choqué tout le monde | `a` | `a` | at space, then back after next word | `a` | `a` |
| 86 | relative | le livre que je lis a trois cents pages | `a` | `a` | no change | `a` | `a` |
| 87 | relative | la maison où j'habite a un grand jardin | `a` | `a` | at space, then back after next word | `a` | `a` |
| 88 | relative | l'homme qui parle a raison | `a` | `a` | at space, then back after next word | `a` | `a` |
| 89 | relative | la fille dont je parle a déménagé | `a` | `a` | no change | `a` | `a` |
| 90 | name | marie a appelé ce matin | `a` | `a` | no change | `a` | `a` |
| 91 | name | paul a raison | `a` | `a` | no change | `a` | `a` |
| 92 | name | julie a fini son travail | `a` | `a` | no change | `a` | `a` |
| 93 | name | pierre a faim | `a` | `a` | no change | `a` | `a` |
| 94 | name | j'ai écrit à marie | `à` | `à` | at space | `a` ✗ | `à` |
| 95 | name | je vais chez thomas à midi | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 96 | elision | il m'a dit non | `m'a` | `m'a` | no change | `m'a` | `m'a` |
| 97 | elision | elle l'a vu hier | `l'a` | `l'a` | no change | `l'a` | `l'a` |
| 98 | elision | je sais qu'il a tort | `a` | `a` | no change | `a` | `a` |
| 99 | elision | jusqu'à demain | `jusqu'à` | `jusqu'à` | at space | `jusqu'a` ✗ | `jusqu'à` |
| 100 | elision | c'est à toi de jouer | `à` | `à` | at space | `a` ✗ | `à` |
| 101 | elision | il n'a pas le temps | `n'a` | `n'a` | no change | `n'a` | `n'a` |
| 102 | elision | il n'y a qu'à demander | `a` | `a` | no change | `a` | `a` |
| 102 | elision | il n'y a qu'à demander | `qu'à` | `qu'à` | at space | `qu'a` ✗ | `qu'a` ✗ |
| 103 | elision | je l'ai donné à julie | `à` | `à` | at space | `a` ✗ | `à` |
| 104 | elision | il m'a appris à nager | `m'a` | `m'a` | no change | `m'a` | `m'a` |
| 104 | elision | il m'a appris à nager | `à` | `à` | at space | `a` ✗ | `à` |
| 105 | y-a | il y a du monde | `a` | `a` | no change | `a` | `a` |
| 106 | y-a | y a pas de souci | `a` | `a` | no change | `a` | `a` |
| 107 | y-a | il n'y a rien à manger | `a` | `a` | no change | `a` | `a` |
| 107 | y-a | il n'y a rien à manger | `à` | `à` | at space | `a` ✗ | `à` |
| 108 | y-a | il y a deux jours | `a` | `a` | no change | `a` | `a` |
| 109 | y-a | y a quelqu'un | `a` | `a` | no change | `a` | `a` |
| 110 | question | à qui tu parles | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 111 | question | à quoi tu penses | `à` | `à` | at space | `a` ✗ | `a` ✗ |
| 112 | question | qui a appelé | `a` | `a` | no change | `a` | `a` |
| 113 | question | il a quel âge | `a` | `a` | no change | `a` | `a` |
| 114 | question | tu penses à quoi | `à` | `à` | at space | `a` ✗ | `à` |
| 115 | question | qui a fait ça | `a` | `a` | no change | `a` | `a` |
| 116 | question | tu vas à la plage | `à` | `à` | at space | `a` ✗ | `à` |
| 117 | question | tu as pensé à prendre le pain | `à` | `à` | at space | `a` ✗ | `à` |
