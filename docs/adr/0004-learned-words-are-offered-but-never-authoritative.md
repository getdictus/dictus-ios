# 0004 — Learned words are offered but never authoritative

- **Date:** 2026-08-13
- **Status:** Accepted; amended 2026-11-17 by #498, which makes a learned word an autocorrect target (L3) under the rule below
- **Context:** Issue #346, decided in the grilling session of 2026-08-13. Implements decision 5 of the #287 session of 2026-08-11, which established the L1/L2/L3 vocabulary. Depends on #287 block A (PR #347), which is what makes the learned set small enough to be worth offering.

## Decision

A learned word is **offered** in the suggestion bar (L1) and **immune** to autocorrect (L2). It was never an **autocorrect target** (L3) until #498, which grants L3 under the narrow rule in "Amendment (#498)" below, and only through that rule.

The offering is implemented by reading `UserDictionary` at query time and merging its prefix matches into `.completions`, in a pure function in DictusCore called from `TextPredictionEngine.suggestions(for:)`. At most one learned word appears, in the first slot, tie-broken by the `lastUsed` timestamp shipped in #305.

## Why the categorical rule is affordable here

`docs/research/287-user-dictionary-learning.md` §5.4 established that no keyboard in the field implements "suggestable but never an autocorrect target" as a category. Everywhere it is probabilistic, enforced by a unified scoring function that Dictus does not have. That reads as a reason to be careful, and it was — until the two code paths were traced.

On space, only `spellCheck` can apply anything (`DictusKeyboardBridge.handleSpace`). Every suggestion mode other than `.corrections` is tap-only. So a candidate that reaches the bar through `.completions` and never through `spellCheck` is structurally incapable of being auto-applied. The categorical rule is not a gate anyone has to write and defend — it is a property of keeping the two sources apart.

This is the load-bearing fact of the whole decision, and it is the thing to re-check before any change that lets a learned word reach `spellCheck`, the trie, or `.corrections`.

## Considered options

**Inject learned words into the trie** (`injectUserWord`, the hook that already existed and did nothing). Rejected: a trie entry is by construction an autocorrect target, so this ships L3 as a side effect of shipping L1. Separately, trie frequencies are log-normalized (#326), so "insert at a low frequency" does not behave the way the number suggests. The hook is deleted rather than left in place, since a function named after the feature that does not implement it is what made #287 look solved.

**Call `UITextChecker.learnWord(_:)`** and let the system checker return learned words for free. The cheapest option by a distance, and rejected on ownership: a word pushed into that store cannot be listed, cleared, or migrated by us. #287 decision 6 made "Reset learned words" the only exit from the dictionary, and this route creates an exit-less second copy. The research could not establish whether that store is device-global or extension-local (§"What could not be established", point 2), so the blast radius is unknown in principle, not merely unmeasured.

## Consequences

- **No language filter.** The store has no language tag, so a word learned in German is offered while typing French. Accepted: the cost is one slot on a prefix the user typed, and L2 immunity already crosses languages invisibly. Tagging is a schema change that #103 (iCloud KVS) builds its merge strategy against; if it becomes necessary, #288 will make it necessary first.
- **A fully typed learned word leaves the bar empty** until space is pressed. There is nothing longer to complete, and echoing the word back costs a slot for a tap that changes nothing. Predictions after the space are unaffected.
- **Autocorrect disabled still offers previously learned words.** #287 decision 8 blocks *learning* in that configuration because nothing vets a new word there; an existing entry was vetted when it was learned, and the bar imposes nothing.
- **Casing is reconstructed from the typed prefix**, not stored. `UserDictionary` lowercases its keys, and the same rule already governs the accent path in `spellCheck`.

## Amendment (#498): a learned word is an autocorrect target, by a separate rule

Typed with a typo, a learned word used to be corrected toward a dictionary word (`dictuq` → `rictus`), the opposite of what learning it was for. #498 makes it a target. It does not compete in the trie's ranking: the trie's frequencies are log-normalized and a learned word only has a usage count, the same reason the offering above takes a reserved slot instead of a rank. It wins by a rule of its own, `LearnedWordCorrection` in DictusCore, called from `TextPredictionEngine.spellCheck`:

1. **The typed word is not in the dictionary.** A correctly typed dictionary word is never rewritten into a learned one. `spellCheck` asks after its dictionary check, and the rule checks again.
2. **It is after the accent, contraction and proper-noun steps, before the split pass and the trie.** The exact transformations keep priority, a capitalized unknown word mid-sentence stays a likely name (#199), and the fuzzy passes no longer get to pick a dictionary word for a word the user taught.
3. **One edit away, at least three letters typed.** The same floor the bigram path uses: a shorter word has too many neighbours.
4. **Used at least twice.** What stops a mistyped word that got learned from becoming a target. A single refusal learns a word at one use, and that word is often the typo itself (#872). It stays immune (L2) but is a target only once the user types it again. A word learned by repetition reaches two uses as it is learned.
5. **Between learned words, more uses wins**, then the word itself, so the answer never depends on hash order.
6. **The bigram rerank keeps it.** A learned word has no bigrams, so `spellCheck(_:previousWord:)` returns it before the rerank, as it does for the language overrides.

On space, slot 1 of the corrections row previews it like any other correction, so the user sees it before it is applied and can refuse it the usual way. Measured with the keyboard bench (#954): no change on the `fr` and `en` runs, and the `fr-learned` / `en-learned` runs correct the four mistyped learned words they contain toward the learned word, with no correctly typed word broken. The PR for #498 carries the table.

