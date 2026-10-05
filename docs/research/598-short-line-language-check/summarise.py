#!/usr/bin/env python3
"""Score the language check's variants for #598, from committed readings only.

    docs/research/598-short-line-language-check/run-readings.sh   # macOS, re-takes the readings
    python3 docs/research/598-short-line-language-check/summarise.py

`readings.jsonl` holds what `NLLanguageRecognizer` said about every output (whole, and
each segment), plus the verdict of the shipping `PolishGuardrail.detectedLanguageMatches`.
This script re-implements that rule, refuses to go on unless it reproduces the shipping
verdict on every single output, and only then scores the variants of plan.md section 3.
`labels.json` holds the hand labels of plan.md section 4; every refusal this script has
to judge must carry one, or it stops.
"""

import json
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent

SCANDINAVIAN = frozenset({"da", "nb", "no", "sv"})
IBERIAN = frozenset({"es", "pt"})
WHOLE_FLOOR = 0.5
SEGMENT_FLOOR = 0.85
SHIPPING_MIN = 12
BUCKETS = [(12, 24), (25, 49), (50, 99), (100, 199), (200, 10**6)]


# MARK: - The rule, and its variants

class Rule:
    """One variant of `PolishGuardrail.matches(polished:expectedCode:thresholds:)`."""

    def __init__(self, name, whole=(SCANDINAVIAN,), segment=(SCANDINAVIAN,),
                 segment_pass=True, minimum=SHIPPING_MIN):
        self.name, self.whole, self.segment = name, whole, segment
        self.segment_pass, self.minimum = segment_pass, minimum

    @staticmethod
    def agrees(read, expected, families):
        return read == expected or any(read in f and expected in f for f in families)

    def refusal(self, record):
        """None when accepted; otherwise "WHOLE" or the list of refusing segments."""
        expected = record["expected"]
        if record["trimmedCharacters"] < 12:
            return None
        whole = record["whole"]
        if whole["confidence"] >= WHOLE_FLOOR and not self.agrees(whole.get("code"), expected, self.whole):
            return "WHOLE"
        segments = record["segments"]
        if not self.segment_pass or len(segments) <= 1:
            return None
        bad = [s for s in segments
               if s["characters"] >= self.minimum
               and s["reading"]["confidence"] >= SEGMENT_FLOOR
               and not self.agrees(s["reading"].get("code"), expected, self.segment)]
        return bad or None


V0 = Rule("V0 shipping")
V1 = Rule("V1 whole output only", segment_pass=False)
V2 = Rule("V2 es/pt family, both passes", whole=(SCANDINAVIAN, IBERIAN), segment=(SCANDINAVIAN, IBERIAN))
V3 = Rule("V3 es/pt family, segment pass only", segment=(SCANDINAVIAN, IBERIAN))
V4 = [Rule(f"V4-{n} segment floor {n} chars", minimum=n) for n in (20, 25, 30, 40, 60)]


# MARK: - Loading, and the two guards

def load():
    records = [json.loads(line) for line in (HERE / "readings.jsonl").read_text().splitlines() if line]
    labels = json.loads((HERE / "labels.json").read_text())
    readable = [r for r in records if r.get("expected")]
    mismatches = [r for r in readable if (V0.refusal(r) is None) != r["shippingAccepts"]]
    if mismatches:
        print(f"error: the re-implemented rule disagrees with the shipping check on {len(mismatches)} outputs;")
        print("       no variant below would mean anything. First: " + json.dumps(mismatches[0])[:300])
        raise SystemExit(1)
    segment_labels = {(s["expected"], s["read"], s["text"]): s for s in labels["segments"]}
    whole_labels = {(w["file"], w["fixture"], w["arm"], w["run"]): w for w in labels["wholeRefusals"]}
    return records, readable, segment_labels, whole_labels


def name(record):
    if record["corpus"] == "K414":
        return f"{record['fixture']}#{record['run']}"
    # The folder as well as the file: three rounds of 587-structured-rewrite each hold a
    # `capture-r4.json`, and the file name alone collides across them.
    where = "/".join(record["file"].split("/")[-2:])
    return f"{where}:{record['fixture']}#{record['run']}[{record.get('arm')}]"


def judge(record, refusal, segment_labels, whole_labels):
    """`false` when every reason for the refusal is a labelled misreading, else `genuine`."""
    if refusal == "WHOLE":
        key = (record["file"], record["fixture"], record.get("arm"), record["run"])
        label = whole_labels.get(key)
        if label is None:
            raise SystemExit(f"error: whole-pass refusal with no label: {name(record)}")
        return "false" if label["label"] == "misread" else "genuine"
    found = []
    for s in refusal:
        label = segment_labels.get((record["expected"], s["reading"]["code"], s["text"]))
        if label is None:
            raise SystemExit(f"error: refusing segment with no label: {name(record)} — {s['text'][:60]}")
        found.append(label["label"])
    return "false" if all(lab == "misread" for lab in found) else "genuine"


# MARK: - Reports

def k414_score(rule, k414):
    caught = [name(r) for r in k414 if r["label"] != "sameLanguage" and rule.refusal(r) is not None]
    missed = [name(r) for r in k414 if r["label"] != "sameLanguage" and rule.refusal(r) is None]
    false = [name(r) for r in k414 if r["label"] == "sameLanguage" and rule.refusal(r) is not None]
    legit = sum(1 for r in k414 if r["label"] == "sameLanguage")
    return caught, missed, false, legit


def c587_split(rule, c587, segment_labels, whole_labels):
    out = {"false": [], "genuine": []}
    for r in c587:
        refusal = rule.refusal(r)
        if refusal is not None:
            out[judge(r, refusal, segment_labels, whole_labels)].append(r)
    return out


def pair_of(record, refusal):
    if refusal == "WHOLE":
        return f"{record['expected']}→{record['whole']['code']} (whole)"
    return ", ".join(sorted({f"{record['expected']}→{s['reading']['code']}" for s in refusal}))


def main():
    records, readable, segment_labels, whole_labels = load()
    k414 = [r for r in readable if r["corpus"] == "K414"]
    c587 = [r for r in readable if r["corpus"] == "C587"]
    unread = [r for r in records if not r.get("expected")]
    print(f"readings: {len(records)} outputs — K414 {len(k414)}, C587 {len(c587)}, "
          f"{len(unread)} with no expected code (pipeline passes them through, excluded)")
    print(f"guard: the re-implemented rule reproduces the shipping verdict on all {len(readable)} outputs")
    print(f"C587 by expected language: {dict(sorted(Counter(r['expected'] for r in c587).items()))}")

    v0 = c587_split(V0, c587, segment_labels, whole_labels)
    measurement_one(c587, v0, segment_labels, whole_labels)
    measurement_two(k414, c587, v0, segment_labels, whole_labels)
    measurement_three(k414, c587, v0, segment_labels, whole_labels)
    length_floor(k414, c587, segment_labels, whole_labels)


def measurement_one(c587, v0, segment_labels, whole_labels):
    print("\n══ M1 — does the misreading survive on ordinary length?")
    whole = [r for r in v0["false"] + v0["genuine"] if V0.refusal(r) == "WHOLE"]
    print(f"\nC587 refusals under V0: {len(v0['false']) + len(v0['genuine'])} — "
          f"{len(whole)} by the whole pass, {len(v0['false']) + len(v0['genuine']) - len(whole)} by the segment pass")
    print(f"  false refusals (every reason a labelled misreading): {len(v0['false'])}")
    print(f"  whole-pass false refusals: {sum(1 for r in v0['false'] if V0.refusal(r) == 'WHOLE')} of {len(whole)}")
    by_pair = defaultdict(list)
    for r in v0["false"]:
        by_pair[pair_of(r, V0.refusal(r))].append(r)
    for pair, rs in sorted(by_pair.items()):
        print(f"  {pair}: {len(rs)} outputs")
        for r in rs:
            s = V0.refusal(r)[0]
            print(f"     {name(r)}  output {r['trimmedCharacters']} ch, whole {r['whole']['code']} "
                  f"{r['whole']['confidence']:.3f}; line {s['characters']} ch at {s['reading']['confidence']:.3f}: {s['text']}")

    misread = {k for k, v in segment_labels.items() if v["label"] == "misread"}
    print("\nEvery labelled misreading, by pair (incl. the ones the Scandinavian rule already accepts):")
    seen = defaultdict(list)
    for r in c587:
        if len(r["segments"]) < 2:
            continue
        for s in r["segments"]:
            key = (r["expected"], s["reading"].get("code"), s["text"])
            if key in misread and s["reading"]["confidence"] >= SEGMENT_FLOOR and s["characters"] >= SHIPPING_MIN:
                seen[(key[0], key[1])].append((s, r))
    for (expected, read), hits in sorted(seen.items()):
        lengths = [s["characters"] for s, _ in hits]
        texts = {s["text"] for s, _ in hits}
        fixtures = {r["fixture"] for _, r in hits}
        print(f"  {expected}→{read}: {len(hits)} lines in {len({id(r) for _, r in hits})} outputs, "
              f"{len(texts)} distinct strings, {min(lengths)}–{max(lengths)} ch, fixtures {sorted(fixtures)}")

    # The rate, per expected language and segment length, over outputs a human would call
    # correct-language: not refused at all, or refused only on labelled misreadings.
    clean = [r for r in c587 if V0.refusal(r) is None] + v0["false"]
    print(f"\nRate of confident misreading (≥ {SEGMENT_FLOOR}, any other code) per segment length, "
          f"over the {len(clean)} correct-language C587 outputs of more than one segment:")
    print("  lang  " + "".join(f"{f'{lo}-{hi}' if hi < 10**6 else f'{lo}+':>14}" for lo, hi in BUCKETS))
    for language in ("es", "pt", "da", "nb", "sv", "fr", "en", "it", "de"):
        row = f"  {language:<5} "
        for lo, hi in BUCKETS:
            segs = [s for r in clean if r["expected"] == language and len(r["segments"]) > 1
                    for s in r["segments"] if lo <= s["characters"] <= hi]
            bad = [s for s in segs if s["reading"].get("code") != language
                   and s["reading"]["confidence"] >= SEGMENT_FLOOR]
            row += f"{f'{len(bad)}/{len(segs)}':>14}"
        print(row)
    print("  (a numerator counts misreadings the Scandinavian rule already accepts; "
          "single-segment outputs are never segment-tested and are left out)")

    print("\nCross-readings between es and pt at ANY confidence, every C587 segment and whole output:")
    cross = Counter()
    for r in c587:
        pair = {r["expected"], r["whole"].get("code")}
        if r["expected"] in IBERIAN and pair == IBERIAN:
            cross[("whole", r["expected"], r["whole"]["code"])] += 1
        for s in r["segments"]:
            if r["expected"] in IBERIAN and {r["expected"], s["reading"].get("code")} == IBERIAN:
                cross[(s["text"], r["expected"], s["reading"]["code"], round(s["reading"]["confidence"], 3))] += 1
    for key, n in sorted(cross.items()):
        print(f"  {n}×  {key}")
    print(f"  es outputs {sum(1 for r in c587 if r['expected'] == 'es')}, "
          f"pt outputs {sum(1 for r in c587 if r['expected'] == 'pt')}")


def measurement_two(k414, c587, v0, segment_labels, whole_labels):
    print("\n══ M2 — read the whole output instead of a line")
    report_k414(V1, k414)
    v1 = c587_split(V1, c587, segment_labels, whole_labels)
    report_c587_delta(V1, v0, v1)


def measurement_three(k414, c587, v0, segment_labels, whole_labels):
    print("\n══ M3 — the cost of an es/pt exception, scored the way PR #588 scored the Scandinavian one")
    iberian = [r for r in k414 if r["expected"] in IBERIAN or r["whole"].get("code") in IBERIAN
               or any(s["reading"].get("code") in IBERIAN for s in r["segments"])]
    print(f"\nK414 outputs touching es or pt at all (expected, whole or any segment): {len(iberian)}")
    for r in iberian:
        print(f"   {name(r)} expected={r['expected']} label={r['label']} whole={r['whole']['code']}")
    for rule in (V2, V3):
        report_k414(rule, k414)
        report_c587_delta(rule, v0, c587_split(rule, c587, segment_labels, whole_labels))
    print("\nOutputs where Apple FM wrote es or pt on a dictation in another language (whole reading ≥ 0.5):")
    for r in c587:
        if r["whole"].get("code") in IBERIAN and r["expected"] != r["whole"]["code"] and r["whole"]["confidence"] >= 0.5:
            print(f"   {name(r)}  expected {r['expected']}, whole {r['whole']['code']} {r['whole']['confidence']:.4f}, "
                  f"V2 {'refuses' if V2.refusal(r) else 'ACCEPTS'}, V3 {'refuses' if V3.refusal(r) else 'ACCEPTS'}")


def length_floor(k414, c587, segment_labels, whole_labels):
    print("\n══ Also scored: a longer segment floor (V4), everything else shipping")
    v0 = c587_split(V0, c587, segment_labels, whole_labels)
    print(f"  {'rule':<34}{'K414 caught':>12}{'K414 false':>12}{'C587 false':>12}{'C587 genuine':>14}")
    for rule in [V0] + V4:
        caught, missed, false, legit = k414_score(rule, k414)
        split = c587_split(rule, c587, segment_labels, whole_labels)
        print(f"  {rule.name:<34}{f'{len(caught)}/{len(caught) + len(missed)}':>12}{f'{len(false)}/{legit}':>12}"
              f"{len(split['false']):>12}{len(split['genuine']):>14}")
        lost = sorted({name(r) for r in v0["genuine"]} - {name(r) for r in split["genuine"]})
        if rule is not V0 and lost:
            print(f"     genuine C587 catches lost vs V0: {len(lost)}")
            if len(lost) <= 3:
                for label in lost:
                    record = next(r for r in v0["genuine"] if name(r) == label)
                    refusal = V0.refusal(record)
                    lines = "; ".join(f"{s['characters']} ch: {s['text'][:70]}" for s in refusal)
                    print(f"       {label} — {lines}")


def report_k414(rule, k414):
    caught0, _, _, _ = k414_score(V0, k414)
    caught, missed, false, legit = k414_score(rule, k414)
    print(f"\nK414 — {rule.name}: caught {len(caught)}/{len(caught) + len(missed)}, "
          f"false rejections {len(false)}/{legit}")
    for label in sorted(set(caught0)):
        state = "kept" if label in caught else "LOST"
        print(f"   {state:<5} {label}")
    for label in false:
        print(f"   FALSE REJECTION {label}")


def report_c587_delta(rule, v0, variant):
    avoided = [r for r in v0["false"] if r not in variant["false"]]
    lost = [r for r in v0["genuine"] if r not in variant["genuine"]]
    print(f"C587 — {rule.name}: false refusals {len(v0['false'])} → {len(variant['false'])}, "
          f"genuine catches {len(v0['genuine'])} → {len(variant['genuine'])}")
    for r in avoided:
        print(f"   refusal avoided: {name(r)}")
    by_pair = Counter(pair_of(r, V0.refusal(r)) for r in lost)
    for pair, n in sorted(by_pair.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"   genuine catch lost: {n:>3}  {pair}")
    if lost:
        examples = sorted(lost, key=lambda r: r["trimmedCharacters"])[:3]
        for r in examples:
            s = V0.refusal(r)[0] if V0.refusal(r) != "WHOLE" else None
            print(f"     e.g. {name(r)}: {s['text'][:90] if s else '(whole)'}")


if __name__ == "__main__":
    main()
