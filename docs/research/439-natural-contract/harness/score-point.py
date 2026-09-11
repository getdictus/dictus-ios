#!/usr/bin/env python3
"""Score a polish-harness `show` capture against #439 Part 2's bars.

Usage:  python3 score-point.py <capture.txt> [<capture.txt> ...]

The bars are in ../bars.md §6 and were committed before the first model call on
`point-fr.json`. The predicates below are the machine-readable form of that
document; if the two ever disagree, bars.md is the one that was declared and
this file is the bug.

Separate from `score.py` on purpose: that file's predicates name the six
longform-fr segments, and nothing here is about them. The question this scores
is narrower — does the bare `point` clause in Natural rule 4 reach an ordinary
French noun.
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

FIXTURES = {f["id"]: f for f in json.loads(
    (Path(__file__).parent / "point-fr.json").read_text(encoding="utf-8"))}

# `point`/`points` as a standalone word, case-insensitive. `points` is counted
# because rule 4 also teaches `deux points` → `:` and a plural noun sits in the
# same ambiguity.
WORD = re.compile(r"\bpoints?\b", re.IGNORECASE)

# A terminal mark where the command word stood. The command-class fixtures put
# the boundary in one known place, so "was a sentence boundary produced at all"
# is read off the output as a whole: the raw carries no terminal mark except in
# the two Parakeet-punctuated fixtures, which carry theirs already.
TERMINAL = re.compile(r"[.!?…]")


def parse(path):
    """Yield (fixture_id, run_index, raw, polished, outcome) from a capture."""
    fixture = raw = None
    run = 0
    buf = None
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        m = re.match(r"━━ \[([^\]]+)\]", line)
        if m:
            fixture, run = m.group(1), 0
            continue
        if line.startswith("  raw:"):
            raw = line.split(":", 1)[1].strip()
            continue
        m = re.match(r"  polished(?: #(\d+))?: (.*)$", line)
        if m:
            run = int(m.group(1) or 1)
            buf = [m.group(2)]
            continue
        # The route line closes the polished block and carries the outcome.
        m = re.match(r" {12}\((\w+),", line)
        if buf is not None and m:
            yield fixture, run, raw, "\n".join(buf), m.group(1)
            buf = None
            continue
        if buf is not None and not line.startswith("  engineOut"):
            buf.append(line)


def score(path):
    print(f"\n══ {path}")
    noun_losses, noun_scored, noun_skipped = [], 0, 0
    command = defaultdict(lambda: {"word_removed": 0, "mark": 0, "scored": 0, "skipped": 0})

    for fixture, run, raw, polished, outcome in parse(path):
        klass = fixture[0]
        # A non-success never reaches the user as engine text — the free polish
        # inserts the deterministic floor, which still carries `point`. Scoring it
        # would count a guardrail rejection as a clean run, so it is excluded from
        # the denominator and reported on its own line.
        if outcome != "success":
            if klass == "N":
                noun_skipped += 1
            else:
                command[fixture]["skipped"] += 1
            continue
        want = len(WORD.findall(raw))
        got = len(WORD.findall(polished))
        if klass == "N":
            noun_scored += 1
            if got < want:
                noun_losses.append((fixture, run, want, got, polished))
        else:
            c = command[fixture]
            c["scored"] += 1
            if got < want:
                c["word_removed"] += 1
            if TERMINAL.search(polished):
                c["mark"] += 1

    print(f"\n  ── BAR P1/P2 · noun class: {len(noun_losses)} losses in {noun_scored} "
          f"scored outputs ({noun_skipped} non-success excluded)")
    for fixture, run, want, got, polished in noun_losses:
        print(f"      – [{fixture}] run {run}: {want} → {got}")
        print(f"        {polished}")

    print(f"\n  ── BAR P3/P4 · command class")
    for fixture in sorted(command):
        c = command[fixture]
        n = c["scored"]
        if not n:
            print(f"      [{fixture}] no scored output ({c['skipped']} non-success)")
            continue
        print(f"      [{fixture}] word removed {c['word_removed']}/{n} · "
              f"terminal mark present {c['mark']}/{n}"
              + (f" · {c['skipped']} non-success" if c["skipped"] else ""))
    total = sum(c["scored"] for c in command.values())
    removed = sum(c["word_removed"] for c in command.values())
    marked = sum(c["mark"] for c in command.values())
    if total:
        print(f"      TOTAL  word removed {removed}/{total} · terminal mark {marked}/{total}")


for arg in sys.argv[1:]:
    score(arg)
