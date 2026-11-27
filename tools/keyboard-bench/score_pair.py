#!/usr/bin/env python3
"""
score_pair.py -- The bilingual replay's report (#1009): pair.tsv + pair-cost.tsv -> markdown.

A word is wrong when its committed text differs from the intended word, case ignored. Two
intended words joined by a missed space are one commit and count once.

Usage:
    python3 -I tools/keyboard-bench/score_pair.py --dir <replay out dir> [--pair fr,en] [--commit <sha>]
"""

import argparse
import collections
import os
import statistics


def percentile(values, q):
    values = sorted(values)
    return values[min(len(values) - 1, int(round(q * (len(values) - 1))))] if values else 0


def majority(rows):
    return collections.Counter(r["gold"] for r in rows).most_common(1)[0][0]


def detection(rows):
    """Right language per word, words of the sentence's language decided in it, inserts
    that flipped the window, and words decided in the old language after a change."""
    sentences = collections.OrderedDict()
    for r in rows:
        sentences.setdefault(r["sentence"], []).append(r)
    matrix = {s: majority(v) for s, v in sentences.items()}
    word_ok = sum(r["decided"] == r["gold"] for r in rows)
    native = [r for r in rows if r["gold"] == matrix[r["sentence"]]]
    native_ok = sum(r["decided"] == r["gold"] for r in native)
    # An insert is a word whose gold language is not its sentence's. It flipped the window
    # when the next word of the sentence, in the sentence's language, is decided otherwise.
    inserts = flips = 0
    for s, v in sentences.items():
        for i, r in enumerate(v):
            if r["gold"] != matrix[s]:
                inserts += 1
                following = v[i + 1] if i + 1 < len(v) else None
                if following and following["gold"] == matrix[s] and following["decided"] != matrix[s]:
                    flips += 1
    # After a message in the other language: how many words are still decided in the old one.
    latencies = []
    order = list(sentences)
    for before, after in zip(order, order[1:]):
        if matrix[before] == matrix[after]:
            continue
        v = sentences[after]
        latencies.append(next((i for i, r in enumerate(v) if r["decided"] == matrix[after]), len(v)))
    return word_ok, (native_ok, len(native)), inserts, flips, latencies


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", required=True)
    parser.add_argument("--pair", default="fr,en")
    parser.add_argument("--commit", default="")
    args = parser.parse_args()

    by = collections.OrderedDict()
    with open(os.path.join(args.dir, "pair.tsv"), encoding="utf-8") as f:
        header = f.readline().rstrip("\n").split("\t")
        for line in f:
            r = dict(zip(header, line.rstrip("\n").split("\t")))
            by.setdefault((r["run"], r["policy"]), []).append(r)
    cost = collections.defaultdict(list)
    with open(os.path.join(args.dir, "pair-cost.tsv"), encoding="utf-8") as f:
        f.readline()
        for line in f:
            run, policy, kind, us = line.rstrip("\n").split("\t")
            cost[(run, policy, kind)].append(int(us))

    runs = list(collections.OrderedDict.fromkeys(run for run, _ in by))
    policies = list(collections.OrderedDict.fromkeys(policy for _, policy in by))

    def wrong(rows):
        return [r for r in rows if r["final"].lower() != r["meant"].lower()]

    print(f"# Bilingual replay, pair {args.pair}" + (f", commit {args.commit[:8]}" if args.commit else ""))
    print()
    print("Wrong words in the final text, per committed word, case ignored. `mono-<lang>` is today's "
          "keyboard set to that language; `detect` is #1010's bilingual keyboard (window and keep rule); "
          "`check` is #1015's bilingual check (window, keep rule, Hex's partner fallback and lean, both "
          "engines on the same taps).")
    print()
    print("| run | words | " + " | ".join(f"`{p}`" for p in policies) + " |")
    print("|---|---:|" + "---:|" * len(policies))
    for run in runs:
        words = len(by[(run, policies[0])])
        print(f"| {run} | {words} | " + " | ".join(str(len(wrong(by[(run, p)]))) for p in policies) + " |")

    languages = args.pair.split(",")
    print()
    print("Words typed right that the keyboard changed (broken), by the word's language. A word is typed "
          "right when the letters that reached the field are the intended word, case ignored.")
    print()
    print("| run | policy | " + " | ".join(f"broken `{lang}` words" for lang in languages) + " |")
    print("|---|---|" + "---:|" * len(languages))
    for run in runs:
        for policy in policies:
            rows = by[(run, policy)]
            cells = []
            for lang in languages:
                right = [r for r in rows if r["gold"] == lang and r["typed"].lower() == r["meant"].lower()]
                broken = [r for r in right if r["final"].lower() != r["meant"].lower()]
                cells.append(f"{len(broken)} of {len(right)}")
            print(f"| {run} | `{policy}` | " + " | ".join(cells) + " |")

    print()
    print("Language decided per word, `detect`:")
    print()
    print("| run | right language, every word | right language, words in their sentence's language "
          "| inserts that flipped the window | words still in the old language after a change of language |")
    print("|---|---:|---:|---:|---|")
    for run in runs:
        rows = by[(run, "detect")]
        word_ok, (native_ok, native_n), inserts, flips, latencies = detection(rows)
        n = len(rows)
        latency = (f"{statistics.mean(latencies):.1f} on average ({', '.join(map(str, latencies))})"
                   if latencies else "-")
        print(f"| {run} | {word_ok} / {n} | {native_ok} / {native_n} | {f'{flips} of {inserts}' if inserts else '-'} "
              f"| {latency} |")

    print()
    print("Words left wrong (intended -> final):")
    print()
    for run in runs:
        for policy in policies:
            bad = [f"{r['meant']}->{r['final']}" for r in wrong(by[(run, policy)])]
            print(f"- {run} `{policy}`: {', '.join(bad) if bad else 'none'}")

    print()
    print("Engine time per keystroke, microseconds, simulator (not a device figure). A letter runs the "
          "correction preview and the suggestions; a space runs the autocorrect.")
    print()
    print("| run | policy | letter p50 | letter p95 | space p50 | space p95 |")
    print("|---|---|---:|---:|---:|---:|")
    for run in runs:
        for policy in policies:
            letters = cost[(run, policy, "letter")]
            spaces = cost[(run, policy, "space")]
            print(f"| {run} | `{policy}` | {statistics.median(letters):.0f} | {percentile(letters, 0.95)} "
                  f"| {statistics.median(spaces):.0f} | {percentile(spaces, 0.95)} |")

    print()
    shown = [p for p in ("detect", "check") if p in policies]
    print("<details><summary>Mixed runs, word by word, " + ", ".join(f"<code>{p}</code>" for p in shown)
          + ": sentence, gold, decided, typed -> final</summary>")
    print()
    print("```")
    for run, policy in [(run, policy) for run in runs for policy in shown]:
        if not run.startswith("mixed"):
            continue
        print(f"{run} {policy}")
        for r in by[(run, policy)]:
            mark = "" if r["decided"] == r["gold"] else "  <- language"
            miss = "" if r["final"].lower() == r["meant"].lower() else f"  (meant {r['meant']})"
            print(f"  {int(r['sentence']):2d} {r['gold']} {r['decided']} {r['typed']} -> {r['final']}{mark}{miss}")
    print("```")
    print()
    print("</details>")


if __name__ == "__main__":
    main()
