#!/usr/bin/env python3
"""Scores closing-phrase-bench rows against the dictus-test-voices manifest (#932).

usage: score.py <dictus-test-voices> <rows.tsv>...

Per engine, pipeline and language (clean clips, and the five tails pooled), then per
tail:
- WER: word error rate after lowercasing and stripping punctuation, as
  WHISPER_CHECK.md does. Mandarin is scored per character (CER), with Latin
  words and digit runs as single tokens. Numbers are not normalized.
- invented: share of decodes with at least one word inserted after the last
  spoken word, i.e. text the clip never says at its end.
Then every decode sent shorter than its clip (a cut inside the speech), and every
decode with an invented ending, verbatim.

A `cut-*` tail (#953) stops inside a word, so it is scored against the reference
prefix that aligns best: the words after the cut cost nothing, words after the last
aligned one are an invented ending.
"""
import csv
import json
import re
import sys
import unicodedata
from collections import defaultdict


def tokens(text, language):
    text = unicodedata.normalize("NFC", text).lower()
    text = re.sub(r"[’`]", "'", text)
    text = re.sub(r"(?<!\w)[-']|[-'](?!\w)", " ", text)
    text = "".join(c if c.isalnum() or c in "-' " else " " for c in text)
    if language == "zh":
        return re.findall(r"[a-z]+|\d+|[^\sa-z\d]", text)
    return text.split()


def align(ref, hyp, prefix=False):
    """Levenshtein alignment: (errors, number of hypothesis tokens after the
    hypothesis token aligned to the last reference token, reference tokens
    aligned). With `prefix`, against the best-aligning prefix of `ref`."""
    n, m = len(ref), len(hyp)
    d = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        d[i][0] = i
    for j in range(m + 1):
        d[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1,
                          d[i - 1][j - 1] + (ref[i - 1] != hyp[j - 1]))
    if prefix:
        # On a tie, the shorter prefix: a word Whisper adds after the cut counts as
        # invented rather than as a misheard next word.
        n = min(range(n + 1), key=lambda k: (d[k][m], k))
    # Trailing insertions: walk back from (n, m) while the cheapest move is an
    # insertion, before any reference token has been consumed.
    i, j, trailing = n, m, 0
    while j > 0 and i > 0:
        if d[i][j] == d[i][j - 1] + 1 and not (d[i][j] == d[i - 1][j - 1] + (ref[i - 1] != hyp[j - 1])):
            trailing += 1
            j -= 1
        else:
            break
    if i == 0:
        trailing = m
    return d[n][m], trailing, n


def main():
    corpus, paths = sys.argv[1], sys.argv[2:]
    manifest = json.load(open(f"{corpus}/manifest.json"))
    expected = {c["file"]: c["text"] for c in manifest["clips"]}
    duration = {c["file"]: c["duration_seconds"] for c in manifest["clips"]}
    cut_inside = []
    agg = defaultdict(lambda: [0, 0, 0, 0])  # errors, ref tokens, invented, decodes
    invented = []
    for path in paths:
        for row in csv.DictReader(open(path), delimiter="\t"):
            lang = row["language"]
            ref = tokens(expected[row["clip"]], lang)
            hyp = tokens(row["text"], lang)
            errors, trailing, aligned = align(ref, hyp, prefix=row["tail"].startswith("cut-"))
            if not row["tail"].startswith("cut-") and row["sent_seconds"] and float(row["sent_seconds"]) < duration[row["clip"]] - 0.005:
                cut_inside.append((row["engine"], row["pipeline"], row["tail"], row["clip"], row["sent_seconds"]))
            for key in [(row["engine"], row["pipeline"], lang, row["tail"]),
                        (row["engine"], row["pipeline"], "all", row["tail"])]:
                a = agg[key]
                a[0] += errors
                a[1] += aligned
                a[2] += trailing > 0
                a[3] += 1
            if trailing:
                tail_words = hyp[-trailing:]
                invented.append((row["engine"], row["pipeline"], row["tail"], row["clip"],
                                 " ".join(tail_words), row["text"][-90:]))

    def bucket(tail):
        return "clean" if tail == "clean" else "cuts" if tail.startswith("cut-") else "tails"

    pooled = defaultdict(lambda: [0, 0, 0, 0])
    for (engine, pipeline, lang, tail), a in agg.items():
        for i in range(4):
            pooled[(engine, pipeline, lang, bucket(tail))][i] += a[i]

    def wer(a):
        return f"{100 * a[0] / a[1]:.1f} %" if a[1] else ""

    def share(a):
        return f"{a[2]}/{a[3]}" if a[3] else ""

    print("| engine | pipeline | language | WER clean clips | WER clips with a tail | invented endings (tails) "
          "| WER clips cut in a word | invented endings (cuts) |")
    print("|---|---|---|---|---|---|---|---|")
    for engine, pipeline, lang in sorted({k[:3] for k in pooled}):
        c, t, x = (pooled[(engine, pipeline, lang, b)] for b in ("clean", "tails", "cuts"))
        print(f"| {engine} | {pipeline} | {lang} | {wer(c)} | {wer(t)} | {share(t)} | {wer(x)} | {share(x)} |")
    print()
    print("| engine | pipeline | language | tail | WER (CER zh) | invented endings |")
    print("|---|---|---|---|---|---|")
    for (engine, pipeline, lang, tail), (e, r, inv, n) in sorted(agg.items()):
        print(f"| {engine} | {pipeline} | {lang} | {tail} | {100 * e / r:.1f} % ({e}/{r}) | {inv}/{n} |")
    print()
    print(f"Decodes sent shorter than their clip: {len(cut_inside)}")
    for row in cut_inside:
        print("- " + " ".join(row))
    print()
    print("| engine | pipeline | tail | clip | inserted after the last spoken word | end of text |")
    print("|---|---|---|---|---|---|")
    for row in invented:
        print("| " + " | ".join(x.replace("|", "/") for x in row) + " |")


if __name__ == "__main__":
    main()
