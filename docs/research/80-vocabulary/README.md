# #80 — custom vocabulary: the replayable corpus

The test bench for the deterministic replacement pass (#80 decision 12). Committed,
versioned, and replayable by anyone on any Mac — it drives no model and needs no
Apple Intelligence.

## Replaying it

```bash
cd DictusCore
swift run polish-harness vocabulary ../docs/research/80-vocabulary/corpus.json
```

It exits non-zero on any case whose output differs from the committed expectation,
or on any case where a second application of the pass changes the result. As of
2026-09-10: **18/18 correct, 18/18 idempotent.**

## What is in the file, and what is not

Each record is a vocabulary, a transcript, and the text the pass must produce from
it. `covers` names the matching rules the case exercises; the harness prints the
union of them so the acceptance criteria can be checked without reading every
record.

`origin` says where a case came from. **`captured`** means a real device produced
that engine output; **`constructed`** means it was written from the matching rules
the issue names.

Today: **4 captured, 14 constructed.** The four captured ones came out of #80's own
device test on 2026-09-10 (iPhone 15 Pro Max, iOS 26.6.1, `parakeet-tdt-0.6b-v3`,
French) and each one names its session in its `note`. They are the first evidence in
this file about what an engine actually does, and they are worth more than the other
fourteen put together — `C2` in particular, where the engine got `Claude Code` right
and the pass has to leave it alone, because 3 of those 6 dictations were already
correct.

The fourteen constructed cases are worth what a unit test is worth: they prove the
pass does what it was specified to do. They do **not** prove the specification
matches what the engines produce.

The issue records the measurement behind the gap: the polish debug exports available
on 2026-09-07 held **182 raw/polished pairs**, and a scan showed them to be
overwhelmingly *polish* rewrites — added connectors, grammar — rather than the engine
mangling technical terms, because the captures are ordinary French speech. So this
corpus could not simply be mined from what already existed; it needed a deliberate
capture session, and the four `captured` cases are its first instalment.

**Two things now make the next mining pass work**, both landed on 2026-09-10:

- The pass writes `vocabularyApplied enabled=… entries=… replacements=… chars=…` to
  the persistent log on every dictation, so an export can be read against whether
  the pass fired at all.
- The polish export's `raw` is the **engine's** output again. It had silently become
  post-vocabulary, which meant the more the feature was used the less the export said
  about what the engines produce — a feature corrupting the record its own validation
  depends on. The corrected text now sits beside it in `vocabularyCorrected`, present
  only when the pass changed something.

## The capture session that is still owed

Run by the maintainer, on a device, and the result appended to `corpus.json` with
`"origin": "captured"`.

1. Settings → enable the polish debug capture, so raw transcripts are written down.
2. Pick 15–20 technical terms that matter in real use: product names, colleagues'
   surnames, library names, company names. Mix French and English ones.
3. Dictate each one **inside an ordinary sentence**, not alone — an isolated word
   gives the engine no context and is not the case the feature serves.
4. Do it twice: once with Parakeet active, once with a Whisper model. The two
   engines mangle differently, and the issue's whole argument is that the fix must
   not depend on which one is running.
5. Export the debug log and read `raw` on each event — the engine's own words. Where
   `vocabularyCorrected` is present, the pass already covered that term; the pair is
   what says so.
6. **Rewrite the carrier sentence to neutral content** whenever it carries anything
   personal, keeping the error pair intact. No maintainer personal content enters
   this public repo — no real colleague names, no client names, no private facts. A
   sentence that is already about dictation and tooling can stay as it is; the four
   `captured` cases were read for this and kept.
7. Add each as a record with `"origin": "captured"` and a `note` giving the date,
   the device, the model and the language.

What that session answers, and this corpus cannot: whether the variants users would
actually type are the variants the engines actually produce, and whether a single
canonical spelling plus a handful of variants is enough coverage per term.

## Shape

```json
{
  "source": "constructed-2026-09-07",
  "fixture": "V1-mangled-technical-term",
  "origin": "constructed",
  "note": "what this case is for",
  "covers": ["mangled technical term", "mid-sentence"],
  "entries": [{ "term": "Kubernetes", "variants": ["cubernetes"] }],
  "raw": "what the engine produced",
  "expected": "what the pass must produce"
}
```

`origin` is `captured` or `constructed`, and `isEnabled` is optional on an entry and
defaults to true, which is what the add sheet produces. The decoder is `VocabularyCorpus` in `DictusCore/Sources/polish-harness/`.
