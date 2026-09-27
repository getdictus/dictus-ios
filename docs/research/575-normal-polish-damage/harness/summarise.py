#!/usr/bin/env python3
"""Every table in findings.md, recomputed from the committed captures (#575).

Run from anywhere: python3 summarise.py

An output's damage label is the UNION of two screens, both read by hand:
  - score.py's per-fixture `_keep` / `_forbid` predicates, plus the added-`ne` check
    (amendment A2);
  - D-lost's lost words (detect.py). Every group it flags on this round was read.
    Exactly one group is not damage: `D1-selfcorrect` losing one `dès` — the model
    folding the speaker's `dès que dès que… dès que` hesitation, which rule 6 licenses.
"""
import json
import os
import sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import detector_eval as de  # noqa: E402
from detect import lost_words  # noqa: E402
from score import damage, norm, parse  # noqa: E402

FIX = {f["id"]: f for f in json.load(open(os.path.join(HERE, "..", "fixtures.json"), encoding="utf-8"))}
ARMS = [
    ("S-natural-fr-10runs", "shipping FR Natural"),
    ("S-auto-10runs", "shipping Auto"),
    ("X-natural-fr-no-examples-5runs", "FR, examples removed"),
    ("M-minimal-5runs", "minimal, punctuation only"),
    ("T-natural-fr-taught-5runs", "FR + taught line"),
    ("T-auto-taught-5runs", "Auto + taught line"),
]
SUBST = {"revaudrai", "preneur", "checker", "settings", "usage", "global", "pourrais", "capte", "mail", "hello"}


def tags(fid, text):
    """Defect classes carried by one output. Empty set = faithful."""
    t = norm(text)
    fx = FIX[fid]
    lost, bad = damage(fx, t)
    out = set()
    for k in lost:
        if k in ("s'il te plaît", "bisous", "je suis planté", "je me suis planté"):
            out.add("deletion")
        elif k == "t'as" or k == "t'en penses":
            out.add("register")
        elif k == "comment tu vas":
            out.add("register")
        elif k == "18h30":
            out.add("format")
        else:
            out.add("substitution")
    for b in bad:
        if b == "+ne" or b == "vas-tu":
            out.add("register")
        else:
            out.add("substitution")
    lw = set(lost_words(fx["raw"], text))
    if fid == "D1-selfcorrect":
        lw.discard("dès")
    if lw & SUBST:
        out.add("substitution")
    if "plaît" in lw or "bisous" in lw:
        out.add("deletion")
    if "18h30" in lw:
        out.add("format")
    if lw - SUBST - {"plaît", "bisous", "18h30"}:
        out.add("other:" + ",".join(sorted(lw - SUBST - {"plaît", "bisous", "18h30"})))
    return out


def main():
    raw_dir = os.path.join(HERE, "..", "raw")
    print("## Per arm: outputs that reached the user (success) and carry damage\n")
    per_fixture = defaultdict(dict)
    class_catch = defaultdict(lambda: [0, 0])  # class -> [caught by D-lost-1, total]
    faithful_refused = faithful_total = 0
    for stem, name in ARMS:
        ok = dmg = caught_by_guardrail = refused = 0
        cls = Counter()
        fdmg = Counter()
        fn = Counter()
        for fid, run, text, outcome in parse(os.path.join(raw_dir, stem + ".txt")):
            if outcome.startswith("caught:"):
                if tags(fid, text):
                    caught_by_guardrail += 1
                continue
            if outcome != "success":
                refused += 1
                continue
            ok += 1
            fn[fid] += 1
            tg = tags(fid, text)
            fires_raw = bool(lost_words(FIX[fid]["raw"], text))
            if tg:
                dmg += 1
                fdmg[fid] += 1
                for c in tg:
                    cls[c.split(":")[0]] += 1
                    class_catch[c.split(":")[0]][1] += 1
                    if fires_raw:
                        class_catch[c.split(":")[0]][0] += 1
            elif stem.startswith("S-"):
                faithful_total += 1
                if fires_raw:
                    faithful_refused += 1
        for fid in FIX:
            if fid in fn:
                per_fixture[fid][stem] = f"{fdmg[fid]}/{fn[fid]}"
        print(f"- **{name}** (`{stem}`): {dmg}/{ok} accepted outputs damaged; "
              f"{refused} refused, {caught_by_guardrail} of them carrying damage. Classes: "
              + ", ".join(f"{k} {v}" for k, v in sorted(cls.items())))
    print("\n## Damaged / accepted, per fixture per arm\n")
    print("| fixture | " + " | ".join(n for _, n in ARMS) + " |")
    print("|---|" + "---|" * len(ARMS))
    for fid in FIX:
        print(f"| `{fid}` | " + " | ".join(per_fixture[fid].get(s, "–") for s, _ in ARMS) + " |")
    print("\n## D-lost-1 on this round's accepted outputs, every arm\n")
    for c, (k, n) in sorted(class_catch.items()):
        print(f"- {c}: fires on {k}/{n} damaged outputs")
    print(f"- faithful outputs on the two shipping arms refused by D-lost-1: {faithful_refused}/{faithful_total}"
          " (all of them `D1-selfcorrect`'s licensed `dès` fold, see docstring)")


if __name__ == "__main__":
    main()
