#!/usr/bin/env python3
"""Replay every recorded output through the SHIPPED lost-word check (#575 fix).

Run from anywhere: python3 replay.py [--verbose]

What it does, in three steps:
  1. Builds one pair per recorded output that reached a user (`success`): this round's
     six captures (raw/), the #439 longform captures, `freepolish.json` (#466), and the
     held-out captures taken for the fix (heldout/, never read while writing the
     allow-list).
  2. Runs `polish-harness lostword` on them: `PolishPipeline.transform` with an engine
     that returns the recorded output verbatim, so the verdict is the shipped chain's,
     in the shipped order, with the shipped length gate. Drives no model.
  3. Scores the verdicts against labels under the 2026-09-24 bar (meaning, not
     wording), written below as auditable rules, and prints the tables in the PR.

A label is the bar applied to what the output did, never the check's own answer. The
rules reuse the research screens (score.py's `_keep`/`_forbid`, D-lost's lost words)
and then sort each defect into "refuse" (a different word, a meaning-bearing word
deleted) or "tolerate" (register, a listed anglicism translated, politeness, format).
Every output the check refuses that no rule calls damage is printed for a human read,
and the reads are in HAND below with their reason.
"""
import collections
import glob
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import detector_eval as de  # noqa: E402
from detect import lost_words  # noqa: E402
from score import damage, norm  # noqa: E402

ROOT = de.ROOT
FIX = {f["id"]: f for f in json.load(open(os.path.join(HERE, "..", "fixtures.json"), encoding="utf-8"))}
HELD = {f["id"]: f for f in json.load(open(os.path.join(HERE, "..", "heldout", "fixtures.json"), encoding="utf-8"))}

# ── Labels under the 2026-09-24 bar ────────────────────────────────────────────────

# A `_keep` phrase lost, or a `_forbid` form present, that the bar TOLERATES. The
# anglicisms are tolerated only when a French equivalent took their place: deleted
# outright, they are a verb or a noun lost.
TOLERATED_KEEP = {"s'il te plaît", "bisous", "merci d'avance", "bonne soirée", "bises", "à plus",
                  "t'as", "t'en penses", "comment tu vas", "18h30"}
ANGLICISM_KEEP = {"checker": ("vérifi",), "le mail": ("email", "e-mail", "courriel", "mail"),
                  "settings": ("paramètre", "réglage")}
TOLERATED_FORBID = {"vas-tu", "vérifier", "email", "e-mail", "courriel", "+ne"}
# D-lost's lost words on this round, sorted by the bar.
# `global` → `globale` is agreement, carried by `usage` → `utilisation` in the same
# outputs; `dès` is D1's hesitation fold (rule 6).
TOLERATED_LOST = {"checker", "settings", "mail", "hello", "plaît", "bisous", "18h30", "dès", "bises", "plus",
                  "soirée", "bonne", "merci", "avance", "global"}
REFUSED_LOST = {"usage", "pourrais", "revaudrai", "preneur", "capte"}

# The two legacy corpora: `label_legacy.py`'s damage words, minus the anglicisms the bar
# now tolerates when translated (`today`, `push`, `deadline`, `review`, `request`).
LEGACY_DAMAGE = {"calcul", "avant", "explique", "machin", "échappe", "reviendra", "voilà", "peut",
                 "petit", "dossier"}

# Human reads of outputs no rule above labels, keyed by pair key. Each carries its reason.
HAND = {}
HAND_PATH = os.path.join(HERE, "..", "heldout", "labels.json")
if os.path.exists(HAND_PATH):
    HAND = json.load(open(HAND_PATH, encoding="utf-8"))


def label_round(fid, text):
    """`refuse`, `tolerate` (damage the bar accepts) or `faithful`, and why."""
    t = norm(text)
    fx = FIX[fid]
    keep_lost, forbid_hit = damage(fx, t)
    refuse, tolerate = [], []
    for k in keep_lost:
        if k in TOLERATED_KEEP:
            tolerate.append(k)
        elif k in ANGLICISM_KEEP:
            (tolerate if any(f in t for f in ANGLICISM_KEEP[k]) else refuse).append(k)
        else:
            refuse.append(k)
    for f in forbid_hit:
        (tolerate if f in TOLERATED_FORBID else refuse).append(f)
    for w in lost_words(fx["raw"], text):
        if w in REFUSED_LOST:
            refuse.append(w)
        elif w in TOLERATED_LOST:
            tolerate.append(w)
        else:
            refuse.append("unread:" + w)
    if refuse:
        return "refuse", sorted(set(refuse))
    return ("tolerate" if tolerate else "faithful"), sorted(set(tolerate))


def label_legacy(raw, text):
    lw = set(lost_words(de.prepass_fr(raw), text))
    hit = lw & LEGACY_DAMAGE
    return ("refuse", sorted(hit)) if hit else ("faithful", [])


# ── Pairs ──────────────────────────────────────────────────────────────────────────

def parse_capture(path, fixtures=None, refused_too=False):
    """Yield (fixture_id, run, raw, text) for every `success` in a `show` capture.

    Unlike `detector_eval.parse_capture`, a polished output that spans several lines —
    the pipeline decodes `<<NL>>` into real newlines — is read whole. Reading only its
    first line hands the check a truncated output, which the length band then refuses
    and which looks to a word count like every later word lost.
    """
    fid = raw = None
    pending = held = None
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        # `refused_too`: a run a guardrail refused prints the ENGINE's output beneath
        # it. The held-out captures were taken with the check live, so its own
        # refusals only exist there — and they are exactly what a human has to read.
        m = re.match(r"  engineOut(?: #(\d+))?: (.*)$", line)
        if m and held:
            yield held[0], held[1], raw, m.group(2)
            held = None
            continue
        m = re.match(r"━━ \[([^\]]+)\]", line)
        if m:
            fid = m.group(1)
            raw = fixtures[fid]["raw"] if fixtures and fid in fixtures else None
            pending = None
            continue
        m = re.match(r"  raw:\s+(.*)$", line)
        if m and (not fixtures or fid not in fixtures):
            raw = m.group(1)
            continue
        m = re.match(r"  polished(?: #(\d+))?: (.*)$", line)
        if m:
            pending = [int(m.group(1) or 1), [m.group(2)]]
            continue
        m = re.match(r"\s+\((\w+),", line)
        if m and pending:
            if m.group(1) == "success":
                yield fid, pending[0], raw, "\n".join(pending[1])
            elif refused_too and m.group(1) == "rejectedGuardrail":
                held = (fid, pending[0])
            pending = None
            continue
        if pending is not None and not re.match(r"  (breaks|engineOut)", line):
            pending[1].append(line)


def pairs():
    out = []
    for path in sorted(glob.glob(os.path.join(HERE, "..", "raw", "*.txt"))):
        arm = os.path.basename(path).rsplit("-", 1)[0]
        for fid, run, raw, text in parse_capture(path, FIX):
            out.append({"key": f"round/{arm}/{fid}#{run}", "route": "auto" if "auto" in arm else "natural",
                        "raw": raw, "output": text, "fid": fid})
    for path in sorted(glob.glob(os.path.join(ROOT, "docs/research/439-natural-contract/raw/short-*-show-5runs.txt"))):
        arm = os.path.basename(path).replace("-show-5runs.txt", "")
        for fid, run, raw, text in parse_capture(path):
            out.append({"key": f"longform/{arm}/{fid}#{run}", "route": "auto" if "auto" in arm else "natural",
                        "raw": raw, "output": text, "fid": fid})
    for i, c in enumerate(json.load(open(os.path.join(ROOT, "docs/research/413-414-guardrail/freepolish.json"),
                                         encoding="utf-8"))):
        if c.get("wasAccepted"):
            out.append({"key": f"freepol/{c['fixture']}#{c['run']}#{i}", "route": c["task"].split(".")[1],
                        "raw": c["raw"], "output": c["output"], "fid": c["fixture"], "lang": c["inputLang"]})
    for path in sorted(glob.glob(os.path.join(HERE, "..", "heldout", "raw-*.txt"))):
        route = "auto" if "auto" in os.path.basename(path) else "natural"
        for fid, run, raw, text in parse_capture(path, HELD, refused_too=True):
            out.append({"key": f"heldout/{route}/{fid}#{run}", "route": route, "raw": raw, "output": text,
                        "fid": fid})
    return out


def run_swift(ps):
    with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False, encoding="utf-8") as f:
        for p in ps:
            f.write(json.dumps({k: p[k] for k in ("key", "route", "raw", "output")}, ensure_ascii=False) + "\n")
        path = f.name
    proc = subprocess.run(["swift", "run", "-q", "--package-path", os.path.join(ROOT, "DictusCore"),
                           "polish-harness", "lostword", path], capture_output=True, text=True, check=True)
    os.unlink(path)
    return {v["key"]: v for v in map(json.loads, proc.stdout.splitlines())}


# ── Report ─────────────────────────────────────────────────────────────────────────

BUCKETS = [(0, 100), (101, 200), (201, 300), (301, 400), (401, 500), (501, 10**6)]


def bucket(chars):
    for lo, hi in BUCKETS:
        if lo <= chars <= hi:
            return f"{lo}–{hi}" if hi < 10**6 else f">{lo - 1}"
    return "?"


def main():
    verbose = "--verbose" in sys.argv
    ps = pairs()
    verdicts = run_swift(ps)
    rows = []
    for p in ps:
        v = verdicts[p["key"]]
        corpus = p["key"].split("/")[0]
        if corpus == "round":
            label, why = label_round(p["fid"], p["output"])
        elif p["key"] in HAND:
            label, why = HAND[p["key"]]["label"], [HAND[p["key"]]["reason"]]
        elif corpus in ("longform", "freepol"):
            label, why = label_legacy(p["raw"], p["output"])
        else:
            label, why = "faithful", []
        refused_here = v.get("check") == "lostWord"
        rows.append(dict(p, **v, label=label, why=why, refused=refused_here,
                         unscoped=bool(v["unscopedLostWords"])))

    print("## 1. This round's recorded outputs (`raw/`, 6 arms), shipped check\n")
    rnd = [r for r in rows if r["key"].startswith("round/")]
    by = collections.Counter((r["label"], r["refused"]) for r in rnd)
    for label in ("refuse", "tolerate", "faithful"):
        n = by[(label, True)] + by[(label, False)]
        print(f"- **{label}** (label under the 2026-09-24 bar): {n} outputs, refused by `lostWord` "
              f"{by[(label, True)]}/{n}")
    cls = collections.Counter()
    for r in rnd:
        if r["label"] == "refuse":
            for w in r["why"]:
                cls[(w, r["refused"])] += 1
    print("\n  Refuse-labelled outputs, per defect (refused / total):")
    for w in sorted({w for w, _ in cls}):
        print(f"  - `{w}`: {cls[(w, True)]}/{cls[(w, True)] + cls[(w, False)]}")
    tol = collections.Counter()
    for r in rnd:
        if r["label"] == "tolerate":
            for w in r["why"]:
                tol[(w, r["refused"])] += 1
    print("\n  Tolerate-labelled outputs, per defect (accepted / total):")
    for w in sorted({w for w, _ in tol}):
        print(f"  - `{w}`: {tol[(w, False)]}/{tol[(w, True)] + tol[(w, False)]}")
    other = collections.Counter((r["outcome"], r.get("check")) for r in rows if r["outcome"] != "success"
                                and r.get("check") != "lostWord")
    if other:
        print("\n  Refused by an EARLIER check on this replay (never reaches `lostWord`): "
              + ", ".join(f"{c} {n}" for (_, c), n in other.items()))

    print("\n## 2. False refusals on faithful and tolerated outputs, per input length\n")
    print("Faithful = no defect, or only defects the bar tolerates. `shipped` is the pipeline's "
          "verdict (French, Natural/Auto, ≤ 500 characters); `unscoped` is what the same check "
          "would refuse with no length gate.\n")
    print("| corpus | chars | outputs | shipped: refused | unscoped: refused |")
    print("|---|---|---|---|---|")
    table = collections.defaultdict(lambda: [0, 0, 0])
    for r in rows:
        if r["label"] == "refuse" or r["route"] == "repair":
            continue
        k = (r["key"].split("/")[0], bucket(r["chars"]))
        table[k][0] += 1
        table[k][1] += r["refused"]
        table[k][2] += r["unscoped"]
    order = {"round": 0, "freepol": 1, "longform": 2, "heldout": 3}
    for (corpus, b), (n, s, u) in sorted(table.items(), key=lambda kv: (order[kv[0][0]], BUCKETS.index(
            next(x for x in BUCKETS if bucket(x[0]) == kv[0][1])))):
        print(f"| {corpus} | {b} | {n} | {s} ({100 * s / n:.1f} %) | {u} ({100 * u / n:.1f} %) |")
    tot = collections.defaultdict(lambda: [0, 0, 0])
    for (corpus, b), vals in table.items():
        for i in range(3):
            tot[b][i] += vals[i]
    print("| **all** | | | | |")
    for b in [bucket(x[0]) for x in BUCKETS]:
        if b in tot:
            n, s, u = tot[b]
            print(f"| all | {b} | {n} | {s} ({100 * s / n:.1f} %) | {u} ({100 * u / n:.1f} %) |")

    print("\n## 3. Damage the shipped check refuses on the legacy corpora and the held-out set\n")
    for corpus in ("longform", "freepol", "heldout"):
        dmg = [r for r in rows if r["key"].startswith(corpus + "/") and r["label"] == "refuse"]
        anyc = sum(r["outcome"] != "success" for r in dmg)
        print(f"- {corpus}: {sum(r['refused'] for r in dmg)}/{len(dmg)} refuse-labelled outputs refused by "
              f"`lostWord`, {anyc}/{len(dmg)} by any check (unscoped `lostWord`: "
              f"{sum(r['unscoped'] for r in dmg)}/{len(dmg)})")

    unread = [r for r in rows if (r["refused"] or r["unscoped"]) and r["label"] != "refuse"]
    print(f"\n## 4. Every faithful-labelled output the check flags ({len(unread)}), for the human read\n")
    for r in unread:
        print(f"- `{r['key']}` ({r['chars']} ch, shipped={'REFUSED' if r['refused'] else 'accepted'}) "
              f"lost={r['unscopedLostWords']}\n    IN : {r['raw']}\n    OUT: {r['output']}")
    if verbose:
        print("\n## 5. Every refuse-labelled output the check lets through\n")
        for r in rows:
            if r["label"] == "refuse" and not r["refused"]:
                print(f"- `{r['key']}` ({r['chars']} ch) why={r['why']} lost={r['unscopedLostWords']}")


if __name__ == "__main__":
    main()
