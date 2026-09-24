#!/usr/bin/env python3
"""Score the reworded language clause against the baselines named in bars.md §2.

    python3 docs/research/587-language-clause/summarise.py

The candidate is this branch's code, run with no `--arm` (so its label is `shipping`).
Three baselines are committed captures from PR 1 and PR 2, taken on the same fixture
file, run count and machine; `Résumé`'s baseline is the `develop-summary` directory arm
run in this round. Every capture is required: a missing one exits, for the reason
PR #597's review gave.
"""

import json
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
RESEARCH = HERE.parent
FIXTURES = RESEARCH.parent.parent / "DictusCore/Sources/polish-harness/fixtures"
TRANSLATED = "translated-structured.json"

# mode -> (candidate capture, baseline capture, baseline arm label)
ROUNDS = {
    "message": (HERE / "capture-message.json",
                RESEARCH / "587-pr2-message-liste/capture-message-i18n.json", "shipping"),
    "notes": (HERE / "capture-notes.json",
              RESEARCH / "587-pr2-message-liste/capture-notes-i18n.json", "shipping"),
    "structured": (HERE / "capture-structured.json",
                   RESEARCH / "587-structured-rewrite/round3/capture-r4.json", "C3"),
    "summary": (HERE / "capture-summary.json", HERE / "capture-summary.json", "develop-summary"),
}


def load():
    missing = [str(path) for mode in ROUNDS for path in ROUNDS[mode][:2] if not path.exists()]
    if missing:
        print("error: missing capture(s), the round is incomplete:")
        for path in sorted(set(missing)):
            print("       " + path)
        raise SystemExit(1)
    raws = {f["id"]: f["raw"] for f in json.loads((FIXTURES / TRANSLATED).read_text())}
    runs = []
    for mode, (candidate, baseline, baseline_arm) in ROUNDS.items():
        for path, wanted, label in ((candidate, "shipping", "reworded"), (baseline, baseline_arm, "develop")):
            for record in json.loads(path.read_text()):
                arm = record["arm"]
                if (arm == "shipping") != (wanted == "shipping"):
                    continue
                if wanted != "shipping" and not arm.startswith(wanted.split("-")[0]):
                    continue
                if record["fixture"] not in raws:
                    continue
                record.setdefault("rejectedCheck", None)
                record["mode"] = mode
                record["armLabel"] = label
                runs.append(record)
    return runs


def scored(r):
    return r.get("hasEngineOutput", True)


def wrong_language(r):
    return r["outputLanguage"] != r["expectedLanguage"] or bool(r["foreignSentences"])


def main():
    runs = load()
    print(f"{len(runs)} runs loaded")
    table = defaultdict(lambda: defaultdict(lambda: defaultdict(list)))
    for r in runs:
        if scored(r):
            table[r["mode"]][r["expectedLanguage"]][r["armLabel"]].append(r)

    print("\n\n════ B1 — language, per mode, language and arm\n")
    print(f"{'mode':11}{'lang':9}{'arm':10}{'outputs':9}{'refusedLang':13}{'%':7}{'wrongAccepted':15}{'wrongAny'}")
    for mode in sorted(table):
        for language in sorted(table[mode]):
            for arm in ("develop", "reworded"):
                cell = table[mode][language].get(arm, [])
                if not cell:
                    continue
                refused = sum(r["rejectedCheck"] == "language" for r in cell)
                accepted_wrong = sum(r["outcome"] == "success" and wrong_language(r) for r in cell)
                print(f"{mode:11}{language:9}{arm:10}{len(cell):<9}{refused:<13}"
                      f"{100 * refused / len(cell):<7.1f}{accepted_wrong:<15}"
                      f"{sum(wrong_language(r) for r in cell)}")

    print("\n\n════ Totals, per mode and arm\n")
    print(f"{'mode':11}{'arm':10}{'outputs':9}{'refusedLang':13}{'wrongAccepted':15}{'english':10}{'bullets'}")
    for mode in sorted(table):
        for arm in ("develop", "reworded"):
            rows = [r for language in table[mode] for r in table[mode][language].get(arm, [])]
            if not rows:
                continue
            english = [r for r in rows if r["expectedLanguage"] == "en"]
            accepted = [r for r in rows if r["outcome"] == "success"]
            bullets = sum(r["listLines"] > 0 for r in accepted)
            print(f"{mode:11}{arm:10}{len(rows):<9}"
                  f"{sum(r['rejectedCheck'] == 'language' for r in rows):<13}"
                  f"{sum(r['outcome'] == 'success' and wrong_language(r) for r in rows):<15}"
                  f"{sum(r['outputLanguage'] == 'en' and not r['foreignSentences'] for r in english)}"
                  f"/{len(english):<7}{bullets}/{len(accepted)}")

    print("\n\n════ Every flagged output on the reworded arm, for the hand read\n")
    for r in runs:
        if scored(r) and r["armLabel"] == "reworded" and wrong_language(r):
            print(f"  [{r['mode']}] {r['fixture']}#{r['run']} {r['outcome']}"
                  f"{'(' + r['rejectedCheck'] + ')' if r['rejectedCheck'] else ''} "
                  f"read={r['outputLanguage']} expected={r['expectedLanguage']}")
            for sentence in r["foreignSentences"][:3]:
                print(f"      FOREIGN: {sentence[:120]}")


if __name__ == "__main__":
    main()
