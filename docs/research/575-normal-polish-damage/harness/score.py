#!/usr/bin/env python3
"""Score polish-harness `show` captures against fixtures.json's _keep/_forbid (#575).

Usage: score.py <fixtures.json> <capture.txt> [<capture.txt> ...]

Prints, per capture: the B1 row counts, the B2 per-fixture damage counts, the B4
guardrail-blind count (damaged AND outcome success) and the B6 outcome tally.
Non-success runs are excluded from B1/B2 denominators (bars.md B6).
"""
import json
import re
import sys


def norm(s):
    return s.lower().replace("’", "'").replace(" ", " ")


def parse(path):
    """Yield (fixture_id, run, text, outcome) from a `show` capture."""
    fid, pending = None, None
    for line in open(path, encoding="utf-8"):
        m = re.match(r"━━ \[([^\]]+)\]", line)
        if m:
            fid = m.group(1)
            continue
        m = re.match(r"  polished(?: #(\d+))?: (.*)$", line)
        if m:
            pending = (int(m.group(1) or 1), m.group(2))
            continue
        m = re.match(r"\s+\((\w+),", line)
        if m and pending:
            yield fid, pending[0], pending[1], m.group(1)
            pending = None


def rows(fid, t):
    """B1 predicates. Returns the set of rows that fired on this output."""
    fired = set()
    if fid == "D2-bisous":
        if "s'il te plaît" not in t or "bisous" not in t:
            fired.add("1")
        for form, tag in (("vas-tu", "4:vas-tu"), ("vérifier", "4:vérifier"), ("email", "4:email")):
            if form in t:
                fired.add("4")
                fired.add(tag)
    if fid == "D4-preneur" and "je suis preneur" not in t:
        fired.add("2")
    if fid == "H1-thanks":
        if "revaudrai" not in t:
            fired.add("3")
        if "se capte" not in t:
            fired.add("5")
    return fired


def damage(fx, t):
    lost = [k for k in fx["_keep"] if norm(k) not in t]
    bad = [f for f in fx["_forbid"] if norm(f) in t]
    return lost, bad


def main():
    fixtures = {f["id"]: f for f in json.load(open(sys.argv[1], encoding="utf-8"))}
    for path in sys.argv[2:]:
        outcomes, row_hits, row_n = {}, {}, {}
        dmg, n = {}, {}
        blind = 0
        details = []
        for fid, run, text, outcome in parse(path):
            outcomes[outcome] = outcomes.get(outcome, 0) + 1
            if outcome != "success":
                continue
            t = norm(text)
            fx = fixtures[fid]
            n[fid] = n.get(fid, 0) + 1
            lost, bad = damage(fx, t)
            if lost or bad:
                dmg[fid] = dmg.get(fid, 0) + 1
                blind += 1
                details.append(f"   {fid} #{run}: lost={lost} forbidden={bad}")
            for key in {"D2-bisous": ["1", "4", "4:vas-tu", "4:vérifier", "4:email"],
                        "D4-preneur": ["2"], "H1-thanks": ["3", "5"]}.get(fid, []):
                row_n[key] = row_n.get(key, 0) + 1
            for r in rows(fid, t):
                row_hits[r] = row_hits.get(r, 0) + 1
        print(f"\n══ {path}")
        print("   outcomes: " + ", ".join(f"{k}={v}" for k, v in sorted(outcomes.items())))
        print("   B1 rows:  " + "  ".join(
            f"row {k}={row_hits.get(k, 0)}/{row_n[k]}" for k in
            ["1", "2", "3", "4", "4:vas-tu", "4:vérifier", "4:email", "5"] if k in row_n))
        print("   B2 damaged runs per fixture:")
        for fid in fixtures:
            if fid in n:
                print(f"     {fid:22s} {dmg.get(fid, 0)}/{n[fid]}")
        probes = [f for f in fixtures if f.startswith("P")]
        pd = sum(dmg.get(f, 0) for f in probes)
        pn = sum(n.get(f, 0) for f in probes)
        print(f"   probes damaged: {pd}/{pn} runs, {sum(1 for f in probes if dmg.get(f, 0))}/{len(probes)} probes at least once;"
              f" control {dmg.get('C1-control', 0)}/{n.get('C1-control', 0)}")
        print(f"   B4 damaged AND success (guardrail-blind): {blind}")
        for d in details:
            print(d)


if __name__ == "__main__":
    main()
