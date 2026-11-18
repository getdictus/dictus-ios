#!/usr/bin/env python3
"""
compare_hits.py -- Today's hit test against the key-target model, tap by tap (#949).

Reads two replay directories of the same runs, one made with `run.sh --hit plain`, one
with `run.sh --hit model`, and prints per language:

  - wrong letters under each hit test, and the taps the model fixed and broke
    (a broken tap is one today's hit test typed right and the model typed wrong);
  - the share of letter taps whose letter the model changed;
  - wrong words in the final text, after autocorrect, under each;
  - the time the pick takes per tap (hit_ns: the plain hit test plus the model) and the
    trie nodes it visits, p50 / p95 / max.

With --bands (docs/research/954-keyboard-baseline/top-row-boundaries.txt), it also
counts the taps that land in the top-row bands where the real keyboard types nothing
(#954), which the replay's grid does not reproduce, and what the model types there.

Taps are matched on (lang, sentence, tap). Up to the first tap whose letter changed, a
sentence is the same in both directories; after it, the model's taps see another word
being typed, which is why both are replays rather than one replay scored twice.

Usage:
    python3 -I tools/keyboard-bench/compare_hits.py --plain <dir> --model <dir> [--title <text>] [--bands <file>]
"""

import argparse
import csv
import os
import re


def read(path):
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE))


def quantile(values, q):
    values = sorted(values)
    return values[min(len(values) - 1, int(q * len(values)))] if values else 0


def wrong_words(texts, lang):
    n = wrong = 0
    for r in texts:
        if r["lang"] != lang:
            continue
        meant = r["intended"].lower().split()
        got = r["final"].lower().split()
        n += len(meant)
        # Word-level edit distance, as score.py counts it.
        prev = list(range(len(got) + 1))
        for i, x in enumerate(meant, 1):
            cur = [i]
            for j, y in enumerate(got, 1):
                cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x != y)))
            prev = cur
        wrong += prev[-1]
    return wrong, n


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--plain", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--title", default="")
    parser.add_argument("--bands")
    parser.add_argument("--row-height", type=float, default=54)
    args = parser.parse_args()
    plain = read(os.path.join(args.plain, "taps.tsv"))
    model = read(os.path.join(args.model, "taps.tsv"))
    texts_plain = read(os.path.join(args.plain, "texts.tsv"))
    texts_model = read(os.path.join(args.model, "texts.tsv"))
    key = lambda r: (r["lang"], r["sentence"], r["tap"])  # noqa: E731
    by_key = {key(r): r for r in plain}

    if args.title:
        print(f"### {args.title}\n")
    print("| lang | letter taps | wrong letters, today | wrong letters, model | fixed | **broken** | letter changed "
          "| wrong words, today | wrong words, model |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    timing = []
    broken_rows = []
    for lang in sorted({r["lang"] for r in model}, key=["fr", "en"].index):
        rows = [r for r in model if r["lang"] == lang and r["intended"] != "space"]
        letters = len(rows)
        wrong_plain = sum(1 for r in plain if r["lang"] == lang and r["intended"] != "space"
                          and r["resolved"] != r["intended"])
        wrong_model = sum(1 for r in rows if r["resolved"] != r["intended"])
        # Within the model run, what the plain hit test would have typed for the same point.
        changed = [r for r in rows if r["resolved"] != r["plain"]]
        fixed = sum(1 for r in changed if r["resolved"] == r["intended"])
        broken = [r for r in changed if r["plain"] == r["intended"]]
        broken_rows += broken
        wp, n = wrong_words(texts_plain, lang)
        wm, _ = wrong_words(texts_model, lang)
        print(f"| {lang} | {letters} | {wrong_plain} | {wrong_model} | {fixed} | **{len(broken)}** "
              f"| {len(changed)} ({100 * len(changed) / letters:.1f}%) | {wp} of {n} | {wm} of {n} |")
        all_taps = [r for r in model if r["lang"] == lang]
        ns = [int(r["hit_ns"]) for r in all_taps]
        visited = [int(r["visited"]) for r in all_taps]
        plain_ns = [int(by_key[key(r)]["hit_ns"]) for r in all_taps if key(r) in by_key]
        timing.append(f"| {lang} | {len(all_taps)} | {quantile(plain_ns, .5) / 1000:.1f} | "
                      f"{quantile(ns, .5) / 1000:.1f} | {quantile(ns, .95) / 1000:.1f} | {max(ns) / 1000:.1f} | "
                      f"{quantile(visited, .5)} | {quantile(visited, .95)} | {max(visited)} |")
    print("\nPick time per tap (µs) and trie nodes visited:\n")
    print("| lang | taps | today p50 | model p50 | model p95 | model max | nodes p50 | nodes p95 | nodes max |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    print("\n".join(timing))
    if args.bands:
        with open(args.bands, encoding="utf-8") as f:
            bands = [(float(a), float(b)) for a, b in re.findall(r"dead ([\d.]+)-([\d.]+) pt", f.read())]
        # The probe moved in 0.1 pt steps: a tap within half a step of a dead probe counts.
        in_band = [r for r in model if 0 <= float(r["y"]) < args.row_height
                   and any(a - 0.05 <= float(r["x"]) <= b + 0.05 for a, b in bands)]
        right = sum(1 for r in in_band if r["resolved"] == r["intended"])
        print(f"\nTop-row dead bands (#954): {len(in_band)} of {len(model)} taps land in one. "
              f"The real keyboard types nothing for them today; the model types the intended letter "
              f"for {right} of them.")
        for r in in_band:
            print(f"- {r['lang']} sentence {r['sentence']} tap {r['tap']} at x {r['x']}: `{r['intended']}`, "
                  f"replay grid `{r['plain']}`, model `{r['resolved']}`")
    if broken_rows:
        print("\nBroken taps (today right, model wrong):\n")
        for r in broken_rows:
            print(f"- {r['lang']} sentence {r['sentence']} tap {r['tap']}: `{r['intended']}` typed `{r['resolved']}`")
    print()


if __name__ == "__main__":
    main()
