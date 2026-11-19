#!/usr/bin/env python3
"""Score the a/à corpus: Dictus replays (commits.tsv) and the Apple run (apple-fr.jsonl).
Usage: score_ag.py corpus.tsv dictus_develop_dir dictus_971_dir apple.jsonl > results.tsv"""
import csv, json, sys, unicodedata
corpus, dev, pr, apple = sys.argv[1:5]

def fold(w):
    return "".join(c for c in unicodedata.normalize("NFD", w) if not unicodedata.combining(c))
def norm(w):
    return (w or "").replace("’", "'").lower()
def is_target(w):
    f = fold(w).lower()
    return f == "a" or f.endswith("'a")

A_GRAVE = {"start", "cap-start", "noun-à", "adj-à", "verb-à", "phrase"}
A_VERB = {"noun-a", "il-a", "pronoun-a", "relative"}

rows = [l.rstrip("\n").split("\t") for l in open(corpus, encoding="utf-8") if l.strip() and not l.startswith("#")][1:]

def commits(d):
    out = {}
    with open(f"{d}/commits.tsv", encoding="utf-8") as f:
        for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
            out.setdefault(int(r["sentence"]), []).append(r["final"])
    return out
cd, cp = commits(dev), commits(pr)
ap = {}
for l in open(apple, encoding="utf-8"):
    r = json.loads(l); ap[r["s"]] = r

def apple_outcome(r, j, typed, expected):
    if r is None: return None, None, ""
    st = [norm(x).split() for x in r["states"]]
    def tok(i):
        return st[i][j] if i < len(st) and j < len(st[i]) else None
    at_space, after_next, final = tok(j), tok(j + 1) if j + 1 < len(st) else tok(j), tok(len(st) - 1)
    bar = r["bars"].get(str(j), {})
    offered = norm(bar.get("middle", "")).strip("«»") if bar else ""
    if at_space != typed:
        if final == at_space and after_next == at_space:
            kind = "space"
        elif after_next != at_space:
            kind = "space+retro"
        else:
            kind = "space+later"
    elif after_next != typed:
        kind = "retro"
    elif final != typed:
        kind = "later"
    else:
        kind = "suggestion" if offered and offered != typed and fold(offered) == typed else "none"
    return final, kind, f"{bar.get('band', '')}"

print("\t".join(["s", "case", "sentence", "token", "expected", "apple_final", "apple_when", "apple_bar", "dictus_develop", "dictus_971"]))
for s, (case, sentence) in enumerate(rows):
    words = sentence.split()
    for j, w in enumerate(words):
        if not is_target(w): continue
        expected = norm(w)
        tcase = case
        if case in A_GRAVE and fold(expected).lower() == expected and not expected.endswith("à"): tcase = "extra-a"
        if case in A_VERB and expected.endswith("à"): tcase = "extra-à"
        typed = fold(expected)
        a_final, a_kind, bar = apple_outcome(ap.get(s), j, typed, expected)
        d1 = norm(cd[s][j]) if j < len(cd.get(s, [])) else "?"
        d2 = norm(cp[s][j]) if j < len(cp.get(s, [])) else "?"
        print("\t".join(map(str, [s, tcase, sentence, j, expected, a_final or "", a_kind or "", bar, d1, d2])))
