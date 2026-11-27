#!/usr/bin/env python3
"""
context_choice.py -- Estimate, offline, what Hex's context choice would do on the #1101 run.

Hex (github.com/anomalyco/hex, branch dev, MIT, Copyright (c) 2026 Christopher Langton)
chooses between same-letter English words ("its"/"it's", "id"/"I'd", "well"/"we'll") with
its typing model's word pairs: `contextChoice` and `revision` in
ios/HEXShared/FullKeyboard/Autocorrect/AutocorrectEngine.swift (lines 1266-1383 at
2f8c3b70). This script restates that rule in Python over an HXTM v3 file (the format
DictusCore/Sources/DictusCore/SpatialDecoder/SpatialDecoderModel.swift reads) and applies
it to every word of corpus/sentences.tsv that belongs to one of Hex's groups, typed as
the typist typed it, with the previous word as intended (the keyboard has usually
corrected it by then) and the next word typed. It prints, per word, the choice on space
(previous word only) and after the next word (Hex's revision), and the totals.

It is an estimate of the rule, not of the keyboard: no tap, no other branch, no casing.

Usage:
    python3 -I context_choice.py --model <en.hextm> [--model <other en.hextm>]
"""

import argparse
import mmap
import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))

GROUPS = [["id", "i'd"], ["ill", "i'll"], ["hell", "he'll"], ["shell", "she'll"], ["wed", "we'd"],
          ["lets", "let's"], ["well", "we'll"], ["its", "it's"], ["your", "you're"],
          ["there", "their", "they're"], ["then", "than"]]
CONTRACTION_WORDS = {"i'd": [["i", "would"], ["i", "had"]], "i'll": [["i", "will"]], "he'll": [["he", "will"]],
                     "she'll": [["she", "will"]], "we'd": [["we", "would"], ["we", "had"]], "let's": [["let", "us"]],
                     "we'll": [["we", "will"]], "it's": [["it", "is"], ["it", "has"]], "you're": [["you", "are"]],
                     "they're": [["they", "are"]]}
GROUP_OF = {w: g for g in GROUPS for w in g}
MARGIN = (3.0, 1.5)
LETTER_MARGIN = (6.0, 3.0)
UNKNOWN = 15.0
SENTENCE_START = 3.0
MISSING_FOLLOWER = 5.0
RICH_FOLLOWERS = {"will", "would", "had", "us"}


class Model:
    """HXTM v3, read as SpatialDecoderModel reads it."""

    def __init__(self, path):
        f = open(path, "rb")
        self.m = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        magic, version, self.words, self.bigrams, blob, letters = struct.unpack_from("<IIIIII", self.m, 0)
        assert magic == 0x4D545848 and version == 3
        self.codes = {}
        for i in range(letters):
            scalar, = struct.unpack_from("<I", self.m, 28 + 8 * i)
            self.codes[chr(scalar)] = self.m[28 + 8 * i + 4]
        self.offsets_at = 28 + 8 * letters
        self.unigram_at = self.offsets_at + 4 * (self.words + 1)
        rows = self.unigram_at + self.words
        rows += (4 - rows % 4) % 4
        self.rows_at = rows
        self.pair_words_at = rows + 4 * (self.words + 1)
        self.pair_costs_at = self.pair_words_at + 4 * self.bigrams
        self.blob_at = self.pair_costs_at + self.bigrams
        assert self.blob_at + blob == len(self.m)
        self.index = {}
        for i in range(self.words):
            s, e = struct.unpack_from("<II", self.m, self.offsets_at + 4 * i)
            self.index[bytes(self.m[self.blob_at + s:self.blob_at + e])] = i

    def idx(self, word):
        try:
            return self.index.get(bytes(self.codes[c] for c in word))
        except KeyError:
            return None

    def unigram(self, i):
        return self.m[self.unigram_at + i] / 8

    def pair(self, a, b):
        lo, end = struct.unpack_from("<II", self.m, self.rows_at + 4 * a)
        hi = end
        while lo < hi:
            mid = (lo + hi) // 2
            if struct.unpack_from("<I", self.m, self.pair_words_at + 4 * mid)[0] < b:
                lo = mid + 1
            else:
                hi = mid
        if lo < end and struct.unpack_from("<I", self.m, self.pair_words_at + 4 * lo)[0] == b:
            return self.m[self.pair_costs_at + lo] / 8
        return None

    def cost(self, word, previous):
        i = self.idx(word)
        if i is None:
            return None
        backoff = 0.92 + self.unigram(i)
        a = self.idx(previous) if previous else None
        p = self.pair(a, i) if a is not None else None
        return backoff if p is None else min(p, backoff)

    def has_pair(self, a, b):
        ia, ib = self.idx(a), self.idx(b)
        return ia is not None and ib is not None and self.pair(ia, ib) is not None


def context_cost(model, word, previous, nxt, starts):
    expanded = CONTRACTION_WORDS.get(word)
    best = float("inf")
    for words in expanded or [[word]]:
        c = model.cost(words[0], previous)
        cost = UNKNOWN if c is None else c
        for k in range(1, len(words)):
            c = model.cost(words[k], words[k - 1])
            cost += UNKNOWN if c is None else c
        if nxt is not None:
            last = words[-1]
            c = model.cost(nxt, last)
            cost += UNKNOWN if c is None else c
            if last in RICH_FOLLOWERS and not model.has_pair(last, nxt):
                cost += MISSING_FOLLOWER
        best = min(best, cost)
    return best - SENTENCE_START if expanded and starts else best


def choice(model, word, previous, nxt, starts):
    group = GROUP_OF.get(word)
    if not group:
        return None
    own = context_cost(model, word, previous, nxt, starts)
    best = None
    for other in group:
        if other == word:
            continue
        c = context_cost(model, other, previous, nxt, starts)
        if best is None or c < best[1]:
            best = (other, c)
    same = best[0].replace("'", "") == word.replace("'", "")
    margins = MARGIN if same else LETTER_MARGIN
    return best[0] if own - best[1] >= (margins[0] if nxt is None else margins[1]) else None


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model", action="append", required=True)
    a = p.parse_args()
    rows = []
    with open(os.path.join(HERE, "corpus", "sentences.tsv"), encoding="utf-8") as f:
        next(f)
        for line in f:
            n, intended, typed, _ = (line.rstrip("\n").split("\t") + [""])[:4]
            rows.append((int(n), intended.split(), typed.split()))
    for path in a.model:
        model = Model(path)
        print(f"## {path}: {model.words} words, {model.bigrams} pairs, {os.path.getsize(path)} bytes\n")
        print("| # | typed | meant | on space | after the next word | outcome |")
        print("|---:|---|---|---|---|---|")
        tally = {"fixed": 0, "kept right": 0, "broken": 0, "missed": 0}
        for n, meant, typed in rows:
            for j, t in enumerate(typed):
                if t not in GROUP_OF:
                    continue
                prev = meant[j - 1] if j else None
                nxt = typed[j + 1] if j + 1 < len(typed) else None
                on_space = choice(model, t, prev, None, j == 0)
                revised = choice(model, t, prev, nxt, j == 0) if nxt else on_space
                final = revised or on_space or t
                m = meant[j]
                outcome = ("fixed" if final == m else "missed") if t != m else ("kept right" if final == m else "broken")
                tally[outcome] += 1
                print(f"| {n} | {t} | {m} | {on_space or '-'} | {revised or '-'} | {outcome} |")
        print("\n" + ", ".join(f"{k} {v}" for k, v in tally.items()) + "\n")


if __name__ == "__main__":
    main()
