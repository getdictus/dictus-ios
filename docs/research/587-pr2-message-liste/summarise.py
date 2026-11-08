#!/usr/bin/env python3
"""Read the #587 PR 2 captures against the bars in bars.md §4.

    python3 docs/research/587-pr2-message-liste/summarise.py

Two modes, two arms — `shipping` is this branch's per-language prompts, `develop` is the
one prompt each mode sent before. The fidelity axes in the captures are `Structuré`'s
contract and are deliberately not printed: nothing here is judged on them (bars.md §5).
"""

import json
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIXTURES = HERE.parent.parent.parent / "DictusCore/Sources/polish-harness/fixtures"

CAPTURES = {
    ("message", "fr"): ("capture-message-fr.json", "message-fr.json"),
    ("message", "i18n"): ("capture-message-i18n.json", "translated-structured.json"),
    ("notes", "fr"): ("capture-notes-fr.json", "notes-fr.json"),
    ("notes", "i18n"): ("capture-notes-i18n.json", "translated-structured.json"),
}
ARMS = ("develop", "shipping")


def load():
    """Every capture in `CAPTURES`, or an exit.

    A missing file is a capture command that failed, and skipping it produced a report
    that looked complete while covering three of four rounds (found by CodeRabbit on
    PR #597). Bars read off a silently short denominator are worse than no bars, so the
    absence is an error here rather than a gap in a table nobody would notice.
    """
    missing = [capture for capture, _ in CAPTURES.values() if not (HERE / capture).exists()]
    if missing:
        print("error: missing capture(s), the round is incomplete: " + ", ".join(sorted(missing)))
        print("       re-run the commands in bars.md §5; this script reports nothing partial.")
        raise SystemExit(1)
    runs = []
    for (mode, part), (capture, fixture_file) in CAPTURES.items():
        path = HERE / capture
        raws = {f["id"]: f["raw"] for f in json.loads((FIXTURES / fixture_file).read_text())}
        for record in json.loads(path.read_text()):
            record.setdefault("rejectedCheck", None)
            record["mode"] = mode
            record["part"] = part
            record["raw"] = raws[record["fixture"]]
            # The arm label is the file's basename; the baseline files are named for it.
            record["armLabel"] = "develop" if record["arm"].endswith("-develop") else "shipping"
            runs.append(record)
    return runs


def scored(r):
    return r.get("hasEngineOutput", True)


def wrong_language(r):
    return r["outputLanguage"] != r["expectedLanguage"] or bool(r["foreignSentences"])


def section(title):
    print(f"\n\n════ {title}\n")


def b1(runs):
    section("B1 — output language, per mode, arm and language (bars.md §4)")
    print(f"{'mode':9}{'lang':9}{'arm':10}{'outputs':9}{'refusedLang':13}{'%':7}{'wrongAccepted':15}{'wrongAny':9}")
    table = defaultdict(lambda: defaultdict(lambda: defaultdict(list)))
    for r in runs:
        if scored(r):
            table[r["mode"]][r["expectedLanguage"]][r["armLabel"]].append(r)
    for mode in sorted(table):
        for language in sorted(table[mode]):
            for arm in ARMS:
                cell = table[mode][language].get(arm, [])
                if not cell:
                    continue
                refused = sum(r["rejectedCheck"] == "language" for r in cell)
                accepted_wrong = sum(r["outcome"] == "success" and wrong_language(r) for r in cell)
                print(f"{mode:9}{language:9}{arm:10}{len(cell):<9}{refused:<13}"
                      f"{100 * refused / len(cell):<7.1f}{accepted_wrong:<15}"
                      f"{sum(wrong_language(r) for r in cell):<9}")
    print("\nEvery flagged output on the shipping arm, for the hand read:")
    for r in runs:
        if scored(r) and r["armLabel"] == "shipping" and wrong_language(r):
            print(f"  [{r['mode']}] {r['fixture']}#{r['run']} {r['outcome']}"
                  f"{'(' + r['rejectedCheck'] + ')' if r['rejectedCheck'] else ''} "
                  f"read={r['outputLanguage']} expected={r['expectedLanguage']}")
            for sentence in r["foreignSentences"]:
                print(f"      FOREIGN: {sentence}")
            if r["outputLanguage"] != r["expectedLanguage"]:
                print(f"      OUTPUT: {r['output'][:240]!r}")


def b2(runs):
    section("B2 — Liste still makes bullets (bars.md §4, #393)")
    for part in ("fr", "i18n"):
        for arm in ARMS:
            rows = [r for r in runs if r["mode"] == "notes" and r["part"] == part
                    and r["armLabel"] == arm and scored(r)]
            if not rows:
                continue
            accepted = [r for r in rows if r["outcome"] == "success"]
            without = [r for r in accepted if r["listLines"] == 0]
            print(f"  notes/{part:5} {arm:10} accepted={len(accepted):<4} with bullets="
                  f"{len(accepted) - len(without):<4} WITHOUT={len(without)}")
            for r in without:
                print(f"      {r['fixture']}#{r['run']}: {r['output'][:160]!r}")


def b3(runs):
    section("B3 — Message unchanged in French (bars.md §4)")
    print(f"{'arm':10}{'runs':6}{'accepted':10}{'blocks':9}{'medianRatio':13}refusedBy")
    for arm in ARMS:
        rows = [r for r in runs if r["mode"] == "message" and r["part"] == "fr"
                and r["armLabel"] == arm and scored(r)]
        if not rows:
            continue
        refused = defaultdict(int)
        for r in rows:
            if r["rejectedCheck"]:
                refused[r["rejectedCheck"]] += 1
        ratios = sorted(r["outputChars"] / r["rawChars"] for r in rows if r["rawChars"])
        median = ratios[len(ratios) // 2] if ratios else 0
        blocks = sum(1 for r in rows if "\n\n" in r["output"])
        checks = ", ".join(f"{k}={v}" for k, v in sorted(refused.items())) or "-"
        accepted = sum(r["outcome"] == "success" for r in rows)
        print(f"{arm:10}{len(rows):<6}{accepted:<10}{blocks:<9}{median:<13.2f}{checks}")
    print("\n  blocks = outputs carrying a blank line, which is decision 6's shape.")


def reported(runs):
    section("Reported, never barred")
    groups = defaultdict(list)
    for r in runs:
        groups[(r["mode"], r["part"], r["armLabel"])].append(r)
    print(f"{'mode':9}{'part':6}{'arm':10}{'runs':6}{'noOutput':10}{'success':9}{'withList':10}refusedBy")
    for key, rows in sorted(groups.items()):
        out = [r for r in rows if scored(r)]
        refused = defaultdict(int)
        for r in out:
            if r["rejectedCheck"]:
                refused[r["rejectedCheck"]] += 1
        checks = ", ".join(f"{k}={v}" for k, v in sorted(refused.items())) or "-"
        accepted = sum(r["outcome"] == "success" for r in out)
        lists = sum(r["listLines"] > 0 for r in out)
        print(f"{key[0]:9}{key[1]:6}{key[2]:10}{len(rows):<6}{len(rows) - len(out):<10}"
              f"{accepted:<9}{lists:<10}{checks}")


def main():
    runs = load()
    print(f"{len(runs)} runs loaded")
    b1(runs)
    b2(runs)
    b3(runs)
    reported(runs)


if __name__ == "__main__":
    main()
