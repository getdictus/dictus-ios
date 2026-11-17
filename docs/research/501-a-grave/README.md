# French `a` or `à` (#501): measurements

Taken 2026-11-17 on the branch `fix/501-french-a-grave`, iPhone 17 simulator, iOS 26.5.

## Keyboard bench (#954), before and after

`tools/keyboard-bench/run.sh`, same 1607 taps. Before is develop at `2e280b7f`, after is
`e0abb42d`, the branch with the rule (later commits change comments and docs only). Full reports: [`bench-before.md`](bench-before.md), [`bench-after.md`](bench-after.md).

| | fr before | fr after | en before | en after |
|---|---:|---:|---:|---:|
| Wrong words in the final text (of 152 fr, 157 en) | 9 | **8** | 9 | 9 |
| Broken (typed right, changed) | 0 | 0 | 0 | 0 |
| Miscorrected | 4 | 4 | 4 | 4 |
| Missed, accent only | 5 | **4** | 0 | 0 |
| `à` typed `a`, left `a` | 1 of 1 | **0 of 1** | | |
| Verb `a` typed `a`, turned into `à` | 0 of 1 | 0 of 1 | | |
| Engine time, space, p95 (ms, simulator) | 0.52 | 0.47 | 0.71 | 0.70 |

The one sentence that changed is the fifth: `la réunion est décalée à jeudi matin` is now
typed `La région est dévaler à jeudi matin` (was `… dévaler a …`). The rule still fires
after the miscorrected `décalée`, because it reads `est` two words back, not the
participle. The corpus has one verb `a` (`elle a trouvé …`), which stays.

The bench corpus has two `a`/`à` in 152 words, so it shows that the rule runs in the
keyboard path. It cannot give a rate, so the rate comes from Tatoeba below.

## False-positive rate on real French text

`tools/a-grave-eval/run.sh` takes every standalone `a` or `à` after the first word of
Tatoeba's 730,700 French sentences (downloaded 2026-11-17, CC BY 2.0 FR, not used to
build the bundled n-grams), types it as `a` after the sentence's own text, and asks the
rule. Its output, the 45 sentences included: [`tatoeba.txt`](tatoeba.txt).

| written | occurrences | typed `a` became `à` |
|---|---:|---:|
| `a` (verb) | 64,601 | 45 (0.07%) |
| `à` (preposition) | 93,468 | 34,539 (36.95%) |

Read one by one, the 45 split three ways:

- **12 are real errors (0.02% of the verbs).** The subject is a clause the three-word
  window does not see, or a noun after a word the table reads as a verb:
  `L'arbre sur le tronc duquel nos initiales étaient gravées a été abattu`,
  `L'économie des pays d'Asie de l'est a été bouleversée`,
  `T'épouser a été la plus grosse erreur de ma vie`,
  `La voiture que je vous ai louée a un problème`,
  `Tout ce qui est en train de se passer a été prédit` (twice),
  `L'exaltation d'avoir réussi à s'échapper a été de courte durée`,
  `La fille dont la jambe est cassée a eu un accident`, `Le bruit de pas a cessé`,
  `S'endormir immédiatement a été difficile`, and `Ils/Elles chantent a cappella`
  (an Italian loan, written without the accent).
- **26 are Tatoeba's own mistakes, which the rule corrects**: `Il va a l'école`,
  `Je penserai a toi`, `Faites attention a vous`, `Il est allé a Tokyo`,
  `Nassim n'arrive pas a convaincre`, …
- **7 are sentences where neither spelling is right**: `J'ai a décidé`,
  `Il contribue a colporté`, `il est marié est a trois enfants`, a Spanish `Va a funcionar`, …

So the measured rate of a correct `a` turned into `à` is 0.07% at most and 0.02% by
reading. 37% of the prepositions are recovered: the rule stays silent where it cannot
prove a verb sits before the `a`, mostly after nouns (`quelque chose à faire`,
`une machine à laver`) and infinitives.

### What was tried first

A prototype in Python (not committed) chose by the bundled bigram scores, `à` when
`bigram(previous, à) > bigram(previous, a)`. On the same sentences, with its own
tokenizer (64,293 verbs), it recovered 79% of the prepositions and accented 11.1% of
the verbs. The bigrams come from books, where a noun is followed by `à` more often than
by `a`, so every noun subject (`le chien a`, `ma voiture a`) flips. Two refinements were
measured and rejected the same way: guessing infinitives from their `-er/-ir/-re`
ending (0.69% of verbs accented) and vetoing the table with the bigrams (no change).

## The real keyboard

`verify-dictus-ios`, build `c9361321` (Debug), a fresh iPhone 17 simulator on iOS 26.5,
`typing.autocorrect` recipe: `je vais a elle a ` typed key by key on the Dictus keys
in a Rappels title. The field read `Je vais à elle a `, and the keyboard logged:

```
<KBD> APPLIED orig="a" → "à" prev="vais"
<KBD> AUTOCORRECT-SKIP word="a" reason=already-valid
```

## Device test KO: the iPhone's lexicon

Pierre's device test (iPhone 15 Pro Max, batch `06d24536`) failed: `je vais a paris`
stayed `a`, and the log showed `AUTOCORRECT-SKIP word="a" reason=lexicon` after
`NOTE lexicon loaded: 10 shortcuts, 1575 words`. The iPhone hands the keyboard its
contacts and text replacements (#873), that lexicon held the word `a`, and
`spellCheck` returned the lexicon's keep before the rule ran. A fresh simulator has
no lexicon, which is why the bench and the real-keyboard check above both passed.

The order is now `SupplementaryLexicon.earlyAnswer`:

1. A shortcut, or a contact's casing, replaces the word.
2. A lexicon word the dictionary does not know, a name, is kept.
3. The contextual rule decides.
4. Any other lexicon word is kept.

The rule only ever swaps one dictionary word for another (`a` for `à`), so a keep on
a dictionary word protected nothing it could break.

`run.sh --lexicon a,ma` now loads those words as the lexicon. Bench, `fr`, at `920db323`:

| | wrong words | sentence 5 |
|---|---:|---|
| No lexicon | 8 | `… dévaler à jeudi matin` |
| Lexicon `a,ma`, new order ([report](bench-after-lexicon.md)) | 8 | `… dévaler à jeudi matin` |
| Lexicon `a,ma`, the old order put back ([report](bench-old-order-lexicon.md)) | 9 | `… dévaler a jeudi matin` |

The old order reproduces the device failure; the new one gives the same 40 sentences
as the run without a lexicon.
