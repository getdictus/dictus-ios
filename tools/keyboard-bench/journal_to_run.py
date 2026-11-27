#!/usr/bin/env python3
"""Turns a typing journal (#1001) into a touch run the bench replays (#954).

The journal is in the debug log a Debug build of Dictus exports (Settings, Export logs,
or Debug Logs, Copy) while "Autocorrect debug logs" is on. Its `TJ TAP` lines hold the
key each tap resolved to and where the finger landed from that key's centre, in key
units: the unit of the bench's run files. Replayed, each tap lands on the same point of
the same key, so the replay types what the keyboard typed on the device, and a PR's
replay shows what the PR changes in that session.

Usage:
    python3 -I tools/keyboard-bench/journal_to_run.py <exported log> <out dir> [--intended <tsv>] [--name <name>]
    tools/keyboard-bench/run.sh --udid <udid> --langs fr-journal \\
        --corpus <out dir>/corpus --runs <out dir>/runs > report.md

Writes, for each language the session typed in, `runs/<lang>-journal.tsv` and
`corpus/<lang>-journal.txt`. A sentence is what was typed in one field, up to a return.
Its corpus line is the words the keyboard committed on the device, so the report's
"Final text" and autocorrect sections compare the replay with the device.

What a replay cannot type is left out and counted: taps on the symbols page (from a
`123` tap to the next `123` or space), held-backspace repeats, and words tapped in the
suggestion bar. A sentence with any of these will not replay the device's text.

--intended (#1011) makes the corpus the words the typist meant instead of the ones the
device committed, so the report scores the keyboard against the typist and not against
itself. The file is a TSV, kept out of the repository with the journal: `typed`, `meant`
and, optionally, the words that must come before (`suis|est`). A committed word is
meant as the mapping says when its typed form is listed; otherwise it is meant as the
device committed it, unless the typist undid it or deleted into it afterwards, when what
they meant is unknown and the slot reads "-", which score.py leaves out. A sentence that
holds something a replay cannot type is left out the same way, every slot "-".
--name names the runs `<lang>-<name>` (default `journal`).

--session N (#1014) keeps the sentences of the Nth exported log only (a file holding several
exports starts each with a "Dictus Debug Log" line), so Adaptive touch can learn on one
device session and be scored on another.
"""
import os
import re
import sys
from collections import defaultdict

TAP = re.compile(r" TJ TAP k=(\S+) dx=(\S+) dy=(\S+) dt=(\S+) kb=(\S+)")
FIELD = re.compile(r" TJ FIELD kb=(\S+)")
WORD = re.compile(r' TJ WORD #(\d+) typed="((?:[^"\\]|\\.)*)" prev=(\S+) final="((?:[^"\\]|\\.)*)"')
REACT = re.compile(r" TJ REACT #(\d+) (deleted|undo)\b")
SESSION = "Dictus Debug Log"
BARTAP = re.compile(r' TJ BARTAP #\d+ slot=\d+ word="((?:[^"\\]|\\.)*)"')
REPEAT = " TJ REPEAT "

# Keys the replay's letter page has. Anything else is on another page or not a key.
REPLAYABLE_EXTRA = {"space", "backspace", "shift", "return", "accent"}


def unescape(word):
    return re.sub(r"\\(.)", r"\1", word)


class Sentence:
    def __init__(self, lang, session=0):
        self.lang = lang
        self.session = session
        self.taps = []  # (key, dx, dy, t_ms)
        self.words = []
        # One per word: (session, journal id, typed, previous, final), None for a bar tap.
        self.records = []
        self.unreplayable = 0
        self.elapsed = 0.0
        # A return ends the sentence, but the word it commits is logged after its tap.
        self.ended = False


def parse(lines):
    sentences = []
    current = None
    symbols = False
    skipped = defaultdict(int)
    session = 0
    # Words the typist undid or deleted into, by (session, journal id).
    reacted = set()

    def close():
        nonlocal current
        if current and current.taps:
            sentences.append(current)
        current = None

    for line in lines:
        if SESSION in line:
            session += 1
            continue
        if m := REACT.search(line):
            reacted.add((session, int(m.group(1))))
            continue
        if m := FIELD.search(line):
            close()
            symbols = False
            continue
        if m := TAP.search(line):
            key, dx, dy, dt, kb = m.groups()
            lang = kb.split("-")[0]
            if current is None or current.lang != lang or current.ended:
                close()
                current = Sentence(lang, session)
            current.elapsed += 0 if dt == "-" else float(dt)
            if key == "123":
                symbols = not symbols
                skipped["symbols page"] += 1
                current.unreplayable += 1
                continue
            if symbols:
                skipped["symbols page"] += 1
                current.unreplayable += 1
                if key == "space":
                    symbols = False
                continue
            if key == "return":
                current.ended = True
                continue
            if len(key) != 1 and key not in REPLAYABLE_EXTRA:
                skipped[f"key {key}"] += 1
                current.unreplayable += 1
                continue
            current.taps.append((key, float(dx), float(dy), current.elapsed))
            continue
        if current is None:
            continue
        if m := WORD.search(line):
            current.words.append(unescape(m.group(4)))
            prev = m.group(3)
            prev = unescape(prev[1:-1]) if prev.startswith('"') else None
            current.records.append((session, int(m.group(1)), unescape(m.group(2)), prev, unescape(m.group(4))))
        elif m := BARTAP.search(line):
            current.words.append(unescape(m.group(1)))
            current.records.append(None)
            skipped["bar taps"] += 1
            current.unreplayable += 1
        elif REPEAT in line:
            skipped["held-backspace repeats"] += 1
            current.unreplayable += 1
    close()
    for sentence in sentences:
        sentence.reacted = reacted
    return sentences, skipped


def read_intended(path):
    """typed (lowercase) -> list of (meant, set of required previous words or None)."""
    table = defaultdict(list)
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) < 2:
                raise SystemExit(f"{path}: bad row {line!r}")
            before = {w.lower() for w in fields[2].split("|")} if len(fields) > 2 and fields[2] else None
            table[fields[0].lower()].append((fields[1], before))
    return table


def intended_words(sentence, table):
    """The words the typist meant, one per committed word; "-" where unknown."""
    if sentence.unreplayable:
        return ["-"] * len(sentence.records)
    out = []
    for record in sentence.records:
        if record is None:
            out.append("-")
            continue
        session, ident, typed, prev, final = record
        meant = None
        for candidate, before in table.get(typed.lower(), []):
            if before is None or (prev or "").lower() in before:
                meant = candidate
                break
        if meant is None:
            meant = "-" if (session, ident) in sentence.reacted else final
        out.append(meant)
    return out


def corpus_line(sentence, table=None):
    # The bench indexes the line by the spaces typed, so it needs a word per space plus
    # the last one; a slot the device committed no word for reads "-".
    spaces = sum(1 for tap in sentence.taps if tap[0] == "space")
    committed = intended_words(sentence, table) if table is not None else sentence.words
    words = [w.lower() for w in committed] or ["-"]
    words += ["-"] * max(0, spaces + 1 - len(words))
    return " ".join(w.replace(" ", "_") or "-" for w in words)


def write(sentences, source, out_dir, table=None, suffix="journal"):
    by_lang = defaultdict(list)
    for sentence in sentences:
        by_lang[sentence.lang].append(sentence)
    os.makedirs(os.path.join(out_dir, "runs"), exist_ok=True)
    os.makedirs(os.path.join(out_dir, "corpus"), exist_ok=True)
    names = []
    for lang, group in sorted(by_lang.items()):
        name = f"{lang}-{suffix}"
        names.append(name)
        rows = [f"# generated by journal_to_run.py from {os.path.basename(source)}",
                "sentence\ttap\tkey\tdx\tdy\tt_ms"]
        for s, sentence in enumerate(group):
            start = sentence.taps[0][3]
            for i, (key, dx, dy, t) in enumerate(sentence.taps):
                rows.append(f"{s}\t{i}\t{key}\t{dx:.4f}\t{dy:.4f}\t{t - start:.0f}")
        with open(os.path.join(out_dir, "runs", f"{name}.tsv"), "w", encoding="utf-8") as f:
            f.write("\n".join(rows) + "\n")
        with open(os.path.join(out_dir, "corpus", f"{name}.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(corpus_line(sentence, table) for sentence in group) + "\n")
    return by_lang, names


def main():
    args = sys.argv[1:]
    options = {}
    while len(args) > 2 and args[-2] in ("--intended", "--name", "--session"):
        options[args[-2]] = args[-1]
        args = args[:-2]
    if len(args) != 2:
        sys.exit(__doc__)
    source, out_dir = args
    table = read_intended(options["--intended"]) if "--intended" in options else None
    with open(source, encoding="utf-8") as f:
        lines = f.read().splitlines()
    sentences, skipped = parse(lines)
    if "--session" in options:
        sentences = [s for s in sentences if s.session == int(options["--session"])]
    if not sentences:
        sys.exit(f"no TJ TAP line in {source}: was the journal on, in a Debug build?")
    by_lang, names = write(sentences, source, out_dir, table, options.get("--name", "journal"))
    for lang, group in sorted(by_lang.items()):
        taps = sum(len(s.taps) for s in group)
        partial = sum(1 for s in group if s.unreplayable)
        print(f"{lang}: {len(group)} sentences, {taps} taps; {partial} sentences hold something a replay cannot type")
    for what, n in sorted(skipped.items()):
        print(f"  left out: {n} {what}")
    print(f"replay: tools/keyboard-bench/run.sh --udid <udid> --langs {','.join(names)} "
          f"--corpus {out_dir}/corpus --runs {out_dir}/runs")


if __name__ == "__main__":
    main()
