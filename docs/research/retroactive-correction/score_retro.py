#!/usr/bin/env python3
"""Table of the retroactive-correction probes: Apple (word by word) against Dictus (replay).
Usage: score_retro.py <this folder> > table.md
Apple is compared case-sensitively (it decides `i` -> `I`); Dictus case-insensitively,
because the replay capitalises the first letter of the field on its own."""
import csv, json, os, sys
here = sys.argv[1]
def apos(w): return (w or "").replace("’", "'")
texts = {}
for k in ("develop", "971"):
    with open(os.path.join(here, "data", f"dictus-{k}-texts.tsv"), encoding="utf-8") as f:
        for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
            texts.setdefault((k, r["lang"]), []).append(r["final"])
for lang in ("en", "fr"):
    rows = [l.rstrip("\n").split("\t") for l in open(os.path.join(here, f"corpus-{lang}.tsv"), encoding="utf-8")
            if l.strip() and not l.startswith("#")][1:]
    ap = {}
    for l in open(os.path.join(here, "data", f"apple-p2-{lang}.jsonl"), encoding="utf-8"):
        r = json.loads(l); ap[r["s"]] = r
    print(f"\n### {'English' if lang == 'en' else 'French'}\n")
    print("| Case | Typed | Expected | Apple at the space | after the next word | When Apple changed it | Apple final | Dictus develop | #971 |")
    print("|---|---|---|---|---|---|---|---|---|")
    for s, (case, sent, t, exp) in enumerate(rows):
        t = int(t)
        st = [apos(x).split() for x in ap[s]["states"]]
        typed = sent.split()[t]
        a1, a2, af = st[t][t], (st[t + 1][t] if t + 1 < len(st) else st[t][t]), st[-1][t]
        if a1 != typed and a2 == a1: when = "at the space"
        elif a1 != typed: when = "at the space, **taken back** after the next word"
        elif a2 != typed: when = "**after the next word**"
        else: when = "never"
        ok = lambda v, ci=False: f"`{v}`" + ("" if (v.lower() == exp.lower() if ci else v == exp) else " ✗")
        d = [apos(texts[(k, lang)][s]).split()[t] for k in ("develop", "971")]
        print(f"| {case} | `{sent}` | `{exp}` | `{a1}` | `{a2}` | {when} | {ok(af)} | {ok(d[0], True)} | {ok(d[1], True)} |")
