#!/usr/bin/env python3
"""
score.py -- The keyboard measurement report (#954).

Reads what a run produced and prints the report as markdown. One scorer for every
source, so a Dictus replay, an Apple run and a device run are counted the same way:

  texts.tsv    lang, sentence, intended, final       every source has this
  taps.tsv     one row per tap: intended and resolved key, engine time
  commits.tsv  one row per space-bar commit: intended word(s), typed, final

Only a replay knows its taps and commits. For any other source, the report holds the
text section alone.

Comparison is case-insensitive (auto-capitalisation is not under test) and
accent-sensitive ("tres" for "très" is a wrong word).

A device run has no files of its own: what was typed is pasted into one text file per
language, one sentence per line in corpus order, and passed with --typed.

Usage:
    python3 -I tools/keyboard-bench/score.py --dir <run dir> --keyboard <name> [--commit <sha>]
    python3 -I tools/keyboard-bench/score.py --typed fr:<file> --typed en:<file> --keyboard <name>
"""

import argparse
import csv
import os
import unicodedata
from collections import Counter, defaultdict


def read(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE))


def distance(a, b):
    """Levenshtein distance between two sequences."""
    prev = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        cur = [i]
        for j, y in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x != y)))
        prev = cur
    return prev[-1]


def fold(word):
    return "".join(c for c in unicodedata.normalize("NFD", word) if not unicodedata.combining(c))


def pct(n, d):
    return f"{100 * n / d:.1f}%" if d else "n/a"


def ms(values, q):
    if not values:
        return "n/a"
    values = sorted(values)
    return f"{values[min(len(values) - 1, int(q * len(values)))] / 1000:.2f}"


def text_section(rows):
    out = ["## Final text", "",
           "| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |",
           "|---|---:|---:|---:|---:|---:|---:|---:|"]
    by_lang = defaultdict(list)
    for r in rows:
        by_lang[r["lang"]].append(r)
    for lang, rs in by_lang.items():
        words = wrong = chars = char_errors = folded_errors = glued = 0
        for r in rs:
            meant = r["intended"].lower().split()
            got = r["final"].lower().split()
            words += len(meant)
            wrong += distance(meant, got)
            chars += len(r["intended"])
            char_errors += distance(r["intended"].lower(), r["final"].lower())
            folded_errors += distance(fold(r["intended"].lower()), fold(r["final"].lower()))
            pairs = {fold(a + b) for a, b in zip(meant, meant[1:])}
            glued += sum(1 for g in got if fold(g) in pairs)
        out.append(f"| {lang} | {len(rs)} | {words} | {wrong} | {pct(wrong, words)} | "
                   f"{pct(char_errors, chars)} | {pct(folded_errors, chars)} | {glued} |")
    out += ["", "Word errors are a word-level edit distance against the intended sentence; a glued word is a "
            "final token that is two consecutive intended words without the space. Ignoring accents leaves the errors "
            "that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.", ""]
    return out


def tap_section(rows):
    out = ["## Taps", "",
           "| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |",
           "|---|---:|---:|---:|---:|---:|---|"]
    by_lang = defaultdict(list)
    for r in rows:
        by_lang[r["lang"]].append(r)
    for lang, rs in by_lang.items():
        letters = [r for r in rs if r["intended"] != "space"]
        wrong = [r for r in letters if r["resolved"] != r["intended"]]
        spaces = [r for r in rs if r["intended"] == "space"]
        missed = [r for r in spaces if r["resolved"] != "space"]
        landed = ", ".join(f"`{k}` {n}" for k, n in Counter(r["resolved"] for r in missed).most_common())
        out.append(f"| {lang} | {len(letters)} | {len(wrong)} ({pct(len(wrong), len(letters))}) | "
                   f"{sum(1 for r in wrong if r['resolved'] == 'space')} | {len(spaces)} | "
                   f"{len(missed)} ({pct(len(missed), len(spaces))}) | {landed or '-'} |")
    out += ["", "## Engine time per keystroke (ms)", "",
            "The suggestion work a letter triggers and the autocorrect a space triggers, run one after the "
            "other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.", "",
            "| lang | key | taps | p50 | p95 | max |", "|---|---|---:|---:|---:|---:|"]
    for lang, rs in by_lang.items():
        for kind, pick in (("letter", lambda r: r["resolved"] not in ("space", "backspace", "shift", "return",
                                                                         "123", "spacer", "none", "other")),
                           ("space", lambda r: r["resolved"] == "space")):
            us = [int(r["engine_us"]) for r in rs if pick(r)]
            out.append(f"| {lang} | {kind} | {len(us)} | {ms(us, 0.5)} | {ms(us, 0.95)} | {ms(us, 1.0)} |")
    out.append("")
    # A bench built with `run.sh --debug` also times the typing journal's tap call (#1001).
    if any(int(r.get("journal_ns") or 0) for r in rows):
        out += ["## Typing journal per tap (µs)", "",
                "What recording one tap costs on the keystroke: the call `GiellaKeyboardView` makes where a "
                "touch resolves to a key. Taps that resolved to no key are not recorded.", "",
                "| lang | taps | p50 | p95 | max |", "|---|---:|---:|---:|---:|"]
        for lang, rs in by_lang.items():
            us = sorted(int(r["journal_ns"]) / 1000 for r in rs if r["resolved"] != "none")
            at = lambda q: f"{us[min(len(us) - 1, int(q * len(us)))]:.1f}" if us else "n/a"
            out.append(f"| {lang} | {len(us)} | {at(0.5)} | {at(0.95)} | {at(1.0)} |")
        out.append("")
    return out


def commit_section(rows):
    out = ["## Autocorrect, per word the space bar committed", "",
           "| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | "
           "missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |",
           "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    by_lang = defaultdict(list)
    for r in rows:
        by_lang[r["lang"]].append(r)
    cases = []
    for lang, rs in by_lang.items():
        c = Counter()
        for r in rs:
            # A run made from a device journal (#1001) writes a multi-word commit with "_"
            # and a word whose intent is unknown as "-" (journal_to_run.py --intended).
            meant, typed, final = r["intended"].lower().replace("_", " "), r["typed"].lower(), r["final"].lower()
            if meant == "-" or meant.startswith("- ") or meant.endswith(" -") or " - " in meant:
                c["unknown"] += 1
                continue
            if " " in meant:
                c["glued"] += 1
                if final == meant:
                    c["split"] += 1
                else:
                    cases.append((lang, "glued", r))
                continue
            c["words"] += 1
            if typed == meant:
                kind = "kept" if final == typed else "broken"
            elif final == meant:
                kind = "fixed"
            elif final == typed:
                kind = "missed"
                if fold(typed) == fold(meant):
                    c["accent"] += 1
            else:
                kind = "miscorrected"
            c[kind] += 1
            if kind in ("broken", "miscorrected", "missed"):
                cases.append((lang, kind, r))
        out.append(f"| {lang} | {c['words']} | {c['kept']} | {c['fixed']} | **{c['broken']}** | {c['missed']} | "
                   f"{c['accent']} | **{c['miscorrected']}** | {c['glued']} | {c['split']} |")
    out += ["", "Wrong autocorrections are the two bold columns. A stray space splits one intended word over two "
            "commits; those halves count as typed wrong.", "",
            "## Every word that did not come out right", "",
            "| lang | outcome | intended | typed | final |", "|---|---|---|---|---|"]
    order = {"broken": 0, "miscorrected": 1, "missed": 2, "glued": 3}
    for lang, kind, r in sorted(cases, key=lambda x: (x[0], order[x[1]])):
        out.append(f"| {lang} | {kind} | {r['intended']} | {r['typed']} | {r['final']} |")
    out.append("")
    return out


def typed_rows(specs):
    """texts.tsv rows from pasted device output: lang:file, one sentence per line."""
    bench = os.path.dirname(os.path.abspath(__file__))
    rows = []
    for spec in specs:
        lang, path = spec.split(":", 1)
        with open(os.path.join(bench, "corpus", f"{lang}.txt"), encoding="utf-8") as f:
            intended = [line.strip() for line in f if line.strip()]
        with open(path, encoding="utf-8") as f:
            typed = [line.strip() for line in f if line.strip()]
        if len(typed) != len(intended):
            raise SystemExit(f"{path}: {len(typed)} lines, the {lang} corpus has {len(intended)}")
        rows += [{"lang": lang, "sentence": str(i), "intended": a, "final": b}
                 for i, (a, b) in enumerate(zip(intended, typed))]
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir")
    parser.add_argument("--typed", action="append", default=[], metavar="LANG:FILE")
    parser.add_argument("--keyboard", required=True)
    parser.add_argument("--commit", default="unknown")
    args = parser.parse_args()
    if bool(args.dir) == bool(args.typed):
        parser.error("pass either --dir or --typed")

    lines = [f"# Keyboard measurement: {args.keyboard}", "", f"commit: `{args.commit}`", ""]
    if args.typed:
        lines += text_section(typed_rows(args.typed))
        print("\n".join(lines))
        return
    texts = read(os.path.join(args.dir, "texts.tsv"))
    if texts is None:
        raise SystemExit(f"no texts.tsv in {args.dir}")
    lines += text_section(texts)
    taps = read(os.path.join(args.dir, "taps.tsv"))
    if taps:
        lines += tap_section(taps)
    commits = read(os.path.join(args.dir, "commits.tsv"))
    if commits:
        lines += commit_section(commits)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
