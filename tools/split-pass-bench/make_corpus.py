#!/usr/bin/env python3
"""
make_corpus.py -- Build the glued-word corpus the split-pass bench measures (#499).

Writes DictusCore/Tests/DictusCoreTests/Fixtures/split-pass-corpus.tsv. The file is
committed; this script exists so it can be rebuilt and audited, not run on every
measurement.

Sources:
  - Tatoeba sentence exports (https://tatoeba.org, CC BY 2.0 FR), one per language:
    https://downloads.tatoeba.org/exports/per_language/<fra|eng|deu|spa>/<lang>_sentences.tsv.bz2
    Adjacent word pairs give the glued cases; long words absent from the keyboard's
    frequency list give the rare legitimate words.
  - DictusKeyboard/Resources/<lang>_frequency.json, the keyboard's own word list:
    long words that are two shorter words end to end ("longtemps").
  - The eight words glued on the simulator keyboard in the spacebar research
    (2026-10-30/31), with what the typist meant.

Usage (the exports are downloaded data, so run the interpreter isolated):
    python3 -I tools/split-pass-bench/make_corpus.py \
        --tatoeba <dir with the four .tsv.bz2> \
        --resources DictusKeyboard/Resources \
        --out DictusCore/Tests/DictusCoreTests/Fixtures/split-pass-corpus.tsv
"""

import argparse
import bz2
import hashlib
import json
import os
import random
import re

LANGS = {"fr": "fra", "en": "eng", "de": "deu", "es": "spa"}

# The spacebar neighbours TextPredictionEngine.trySplitWithSignal reads
# (azertySpacebarNeighbors / qwertySpacebarNeighbors), minus ",": the comma key
# commits the word before it (#872, AutocorrectTrigger.commitsWord) and
# wordAtCursor splits on it, so "pas,mal" never reaches spellCheck as one word.
NEIGHBOURS = {"fr": ["n", "b"], "en": ["n", "b", "m"], "de": ["n", "b", "m"], "es": ["n", "b", "m"]}

# Cases per category and language. French is the keyboard's main language.
COUNTS = {
    "fr": {"missed-space": 150, "neighbour-key": 75, "legit-compound": 50, "legit-rare": 50},
    "en": {"missed-space": 50, "neighbour-key": 25, "legit-compound": 20, "legit-rare": 20},
    "de": {"missed-space": 50, "neighbour-key": 25, "legit-compound": 20, "legit-rare": 20},
    "es": {"missed-space": 50, "neighbour-key": 25, "legit-compound": 20, "legit-rare": 20},
}

# Typed on the Dictus keyboard in the simulator (spacebar research,
# logs/dictus-split-pass-samples.csv). "expected" is what the typist meant.
OBSERVED = [
    ("pasmal", "pas mal"),
    ("jesuis", "je suis"),
    ("bonjourmonsieur", "bonjour monsieur"),
    ("cavient", "ça vient"),
    ("motsuivant", "mot suivant"),
    ("jepense", "je pense"),
    ("pasnmal", "pas mal"),
    ("surtoutdune", "surtout d'une"),
]

SEED = 499
# A word: letters only. No apostrophe, hyphen or digit: a glue across "l'" or
# "peut-être" is not a missed space.
WORD = re.compile(r"^[^\W\d_]+$")
# Punctuation that can sit against a word; a pair across it is not adjacent text.
EDGE = "«»\"“”‘’()[]…"


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def sentences(path):
    """(id, text) in file order."""
    with bz2.open(path, "rt", encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) == 3:
                yield parts[0], parts[2]


def scan(path):
    """Adjacent lowercase word pairs (with sentence id), and mid-sentence word counts."""
    pairs = []
    lower = {}
    capital = {}
    first_seen = {}
    for sid, text in sentences(path):
        prev = None  # previous token, when nothing separates it from this one
        for i, tok in enumerate(text.split()):
            clean = tok.strip(EDGE).rstrip(".,;:!?").lstrip("¡¿")
            if i > 0 and WORD.match(clean) and clean != clean.lower():
                key = clean.lower()
                capital[key] = capital.get(key, 0) + 1
            # Mid-sentence lowercase words only: a capital means a sentence start
            # or a name, neither of which is the case under study.
            is_word = bool(WORD.match(clean)) and clean == clean.lower() and i > 0
            if is_word:
                lower[clean] = lower.get(clean, 0) + 1
                first_seen.setdefault(clean, sid)
                if prev is not None and tok.startswith(clean):
                    pairs.append((prev, clean, sid))
            prev = clean if is_word and tok == clean else None
    return pairs, lower, capital, first_seen


def pick_pairs(pairs, n, rng, taken, freq, make_typed):
    """Draws pairs weighted by occurrence, one case per distinct typed string."""
    out = []
    order = list(range(len(pairs)))
    rng.shuffle(order)
    for idx in order:
        left, right, sid = pairs[idx]
        typed = make_typed(left, right, len(out))
        if typed in taken or typed in freq or (left + right) in freq:
            continue  # duplicate, or the glue is itself a word ("parfois")
        taken.add(typed)
        out.append((typed, f"{left} {right}", f"tatoeba:{sid}"))
        if len(out) == n:
            break
    return out


def compounds(freq_ranked, n, rng, taken):
    """Long frequency-list words that are two frequency-list words end to end."""
    top = set(freq_ranked[:20000])
    candidates = []
    for w in freq_ranked[:40000]:
        if len(w) < 7 or not WORD.match(w) or w != w.lower() or w in taken:
            continue
        for k in range(3, len(w) - 2):
            if w[:k] in top and w[k:] in top:
                candidates.append(w)
                break
    rng.shuffle(candidates)
    out = []
    for w in candidates[:n]:
        taken.add(w)
        out.append((w, w, "frequency"))
    return out


def rare(lower, capital, first_seen, freq, n, rng, taken):
    """Real long words the keyboard's word list does not have.

    Seen lowercase mid-sentence at least five times, and capitalised there at most
    a quarter as often, which keeps typos and names (bands, places) out.
    """
    candidates = sorted(
        w for w, c in lower.items()
        if c >= 5 and capital.get(w, 0) * 4 <= c
        and len(w) >= 8 and w not in freq and w not in taken
    )
    rng.shuffle(candidates)
    out = []
    for w in candidates[:n]:
        taken.add(w)
        out.append((w, w, f"tatoeba:{first_seen[w]}"))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tatoeba", required=True)
    ap.add_argument("--resources", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    rows = []
    header = [
        "# Glued-word corpus for the split-pass bench (#499). Built by tools/split-pass-bench/make_corpus.py.",
        "# Tatoeba sentences (https://tatoeba.org), CC BY 2.0 FR. Exports downloaded 2026-10-31, sha256:",
    ]
    for lang, code in LANGS.items():
        path = os.path.join(args.tatoeba, f"{code}_sentences.tsv.bz2")
        header.append(f"#   {code}_sentences.tsv.bz2 {sha256(path)}")
        with open(os.path.join(args.resources, f"{lang}_frequency.json"), encoding="utf-8") as f:
            freq_counts = json.load(f)
        freq = set(freq_counts)
        freq_ranked = [w for w, _ in sorted(freq_counts.items(), key=lambda kv: -kv[1])]
        pairs, lower, capital, first_seen = scan(path)
        rng = random.Random(f"{SEED}-{lang}")
        # Observed glues stay in their own category only.
        taken = {t for t, _ in OBSERVED} if lang == "fr" else set()
        counts = COUNTS[lang]
        neighbours = NEIGHBOURS[lang]

        cases = {
            "missed-space": pick_pairs(
                pairs, counts["missed-space"], rng, taken, freq, lambda l, r, i: l + r
            ),
            "neighbour-key": pick_pairs(
                pairs, counts["neighbour-key"], rng, taken, freq,
                lambda l, r, i: l + neighbours[i % len(neighbours)] + r
            ),
            "legit-compound": compounds(freq_ranked, counts["legit-compound"], rng, taken),
            "legit-rare": rare(lower, capital, first_seen, freq, counts["legit-rare"], rng, taken),
        }
        if lang == "fr":
            cases["observed"] = [(t, e, "research:spacebar-2026-10-31") for t, e in OBSERVED]
        for cat in ("observed", "missed-space", "neighbour-key", "legit-compound", "legit-rare"):
            for i, (typed, expected, source) in enumerate(cases.get(cat, []), 1):
                rows.append((f"{lang}-{cat}-{i:03d}", lang, cat, typed, expected, source))

    header.append("# Columns: id, lang, category, typed (what reached the space bar), expected, source.")
    with open(args.out, "w", encoding="utf-8") as f:
        f.write("\n".join(header) + "\n")
        f.write("id\tlang\tcategory\ttyped\texpected\tsource\n")
        for row in rows:
            f.write("\t".join(row) + "\n")
    print(f"{len(rows)} cases -> {args.out}")


if __name__ == "__main__":
    main()
