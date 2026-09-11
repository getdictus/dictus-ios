#!/usr/bin/env python3
"""Score a polish-harness `show` capture against #437's bars.

Usage:  python3 score.py <capture.txt> [<capture.txt> ...]

The bars are in ../bars.md and were committed before the first model call on a
candidate prompt. The predicates below are the machine-readable form of that
document; if the two ever disagree, bars.md is the one that was declared and
this file is the bug.

It reads the same `show --runs N` capture that gets committed as evidence, for
the reason #439's scorer does: `eval` reports one pass/fail per fixture on one
sample, and every bar here is a count over repeated calls.

The capture parser is #439's, unchanged apart from the module it lives in. It
already handles a polished block spanning several lines, which is the whole
point of this round.
"""

import re
import sys
from collections import defaultdict

# ── Bar 1 — breaks, per fixture ───────────────────────────────────────────────
# The table declared in the issue's comment of 2026-08-27 14:46. Fixture 2 is not
# named there and is reported without a threshold: its shape (an update with a
# figures section) makes a break defensible and its absence equally so.
BREAKS = {
    "1-free-form": (0, 0),
    "2-project-update": None,
    "3-message-draft": (1, None),
    "4-explanation": (1, None),
    "5-rambling": (1, None),
    "6-unscripted": (1, None),
}

# ── Bar 2 — no list syntax the speaker did not dictate ────────────────────────
# A leading ordinal or bullet on any line, which is the shape Typeless returns on
# four of these six and the one the contract refuses. None of the six raws
# dictates a list, so any hit is a violation.
LIST_MARKER = re.compile(r"^\s*(?:\d+\s*[.)]|[-*•‣▪])\s+", re.M)

# ── Bar 3 — content that must survive, verbatim ───────────────────────────────
# #439's KEEP list, carried over unchanged so the two rounds are comparable, plus
# the spans the 14:46 and 15:50 comments name by hand. Matched case-insensitively:
# a proper noun the model failed to capitalize is a rule-2 miss, not a deletion.
#
# `11h` and `14h` are deliberately NOT here. The model expanding them to `11
# heures` is a Preserve violation (ADR 0003 number formats) and #439 scores it
# under its register bar; counting it as a deletion too would double-count one
# defect and blunt the bar this round is judged on.
KEEP = {
    "1-free-form": ["bosser", "trucs", "coder", "produit tout seul"],
    "2-project-update": ["StoreKit", "Thomas", "Sarah", "fin octobre", "sandbox", "412"],
    "3-message-draft": ["dentiste", "t'arrange", "visio", "point d'équipe"],
    "4-explanation": ["en calcul", "trois étapes", "90", "millisecondes",
                      "ambiguïtés", "paragraphes"],
    "5-rambling": ["ça me reviendra", "Julien", "mardi", "février", "comptable",
                   "19 euros", "assurance", "entretien"],
    "6-unscripted": ["Dictus", "gros pavé", "c'est pas", "sixième", "listes"],
}

# ── Bar 4 — where fixture 4's boundary lands ─────────────────────────────────
# The 15:50 comment: the break should fall after `on découpe en paragraphes` and
# not inside the run-on that follows, because the words dropped in the baseline
# are the tail of the clause the model cuts in two. Reported per run.
BOUNDARY_AFTER = {"4-explanation": "paragraphes"}

# ── Bar 5 — the general word-loss form, and its declared allowances ──────────
# "No word present in the input is absent from the whitespace-stripped output."
# Taken as a SET over content words, so a stutter (`le comptable le comptable`)
# and a repeated filler (`en fait` twice, one kept) can never register: a word
# counts as lost only when every occurrence of it is gone.
#
# ADR 0003 authorises a handful of total removals and one class of substitution,
# and a scorer that ignored them would report a contract-abiding run as a failure.
# The allowance below is derived from the six `raw` fields and ADR 0003 alone,
# written before the first candidate call, and it is the complete list:
#
#   - rules 6 and 7, stutters and gratuitous fillers, total-removal vocabulary;
#   - rule 8, the six ASR-repair sources #439 lists (R1-R6) and the two shapes it
#     measured repairing reliably — fixture 3's off-language clause and fixture
#     6's mangled app names;
#   - rule 9, one-letter typos, for the two the raws carry.
#
# Anything outside it is reported as an unattributed loss. That number is the
# comparative half of this bar: the candidate has to come in at or under the
# baseline, per the brief's "beat the baseline rather than match it".
ALLOWED_LOSS = {
    # Rules 6 and 7, every fixture.
    None: {"euh", "hum", "bah", "heu", "ben"},
    # Rule 8 / R1, plus the off-language clause the prompt repairs 5/5.
    "3-message-draft": {"tante", "and", "i", "think", "that", "it", "will",
                        "pourrais"},
    # Rule 8 / R5.
    "4-explanation": {"ses", "essaye"},
    # Rule 8 / R2, R3, R4, and the rule-9 typo `machin` sits under Preserve, not here.
    "5-rambling": {"repete", "zappais", "honnete", "les"},
    # Rule 8 / R6.
    "2-project-update": {"apple"},
    # Rule 8 on the two app names the STT mangled, and the rule-9 typo `l,'idée`.
    "6-unscripted": {"type", "less", "laiss", "vs", "l"},
}

# Function words, folded, dropped before the share is taken. Same reasoning as
# `PolishGrounding.functionWords`: they are shared by every French sentence and
# would drown the signal. French only — these six fixtures are French.
FUNCTION_WORDS = set("""
le la les un une des du de d au aux et ou ni mais donc or car que qui quoi dont a en y
il elle ils elles on nous vous je tu me te se ce cet cette ces son sa ses leur leurs
mon ma mes ton ta tes notre nos votre vos pour par avec sans sur sous dans chez vers entre
pas ne plus tres bien tout tous toute toutes meme aussi comme si quand alors depuis apres
avant encore deja etre avoir fait faire est sont etait ete suis es sommes etes ont as ai
avons avez peut peux pouvoir doit dois devoir va vais aller ca cela c l j n s t m qu
""".split())

RATIO_MIN, RATIO_MAX = 0.92, 1.15


def fold(word):
    """Lowercase, strip diacritics, the way `PolishLexicon.fold` does."""
    import unicodedata
    stripped = unicodedata.normalize("NFD", word.lower())
    return "".join(c for c in stripped if unicodedata.category(c) != "Mn")


def content_words(text):
    words = re.findall(r"[^\W\d_]+", text, re.UNICODE)
    return {fold(w) for w in words} - FUNCTION_WORDS


def parse(path):
    """Yield (fixture_id, run_index, raw, polished) from a `show` capture."""
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
        # The route line closes the polished block, which spans lines exactly
        # when this round works.
        if buf is not None and re.match(r" {12}\(", line):
            yield fixture, run, raw, "\n".join(buf)
            buf = None
            continue
        if buf is not None:
            buf.append(line)


def score(path):
    runs = defaultdict(dict)
    raws = {}
    for fixture, run, raw, polished in parse(path):
        runs[run][fixture] = polished
        raws[fixture] = raw

    print(f"\n══ {path}")
    breaks_seen = defaultdict(list)
    violations_per_run = []
    unattributed_total = 0
    for run in sorted(runs):
        outputs = runs[run]
        violations = []
        for fixture, text in outputs.items():
            n = text.count("\n")
            breaks_seen[fixture].append(n)
            bounds = BREAKS.get(fixture)
            if bounds:
                low, high = bounds
                if n < low:
                    violations.append(f"breaks {n} < {low} [{fixture}]")
                if high is not None and n > high:
                    violations.append(f"breaks {n} > {high} [{fixture}]")
            if LIST_MARKER.search(text):
                violations.append(f"list syntax [{fixture}]")
            if "<<NL>>" in text:
                violations.append(f"<<NL>> leak [{fixture}]")
            ratio = len(text) / len(raws[fixture])
            if not RATIO_MIN <= ratio <= RATIO_MAX:
                violations.append(f"ratio {ratio:.2f} [{fixture}]")
            for needle in KEEP.get(fixture, []):
                if needle.lower() not in text.lower():
                    violations.append(f'deleted: "{needle}" [{fixture}]')
            lost = (content_words(raws[fixture]) - content_words(text)
                    - ALLOWED_LOSS[None] - ALLOWED_LOSS.get(fixture, set()))
            if lost:
                unattributed_total += len(lost)
                violations.append(f"lost {sorted(lost)} [{fixture}]")
            if fixture in BOUNDARY_AFTER and n:
                anchor = BOUNDARY_AFTER[fixture]
                landed = any(line.rstrip(" .!?:;» ").lower().endswith(anchor)
                             for line in text.split("\n")[:-1])
                if not landed:
                    violations.append(f"boundary not after '{anchor}' [{fixture}]")
        violations_per_run.append(violations)
        print(f"  run {run}: violations {len(violations)}")
        for v in violations:
            print(f"      – {v}")

    n = len(violations_per_run)
    if not n:
        return
    print(f"\n  ── runs with 0 violations: "
          f"{sum(1 for v in violations_per_run if not v)}/{n}")
    print("  ── line breaks per fixture, per run:")
    for fixture in sorted(breaks_seen):
        counts = breaks_seen[fixture]
        bar = BREAKS.get(fixture)
        want = "—" if bar is None else (f"{bar[0]}" if bar[1] == bar[0] else f"≥{bar[0]}")
        held = (bar is None
                or all(c >= bar[0] and (bar[1] is None or c <= bar[1]) for c in counts))
        print(f"     {fixture:<18} want {want:<3} got {counts} "
              f"{'OK' if held else 'FAIL'}")
    print(f"  ── unattributed word losses, all fixtures, all runs: {unattributed_total}")


for arg in sys.argv[1:]:
    score(arg)
