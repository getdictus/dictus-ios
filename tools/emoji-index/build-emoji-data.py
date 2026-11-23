#!/usr/bin/env python3
"""Builds the emoji panel's index files from Unicode's data and Hex's chat words.

Ported from Hex (github.com/anomalyco/hex, ios/scripts/build-emoji-data.py, branch dev,
MIT, Copyright (c) 2026 Christopher Langton). Dictus's changes (#1027):
- French, which Hex has no index for; Norwegian, which Dictus has no layout for, is gone.
- Smileys and People are two categories, as Dictus's picker always had them.
- Folding also opens the ligatures oe and ae ("cœur" and "coeur" are one word); see fold().

Sources:
- emoji-test.txt 18.0 (Unicode License v3): the emoji, their order, groups, versions
  and skin tones
- CLDR 49 annotations and annotationsDerived (Unicode License v3): names and keywords
  in English, Spanish, German and French
- emoji-aliases-en.txt (Hex's own, MIT): chat words such as "congrats" and "bday"

    tools/emoji-index/build-emoji-data.py [--sources DIR] [--no-aliases] [--out DIR]

With --sources, reads emoji-test.txt, ann-<cldr>.xml and der-<cldr>.xml from DIR
instead of downloading them. Writes DictusCore/Sources/DictusCore/Emoji/EmojiIndex/emoji-index-<lang>.txt:
one file per keyboard layout, its language's words with English's beside them,
already folded, weighted and sorted, so the keyboard only reads it into flat buffers.

Folding (must match EmojiText.fold in Swift): the ligatures oe and ae opened, NFD, drop
combining marks, lowercase, curly apostrophes made straight.
"""

import argparse
import hashlib
import math
import pathlib
import re
import sys
import unicodedata
import urllib.request
import xml.etree.ElementTree as ET

EMOJI_TEST_URL = "https://www.unicode.org/Public/18.0.0/emoji/emoji-test.txt"
EMOJI_TEST_SHA256 = "8f3735cda1f92a779d78af67cf86066bb1f07143dc22f2ac29394d9bc57ab21a"
CLDR_TAG = "release-49"
CLDR_BASE = f"https://raw.githubusercontent.com/unicode-org/cldr/{CLDR_TAG}/common"
# Dictus's languages (SupportedLanguage), by their CLDR file.
LANGUAGES = {"en": "en", "es": "es", "de": "de", "fr": "fr"}
HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent

# The panel's categories, in the order its bar shows them.
CATEGORIES = {
    "Smileys & Emotion": 0,
    "People & Body": 1,
    "Animals & Nature": 2,
    "Food & Drink": 3,
    "Activities": 4,
    "Travel & Places": 5,
    "Objects": 6,
    "Symbols": 7,
    "Flags": 8,
}
TONES = [0x1F3FB, 0x1F3FC, 0x1F3FD, 0x1F3FE, 0x1F3FF]
LINE = re.compile(r"^([0-9A-F ]+?)\s*;\s*([\w-]+)\s*#\s*\S+\s+E(\d+\.\d+)\s+(.+)$")

# Words too common to say anything about an emoji, in the four languages. French's leaves
# out the words English names emoji with ("car", "son", "plus"): the list is shared.
# The keyboard reads this list from the index, so it lives only here.
STOPWORDS = """
a an the i im me my mine you your youre we our us it its is are was were be been being am
to of in on at for with and or but so just this that these those have has had do does did
will would can could should shall not all some any about from by up out if then than too
very really get got he she they them his her their what when where how who why there here
now again into onto over as also still let lets gonna wanna dont cant ll ve re much more
most one ones other off such only own same both each few s t d m
le la les un une des du au aux et ou mais donc ni je tu il elle nous vous ils elles te mon
ma mes ton ta tes sa ses notre nos votre vos leur leurs ce cet cette ces qui que quoi ne pas tres
bien est sont suis etre avoir ai avons avez ont fait pour par sur dans avec sans sous qu
el la los las un una y o que de del en es por con para lo se su al mi tu yo muy ya
der die das und ist ich nicht ein eine zu mit sich auf fur dem den im es wir ihr sie aber auch so
""".split()
STOP = set(STOPWORDS)


# NFD leaves ligatures whole: "cœur" would never meet "coeur", which is how French is
# typed on a keyboard without the ligature.
LIGATURES = str.maketrans({"œ": "oe", "Œ": "OE", "æ": "ae", "Æ": "AE"})


def fold(text):
    text = unicodedata.normalize("NFD", text.replace("’", "'").translate(LIGATURES))
    return "".join(c for c in text if not unicodedata.combining(c)).lower()


def words(text):
    """Folded words: letters and digits, an apostrophe's tail dropped ("that's" -> "that")."""
    out = []
    for part in re.split(r"[^\w']+|_", fold(text)):
        head = part.split("'", 1)[0]
        if head:
            out.append(head)
    return out


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def read_sources(folder):
    if folder:
        test = (folder / "emoji-test.txt").read_bytes()
        ann = {lang: (folder / f"ann-{cldr}.xml").read_bytes() for lang, cldr in LANGUAGES.items()}
        der = {lang: (folder / f"der-{cldr}.xml").read_bytes() for lang, cldr in LANGUAGES.items()}
    else:
        test = fetch(EMOJI_TEST_URL)
        ann = {lang: fetch(f"{CLDR_BASE}/annotations/{cldr}.xml") for lang, cldr in LANGUAGES.items()}
        der = {lang: fetch(f"{CLDR_BASE}/annotationsDerived/{cldr}.xml") for lang, cldr in LANGUAGES.items()}
    digest = hashlib.sha256(test).hexdigest()
    if digest != EMOJI_TEST_SHA256:
        sys.exit(f"emoji-test.txt changed: {digest}")
    return test.decode("utf-8"), ann, der


def parse_emoji(text):
    """Fully-qualified emoji in file order, skin tone variants folded into their base."""
    group = ""
    bases = []  # [codepoints, group, version, name, tones]
    by_key = {}
    variants = []
    for raw in text.splitlines():
        if raw.startswith("# group:"):
            group = raw.split(":", 1)[1].strip()
            continue
        match = LINE.match(raw)
        if not match or match.group(2) != "fully-qualified" or group == "Component":
            continue
        points = tuple(int(p, 16) for p in match.group(1).split())
        tones = [p for p in points if p in TONES]
        if tones:
            variants.append((points, tones))
            continue
        key = tuple(p for p in points if p != 0xFE0F)
        by_key[key] = len(bases)
        bases.append([points, group, match.group(3), match.group(4), [None] * 5])
    for points, tones in variants:
        # One tone for everyone in it: the picker offers five.
        if len(set(tones)) != 1:
            continue
        key = tuple(p for p in points if p not in TONES and p != 0xFE0F)
        index = by_key.get(key)
        if index is None:
            continue
        slot = TONES.index(tones[0])
        if bases[index][4][slot] is None:
            bases[index][4][slot] = points
    return bases


def to_string(points):
    return "".join(chr(p) for p in points)


def annotations(*sources):
    """CLDR names and keywords by emoji (FE0F removed); the first source wins."""
    names = {}
    keywords = {}
    for source in sources:
        root = ET.fromstring(source)
        for node in root.iter("annotation"):
            emoji = node.get("cp", "").replace("️", "")
            text = (node.text or "").strip()
            if not emoji or not text:
                continue
            if node.get("type") == "tts":
                names.setdefault(emoji, text)
            else:
                keywords.setdefault(emoji, [k.strip() for k in text.split("|") if k.strip()])
    return {e: (names.get(e, ""), keywords.get(e, [])) for e in set(names) | set(keywords)}


def family(name):
    """'man running', 'woman running' and 'person running facing right' are one family."""
    name = name.split(":", 1)[0]
    if name.endswith(" facing right"):
        name = name[: -len(" facing right")]
    for prefix in ("man ", "woman ", "person ", "men ", "women ", "people "):
        if name.startswith(prefix):
            return name[len(prefix):]
    return name


class Index:
    def __init__(self, count):
        self.words = {}  # key -> {entry: weight}
        self.phrases = {}
        self.alias_keys = set()
        self.search_names = [[] for _ in range(count)]
        self.search_keywords = [[] for _ in range(count)]

    def _add(self, table, key, entry, weight):
        hits = table.setdefault(key, {})
        hits[entry] = max(hits.get(entry, 0), weight)

    def name(self, text, entry, scale):
        parts = words(text)
        for part in parts:
            if part not in self.search_names[entry]:
                self.search_names[entry].append(part)
        content = [p for p in parts if p not in STOP and len(p) >= 2]
        # A one-word name ("pizza") is the strongest match there is.
        weight = 1.0 if len(content) <= 1 else 0.75
        for part in content:
            self._add(self.words, part, entry, weight * scale)
        if 1 < len(parts) <= 4:
            self._add(self.phrases, " ".join(parts), entry, 0.95 * scale)

    def keyword(self, text, entry, scale):
        parts = words(text)
        for part in parts:
            if part not in self.search_keywords[entry] and part not in self.search_names[entry]:
                self.search_keywords[entry].append(part)
        content = [p for p in parts if p not in STOP and len(p) >= 2]
        if len(parts) > 1:
            if len(parts) <= 4:
                self._add(self.phrases, " ".join(parts), entry, 0.85 * scale)
            for part in content:
                self._add(self.words, part, entry, 0.3 * scale)
        else:
            for part in content:
                self._add(self.words, part, entry, 0.6 * scale)

    def alias(self, text, entries):
        """Hex's chat words: the first emoji listed is the best answer."""
        parts = words(text)
        if not parts:
            return
        key = " ".join(parts)
        self.alias_keys.add(key)
        table = self.words if len(parts) == 1 else self.phrases
        for rank, entry in enumerate(entries):
            self._add(table, key, entry, max(0.9, 1.2 - 0.1 * rank))

    def finish(self, table):
        """A word that names many emoji ("face", "hand") says little about any one of them."""
        out = []
        for key in sorted(table):
            hits = table[key]
            factor = 1.0
            if key not in self.alias_keys:
                factor = 1 / (1 + 0.5 * math.log2(max(1.0, len(hits) / 2)))
            ranked = sorted(hits.items(), key=lambda item: (-item[1] * factor, item[0]))
            out.append((key, [(entry, weight * factor) for entry, weight in ranked]))
        return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", type=pathlib.Path)
    parser.add_argument("--no-aliases", action="store_true", help="CLDR words only, for measuring")
    parser.add_argument("--out", type=pathlib.Path, default=REPO / "DictusCore" / "Sources" / "DictusCore" / "Emoji" / "EmojiIndex")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    test, ann, der = read_sources(args.sources)
    bases = parse_emoji(test)
    ordered = [b for _, b in sorted(enumerate(bases), key=lambda item: (CATEGORIES[item[1][1]], item[0]))]
    position = {to_string(b[0]): i for i, b in enumerate(ordered)}
    tables = {lang: annotations(ann[lang], der[lang]) for lang in LANGUAGES}
    aliases = []
    if not args.no_aliases:
        for raw in (HERE / "emoji-aliases-en.txt").read_text(encoding="utf-8").splitlines():
            if raw and not raw.startswith("#"):
                word, targets = raw.split("\t")
                aliases.append((word, [position[e] for e in targets.split(" ") if e in position]))

    families = {}
    for lang in LANGUAGES:
        langs = [lang] if lang == "en" else [lang, "en"]
        index = Index(len(ordered))
        english_names = []
        for i, (points, _, _, test_name, _) in enumerate(ordered):
            emoji = to_string(points)
            for rank, source in enumerate(langs):
                # English beside another layout counts a little less than the layout's own words.
                scale = 1.0 if rank == 0 else 0.85
                name, keywords = tables[source].get(emoji.replace("️", ""), ("", []))
                if source == "en":
                    english_names.append(name or test_name)
                    name = name or test_name
                # A flag's name ("flag: Japan") also gives its place as a keyword.
                if ":" in name and "\U0001F1E6" <= emoji[0] <= "\U0001F1FF":
                    keywords = keywords + [name.split(":", 1)[1].strip()]
                index.name(name, i, scale)
                for keyword in keywords:
                    index.keyword(keyword, i, scale)
        if langs[-1] == "en":
            for word, entries in aliases:
                index.alias(word, entries)

        lines = [
            "# Generated by tools/emoji-index/build-emoji-data.py (ported from Hex, MIT); do not edit.\n",
            "# Unicode emoji-test.txt 18.0 and CLDR 49 (Unicode License v3, LICENSE-Unicode.txt),\n",
            "# and Hex's own chat words (tools/emoji-index/emoji-aliases-en.txt).\n",
            "# S stopwords; E emoji, category, version, skin tones, family, name, search words\n",
            "# (name's | keywords'); W word, entry:weight...; P phrase, entry:weight...\n",
            "S\t" + " ".join(STOPWORDS) + "\n",
        ]
        for i, (points, group, version, _, tones) in enumerate(ordered):
            name = english_names[i]
            family_id = families.setdefault(family(name), len(families))
            toned = " ".join(to_string(t) for t in tones) if all(tones) else ""
            search = " ".join(index.search_names[i]) + "|" + " ".join(index.search_keywords[i])
            lines.append(f"E\t{to_string(points)}\t{CATEGORIES[group]}\t{version}\t{toned}\t{family_id}\t{name}\t{search}\n")
        for tag, table in (("W", index.words), ("P", index.phrases)):
            for key, hits in index.finish(table):
                postings = ",".join(f"{entry}:{weight:.3f}" for entry, weight in hits)
                lines.append(f"{tag}\t{key}\t{postings}\n")
        path = args.out / f"emoji-index-{lang}.txt"
        path.write_text("".join(lines), encoding="utf-8")
        print(f"{path.name}: {len(ordered)} emoji, {len(index.words)} words, {len(index.phrases)} phrases, {path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
