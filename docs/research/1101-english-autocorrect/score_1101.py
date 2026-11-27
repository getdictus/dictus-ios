#!/usr/bin/env python3
"""
score_1101.py -- The #1101 tables: every keyboard on the same 56 English sentences.

Reads corpus/sentences.tsv (intended, typed, slip categories) and one texts.tsv per
keyboard (the bench's format: lang, sentence, intended, final), and prints markdown:
the sentence-by-sentence table, the totals, the outcome per failure family, and every
word a keyboard got wrong.

Each intended word gets one outcome, compared without case and with Apple's ’ made ':

  typed right: kept (right) or **broken** (changed to something else)
  typed wrong: fixed, missed (left as typed) or **miscorrected** (changed, still wrong)

Broken and miscorrected are the "weird" words: the keyboard wrote a word the typist
did not type and did not mean. A word whose previous word was typed wrong is counted
apart ("after a user typo"): its context was the typist's error, not the keyboard's.
Capitals are scored separately (a lone `i` left lowercase), never as wrong words.

Words are aligned typed -> final with difflib; when a keyboard joins or splits words,
every intended word in that stretch is wrong.

Usage:
    python3 -I score_1101.py --corpus corpus/sentences.tsv \
        --run Apple=apple/texts.tsv --run "build 43"=b43/texts.tsv ... > tables.md
"""

import argparse
import csv
import difflib
from collections import Counter, defaultdict

SLANG = {"gonna", "lol", "tbh", "idk", "omg", "ngl", "u", "k", "ur", "ok"}
NAMES = {"taylor", "swift", "uber", "chipotle", "venmo", "target", "jaxon", "kayla", "brandon", "instagram",
         "starbucks", "iphone", "amazon", "netflix", "hulu", "mike", "coachella", "priya", "dev",
         "thanksgiving", "december", "friday"}
# Contractions typed without the apostrophe that are also English words.
REAL_WORD = {"ill", "its", "were", "well", "id", "wont", "lets", "cant"}
SLIP_NAMES = {"A": "no apostrophe", "T": "typo list pair", "X": "swapped letters", "O": "missed letter",
              "D": "doubled letter", "N": "neighbour key",
              "P": "Pierre's device journal"}


def norm(w):
    return w.lower().replace("’", "'").strip(".,!?")


def read_corpus(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        next(f)
        for line in f:
            n, intended, typed, slips = (line.rstrip("\n").split("\t") + [""])[:4]
            rows.append((int(n), intended.split(), typed.split(), dict(s.split(":") for s in slips.split())))
    return rows


def read_texts(path):
    with open(path, encoding="utf-8", newline="") as f:
        return {int(r["sentence"]): r["final"] for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE)}


def align(typed, final):
    """For each typed word, the final word it became, or None inside a join or split."""
    out = [None] * len(typed)
    sm = difflib.SequenceMatcher(a=[norm(w) for w in typed], b=[norm(w) for w in final], autojunk=False)
    for op, a0, a1, b0, b1 in sm.get_opcodes():
        if op == "equal" or (op == "replace" and a1 - a0 == b1 - b0):
            for k in range(a1 - a0):
                out[a0 + k] = final[b0 + k]
    return out


def families(n_index, meant, got, slips, j):
    """The risk families an intended word belongs to."""
    m, g = norm(meant[j]), norm(got[j])
    fam = []
    if "'" in m:
        fam.append("contraction, real word typed" if g in REAL_WORD else "contraction")
    elif m in REAL_WORD and g == m:
        fam.append("real word that looks like a contraction")
    if m in SLANG:
        fam.append("slang / shorthand")
    if m in NAMES:
        fam.append("name or brand")
    if len(m) == 1:
        fam.append("single letter")
    if g in slips:
        fam.append(SLIP_NAMES[slips[g]])
        if len(m.replace("'", "")) <= 3:
            fam.append("short word with a slip")
    if j == 0:
        fam.append("sentence start")
    if j > 0 and norm(meant[j - 1]) in NAMES:
        fam.append("after a name or brand")
    return fam


def score(corpus, finals):
    words = []
    for n, meant, got, slips in corpus:
        final = finals.get(n - 1, "").split()
        mapped = align(got, final)
        for j in range(len(meant)):
            m, g, f = norm(meant[j]), norm(got[j]), mapped[j]
            fn = norm(f) if f is not None else None
            if g == m:
                outcome = "kept" if fn == m else "broken"
            elif fn == m:
                outcome = "fixed"
            elif fn == g:
                outcome = "missed"
            else:
                outcome = "miscorrected"
            words.append({
                "n": n, "j": j, "meant": meant[j], "typed": got[j], "final": f if f is not None else "(joined/split)",
                "outcome": outcome, "after_typo": j > 0 and norm(got[j - 1]) != norm(meant[j - 1]),
                "families": families(n, meant, got, slips, j),
                "lower_i": j > 0 and m.split("'")[0] == "i" and f is not None and f.startswith("i"),
            })
    return words


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--corpus", required=True)
    p.add_argument("--run", action="append", required=True, help="name=texts.tsv")
    a = p.parse_args()
    corpus = read_corpus(a.corpus)
    runs = []
    for spec in a.run:
        name, path = spec.split("=", 1)
        finals = read_texts(path)
        runs.append((name, finals, score(corpus, finals)))

    out = ["## Totals", "",
           "| | " + " | ".join(r[0] for r in runs) + " |",
           "|---|" + "---:|" * len(runs)]

    def row(label, fn):
        out.append(f"| {label} | " + " | ".join(str(fn(r)) for r in runs) + " |")

    total_typed_wrong = sum(1 for w in runs[0][2] if norm(w["typed"]) != norm(w["meant"]))
    row("Sentences", lambda r: len(corpus))
    row("**Sentences exactly right** (case ignored)", lambda r: sum(
        1 for n, meant, *_ in corpus if [norm(x) for x in r[1].get(n - 1, "").split()] == [norm(x) for x in meant]))
    row("Words", lambda r: len(r[2]))
    row(f"Words typed wrong", lambda r: total_typed_wrong)
    row("**Typed wrong, fixed**", lambda r: sum(w["outcome"] == "fixed" for w in r[2]))
    row("Typed wrong, missed (left as typed)", lambda r: sum(w["outcome"] == "missed" for w in r[2]))
    row("**Wrongly changed** (broken + miscorrected)", lambda r: sum(w["outcome"] in ("broken", "miscorrected") for w in r[2]))
    row("…broken (typed right, changed)", lambda r: sum(w["outcome"] == "broken" for w in r[2]))
    row("…miscorrected (typed wrong, changed to another wrong word)", lambda r: sum(w["outcome"] == "miscorrected" for w in r[2]))
    row("…of the wrongly changed, right after a user typo", lambda r: sum(
        w["outcome"] in ("broken", "miscorrected") and w["after_typo"] for w in r[2]))
    row("Wrong words in the final text", lambda r: sum(w["outcome"] not in ("kept", "fixed") for w in r[2]))
    row("…of which right after a user typo (counted apart)", lambda r: sum(
        w["outcome"] not in ("kept", "fixed") and w["after_typo"] for w in r[2]))
    n_i = sum(1 for w in runs[0][2] if norm(w["meant"]).split("'")[0] == "i" and w["j"] > 0)
    row(f"Casing: `i`, `i'm`, `i'll`... left lowercase mid-sentence (of {n_i})", lambda r: sum(w["lower_i"] for w in r[2]))
    n_names = sum(1 for w in runs[0][2] if norm(w["meant"]) in NAMES)
    row(f"Casing: names and brands written with a capital (of {n_names})", lambda r: sum(
        1 for w in r[2] if norm(w["meant"]) in NAMES and w["final"][:1].isupper()))
    out.append("")

    fams = sorted({f for w in runs[0][2] for f in w["families"]})
    out += ["## Per failure family: words right / words in the family (wrongly changed)", "",
            "| family | words | " + " | ".join(r[0] for r in runs) + " |", "|---|---:|" + "---|" * len(runs)]
    for fam in fams:
        cells = []
        for _, _, ws in runs:
            fw = [w for w in ws if fam in w["families"]]
            ok = sum(w["outcome"] in ("kept", "fixed") for w in fw)
            bad = sum(w["outcome"] in ("broken", "miscorrected") for w in fw)
            cells.append(f"{ok} ({bad})")
        n = sum(1 for w in runs[0][2] if fam in w["families"])
        out.append(f"| {fam} | {n} | " + " | ".join(cells) + " |")
    out.append("")

    out += ["## Sentence by sentence", "",
            "Wrong words in **bold**. `typed` is what the typist pressed.", "",
            "| # | expected | typed | " + " | ".join(r[0] for r in runs) + " |",
            "|---:|---|---|" + "---|" * len(runs)]
    for n, meant, got, _ in corpus:
        cells = []
        for _, finals, ws in runs:
            bad = {(w["n"], w["j"]) for w in ws if w["outcome"] not in ("kept", "fixed")}
            final = finals.get(n - 1, "")
            mark = [norm(x) for x in final.split()]
            if mark == [norm(x) for x in meant]:
                cells.append("✓")
            else:
                wrong_finals = {norm(w["final"]) for w in ws if w["n"] == n and (w["n"], w["j"]) in bad}
                meant_set = {norm(x) for x in meant}
                cells.append(" ".join(f"**{x}**" if norm(x) in wrong_finals or norm(x) not in meant_set else x
                                      for x in final.split()) or "(empty)")
        out.append(f"| {n} | {' '.join(meant)} | {' '.join(got)} | " + " | ".join(cells) + " |")
    out += ["", "✓: the whole sentence is right, case ignored.", ""]

    out += ["## Every word a keyboard got wrong", "",
            "| keyboard | # | outcome | meant | typed | wrote | after a user typo | families |",
            "|---|---:|---|---|---|---|---|---|"]
    for name, _, ws in runs:
        for w in ws:
            if w["outcome"] in ("kept", "fixed"):
                continue
            out.append(f"| {name} | {w['n']} | {w['outcome']} | {w['meant']} | {w['typed']} | {w['final']} | "
                       f"{'yes' if w['after_typo'] else ''} | {', '.join(w['families'])} |")
    print("\n".join(out))


if __name__ == "__main__":
    main()
