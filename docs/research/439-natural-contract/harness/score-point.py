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

# A terminal mark AT THE BOUNDARY the command word stood on — not anywhere in the
# output. The looser reading scores 10/10 on everything and means nothing, because
# the model ends every output with a period regardless. So each command fixture
# names the first words of its second clause, and the predicate asks whether a
# terminal mark precedes them, with at most the leftover `point` in between.
#
# C4 is excluded: its raw already carries the boundary mark, which bars.md §8
# declared. C5 is NOT excluded — its raw carries commas, not a terminal mark, so
# the question is live there. bars.md §8 lumps C4 and C5 together and is too broad
# on C5; the bar itself ("terminal mark present at the boundary") is what is scored.
SECOND_CLAUSE = {
    "C1-bare-boundary": "on se voit",
    "C2-bare-boundary": "il reste juste",
    "C3-bare-boundary": "on peut lancer",
    "C5-parakeet-punctuated": "je préviens",
}


def boundary_mark(fixture, polished):
    """True when a terminal mark closes the clause before `fixture`'s second clause."""
    opener = SECOND_CLAUSE.get(fixture)
    if opener is None:
        return None
    pattern = r"[.!?…][\s\"«]*(?:[Pp]oint\s*[,.;:]?\s*)?" + re.escape(opener)
    return re.search(pattern, polished, re.IGNORECASE) is not None


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
    command = defaultdict(
        lambda: {"word_removed": 0, "mark": 0, "mark_scored": 0, "scored": 0, "skipped": 0})

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
            mark = boundary_mark(fixture, polished)
            if mark is not None:
                c["mark_scored"] += 1
                c["mark"] += 1 if mark else 0

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
        mark = (f"boundary mark {c['mark']}/{c['mark_scored']}"
                if c["mark_scored"] else "boundary mark n/a (already in the raw)")
        print(f"      [{fixture}] word removed {c['word_removed']}/{n} · {mark}"
              + (f" · {c['skipped']} non-success" if c["skipped"] else ""))
    total = sum(c["scored"] for c in command.values())
    removed = sum(c["word_removed"] for c in command.values())
    marked = sum(c["mark"] for c in command.values())
    mark_total = sum(c["mark_scored"] for c in command.values())
    if total:
        print(f"      TOTAL  word removed {removed}/{total} · "
              f"boundary mark {marked}/{mark_total}")


for arg in sys.argv[1:]:
    score(arg)
