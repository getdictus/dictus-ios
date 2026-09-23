#!/usr/bin/env python3
"""D-lost, the candidate model-free detector declared in bars.md §Q5 (#575).

A word is LOST when the input carries more occurrences of it than the output.
Licensed removals (rules 3, 4, 6, 7 of the Natural contract) are not counted, and
neither are French function words. D-lost-1 refuses on >= 1 lost word, D-lost-2 on
>= 2.

Library use: `lost_words(input, output)` -> list of lost words.
CLI: detect.py pairs.jsonl  (one {"id", "input", "output"} per line) prints every
pair with its lost words, for the human read bars.md requires.
"""
import json
import re
import sys
from collections import Counter

FILLERS = {"euh", "hum", "bah", "heu", "ben"}
VERBAL = {"virgule", "point"}
NUMBER_WORDS = {
    "zéro", "un", "une", "deux", "trois", "quatre", "cinq", "six", "sept", "huit",
    "neuf", "dix", "onze", "douze", "treize", "quatorze", "quinze", "seize", "vingt",
    "trente", "quarante", "cinquante", "soixante", "cent", "cents", "mille",
}
# French function words. Losing one of these is not counted: it is either grammar the
# polish may legitimately touch (elision, `ne`-less negation stays, articles after a
# contraction) or too common to carry the damage signal on its own.
STOP = {
    "le", "la", "les", "l", "un", "une", "des", "du", "de", "d", "au", "aux", "à", "a",
    "et", "ou", "mais", "donc", "or", "ni", "car", "que", "qu", "qui", "quoi", "dont",
    "où", "ce", "c", "ça", "cela", "ceci", "cet", "cette", "ces", "se", "s", "si",
    "je", "j", "tu", "t", "il", "elle", "on", "nous", "vous", "ils", "elles", "me",
    "m", "te", "lui", "leur", "y", "en", "ne", "n", "pas", "plus", "est", "es", "suis",
    "sont", "ai", "as", "avons", "avez", "ont", "être", "avoir", "pour", "par", "sur",
    "dans", "avec", "sans", "sous", "chez", "vers", "entre", "mon", "ma", "mes", "ton",
    "ta", "tes", "son", "sa", "ses", "notre", "nos", "votre", "vos", "leurs", "tout",
    "tous", "toute", "toutes", "bien", "très", "aussi", "alors", "puis", "comme", "oui",
    "non", "fait", "vois", "sais",
}


def tokens(s):
    s = s.lower().replace("’", "'")
    return [t for t in re.split(r"[^\w]+", s) if t and t != "_"]


def lost_words(inp, out):
    it, ot = tokens(inp), tokens(out)
    # Rule 6: an immediate same-word repeat in the input may collapse to one.
    dedup = [t for i, t in enumerate(it) if i == 0 or t != it[i - 1]]
    ci, co = Counter(dedup), Counter(ot)
    gained_digit = any(t.isdigit() for t in ot) and not any(t.isdigit() for t in it)
    lost = []
    for word, k in ci.items():
        if co.get(word, 0) >= k:
            continue
        if word in STOP or word in FILLERS or word in VERBAL:
            continue
        if word in NUMBER_WORDS and (gained_digit or any(t.isdigit() for t in ot)):
            continue
        lost.append(word)
    return sorted(lost)


def main():
    for line in open(sys.argv[1], encoding="utf-8"):
        p = json.loads(line)
        lw = lost_words(p["input"], p["output"])
        flag = "D1" if len(lw) >= 1 else "  "
        flag += "+D2" if len(lw) >= 2 else "   "
        print(f"{flag} {p['id']}: {lw}")


if __name__ == "__main__":
    main()
