#!/usr/bin/env python3
"""D-protected: a post-hoc SKETCH of a narrow check, written AFTER the round (#575).

Not a declared candidate: it was written from this round's results, so its catch rate
on this round is fitted to the round, not measured on held-out data. What IS a fair
measurement is its false-refusal count on the two legacy corpora, which it never saw.

It refuses when (a) the output carries more `ne` / `n'` than the input (an oral
negation formalised), or (b) a phrase from a short protected lexicon is in the input
and absent from the output.
"""
import re
import sys

LEXICON = [
    "s'il te plaît", "s'il vous plaît", "bisous", "bises", "merci", "t'as", "t'es",
    "checker", "check", "mail", "settings", "today", "push", "deadline", "review",
]
NE = re.compile(r"(?<![\w'])(ne|n')(?![\w])|(?<![\w'])n'")


def norm(s):
    return s.lower().replace("’", "'").replace(" ", " ")


def violations(inp, out):
    i, o = norm(inp), norm(out)
    v = []
    if len(NE.findall(o)) > len(NE.findall(i)):
        v.append("+ne")
    for p in LEXICON:
        if re.search(r"(?<![\w])" + re.escape(p) + r"(?![\w])", i) and not re.search(r"(?<![\w])" + re.escape(p) + r"(?![\w])", o):
            v.append(p)
    return v


if __name__ == "__main__":
    sys.path.insert(0, __file__.rsplit("/", 1)[0])
    import json
    import detector_eval as d
    labels = json.load(open(__file__.rsplit("/", 1)[0] + "/labels.json", encoding="utf-8"))
    from collections import Counter
    n = Counter()
    for corpus, key, raw, out in d.corpora():
        if corpus == "round":
            continue
        n[corpus] += 1
        v = violations(raw, out)
        if v:
            print(corpus, key, labels.get(key, "unflagged-by-D-lost"), v)
    print(n)
