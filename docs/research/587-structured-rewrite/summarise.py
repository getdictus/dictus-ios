#!/usr/bin/env python3
"""Read the #587 captures against the bars declared in bars.md §4.

    python3 docs/research/587-structured-rewrite/summarise.py            # round 1 (C1)
    python3 docs/research/587-structured-rewrite/summarise.py round2     # round 2 (C2)
    python3 docs/research/587-structured-rewrite/summarise.py round3     # confirmation

Every number in findings.md that is not read straight off a `raw/` capture comes from
here. The harness already records, per run, the observables bars.md §4 defines
(`FidelityShape`): the expected language, the output's reading, the foreign sentences,
the list lines and the shipping incompleteness check. This script only counts them per
bar and prints, by text, everything a bar says must be read by hand.

Two screens here are greps rather than scorers, for the reason #570's summarise.py
gives: whether an output copied a prompt's own worked example is a property of this
prompt family, not of a polish output, so it has no business in a shipped type.
"""

import json
import re
import statistics
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIXTURES = HERE.parent.parent.parent / "DictusCore/Sources/polish-harness/fixtures"

CAPTURES = {
    "r1-device": ("capture-r1-device.json", "device-structured-fr.json"),
    "r1-longform": ("capture-r1-longform.json", "longform-fr.json"),
    "r2": ("capture-r2.json", "device-structured-0918-fr.json"),
    "r3": ("capture-r3.json", "device-structured-en.json"),
    "r4": ("capture-r4.json", "translated-structured.json"),
}

# bars.md §3: fixtures excluded from the prose bar. T6 in every language.
NOT_PROSE = {"4-explanation", "D1-three-steps", "D2-three-steps-drift", "5-rambling",
             "D9-suggestion-bar", "2-project-update", "F9-summary-and-stats"}
ENUMERATING = "2-project-update"

# Content that belongs to one arm's worked examples and to no fixture. A hit means the
# example was copied into the output (#414, #583 §9.1).
EXAMPLE_CONTENT = {
    "shipping": ["plombier", "chauffe-eau", "garage", "commande le bois", "plantes du hall",
                 "café", "hedge", "compost", "fence", "garden", "jardin"],
    "C1": ["vélo", "roue arrière", "frein", "magasin", "passport", "charger", "ferry",
           "hotel", "hôtel"],
    # C2 and the landed prompt show the same two examples in every language; the
    # screen is the French and English words, plus the one proper noun of the sets.
    "C2": ["vélo", "roue arrière", "frein", "magasin", "passport", "charger", "ferry",
           "hotel", "hôtel"],
    "C3": ["vélo", "roue arrière", "frein", "magasin", "passport", "charger", "ferry",
           "hotel", "hôtel"],
}

# A sentence about the speaker's memory, in any of the covered languages. A screen for
# the hand read B2a asks for, deliberately wider than the shipped check.
MEMORY = re.compile(r"souvien|souvenir|rappelle plus|échapp|oubli|mémoire|reviendra|remember|"
                    r"recall|forgot|memory|slips? my mind|escapes me|acuerdo|recuerdo|olvid|"
                    r"erinner|vergessen|entfallen|ricord|sfugg|dimentic|lembr|esquec",
                    re.IGNORECASE)


ROUND = sys.argv[1] if len(sys.argv) > 1 else ""
CANDIDATE = {"": "C1", "round2": "C2", "round3": "C3", "round4": "shipping"}.get(ROUND, "C1")
ARMS = ("shipping",) if CANDIDATE == "shipping" else ("shipping", CANDIDATE)


def load():
    runs = []
    for round_name, (capture, fixture_file) in CAPTURES.items():
        path = HERE / ROUND / capture
        if not path.exists():
            continue
        raws = {f["id"]: f["raw"] for f in json.loads((FIXTURES / fixture_file).read_text())}
        for record in json.loads(path.read_text()):
            record["round"] = round_name
            # The encoder omits a nil optional, so a run nothing refused has no key.
            record.setdefault("rejectedCheck", None)
            record["raw"] = raws[record["fixture"]]
            runs.append(record)
    return runs


def scored(r):
    return r.get("hasEngineOutput", True)


def base_id(fixture):
    return fixture.split(".")[0]


def is_prose(fixture):
    return base_id(fixture) not in NOT_PROSE and not base_id(fixture).startswith("T6")


def wrong_language(r):
    return r["outputLanguage"] != r["expectedLanguage"] or bool(r["foreignSentences"])


def section(title):
    print(f"\n\n════ {title}\n")


def b1(runs):
    section("B1 — output language, per language and arm (bars.md §4)")
    table = defaultdict(lambda: defaultdict(list))
    for r in runs:
        if scored(r):
            table[r["expectedLanguage"]][r["arm"]].append(r)
    print(f"{'lang':9}{'arm':10}{'outputs':9}{'refusedLang':13}{'%':7}{'wrongAccepted':15}{'wrongAny':9}")
    for language in sorted(table):
        for arm in ARMS:
            cell = table[language].get(arm, [])
            if not cell:
                continue
            refused = sum(r["rejectedCheck"] == "language" for r in cell)
            accepted_wrong = sum(r["outcome"] == "success" and wrong_language(r) for r in cell)
            any_wrong = sum(wrong_language(r) for r in cell)
            print(f"{language:9}{arm:10}{len(cell):<9}{refused:<13}{100 * refused / len(cell):<7.1f}"
                  f"{accepted_wrong:<15}{any_wrong:<9}")
    print("\nEvery flagged output, for the hand read (arm, fixture#run, outcome, reading, foreign sentences):")
    for r in runs:
        if scored(r) and wrong_language(r):
            print(f"  [{r['arm']}] {r['fixture']}#{r['run']} {r['outcome']}"
                  f"{'(' + r['rejectedCheck'] + ')' if r['rejectedCheck'] else ''} "
                  f"read={r['outputLanguage']} expected={r['expectedLanguage']}")
            for sentence in r["foreignSentences"]:
                print(f"      FOREIGN: {sentence}")
            if r["outputLanguage"] != r["expectedLanguage"]:
                print(f"      OUTPUT: {r['output'][:300]!r}")


def b2(runs):
    section("B2 — fabrication (bars.md §4)")
    for arm in ARMS:
        rows = [r for r in runs if r["arm"] == arm and scored(r)]
        accepted = [r for r in rows if r["outcome"] == "success"]
        check = [r for r in rows if r["incompletenessFabricated"]]
        axis4 = [r for r in rows if r["speakerState"] == "fabricated"]
        refused_check = [r for r in rows if r["rejectedCheck"] == "incompleteness"]
        print(f"{arm:9} outputs={len(rows)} accepted={len(accepted)} "
              f"checkFlags={len(check)} refusedByCheck={len(refused_check)} axis4Fabricated={len(axis4)} "
              f"acceptedWithCheckFlag={sum(r['incompletenessFabricated'] for r in accepted)}")
    print("\nB2a hand-read screen — ACCEPTED outputs with a memory word absent from the transcript:")
    for r in runs:
        if not scored(r) or r["outcome"] != "success":
            continue
        for sentence in re.split(r"(?<=[.!?。！？])\s+|\n+", r["output"]):
            if MEMORY.search(sentence) and not MEMORY.search(r["raw"]):
                print(f"  [{r['arm']}] {r['fixture']}#{r['run']}: {sentence.strip()}")
    print("\nB2a hand-read screen — every run whose engine output carries a flagged sentence (refused or not):")
    for r in runs:
        if scored(r) and (r["incompletenessFabricated"] or r["speakerState"] == "fabricated"):
            tail = r["output"].strip().splitlines()[-1] if r["output"].strip() else ""
            print(f"  [{r['arm']}] {r['fixture']}#{r['run']} {r['outcome']}"
                  f"{'(' + r['rejectedCheck'] + ')' if r['rejectedCheck'] else ''} "
                  f"check={r['incompletenessFabricated']} axis4={r['speakerState']}: {tail[:160]}")
    print("\nB2b — rule 7 on 5-rambling (axis 4 verdict per run):")
    for arm in ARMS:
        verdicts = [r["speakerState"] for r in runs if r["arm"] == arm and r["fixture"] == "5-rambling" and scored(r)]
        print(f"  {arm:9} {verdicts}")
    print("\nExample content copied into an output (arm's own examples):")
    for r in runs:
        if not scored(r):
            continue
        for word in EXAMPLE_CONTENT[r["arm"]]:
            if word.lower() in r["output"].lower() and word.lower() not in r["raw"].lower():
                print(f"  [{r['arm']}] {r['fixture']}#{r['run']} {r['outcome']} — {word!r}")


def b3(runs):
    section("B3 — lists (bars.md §4)")
    for arm in ARMS:
        rows = [r for r in runs if r["arm"] == arm and scored(r)]
        prose = [r for r in rows if is_prose(r["fixture"])]
        listed = [r for r in prose if r["listLines"] > 0]
        print(f"{arm:9} prose outputs={len(prose)} with a list line={len(listed)}")
        for r in listed:
            print(f"    {r['fixture']}#{r['run']} {r['outcome']} listLines={r['listLines']}")
        enum = [r for r in rows if r["fixture"] == ENUMERATING]
        print(f"          enumerating fixture {ENUMERATING}: listLines per run = "
              f"{[r['listLines'] for r in enum]} → lists (≥ 2 lines) in "
              f"{sum(r['listLines'] >= 2 for r in enum)}/{len(enum)}")
        t6 = [r for r in rows if r["fixture"].startswith("T6")]
        if t6:
            print(f"          T6 (translated enumeration, observable): lists in "
                  f"{sum(r['listLines'] >= 2 for r in t6)}/{len(t6)}")


def b4(runs):
    section("B4 — #583's fidelity axes on R1, per arm (bars.md §4, margin + 2)")
    axes = [("unrecalled", lambda r: len(r["unrecalled"]) > 0),
            ("personLost", lambda r: r["personLost"] > 0),
            ("hedgeLost", lambda r: r["hedgeLost"] > 0),
            ("stanceHardened", lambda r: r["stanceHardened"] > 0),
            ("fabricated", lambda r: r["speakerState"] == "fabricated"),
            ("dropped", lambda r: r["speakerState"] == "dropped")]
    r1 = [r for r in runs if r["round"].startswith("r1") and scored(r)]
    counts = {}
    for arm in ARMS:
        rows = [r for r in r1 if r["arm"] == arm]
        counts[arm] = {name: sum(test(r) for r in rows) for name, test in axes}
        counts[arm]["n"] = len(rows)
    print(f"{'axis':16}{'shipping':12}{CANDIDATE:12}verdict")
    for name, _ in axes:
        if CANDIDATE not in counts:
            continue
        s, c = counts["shipping"][name], counts[CANDIDATE][name]
        print(f"{name:16}{s}/{counts['shipping']['n']:<9}{c}/{counts[CANDIDATE]['n']:<9}"
              f"{'holds' if c <= s + 2 else 'FAILS'}")
    print("\nObservables on R1:")
    for arm in ARMS:
        rows = [r for r in r1 if r["arm"] == arm]
        print(f"  {arm:9} inversions={sum(r['inversions'] for r in rows)} "
              f"negationDropped={sum(r['negationDropped'] > 0 for r in rows)}/{len(rows)}")


def stray_lines(runs):
    section("Stray lines — a line made only of punctuation, e.g. `---` (observable)")
    for arm in ARMS:
        rows = [r for r in runs if r["arm"] == arm and scored(r)]
        hits = [r for r in rows
                if any(line.strip() and not re.search(r"\w", line) for line in r["output"].splitlines())]
        print(f"{arm:9} {len(hits)}/{len(rows)}: " + ", ".join(f"{r['fixture']}#{r['run']}({r['outcome']})" for r in hits))


def reported(runs):
    section("Reported, never barred — per round and arm")
    groups = defaultdict(list)
    for r in runs:
        groups[(r["round"], r["arm"])].append(r)
    print(f"{'round':13}{'arm':10}{'runs':6}{'noOutput':10}{'success':9}{'refusedBy':42}{'medianRatio':12}{'withBreak'}")
    for (round_name, arm), rows in sorted(groups.items()):
        out = [r for r in rows if scored(r)]
        refused = defaultdict(int)
        for r in out:
            if r["rejectedCheck"]:
                refused[r["rejectedCheck"]] += 1
        ratios = [r["outputChars"] / r["rawChars"] for r in out if r["rawChars"]]
        breaks = sum("\n\n" in r["output"] for r in out)
        print(f"{round_name:13}{arm:10}{len(rows):<6}{len(rows) - len(out):<10}"
              f"{sum(r['outcome'] == 'success' for r in out):<9}"
              f"{', '.join(f'{k}={v}' for k, v in sorted(refused.items())) or '-':42}"
              f"{statistics.median(ratios) if ratios else 0:<12.2f}{breaks}/{len(out)}")


def main():
    runs = load()
    print(f"{len(runs)} runs loaded from {sorted({r['round'] for r in runs})}")
    b1(runs)
    b2(runs)
    b3(runs)
    b4(runs)
    stray_lines(runs)
    reported(runs)


if __name__ == "__main__":
    main()
