#!/usr/bin/env python3
"""
make_typos.py -- Write what the typist of a typo run types (docs/research/multilingual-autocorrect/).

A typo run replays the mistakes people really make in a language, not the Gaussian
misses of the touch model. For each sentence of `corpus/<lang>-typos.txt` (what the
typist means), this writes the line of `corpus/<lang>-typos.keys` (what the typist
types), in two steps:

1. The language's systematic mistake, on every word:
   - en: no apostrophe (`dont` for `don't`, `im` for `i'm`);
   - es: no accent and no tilde (`esta` for `está`, `manana` for `mañana`);
   - de: umlauts typed as two letters (`fuer`) on even sentences and as the plain
     vowel (`fur`) on odd ones, ß typed `ss`.
2. At most one slip per sentence: the first word, left to right, that has a pair in
   `typos-<lang>.tsv` not used by an earlier sentence, and whose category step 1
   does not already produce (a transposition, an omitted or doubled letter, `das` for
   `dass`), gets the pair's typo. A pair is used once per run, so `ic` for `ich`
   does not take every German sentence that starts with `ich`. Pairs that change the
   word count (`alot`) and capitalisation pairs (the bench compares without case) are
   left out.

The pairs come from public typo corpora; their sources and licences are in
docs/research/multilingual-autocorrect/typo-sources.md. The output is deterministic:
rerunning rewrites the same files byte for byte. make_runs.py then turns the keys into
a run whose taps land on the key centres.

Usage:
    python3 -I tools/keyboard-bench/make_typos.py --bench tools/keyboard-bench \
        --pairs docs/research/multilingual-autocorrect
"""

import argparse
import os
import unicodedata

LANGS = ["en", "es", "de"]
# Categories step 1 already produces, or that the bench cannot score.
SKIPPED = ("apostrophe", "accent", "tilde", "umlaut", "eszett", "lowercased", "missing-space")
UMLAUT_DIGRAPHS = {"ä": "ae", "ö": "oe", "ü": "ue"}


def systematic(word, lang, sentence_index):
    if lang == "en":
        return word.replace("'", "")
    if lang == "es":
        return "".join(c for c in unicodedata.normalize("NFD", word) if not unicodedata.combining(c))
    if lang == "de":
        word = word.replace("ß", "ss")
        for umlaut, digraph in UMLAUT_DIGRAPHS.items():
            word = word.replace(umlaut, digraph if sentence_index % 2 == 0 else digraph[0])
        return word
    raise SystemExit(f"no typo rules for {lang}")


def slips(path):
    """correct word -> typo, for the pairs step 2 may use, first pair of a word wins."""
    out = {}
    with open(path, encoding="utf-8") as f:
        next(f)
        for line in f:
            typo, correct, category, _ = line.rstrip("\n").split("\t")
            if " " in correct or any(s in category for s in SKIPPED):
                continue
            out.setdefault(correct.lower(), typo.lower())
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bench", required=True)
    parser.add_argument("--pairs", required=True)
    parser.add_argument("--langs", default=",".join(LANGS))
    args = parser.parse_args()
    for lang in args.langs.split(","):
        pairs = slips(os.path.join(args.pairs, f"typos-{lang}.tsv"))
        with open(os.path.join(args.bench, "corpus", f"{lang}-typos.txt"), encoding="utf-8") as f:
            sentences = [line.strip() for line in f if line.strip()]
        lines = []
        used = set()
        for index, sentence in enumerate(sentences):
            words = sentence.split()
            typed = [systematic(w, lang, index) for w in words]
            for i, word in enumerate(words):
                if word in pairs and word not in used:
                    typed[i] = pairs[word]
                    used.add(word)
                    break
            lines.append(" ".join(typed))
        path = os.path.join(args.bench, "corpus", f"{lang}-typos.keys")
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        print(f"{path}: {len(lines)} sentences, {len(used)} with a slip")


if __name__ == "__main__":
    main()
