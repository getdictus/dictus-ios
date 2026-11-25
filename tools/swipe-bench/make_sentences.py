#!/usr/bin/env python3
"""Picks the swipe bench's sentences (#948) from Tatoeba's detailed per-language exports.

  python3 -I tools/swipe-bench/make_sentences.py LANG SENTENCES.tsv.bz2 user_languages.csv OUTDIR

LANG is en, fr or de. The exports are
https://downloads.tatoeba.org/exports/per_language/{eng,fra,deu}/{eng,fra,deu}_sentences_detailed.tsv.bz2
and https://downloads.tatoeba.org/exports/user_languages.tar.bz2 (CC BY 2.0 FR). Writes
OUTDIR/LANG-dev.tsv (500 sentences) and OUTDIR/LANG-test.tsv (2,000). Deterministic for the
same exports.

Kept, as Hex's held-out sets and docs/research/multilingual-autocorrect/corpus.md pick theirs:
- an author who declares the language at level 5 (native) in user_languages.csv;
- 3 to 14 words once normalized (NFC, lowercase, ’ read as ', hyphens as spaces, the
  punctuation . , ! ? ; : " « » ( ) … – — dropped), every character in the language's model
  alphabet, no word starting or ending with an apostrophe (a quotation mark);
- the first sentence (by Tatoeba id) of each normalized text.
Then shuffled with seed 948: the first 500 are the dev split, the next 2,000 the test split.
The bench reports on the test split only and nothing is tuned on it; the dev split is there
for whoever tunes the decoder later.
"""
import bz2
import os
import random
import sys
import unicodedata

ALPHABET = {
    "en": set("abcdefghijklmnopqrstuvwxyz'"),
    "fr": set("abcdefghijklmnopqrstuvwxyz'àâæçèéêëîïôùûüœ"),
    # de.hextm's letters: no apostrophe, so "geht's" and "gibt's" leave their sentence out.
    "de": set("abcdefghijklmnopqrstuvwxyzäöüß"),
}
TATOEBA = {"en": "eng", "fr": "fra", "de": "deu"}
DROP = dict.fromkeys(map(ord, '.,!?;:"«»()…–—'), " ")
DEV, TEST, SEED = 500, 2000, 948


def normalize(text):
    text = unicodedata.normalize("NFC", text).lower()
    text = text.replace("’", "'").replace("‘", "'").replace("-", " ").translate(DROP)
    return " ".join(text.split())


def main():
    lang, export, users, out = sys.argv[1:5]
    natives = set()
    with open(users, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 3 and parts[0] == TATOEBA[lang] and parts[1] == "5":
                natives.add(parts[2])
    picked, seen = [], set()
    rows = []
    with bz2.open(export, "rt", encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 4 or parts[1] != TATOEBA[lang]:
                continue
            rows.append((int(parts[0]), parts[3], parts[2]))
    rows.sort()
    for sid, author, text in rows:
        if author not in natives:
            continue
        sentence = normalize(text)
        words = sentence.split(" ")
        if not 3 <= len(words) <= 14 or not set(sentence) - {" "} <= ALPHABET[lang]:
            continue
        if any(w.startswith("'") or w.endswith("'") for w in words) or sentence in seen:
            continue
        seen.add(sentence)
        picked.append((sid, author, sentence))
    random.Random(SEED).shuffle(picked)
    os.makedirs(out, exist_ok=True)
    for split, chosen in (("dev", picked[:DEV]), ("test", picked[DEV:DEV + TEST])):
        with open(os.path.join(out, f"{lang}-{split}.tsv"), "w", encoding="utf-8", newline="\n") as f:
            f.write(f"# Tatoeba ({TATOEBA[lang]}_sentences_detailed.tsv, export of 2026-11-21), CC BY 2.0 FR,"
                    f" https://tatoeba.org/en/sentences/show/<id>. {split} split, picked by make_sentences.py.\n")
            f.write("# id\tauthor\tsentence (normalized)\n")
            for sid, author, sentence in chosen:
                f.write(f"{sid}\t{author}\t{sentence}\n")
    print(f"{lang}: {len(rows)} sentences, {len(natives)} native authors, {len(picked)} eligible", file=sys.stderr)


if __name__ == "__main__":
    main()
