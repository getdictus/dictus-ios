#!/usr/bin/env python3
"""Read a #550 paragraph-round capture and print the two quantities the harness
does not: placement agreement with the Typeless reference, and the fit for N.

Usage:  python3 score.py captures/round1.json [captures/round2.json ...]

The BARS are scored in Swift, in `ParagraphRound.summary`, on the same sentence cut
the arm was given — the prompt and the scorer cannot disagree there by construction.
What is left for this file is the pair that bars.md §6 declares **reported, never
barred**, plus the fit that supplies N.

If this file and bars.md ever disagree, bars.md is the one that was declared before
the first model call and this file is the bug.
"""

import json
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).parent
REFERENCES = json.loads((HERE / "references.json").read_text())

# The fit, from bars.md §4. Five reference points, character count of the text a
# paragrapher would be handed against the number of breaks the reference produced.
# Two of the five character counts come from a Typeless output, because texts A and B
# have no Dictus side. Reported with the fit rather than smoothed into it.
FIT_POINTS = [
    ("Text A (both takes)", 246, 1, "Typeless text; no Dictus side exists"),
    ("Text B (both takes)", 314, 1, "Typeless text; no Dictus side exists"),
    ("Fixture 3, message draft", 356, 2, "Dictus polished"),
    ("Fixture 1, free-form", 403, 1, "Dictus polished"),
    ("Fixture 7, 89 s", 1150, 3, "Dictus polished"),
]


def target_breaks(chars):
    """The rule the arms obey. Mirrors `ParagraphRound.targetBreaks`."""
    return max(1, round(chars / 400))


def report_fit():
    xs = [point[1] for point in FIT_POINTS]
    ys = [point[2] for point in FIT_POINTS]
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    slope = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sum((x - mx) ** 2 for x in xs)
    intercept = my - slope * mx
    predictions = [intercept + slope * x for x in xs]
    sst = sum((y - my) ** 2 for y in ys)
    sse = sum((y - p) ** 2 for y, p in zip(ys, predictions))

    print("════ THE FIT FOR N (bars.md §4) — five points, and it is not settled\n")
    print(f"  ordinary least squares:  breaks = {intercept:.3f} + chars / {1 / slope:.0f}"
          f"        R² = {1 - sse / sst:.2f}")
    print("  the rule the arms obey:  N = max(1, round(chars / 400))\n")
    print(f"  {'reference':28} {'chars':>6} {'actual':>7} {'OLS':>6} {'rounded':>8} {'rule/400':>9}   note")
    for (name, chars, breaks, note), prediction in zip(FIT_POINTS, predictions):
        print(f"  {name:28} {chars:6d} {breaks:7d} {prediction:6.2f} {round(prediction):8d}"
              f" {target_breaks(chars):9d}   {note}")
    hits = sum(1 for (_, c, b, _) in FIT_POINTS if target_breaks(c) == b)
    print(f"\n  Both forms score the same: {hits} of {len(FIT_POINTS)} exact, the miss "
          f"being fixture 3 by one break.")
    print("  Untested below 246 and above 1 150 characters. Uncertainty ±1 break over "
          "that range.")
    print("  Four of the nine paired samples are excluded because the reference returned "
          "lists there,")
    print("  not paragraphs — see references.json. That is nearly half the evidence this "
          "fit cannot use.")


def report_placement(runs):
    print("\n\n════ PLACEMENT AGREEMENT — reported, never barred (bars.md §2, §6)\n")
    print("  A break is 'hit' when the arm starts a paragraph on the same sentence the")
    print("  reference does. 'extra' is a break the reference does not have. Neither is a")
    print("  bar: text A proves the reference is one acceptable answer among several.\n")

    per_arm = defaultdict(lambda: [0, 0, 0, 0])   # hits, reference total, extra, runs
    rows = []
    for run in runs:
        reference = REFERENCES.get(run["fixture"])
        # A run whose words moved has no comparable placement: its break offsets do
        # not land on the input's sentence ends at all, so it would score 0 for a
        # reason that is already bar 1's finding rather than a placement result.
        if not reference or run.get("engineError") or run.get("parseFailure"):
            continue
        if run.get("fidelity") is False:
            continue
        wanted = set(reference["starts"])
        got = set(run["starts"])
        hits, extra = len(wanted & got), len(got - wanted)
        rows.append((run["arm"], run["fixture"], run["run"], sorted(got), hits, len(wanted), extra))
        bucket = per_arm[run["arm"]]
        bucket[0] += hits
        bucket[1] += len(wanted)
        bucket[2] += extra
        bucket[3] += 1

    print(f"  {'arm':20} {'runs':>5} {'reference breaks hit':>21} {'extra breaks':>13}")
    for arm in sorted(per_arm):
        hits, total, extra, count = per_arm[arm]
        share = f"{hits}/{total}" + (f"  ({100 * hits / total:.0f}%)" if total else "")
        print(f"  {arm:20} {count:5d} {share:>21} {extra:13d}")

    print("\n  Only P1, P3 and P7 carry a reference. On the other four the Typeless output")
    print("  is a list, not paragraphing, so there is nothing to agree with.")
    print("  Runs that failed bar 1, threw, or returned no usable indices are left out:")
    print("  their break offsets do not land on the input's sentences at all, so a zero")
    print("  there would restate bar 1 rather than say anything about placement.")
    print("  'runs' is therefore what each arm had left to be judged on.\n")
    print(f"  {'arm':20} {'fixture':20} {'run':>3}  {'reference':14} {'arm':16} hit/extra")
    for arm, fixture, index, got, hits, total, extra in rows:
        wanted = REFERENCES[fixture]["starts"]
        print(f"  {arm:20} {fixture:20} {index:3d}  {str(wanted):14} "
              f"{str(got):16} {hits}/{total}, +{extra}")


def report_null_baselines(runs):
    """What the index arms are worth against two rules that use no model at all.

    This is the question a structural design has to answer and the harness cannot:
    once fidelity, boundary discipline and the count have all been moved into code,
    is the MODEL still contributing anything? Two baselines, both computable from the
    sentence cut and N alone:

      head    break after the first N sentences
      even    break at N evenly spaced sentence boundaries

    An arm that matches a baseline is not doing worse than it. It is doing the same
    thing, for a call and a latency.
    """
    print("\n\n════ AGAINST TWO RULES THAT USE NO MODEL\n")
    print("  head = break after the first N sentences.")
    print("  even = break at N evenly spaced boundaries, round(k·(S-1)/(N+1))+1 for k=1..N.\n")
    per_arm = defaultdict(lambda: [0, 0, 0])
    for run in runs:
        if run.get("engineError") or run.get("parseFailure") or not run["starts"]:
            continue
        n, sentences = run["targetN"], run["sentenceCount"]
        head = list(range(2, 2 + n))
        even = sorted({round(k * (sentences - 1) / (n + 1)) + 1 for k in range(1, n + 1)})
        bucket = per_arm[run["arm"]]
        bucket[0] += 1
        bucket[1] += run["starts"] == head
        bucket[2] += run["starts"] == even
    print(f"  {'arm':20} {'runs':>5} {'== head':>10} {'== even':>10}")
    for arm in sorted(per_arm):
        total, head, even = per_arm[arm]
        print(f"  {arm:20} {total:5d} {f'{head}/{total}':>10} {f'{even}/{total}':>10}")


def report_latency(runs):
    print("\n\n════ LATENCY — reported, never barred (bars.md §6)\n")
    print("  #437's curve, for the first call this would sit behind: 2.2 s at 395 chars,")
    print("  7.6 s at 1 283. Its isolated second pass cost a further 1.4–5.2 s.")
    print("  Whether a second call is worth its seconds is the maintainer's decision.\n")
    by_arm_fixture = defaultdict(list)
    for run in runs:
        if run.get("engineError"):
            continue
        by_arm_fixture[(run["arm"], run["fixture"])].append(run["ms"])
    arms = sorted({arm for arm, _ in by_arm_fixture})
    fixtures = sorted({fixture for _, fixture in by_arm_fixture})
    print(f"  {'arm':20}" + "".join(f"{f.split('-')[0]:>8}" for f in fixtures) + f"{'median':>9}")
    for arm in arms:
        cells, everything = "", []
        for fixture in fixtures:
            times = sorted(by_arm_fixture.get((arm, fixture), []))
            everything += times
            cells += f"{times[len(times) // 2]:>8}" if times else f"{'-':>8}"
        everything.sort()
        print(f"  {arm:20}{cells}{everything[len(everything) // 2]:>9}")
    print("\n  Milliseconds, median over the runs of that arm on that fixture.")


def main():
    paths = sys.argv[1:] or [str(HERE / "captures" / "round1.json")]
    runs = []
    for path in paths:
        runs += json.loads(Path(path).read_text())
    print(f"capture: {len(runs)} runs from {len(paths)} file(s)\n")
    report_fit()
    report_placement(runs)
    report_null_baselines(runs)
    report_latency(runs)


if __name__ == "__main__":
    main()
