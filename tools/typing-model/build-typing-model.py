#!/usr/bin/env python3
"""Builds a spatial decoder model (DictusKeyboard/Resources/<lang>.hextm) from Google
Books Ngram v3 (2020-02-17, CC BY 3.0) word and word-pair counts, keeping only words a
word list knows: SCOWL (sizes up to 70) for English, RLA-ES (LibreOffice's es_ES and
es_MX Hunspell dictionaries, used under their MPL 1.1 option) for Spanish, and
Grammalecte's "Classique" French Hunspell dictionary (LibreOffice's fr_FR, MPL 2.0) plus
the elided clitics ("l'", "j'", "qu'") for French, and Markus Enzenberger's German wordlist
(github.com/enz/german-wordlist, CC0 1.0, pinned commit) for German. Counts are summed over
1980-2019.

Adapted from Hex's `ios/scripts/build-typing-model.py` (github.com/anomalyco/hex, branch
dev, MIT, Copyright (c) 2026 Christopher Langton). Dictus adds French (#1011); the
format and the English and Spanish paths are Hex's, unchanged, so `en.hextm` here is
byte-identical to Hex's. German (#948) mirrors Hex's German recipe
(`android/benchmark/typing/build-layout-model.py`: shards "ger" 8 + 181, letters a-z ä ö
ü ß, 95,000 words) but keeps only the words of the CC0 list, where Hex keeps every
alphabetic token of the corpus, and gives ß the base s, since no Dictus layout has an ß key.

    python3 -m venv /tmp/venv && /tmp/venv/bin/pip install spylls   # Spanish and French
    /tmp/venv/bin/python tools/typing-model/build-typing-model.py fr <workdir> DictusKeyboard/Resources/fr.hextm

Needs about 7 GB free in <workdir> while it runs (English downloads ~240 GB of ngrams,
Spanish ~50 GB, French ~95 GB, German ~150 GB, each file deleted once counted) and a fast connection; every stage is
cached in <workdir>, so a rerun resumes. Deterministic for the same inputs.

Format v3 (little-endian), memory-mapped by SpatialDecoderModel.swift:
    "HXTM" u32 version=3, u32 words N, u32 pairs B, u32 blob bytes, u32 alphabet size A,
    char[4] language
    A x (u32 Unicode scalar, u8 code, u8 base code, u16 0)   codes 1..A by scalar; base is
        the unaccented letter's code (é -> e) or the letter's own
    u32[N+1] word offsets into the blob (words sorted by code bytes), u8[N] word cost,
    padding to 4, u32[N+1] first pair of each word, u32[B] second words (sorted within
    each first word), u8[B] pair cost, blob (one code byte per letter)
Costs are -ln(p) in eighths of a nat, clamped to 255: P(word), and P(second | first).
"""
import gzip, hashlib, math, multiprocessing, os, re, struct, subprocess, sys, tarfile, unicodedata, urllib.request

BASE = "https://storage.googleapis.com/books/ngrams/books/20200217"
FILES = {"en": ("eng", 24, 589), "es": ("spa", 3, 73), "fr": ("fre", 6, 115), "de": ("ger", 8, 181)}
SCOWL = "https://downloads.sourceforge.net/project/wordlist/SCOWL/2020.12.07/scowl-2020.12.07.tar.gz"
RLA_ES = "https://raw.githubusercontent.com/LibreOffice/dictionaries/master/es/"
RLA_ES_LOCALES = ("es_ES", "es_MX")
FR_FR = "https://raw.githubusercontent.com/LibreOffice/dictionaries/master/fr_FR/dictionaries/"
# Google Books keeps most elisions whole ("j'ai", "qu'il") and splits off "l'" and "d'"
# ("l'" + "homme"): those clitics are words of their own, which Hunspell does not list.
FR_ELISIONS = {"c'", "d'", "j'", "l'", "m'", "n'", "s'", "t'", "qu'", "jusqu'", "lorsqu'", "puisqu'", "quoiqu'"}
# German: Markus Enzenberger's list, CC0 1.0, at a pinned commit, checked by its SHA-256.
# It writes each word as German does ("Haus", "gehen"); the model is lowercase, so a word is
# kept when its lowercase form is any entry's lowercase form.
DE_LIST = ("https://raw.githubusercontent.com/enz/german-wordlist/"
           "1071d87d9535b57b80ec076c699f2578a28ee9dc/words",
           "20095928ca70974fb5d86e44f10181cee16e2831b0d4b1a4ddd12c261aebc5e9")
FIRST_YEAR = 1980
MAX_WORDS = {"en": 90_000, "es": 110_000, "fr": 110_000, "de": 95_000}
MAX_BYTES = 3_600_000      # the whole model
MIN_PAIR = 2_000           # pairs rarer than this (1980-2019) can't make the cut
LETTERS = {"en": "abcdefghijklmnopqrstuvwxyz'", "es": "abcdefghijklmnopqrstuvwxyzñáéíóúü",
           "fr": "abcdefghijklmnopqrstuvwxyzàâæçéèêëîïôœùûüÿ'", "de": "abcdefghijklmnopqrstuvwxyzäöüß"}
# A letter with no key of its own and no canonical decomposition, read on another key: ß has
# no key on any Dictus layout and is swiped through s ("straße" on s-t-r-a-s-e).
BASE_LETTER = {"ß": "s"}


def urls(lang, n):
    code, ones, twos = FILES[lang]
    count = ones if n == 1 else twos
    return [f"{BASE}/{code}/{n}-{i:05d}-of-{count:05d}.gz" for i in range(count)]


def fetch(url, path):
    if not os.path.exists(path):
        subprocess.run(["curl", "-sSfL", "--http1.1", "--retry", "8", "--retry-all-errors", "-o", path + ".part", url], check=True)
        os.replace(path + ".part", path)


def record_sha256(raw, out):
    """Writes `<out>.sha256` (sha256, size, shard name) before the shard is deleted, so the
    exact inputs of a model can be listed after the run (`cat <workdir>/*/*.sha256`)."""
    h = hashlib.sha256()
    with open(raw, "rb") as f:
        for block in iter(lambda: f.read(1 << 22), b""):
            h.update(block)
    with open(out + ".sha256", "w") as f:
        f.write(f"{h.hexdigest()}  {os.path.getsize(raw)}  {os.path.basename(raw)}\n")


def lines(path):
    proc = subprocess.Popen(["gzip", "-dc", path], stdout=subprocess.PIPE, bufsize=1 << 20)
    yield from proc.stdout
    proc.wait()


def years(fields):
    total = 0
    for f in fields:
        y, c, _ = f.split(b",")
        if int(y) >= FIRST_YEAR:
            total += int(c)
    return total


def lower(token):
    if token.isascii():
        return token.lower()
    return token.decode("utf-8", "replace").lower().encode("utf-8")


def count_unigrams(job):
    lang, url, work = job
    out = os.path.join(work, "uni", os.path.basename(url) + ".tsv")
    if os.path.exists(out):
        return out
    raw = os.path.join(work, "raw", os.path.basename(url))
    fetch(url, raw)
    word = re.compile(("^[" + LETTERS[lang] + "]+$").encode("utf-8"))
    counts = {}
    for line in lines(raw):
        parts = line.rstrip(b"\n").split(b"\t")
        w = lower(parts[0])
        if b"_" in w or not word.match(w):
            continue
        counts[w] = counts.get(w, 0) + years(parts[1:])
    with open(out + ".part", "wb") as f:
        for w, c in counts.items():
            if c:
                f.write(w + b"\t" + str(c).encode() + b"\n")
    record_sha256(raw, out)
    os.replace(out + ".part", out)
    os.remove(raw)
    return out


VOCAB = set()


def load_vocab(path):
    global VOCAB
    VOCAB = {line.split("\t", 1)[0].encode("utf-8") for line in open(path, encoding="utf-8")}


def count_pairs(job):
    lang, url, work = job
    out = os.path.join(work, "bi", os.path.basename(url) + ".tsv")
    if os.path.exists(out):
        return out
    raw = os.path.join(work, "raw", os.path.basename(url))
    fetch(url, raw)
    vocab = VOCAB
    counts = {}
    for line in lines(raw):
        tab = line.find(b"\t")
        ngram = line[:tab]
        space = ngram.find(b" ")
        a, b = lower(ngram[:space]), lower(ngram[space + 1:])
        if a in vocab and b in vocab:
            key = a + b" " + b
            counts[key] = counts.get(key, 0) + years(line[tab + 1:].rstrip(b"\n").split(b"\t"))
    with open(out + ".part", "wb") as f:
        for k, c in counts.items():
            if c >= MIN_PAIR // 4:
                f.write(k + b"\t" + str(c).encode() + b"\n")
    record_sha256(raw, out)
    os.replace(out + ".part", out)
    os.remove(raw)
    return out


def word_list(lang, work):
    """The words the word list accepts, as a predicate on lowercase strings."""
    if lang == "en":
        path = os.path.join(work, "scowl.tar.gz")
        fetch(SCOWL, path)
        words = set()
        with tarfile.open(path) as t:
            for m in t.getmembers():
                name = os.path.basename(m.name)
                kind, _, size = name.rpartition(".")
                if kind in ("english-words", "american-words", "british-words", "english-contractions") \
                        and size.isdigit() and int(size) <= 70:
                    for w in t.extractfile(m).read().decode("latin-1").split():
                        if w == w.lower():
                            words.add(w)
        return words.__contains__
    if lang == "de":
        url, sha256 = DE_LIST
        path = os.path.join(work, "german-wordlist.txt")
        fetch(url, path)
        data = open(path, "rb").read()
        if hashlib.sha256(data).hexdigest() != sha256:
            sys.exit(f"{path}: SHA-256 is not {sha256}")
        words = {w.lower() for w in data.decode("utf-8").split()}
        return words.__contains__
    from spylls.hunspell import Dictionary
    if lang == "fr":
        for ext in ("dic", "aff"):
            fetch(f"{FR_FR}fr.{ext}", os.path.join(work, f"fr.{ext}"))
        french = Dictionary.from_files(os.path.join(work, "fr"))
        return lambda w: w in FR_ELISIONS or (not w.endswith("'") and french.lookup(w))
    dictionaries = []
    for locale in RLA_ES_LOCALES:
        for ext in ("dic", "aff"):
            fetch(f"{RLA_ES}{locale}.{ext}", os.path.join(work, f"{locale}.{ext}"))
        dictionaries.append(Dictionary.from_files(os.path.join(work, locale)))
    return lambda w: any(d.lookup(w) for d in dictionaries)


def check_words(args):
    lang, work, words = args
    accept = word_list(lang, work)
    return [w for w in words if accept(w)]


def cost(p):
    return max(0, min(255, round(-math.log(max(p, 1e-30)) * 8)))


def main(lang, work, out_path):
    for d in ("raw", "uni", "bi"):
        os.makedirs(os.path.join(work, d), exist_ok=True)
    workers = int(os.environ.get("WORKERS", "12"))
    with multiprocessing.Pool(workers) as pool:
        uni_files = pool.map(count_unigrams, [(lang, u, work) for u in urls(lang, 1)])
    counts = {}
    for p in uni_files:
        for line in open(p, "rb"):
            w, c = line.rstrip(b"\n").split(b"\t")
            counts[w] = counts.get(w, 0) + int(c)
    total = sum(counts.values())
    vocab_path = os.path.join(work, "vocab.tsv")
    if not os.path.exists(vocab_path):
        ranked = sorted(counts, key=lambda w: (-counts[w], w))[: MAX_WORDS[lang] * 4]
        texts = [w.decode("utf-8") for w in ranked]
        word_list(lang, work)  # downloads the list once, before the workers read it
        chunks = [texts[i::workers] for i in range(workers)]
        with multiprocessing.Pool(workers) as pool:
            ok = set().union(*map(set, pool.map(check_words, [(lang, work, c) for c in chunks])))
        kept = [w for w in texts if w in ok][: MAX_WORDS[lang]]
        with open(vocab_path, "w", encoding="utf-8") as f:
            for w in kept:
                f.write(f"{w}\t{counts[w.encode('utf-8')]}\n")
    vocab = {}
    for line in open(vocab_path, encoding="utf-8"):
        w, c = line.rstrip("\n").split("\t")
        vocab[w] = int(c)

    with multiprocessing.Pool(workers, initializer=load_vocab, initargs=(vocab_path,)) as pool:
        bi_files = pool.map(count_pairs, [(lang, u, work) for u in urls(lang, 2)])
    pairs = {}
    for p in bi_files:
        for line in open(p, "rb"):
            k, c = line.rstrip(b"\n").split(b"\t")
            pairs[k] = pairs.get(k, 0) + int(c)
    write_model(lang, vocab, total, pairs, out_path)


def write_model(lang, vocab, total, pairs, out_path):
    scalars = sorted({c for w in vocab for c in w})
    code = {c: i + 1 for i, c in enumerate(scalars)}
    def base(c):
        b = BASE_LETTER.get(c) or unicodedata.normalize("NFD", c)[0]
        return code.get(b, code[c])
    enc = {w: bytes(code[c] for c in w) for w in vocab}
    words = sorted(vocab, key=lambda w: enc[w])
    index = {w: i for i, w in enumerate(words)}
    blob = b"".join(enc[w] for w in words)
    fixed = 28 + 8 * len(scalars) + 4 * (len(words) + 1) + len(words) + 3 + 4 * (len(words) + 1) + len(blob)
    budget = (MAX_BYTES - fixed) // 5

    # Keep the pairs that tell the most over the single-word model (backoff 0.4):
    # count x log(P(b | a) / (0.4 P(b))), positive only, best first, as many as fit.
    scored = []
    for k, c in pairs.items():
        if c < MIN_PAIR:
            continue
        a, b = k.decode("utf-8").split(" ")
        p = c / vocab[a]
        gain = c * math.log(p / (0.4 * vocab[b] / total))
        if gain > 0:
            scored.append((gain, index[a], index[b], min(p, 1.0)))
    scored.sort(reverse=True)
    kept = sorted((a, b, p) for _, a, b, p in scored[:budget])
    rows = [0] * (len(words) + 1)
    for a, _, _ in kept:
        rows[a + 1] += 1
    for i in range(len(words)):
        rows[i + 1] += rows[i]

    offsets, at = [], 0
    for w in words:
        offsets.append(at)
        at += len(enc[w])
    offsets.append(at)
    out = bytearray(b"HXTM")
    out += struct.pack("<IIIII", 3, len(words), len(kept), len(blob), len(scalars))
    out += lang.encode("ascii").ljust(4, b"\0")
    for c in scalars:
        out += struct.pack("<IBBH", ord(c), code[c], base(c), 0)
    out += struct.pack(f"<{len(offsets)}I", *offsets)
    out += bytes(cost(vocab[w] / total) for w in words)
    out += b"\0" * (-len(out) % 4)
    out += struct.pack(f"<{len(rows)}I", *rows)
    out += struct.pack(f"<{len(kept)}I", *(b for _, b, _ in kept))
    out += bytes(cost(p) for _, _, p in kept)
    out += blob
    with open(out_path, "wb") as f:
        f.write(out)
    print(f"{out_path}: {lang}, {len(words)} words, {len(kept)} pairs of {len(scored)} useful, "
          f"{len(scalars)} letters, {len(out) / 1e6:.2f} MB")


if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[1] not in FILES:
        sys.exit(__doc__)
    main(*sys.argv[1:])
