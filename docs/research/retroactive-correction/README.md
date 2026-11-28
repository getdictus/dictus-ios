# Retroactive correction: fixing the previous word when the next one contradicts it

Research only, no product code. Question: Apple's keyboard sometimes changes a word
**after** the user has typed the word that follows it. How often does it do that, on
which cases, and can a keyboard extension do the same thing safely?

Related: #114 (unified candidate scoring), #500 (corrections that do not fit the
sentence), #971 (`a` → `à` from the words before), and the `a` / `à` measurements in
[`../a-grave-vs-apple/`](../a-grave-vs-apple/README.md).

## What Apple does (measured)

iPhone 17 simulator, iOS 26.5, 2026-11-19, my own simulator. Apple's English
keyboard as shipped; Apple's French keyboard with the language asset installed by
[`../a-grave-vs-apple/tools/install-apple-french-sim.sh`](../a-grave-vs-apple/tools/install-apple-french-sim.sh)
(see that folder's README for the caveat). Each probe is typed word by word in a
Reminders title with `axe` (`../a-grave-vs-apple/tools/apple_ag.py`), and the title is
read back after every space, so the table shows the word right after its own space and
again after the next word's space. Dictus develop (`13c134a1`) and #971 (`09c4bb0a`)
through the #954 replay. Corpora: [`corpus-en.tsv`](corpus-en.tsv) (26 probes),
[`corpus-fr.tsv`](corpus-fr.tsv) (10 probes), plus the 117 `a` / `à` sentences of
`../a-grave-vs-apple/`. Table: [`score_retro.py`](score_retro.py), raw runs in [`data/`](data/).

**Apple changes a word after the next one, but rarely, and mostly to take back a guess
it made at the space.** Over 160 probed tokens (26 English, 10 French, 124 `a` / `à`):

| What happened to the word | English | French probes | `a` / `à` corpus |
|---|---:|---:|---:|
| Changed at its own space, kept | 17 | 3 | 68 |
| Changed at its space, **taken back** after the next word | 1 (`its own`) | 0 | 5 (`à` → `a` before a verb) |
| Unchanged at its space, **changed after the next word** | 1 (`well be` → `we'll be`) | 0 | 0 |
| Never changed | 7 | 7 | 51 |

- **One forward retroactive correction**, `well` → `we'll` once `be` follows. `well` is
  a word, so at the space Apple has no reason to touch it; `be` makes it a contraction.
- **Six take-backs.** Apple writes its best guess at the space (`its` → `it's`, `a` →
  `à`) and reverts it when the next word contradicts it (`its own`, `la boulangerie à`
  → `a fermé`). The next word is a safety net for an eager guess, not the main
  decision.
- **Most ambiguity is decided at the space**, from the words before: `its raining` →
  `it's`, `were going` → `we're`, `id like` → `I'd`, `il ma` → `il m'a`, `je suis la` →
  `là`, `une machine a` → `à`.
- **What Apple gets wrong, it also gets wrong after the next word**: `your welcome`,
  `their is`, `there car`, `better then`, `loose it`, `to late`, `ces bon`, `sa va`,
  `ou est`, `il et parti`, `ils son partis`, `il ce lave` all stay. Two eager guesses are
  never taken back: `were here yesterday` → `we're here yesterday`, `hell no` → `he'll
  no`.
- **Dictus never changes a word after its space.** On these probes it ends with 7 of
  26 English right (its `I` is the replay's capital at the start of the field, not a
  decision) and 1 of 10 French (`on a`); #971 adds `il m'a` (#970's rule, merged into
  that branch) and `à`, for 3 of 10. It
  has no English contraction rule for `its`, `were`, `id`, `ill`, `well`, `shell`,
  `hell`, `lets`, `wont`, `shed`, `wed`.

### English

| Case | Typed | Expected | Apple at the space | after the next word | When Apple changed it | Apple final | Dictus develop | #971 |
|---|---|---|---|---|---|---|---|---|
| pronoun-i | `i think so` | `I` | `I` | `I` | at the space | `I` | `I` | `I` |
| contraction | `its raining again` | `it's` | `it's` | `it's` | at the space | `it's` | `Its` ✗ | `Its` ✗ |
| contraction | `its a good idea` | `it's` | `it's` | `it's` | at the space | `it's` | `Its` ✗ | `Its` ✗ |
| contraction | `were going home now` | `we're` | `we're` | `we're` | at the space | `we're` | `Were` ✗ | `Were` ✗ |
| contraction | `your welcome` | `you're` | `your` | `your` | never | `your` ✗ | `Your` ✗ | `Your` ✗ |
| contraction | `id like a coffee` | `I'd` | `I'd` | `I'd` | at the space | `I'd` | `Id` ✗ | `Id` ✗ |
| contraction | `ill be there soon` | `I'll` | `I'll` | `I'll` | at the space | `I'll` | `Ill` ✗ | `Ill` ✗ |
| contraction | `well be late` | `we'll` | `well` | `we'll` | **after the next word** | `we'll` | `Well` ✗ | `Well` ✗ |
| contraction | `shell be back tomorrow` | `she'll` | `she'll` | `she'll` | at the space | `she'll` | `Shell` ✗ | `Shell` ✗ |
| contraction | `hell be fine` | `he'll` | `he'll` | `he'll` | at the space | `he'll` | `Hell` ✗ | `Hell` ✗ |
| contraction | `lets go now` | `let's` | `let's` | `let's` | at the space | `let's` | `Lets` ✗ | `Lets` ✗ |
| contraction | `wont you come` | `won't` | `won't` | `won't` | at the space | `won't` | `Wont` ✗ | `Wont` ✗ |
| contraction | `cant wait` | `can't` | `can't` | `can't` | at the space | `can't` | `Can't` | `Can't` |
| contraction | `dont worry` | `don't` | `don't` | `don't` | at the space | `don't` | `Don't` | `Don't` |
| homophone | `their is a problem` | `there` | `their` | `their` | never | `their` ✗ | `Their` ✗ | `Their` ✗ |
| homophone | `there car is red` | `their` | `there` | `there` | never | `there` ✗ | `There` ✗ | `There` ✗ |
| homophone | `better then nothing` | `than` | `then` | `then` | never | `then` ✗ | `then` ✗ | `then` ✗ |
| homophone | `i dont want to loose it` | `lose` | `loose` | `loose` | never | `loose` ✗ | `loose` ✗ | `loose` ✗ |
| homophone | `it was to late` | `too` | `to` | `to` | never | `to` ✗ | `to` ✗ | `to` ✗ |
| typo | `teh car is red` | `the` | `the` | `the` | at the space | `the` | `Teh` ✗ | `Teh` ✗ |
| contraction | `shed be back soon` | `she'd` | `she'd` | `she'd` | at the space | `she'd` | `Shed` ✗ | `Shed` ✗ |
| contraction | `wed like to come` | `we'd` | `we'd` | `we'd` | at the space | `we'd` | `Wed` ✗ | `Wed` ✗ |
| keep | `its own way` | `its` | `it's` | `its` | at the space, **taken back** after the next word | `its` | `Its` | `Its` |
| keep | `were here yesterday` | `were` | `we're` | `we're` | at the space | `we're` ✗ | `Were` | `Were` |
| keep | `well done` | `well` | `well` | `well` | never | `well` | `Well` | `Well` |
| keep | `hell no` | `hell` | `he'll` | `he'll` | at the space | `he'll` ✗ | `Hell` | `Hell` |

### French

| Case | Typed | Expected | Apple at the space | after the next word | When Apple changed it | Apple final | Dictus develop | #971 |
|---|---|---|---|---|---|---|---|---|
| elision | `il ma dit non` | `m'a` | `m'a` | `m'a` | at the space | `m'a` | `ma` ✗ | `m'a` |
| elision | `ces bon pour moi` | `c'est` | `ces` | `ces` | never | `ces` ✗ | `Ces` ✗ | `Ces` ✗ |
| elision | `sa va bien` | `ça` | `sa` | `sa` | never | `sa` ✗ | `Sa` ✗ | `Sa` ✗ |
| homograph | `ou est la gare` | `où` | `ou` | `ou` | never | `ou` ✗ | `Ou` ✗ | `Ou` ✗ |
| homograph | `il et parti` | `est` | `et` | `et` | never | `et` ✗ | `et` ✗ | `et` ✗ |
| homograph | `ils son partis` | `sont` | `son` | `son` | never | `son` ✗ | `son` ✗ | `son` ✗ |
| homograph | `il ce lave` | `se` | `ce` | `ce` | never | `ce` ✗ | `ce` ✗ | `ce` ✗ |
| homograph | `je suis la ce soir` | `là` | `là` | `là` | at the space | `là` | `la` ✗ | `la` ✗ |
| homograph | `je vais a paris` | `à` | `à` | `à` | at the space | `à` | `a` ✗ | `à` |
| homograph | `on a gagne` | `a` | `a` | `a` | never | `a` | `a` | `a` |

## What a keyboard extension can do

### Reading the previous word

`textDocumentProxy.documentContextBeforeInput` returns the text before the cursor. The
keyboard already depends on it for every correction: `AutocorrectRejectionMemory.wordAtCursor`
splits it into the current word and the prefix before it. For a retroactive correction
the keyboard needs the previous word, the boundary after it, the current word and the
boundary the user just typed: in the worst case a few dozen characters.

Limits that apply:

- **Hosts window the context.** Some hosts return only the current sentence or
  paragraph, or a fixed window (#266 measured a mirror that stops growing). Two words
  fit inside any window seen so far, but a window that begins inside the previous word
  is possible right after a paragraph break. The check has to be "the context ends
  with exactly what the keyboard wrote", not "the context contains it".
- **The context can lie.** #530: after the user deletes a selection, the proxy's
  mirror keeps characters the document no longer holds. `MirrorSyncState` detects this
  by comparing the mirror's length before and after each keyboard edit, and
  `MirrorGatedReplacement.check` refuses every counting edit while it is suspect.
- **A refused insertion.** #532: some hosts accept nothing the keyboard sends. A
  correction that deletes and then fails to insert destroys text. Today's autocorrect
  carries that risk for one word; a retroactive one carries it for two.

### Rewriting it

The proxy has no "replace range". Three primitives are available:

| Primitive | Behaviour | Fit |
|---|---|---|
| `deleteBackward()` × n, then `insertText(_:)` | Synchronous for the mirror: the length can be read before and after in the same run-loop turn, which is what `MirrorSync` relies on. | What every existing rewrite uses. |
| `adjustTextPosition(byCharacterOffset:)` | Moves the caret. The mirror updates **asynchronously** in many hosts, so `documentContextBeforeInput` read right after it is stale. | Would let the keyboard edit the previous word without retyping the current one, but nothing can be verified in the same turn. Not recommended. |
| `setMarkedText(_:selectedRange:)` | Composition text, for input methods. | Dictus never uses marked text; using it here would change how every host renders the word. Not needed. |

So a retroactive correction is: delete the current word, its trailing boundary and the
previous word; insert the corrected previous word, the boundary and the current word
again. The current word is retyped exactly as the context shows it.

### Code that already rewrites committed text

Two paths already reach behind the caret and put text back. Both are the model to copy.

- **Autocorrect undo** (`DictusKeyboard/KeyboardRootView.swift`, `performUndo`): finds
  the corrected word in the context **with everything typed after it**, deletes back
  to it, inserts the original word and then re-inserts the text that followed. It
  brackets the edit with `bridge.mirrorLength()` and `observeMirror(...)` so the
  detector sees it (#548).
- **Address revert** (`DictusCore/.../TextCorrection/AddressCorrectionRevert.swift`,
  #919): after `helene.` was corrected to `Hélène.`, the next key (`b`) shows the text
  is an e-mail address, so the correction is undone **because of what came after it**.
  It checks `context.hasSuffix(corrected + mark)`, gets its delete count from
  `MirrorGatedReplacement.check`, deletes, inserts the original, and reports the edit to
  `MirrorSyncState.observe`. This is a retroactive correction in all but name, limited
  to one punctuation mark of lookahead.

### What has to change for two words

- **The mirror gate assumes the current word.** `MirrorSyncState.noteBoundaryInserted`
  ends suspicion at each space because "a counting site only ever asks about the
  CURRENT word" (comment in `MirrorSync.swift`). A retroactive correction counts across
  that boundary, so it must also refuse while a **dormant** surplus exists, not only
  while `isSuspect` is true. That is a new condition, and it is the single most
  important safety rule of the design.
- **The suffix check covers both words.** `AutocorrectReplacement.check(context:word:)`
  verifies one word and a boundary before it. The retroactive check is the same test on
  `previous + boundary + current + boundary`, with the boundary before `previous`
  checked as today.
- **Undo.** `AutocorrectRejectionMemory` keys corrections by the text before the word
  (`positionKey(prefix:)`). A retroactive correction is a correction at the previous
  word's position: it calls `correctionApplied(prefix:corrected:)` with that prefix, so
  an undo there is remembered and the rule never fires twice at that position. The
  bar's undo chip (`pendingUndo`) holds one correction; if the current word was also
  corrected at the same space, the retroactive one must not fire (one visible change
  per space), or the chip must restore both.
- **The caret must be at the end of what the keyboard typed.** If the user moved the
  caret, selected text or pasted (any host-side change the keyboard did not make since
  the previous word), skip. The keyboard knows what it wrote: keeping the last two
  commits (prefix, typed, written) is enough to check it.

## Proposed design for a later step

1. **One record per committed word** in the bridge: the prefix key, the word as typed,
   the word as written, and whether a correction was applied. Keep the last two.
2. **A rule that reads both sides.** `ContextualHomograph` (#971) decides from the words
   before. Add the words after, as data, per pair:
   - `a` → `à` when the next word is an infinitive (`laver`, `faire`, `dormir`) or one
     of the set-phrase heads (`pied`, `côté`, `cause`, `peine`, `travers`, `demain`);
   - `à` → `a` when the next word is a past participle (`été`, `fini`, `appelé`), so a
     wrong `à` written at the space can be taken back;
   - `ma` → `m'a`, `sa` → `ça`, `ou` → `où`, `la` → `là`, `et` → `est`, `son` → `sont`,
     each with the next words that prove it.
   It runs at the space after the next word, and only when the first word was written
   as typed (never on top of an earlier correction).
3. **A counting site** `RetroactiveCountingSite.apply(editor:previous:corrected:current:boundary:mirror:)`
   in DictusCore, modelled on `AddressCorrectionRevert.apply`: two-word suffix check,
   refusal on a suspect or dormant mirror, delete, insert, `mirror.observe`, a DEBUG log
   line `AUTOCORRECT branch=retroactive orig=… corr=… next=…`.
4. **Undo**: register the correction at the previous word's prefix; the chip shows the
   retroactive change when it is the only change at that space.
5. **Measure first**: the bench replay (`tools/keyboard-bench/main.swift`) already
   commits words one by one; it can apply the rule after each commit and report fixed /
   broken per case, on this folder's corpora and on the `a-grave-vs-apple` corpus, before
   any keyboard code.
