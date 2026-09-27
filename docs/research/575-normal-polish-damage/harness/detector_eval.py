#!/usr/bin/env python3
"""Score D-lost (detect.py) over three corpora, and B9's floor-vs-output distance (#575).

Usage:
  detector_eval.py flags            # every pair D-lost-1 flags, for the human read
  detector_eval.py score            # counts, using labels.json for the flagged pairs

Corpora (bars.md Q5):
  round    — this round's successes, every capture under raw/ (engine output vs the
             pre-passed input; the pre-pass is the identity on 13 of 14 fixtures and
             D1's ellipsis collapse removes no word).
  longform — docs/research/439-natural-contract/raw/short-*-show-5runs.txt
  freepol  — docs/research/413-414-guardrail/freepolish.json (accepted free polish)

labels.json maps a pair key to "damage" or "faithful". A pair D-lost-1 does NOT flag is
never labelled: the detector cannot refuse it, so it cannot be a false refusal. It can
still be a MISS, which is why B7 is counted from score.py's predicates, not from here.
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, HERE)
from detect import lost_words, tokens  # noqa: E402


# Mirror of VerbalPunctuationPrepass's French rules (bars.md amendment A1). The
# pipeline judges the engine's output against the PRE-PASSED text, so a spoken command
# the regex already replaced is not a word the model lost.
FR_PREPASS = [
    (r"\bretour à la ligne\b", "\n"), (r"\bnouvelle ligne\b", "\n"), (r"\bà la ligne\b", "\n"),
    (r"\bpoint d['’]interrogation\b", "?"), (r"\bpoint d['’]exclamation\b", "!"),
    (r"\bpoint virgule\b", ";"), (r"\bdeux points\b", ":"), (r"\bvirgule\b", ","),
]


def prepass_fr(raw):
    out = raw
    for pat, rep in FR_PREPASS:
        out = re.sub(pat, rep, out, flags=re.IGNORECASE)
    return out


def parse_capture(path, fixtures=None):
    fid, raw, pending = None, None, None
    for line in open(path, encoding="utf-8"):
        m = re.match(r"━━ \[([^\]]+)\]", line)
        if m:
            fid = m.group(1)
            raw = fixtures[fid]["raw"] if fixtures and fid in fixtures else None
            continue
        m = re.match(r"  raw:\s+(.*)$", line)
        if m and raw is None:
            raw = m.group(1)
            continue
        m = re.match(r"  polished(?: #(\d+))?: (.*)$", line)
        if m:
            pending = (int(m.group(1) or 1), m.group(2))
            continue
        m = re.match(r"\s+\((\w+),", line)
        if m and pending:
            if m.group(1) == "success":
                yield fid, pending[0], raw, pending[1]
            pending = None


def corpora():
    fx = {f["id"]: f for f in json.load(open(os.path.join(HERE, "..", "fixtures.json"), encoding="utf-8"))}
    out = []
    for path in sorted(glob.glob(os.path.join(HERE, "..", "raw", "*.txt"))):
        arm = os.path.basename(path).rsplit("-", 1)[0]
        for fid, run, raw, text in parse_capture(path, fx):
            out.append(("round", f"{arm}/{fid}#{run}", prepass_fr(raw), text))
    for path in sorted(glob.glob(os.path.join(ROOT, "docs/research/439-natural-contract/raw/short-*-show-5runs.txt"))):
        arm = os.path.basename(path).replace("-show-5runs.txt", "")
        for fid, run, raw, text in parse_capture(path):
            out.append(("longform", f"{arm}/{fid}#{run}", prepass_fr(raw), text))
    for i, c in enumerate(json.load(open(os.path.join(ROOT, "docs/research/413-414-guardrail/freepolish.json"), encoding="utf-8"))):
        if c.get("wasAccepted") and c.get("inputLang") == "fr":
            out.append(("freepol", f"freepol/{c['fixture']}#{c['run']}#{i}", prepass_fr(c["raw"]), c["output"]))
    return out


def word_diff(a, b):
    """Words changed between two texts: size of the multiset symmetric difference."""
    from collections import Counter
    ca, cb = Counter(tokens(a)), Counter(tokens(b))
    return sum(((ca - cb) + (cb - ca)).values())


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "flags"
    pairs = corpora()
    if mode == "flags":
        for corpus, key, raw, text in pairs:
            lw = lost_words(raw, text)
            if lw:
                print(f"{corpus}\t{key}\t{lw}\n    IN : {raw}\n    OUT: {text}")
        return
    labels = json.load(open(os.path.join(HERE, "labels.json"), encoding="utf-8"))
    # The round corpus is scored by summarise.py, whose labels cover every output.
    for corpus in ("longform", "freepol"):
        rows = [(k, r, t) for c, k, r, t in pairs if c == corpus]
        stats = {}
        for thr in (1, 2):
            refused_damage = refused_faithful = 0
            unlabelled = []
            for k, r, t in rows:
                if len(lost_words(r, t)) >= thr:
                    lab = labels.get(k)
                    if lab == "damage":
                        refused_damage += 1
                    elif lab == "faithful":
                        refused_faithful += 1
                    else:
                        unlabelled.append(k)
            faithful_total = len(rows) - sum(1 for k, _, _ in rows if labels.get(k) == "damage")
            stats[thr] = (refused_damage, refused_faithful, faithful_total, unlabelled)
        print(f"\n══ {corpus}: {len(rows)} accepted outputs")
        for thr, (rd, rf, ft, un) in stats.items():
            pct = 100.0 * rf / ft if ft else 0.0
            print(f"   D-lost-{thr}: refuses {rd} labelled-damage, {rf}/{ft} faithful ({pct:.1f} %)"
                  + (f"  UNLABELLED: {un}" if un else ""))
    # B9: what the floor would have given instead of the accepted output, round corpus.
    fx = {f["id"]: f for f in json.load(open(os.path.join(HERE, "..", "fixtures.json"), encoding="utf-8"))}
    diffs = [word_diff(r, t) for c, k, r, t in pairs if c == "round" and k.startswith("S-")]
    diffs_long = [word_diff(r, t) for c, k, r, t in pairs if c == "longform"]
    for name, d in (("round, shipping arms", diffs), ("longform", diffs_long)):
        if d:
            d = sorted(d)
            print(f"\n   B9 {name}: words differing between floor and accepted output — "
                  f"median {d[len(d) // 2]}, max {d[-1]}, zero on {sum(1 for x in d if x == 0)}/{len(d)}")


if __name__ == "__main__":
    main()
