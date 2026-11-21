#!/usr/bin/env python3
"""
compare.py -- One table across keyboard-bench replays: model off, each model, each weight (#996).

Each argument is `label=dir`, a directory tools/keyboard-bench/run.sh wrote (taps.tsv,
commits.tsv, texts.tsv). For each run (fr, en, en-typos, es, de) it prints the words
wrong in the final text, the space bar's broken, miscorrected and fixed words, the next
word in the bar's top 3, and the engine's ms per space and per letter (p50 / p95).
taps.tsv's lm_ms column, when present, gives the model's own ms per space and per letter;
it is the model's time only in the replay that computed the answers (the first weight).

With --cases, it also prints corpus/fr-pierre-device.cases: one row per case Pierre typed
on his iPhone, what each replay wrote for it, and the totals.

Usage:
    python3 -I tools/keyboard-lm/compare.py off=build/996/off qwen=build/996/sweep-qwen/w0.02 [--cases]
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "keyboard-bench"))
import score  # noqa: E402

BENCH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "keyboard-bench")
RUNS = ["fr", "en", "en-typos", "es", "de"]


def quantile(values, q):
    if not values:
        return None
    values = sorted(values)
    return values[min(len(values) - 1, int(q * len(values)))]


def fmt(value):
    return "n/a" if value is None else f"{value:.2f}"


def commit_counts(rows):
    counts = {}
    for r in rows:
        meant, typed, final = score.norm(r["intended"]), score.norm(r["typed"]), score.norm(r["final"])
        c = counts.setdefault(r["lang"], {"broken": 0, "miscorrected": 0, "fixed": 0, "missed": 0})
        if " " in meant:
            continue
        if typed == meant:
            c["broken"] += final != typed
        elif final == meant:
            c["fixed"] += 1
        elif final == typed:
            c["missed"] += 1
        else:
            c["miscorrected"] += 1
    return counts


def summary(directory):
    texts = score.read(os.path.join(directory, "texts.tsv")) or []
    commits = score.read(os.path.join(directory, "commits.tsv")) or []
    taps = score.read(os.path.join(directory, "taps.tsv")) or []
    out = {}
    for r in texts:
        s = out.setdefault(r["lang"], {"wrong": 0, "words": 0})
        meant, got = score.norm(r["intended"]).split(), score.norm(r["final"]).split()
        s["words"] += len(meant)
        s["wrong"] += score.distance(meant, got)
    for lang, c in commit_counts(commits).items():
        out[lang].update(c)
    for lang in out:
        rs = [r for r in commits if r["lang"] == lang and r.get("next")]
        hits = sum(r["next"].lower() in [w.lower() for w in r["predicted"].split(",") if w][:3] for r in rs)
        out[lang]["top3"] = 100 * hits / len(rs) if rs else None
        for key, picked in (("space", lambda t: t == "space"), ("letter", lambda t: t != "space")):
            rows = [r for r in taps if r["lang"] == lang and picked(r["intended"])]
            out[lang][key] = [int(r["engine_us"]) / 1000 for r in rows]
            out[lang][key + "_lm"] = [float(r["lm_ms"]) for r in rows if "lm_ms" in r and float(r["lm_ms"]) > 0]
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("replays", nargs="+", help="label=dir")
    parser.add_argument("--cases", action="store_true")
    args = parser.parse_args()
    replays = [tuple(a.split("=", 1)) for a in args.replays]
    summaries = [(label, summary(d)) for label, d in replays]

    print("| run | replay | wrong words, final text | broken | miscorrected | fixed | missed | next word in top 3 "
          "| engine ms per space p50 / p95 | per letter p50 / p95 | model ms per space p50 / p95 (n) "
          "| per letter p50 / p95 (n) |")
    print("|---|---|---:|---:|---:|---:|---:|---:|---|---|---|---|")
    for run in RUNS:
        for label, s in summaries:
            if run not in s:
                continue
            r = s[run]
            top3 = "n/a" if r["top3"] is None else f"{r['top3']:.1f}%"
            print(f"| {run} | {label} | {r['wrong']} / {r['words']} | {r['broken']} | {r['miscorrected']} | "
                  f"{r['fixed']} | {r['missed']} | {top3} | {fmt(quantile(r['space'], .5))} / "
                  f"{fmt(quantile(r['space'], .95))} | {fmt(quantile(r['letter'], .5))} / "
                  f"{fmt(quantile(r['letter'], .95))} | {fmt(quantile(r['space_lm'], .5))} / "
                  f"{fmt(quantile(r['space_lm'], .95))} ({len(r['space_lm'])}) | "
                  f"{fmt(quantile(r['letter_lm'], .5))} / {fmt(quantile(r['letter_lm'], .95))} "
                  f"({len(r['letter_lm'])}) |")

    if args.cases:
        print()
        cases = score.read(os.path.join(BENCH, "corpus", "fr-pierre-device.cases"))
        finals = {}
        for label, d in replays:
            rows = score.read(os.path.join(d, "texts.tsv")) or []
            finals[label] = {int(r["sentence"]): r["final"] for r in rows if r["lang"] == "fr-pierre-device"}
        print("| typed | before it | Pierre meant | kind | " + " | ".join(label for label, _ in replays) + " |")
        print("|---|---|---|---|" + "---|" * len(replays))
        right = {label: {"wrong": 0, "guard": 0} for label, _ in replays}
        totals = {"wrong": 0, "guard": 0}
        for c in cases:
            sentence, context_words = int(c["sentence"]), int(c["context_words"])
            accepted = [score.norm(a) for a in c["accepted"].split("|")]
            # A guard is a case today's keyboard already gets right; every other case is one it gets wrong.
            cells = []
            for label, _ in replays:
                words = finals[label].get(sentence, "").split()
                got = " ".join(words[context_words:])
                ok = score.norm(got) in accepted
                cells.append(f"{got} {'✓' if ok else '✗'}")
                kind = "guard" if c["kind"] == "guard" else "wrong"
                right[label][kind] += ok
            kind = "guard" if c["kind"] == "guard" else "wrong"
            totals[kind] += 1
            before = " ".join(finals[replays[0][0]].get(sentence, "").split()[:context_words]) or "(start)"
            print(f"| `{c['typed']}` | {before} | {c['accepted'].replace('|', ' or ')} | {c['kind']} | "
                  + " | ".join(cells) + " |")
        print()
        for label, _ in replays:
            print(f"- {label}: {right[label]['wrong']} of {totals['wrong']} non-guard cases right, "
                  f"{right[label]['guard']} of {totals['guard']} guards right")


if __name__ == "__main__":
    main()
