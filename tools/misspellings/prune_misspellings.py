#!/usr/bin/env python3
"""
prune_misspellings.py -- Drop known misspellings from a keyboard word list (#995).

A word in DictusKeyboard/Resources/<lang>_frequency.json counts as correct, so
autocorrect leaves it alone. The English list, taken from web counts, holds `teh`,
`recieve`, `definately`. This script removes the entries a public list of common
misspellings names, keeps their correct form, and records every removal in
tools/misspellings/removed-<lang>.tsv. The rule and the sources are in README.md.

The removal file is the record: a word it lists is removed again on every run, so a
rerun on the pruned list changes nothing, and a list rebuilt from its corpus
(scripts/curate_en_dictionary.py) is pruned the same way by running this again.

Usage (the source is downloaded data, so run the interpreter isolated):
    python3 -I tools/misspellings/prune_misspellings.py --lang en \
        --source <wikipedia raw page> --resources DictusKeyboard/Resources
then rebuild the trie:
    python3 tools/dict_builder.py DictusKeyboard/Resources/en_frequency.json \
        DictusKeyboard/Resources/en_spellcheck.dict
"""

import argparse
import csv
import hashlib
import json
import os
import re
import subprocess
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))

# Pinned revisions, so the selection can be rerun and audited.
SOURCES = {
    "en": {
        "name": "Wikipedia:Lists of common misspellings/For machines",
        "url": "https://en.wikipedia.org/w/index.php?oldid=1199637275&action=raw",
        "sha256": "3b6a9290e5aaad968da7ec769a5174adb45247688ef7ae097fd2dd80237a3050",
        "checkers": ["en"],
    },
    "es": {
        "name": "Wikipedia:Corrector ortográfico/Listado",
        "url": "https://es.wikipedia.org/w/index.php?oldid=176376567&action=raw",
        "sha256": "46f237ad2fd11573cf3c1c842ec96e311435345349c328326375ea205a2bcf39",
        # The Spanish list also names loanwords and foreign place names (`garage`,
        # `kenya`). A word the English checker accepts is one of those, not a typo.
        "checkers": ["es", "en"],
    },
}

FIELDS = ["misspelling", "target", "misspelling_count", "target_count", "source"]


def fold(word):
    """The word without its diacritics."""
    return "".join(c for c in unicodedata.normalize("NFD", word) if unicodedata.category(c) != "Mn")


def damerau(a, b):
    """Edit distance counting an adjacent swap as one edit (`teh` -> `the` is 1)."""
    d = [[0] * (len(b) + 1) for _ in range(len(a) + 1)]
    for i in range(len(a) + 1):
        d[i][0] = i
    for j in range(len(b) + 1):
        d[0][j] = j
    for i in range(1, len(a) + 1):
        for j in range(1, len(b) + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
            if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
                d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1)
    return d[len(a)][len(b)]


def parse_en(text):
    """` misspelling->correction, correction` lines."""
    for line in text.splitlines():
        m = re.match(r"^ ([^\s>]+)->(.+)$", line)
        if m:
            yield m.group(1), [c.strip() for c in m.group(2).split(",")]


def parse_es(text):
    """` misspelling|param|correction (note), correction` lines. A `cs` entry only
    applies to one capitalisation, which a lowercase word list cannot express."""
    for line in text.splitlines():
        m = re.match(r"^ ([^|\s]+)\|([^|]*)\|(.+)$", line)
        if not m or m.group(2).strip():
            continue
        alternatives = re.split(r",(?![^()]*\))", m.group(3))
        yield m.group(1), [re.sub(r"\(.*?\)", "", a).strip() for a in alternatives]


PARSERS = {"en": parse_en, "es": parse_es}


def candidates(lang, text, counts):
    """(misspelling, target) pairs the rule selects, before the spelling check."""
    pairs = {}
    for typed, corrections in PARSERS[lang](text):
        word = typed.lower()
        if word not in counts or word in pairs:
            continue
        lowered = [c.lower() for c in corrections]
        # The source lists the typed form among its corrections when it is often right.
        # A correction that only adds an accent is the accent rule's case (#994), and
        # one that is a phrase (`aver` -> `a ver`) leaves the target in doubt.
        if any(c == word or fold(c) == fold(word) or not re.fullmatch(r"\w+", c) for c in lowered):
            continue
        for target in lowered:
            # A one- or two-letter target is an abbreviation (`mts` -> `m`), not a spelling.
            if len(target) < 3 or target not in counts:
                continue
            if counts[target] <= counts[word] or damerau(word, target) > 2:
                continue
            pairs[word] = target
            break
    return pairs


def flagged_by_apple(languages, words):
    """The words every listed macOS spelling checker flags, i.e. not real words."""
    flagged = set(words)
    for language in languages:
        result = subprocess.run(
            ["xcrun", "swift", os.path.join(HERE, "apple_spellcheck.swift"), language],
            input="\n".join(sorted(flagged)) + "\n", capture_output=True, text=True, check=True,
        )
        flagged &= set(result.stdout.split())
    return flagged


def read_removed(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_json_like(path, original, counts):
    """Rewrite the list in the layout it was read in, so the diff shows removals only."""
    for separators in ((",", ":"), (", ", ": ")):
        for ensure_ascii in (False, True):
            if json.dumps(json.loads(original), separators=separators, ensure_ascii=ensure_ascii) == original.rstrip("\n"):
                trailing = original[len(original.rstrip("\n")):]
                with open(path, "w", encoding="utf-8") as f:
                    f.write(json.dumps(counts, separators=separators, ensure_ascii=ensure_ascii) + trailing)
                return
    raise SystemExit(f"{path}: unknown JSON layout, not rewritten")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--lang", required=True, choices=sorted(SOURCES))
    parser.add_argument("--source", required=True, help="the raw page at SOURCES[lang]['url']")
    parser.add_argument("--resources", required=True, help="DictusKeyboard/Resources")
    args = parser.parse_args()

    source = SOURCES[args.lang]
    raw = open(args.source, "rb").read()
    digest = hashlib.sha256(raw).hexdigest()
    if source["sha256"] and digest != source["sha256"]:
        raise SystemExit(f"{args.source}: sha256 {digest}, expected {source['sha256']} ({source['url']})")

    path = os.path.join(args.resources, f"{args.lang}_frequency.json")
    original = open(path, encoding="utf-8").read()
    counts = json.loads(original)

    removed_path = os.path.join(HERE, f"removed-{args.lang}.tsv")
    removed = {row["misspelling"]: row for row in read_removed(removed_path)}

    pairs = candidates(args.lang, raw.decode("utf-8"), counts)
    flagged = flagged_by_apple(source["checkers"], pairs) if pairs else set()
    for word, target in pairs.items():
        if word in flagged and word not in removed:
            removed[word] = {
                "misspelling": word, "target": target,
                "misspelling_count": counts[word], "target_count": counts[target],
                "source": source["name"],
            }

    kept = {w: c for w, c in counts.items() if w not in removed}
    write_json_like(path, original, kept)

    rows = sorted(removed.values(), key=lambda r: (-int(r["misspelling_count"]), r["misspelling"]))
    with open(removed_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    print(f"{args.lang}: source sha256 {digest}")
    print(f"{args.lang}: {len(pairs)} listed misspellings in the word list, "
          f"{len(pairs) - len(flagged & set(pairs))} kept as real words by the spelling checker")
    print(f"{args.lang}: {len(counts) - len(kept)} removed this run, {len(removed)} in {os.path.relpath(removed_path)}")
    for word in sorted(set(pairs) - flagged):
        print(f"  kept (real word): {word} -> {pairs[word]}")


if __name__ == "__main__":
    main()
