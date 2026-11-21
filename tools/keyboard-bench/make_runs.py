#!/usr/bin/env python3
"""
make_runs.py -- Turn the corpus into replayable touch runs (#954).

A run is what a typist's thumbs would do for each sentence: one tap per key, aimed at
the key's centre and landing off it by a random offset. The offsets are drawn once,
with a fixed seed, and committed, so every replay of a run sees the same taps.

Offsets are stored in key units, not points: dx in widths of a one-unit letter key, dy
in row heights. The replayer turns them into points on whatever keyboard it replays
on, which is what lets the same run drive the Dictus keyboard and Apple's.

The typist types the way people type fast: lowercase, no accent typed ("tres" for
"très", "manana" for "mañana"), one space after every word, the last word included so
it gets committed. A letter that has its own key on the layout is typed: the German
QWERTZ page has ä, ö and ü. The German page has no ß key, so ß is typed "ss".

A typo run (`<lang>-typos`) types what `corpus/<lang>-typos.keys` holds, line for line,
instead of folding the intended sentence: the realistic mistakes of
docs/research/multilingual-autocorrect/. Its taps land on the key centre (no offset),
so the run measures what autocorrect does with the mistake alone.

`fr-pierre-device` (#996) is typed the same way, from `corpus/fr-pierre-device.keys`: the
words Pierre typed on his iPhone, each with the words before it. Its lines keep the
accents and apostrophes he typed, which the French letter page types with the key beside
`n` (`FrenchAdaptiveKey`): `é`, `à`, `ô`, `î`, `ù` are the vowel then that key, and an
apostrophe after a consonant is that key alone. An apostrophe after a vowel, which that
key would turn into an accent, comes from the symbols page (`sym:'`). A line may glue
two intended words (`pasqueil` for `parce qu'il`).

The touch model is an assumption, not a measurement: Gaussian offsets with the
standard deviations below, the same for every key. It is what a recorded device run
would replace (docs/keyboard-measurement.md, "Limits").

Usage:
    python3 -I tools/keyboard-bench/make_runs.py \
        --corpus tools/keyboard-bench/corpus --out tools/keyboard-bench/runs

--seed and --passes draw other runs of the same corpus, and --sigma-x / --sigma-y a
sloppier or neater typist (#949 replays such held-out runs).
A pass types every sentence once more; sentence numbers keep counting, so sentence s
of the run is line s modulo the corpus length. The defaults rewrite the committed runs.
"""

import argparse
import os
import random
import unicodedata

# The learned runs type the corpus that holds the learned words of <lang>-learned.words
# (#498). Each run seeds its own random stream, so adding one leaves the others unchanged.
LANGS = ["fr", "en", "fr-learned", "en-learned", "es", "de",
         "en-typos", "es-typos", "de-typos", "fr-pierre-device"]
SEED = 954
# Spread of the landing point around the key centre, in key units.
SIGMA_X = 0.22
SIGMA_Y = 0.18
# Thumbs land slightly below the centre of the key they aim at.
MEAN_Y = 0.05
# Time between two taps, in milliseconds: about 70 words a minute.
MEAN_INTERVAL_MS = 170
SIGMA_INTERVAL_MS = 40
MIN_INTERVAL_MS = 60


# Letters a language's letter page has a key for, typed as they are rather than folded.
OWN_KEYS = {"de": "äöü"}
# Letters with no key and no accent to drop, and what the typist types instead.
SUBSTITUTES = {"ß": "ss"}


def keys_for(sentence, lang="fr"):
    """The keys a fast typist presses for this sentence: letters without accents."""
    own = OWN_KEYS.get(lang, "")
    keys = []
    for word in sentence.split():
        for char in word:
            if char in own:
                keys.append(char)
                continue
            folded = unicodedata.normalize("NFD", SUBSTITUTES.get(char, char))
            keys.extend(c for c in folded if not unicodedata.combining(c))
        keys.append("space")
    return keys


# What the French adaptive key writes after each vowel (FrenchAdaptiveKey.defaults).
FRENCH_ACCENT_KEY = {"é": "e", "à": "a", "ô": "o", "î": "i", "ù": "u"}
VOWELS = "aeiouy"


def typed_keys(line, lang="en"):
    """A typed run's keys: every character of the line as written, one space per word.
    On the French page, an accented vowel or an apostrophe goes through the adaptive key."""
    keys = []
    for word in line.split():
        for i, char in enumerate(word):
            if lang != "fr":
                keys.append(char)
            elif char in FRENCH_ACCENT_KEY:
                keys.extend([FRENCH_ACCENT_KEY[char], "accent"])
            elif char == "'":
                after_vowel = i > 0 and word[i - 1] in VOWELS and word[max(0, i - 2):i] != "qu"
                keys.append("sym:'" if after_vowel else "accent")
            else:
                keys.append(char)
        keys.append("space")
    return keys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--corpus", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--seed", default=str(SEED))
    parser.add_argument("--passes", type=int, default=1)
    parser.add_argument("--langs", default=",".join(LANGS))
    parser.add_argument("--sigma-x", type=float, default=SIGMA_X)
    parser.add_argument("--sigma-y", type=float, default=SIGMA_Y)
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)

    for lang in args.langs.split(","):
        rng = random.Random(f"{args.seed}-{lang}")
        with open(os.path.join(args.corpus, f"{lang}.txt"), encoding="utf-8") as f:
            sentences = [line.strip() for line in f if line.strip()]
        typos = os.path.exists(os.path.join(args.corpus, f"{lang}.keys"))
        if typos:
            with open(os.path.join(args.corpus, f"{lang}.keys"), encoding="utf-8") as f:
                typed = [line.strip() for line in f if line.strip()]
            if len(typed) != len(sentences):
                raise SystemExit(f"{lang}.keys must have one line per sentence")
            if lang.endswith("-typos") and any(len(a.split()) != len(b.split()) for a, b in zip(typed, sentences)):
                raise SystemExit(f"{lang}.keys must have as many words per line as {lang}.txt")
        base = lang.split("-")[0]
        rows = []
        for index, sentence in enumerate(sentences * args.passes):
            t = 0
            keys = typed_keys(typed[index % len(typed)], base) if typos else keys_for(sentence, base)
            for tap, key in enumerate(keys):
                if tap > 0:
                    t += max(MIN_INTERVAL_MS, round(rng.gauss(MEAN_INTERVAL_MS, SIGMA_INTERVAL_MS)))
                dx = 0.0 if typos else rng.gauss(0, args.sigma_x)
                dy = 0.0 if typos else rng.gauss(MEAN_Y, args.sigma_y)
                rows.append(f"{index}\t{tap}\t{key}\t{dx:.4f}\t{dy:.4f}\t{t}")
        path = os.path.join(args.out, f"{lang}.tsv")
        with open(path, "w", encoding="utf-8") as f:
            f.write(f"# generated by make_runs.py: seed {args.seed}, sigma_x {args.sigma_x}, sigma_y {args.sigma_y}, "
                    f"mean_y {MEAN_Y}, interval {MEAN_INTERVAL_MS}+-{SIGMA_INTERVAL_MS} ms\n")
            f.write("sentence\ttap\tkey\tdx\tdy\tt_ms\n")
            f.write("\n".join(rows) + "\n")
        print(f"{path}: {len(sentences)} sentences, {len(rows)} taps")


if __name__ == "__main__":
    main()
