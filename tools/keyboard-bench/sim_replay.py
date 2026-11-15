#!/usr/bin/env python3
"""
sim_replay.py -- Type the touch runs on a real keyboard in a simulator (#954).

Sends the runs' taps as real touches with `axe`, into the title of a Reminders
reminder, and reads back what the keyboard wrote. Only the final text is observable,
so the output is a texts.tsv that score.py reads like any other source.

Two keyboards:

  --keyboard apple   Apple's keyboard. It lists its keys and their frames in the
                     accessibility tree, so each tap is placed as on Dictus: the
                     intended key's centre plus the run's offset, in key units.
  --keyboard dictus  The Dictus keyboard. Its keys are not in the accessibility
                     tree, so the taps are the points the in-process replay
                     computed (taps.tsv from run.sh), moved down by --grid-top, the
                     screen y of the key grid's top edge. This checks that the
                     in-process replay types what the real keyboard types.

Before running, on a booted simulator:
  1. The keyboard under test is the one Reminders shows: Apple's French AZERTY for
     fr, Apple's English QWERTY for en, or Dictus (long-press the globe to pick it).
  2. Reminders has been opened once, past its welcome and iCloud screens.
For each sentence the script relaunches Reminders, opens a new reminder and types the
sentence in its title. Relaunching is the reset: the return key opens the reminder's
detail sheet instead of a new row.

Usage:
    python3 -I tools/keyboard-bench/sim_replay.py --udid <udid> --lang fr --keyboard apple \
        --bench tools/keyboard-bench --out build/keyboard-bench/apple-fr
    python3 -I tools/keyboard-bench/sim_replay.py --udid <udid> --lang fr --keyboard dictus \
        --taps build/keyboard-bench/out/taps.tsv --grid-top 583.2 \
        --bench tools/keyboard-bench --out build/keyboard-bench/dictus-sim-fr
"""

import argparse
import csv
import json
import os
import subprocess
import time

REMINDERS = "com.apple.reminders"


def tree(udid):
    out = subprocess.run(["axe", "describe-ui", "--udid", udid], check=True, capture_output=True, text=True).stdout
    nodes = []

    def walk(n):
        nodes.append(n)
        for c in n.get("children", []):
            walk(c)

    data = json.loads(out)
    for n in data if isinstance(data, list) else [data]:
        walk(n)
    return nodes


def apple_keys(nodes):
    """Apple's letter keys and space bar, by what they type, with their frames."""
    found = {}
    for n in nodes:
        label, frame = n.get("AXLabel"), n.get("frame")
        if n.get("type") != "Button" or not label or not frame or frame["height"] == 0:
            continue
        if len(label) == 1 and label.isalpha():
            found[label.lower()] = frame
        elif label == " ":
            found["space"] = frame
    return found


def titles(nodes):
    return [n.get("AXValue") or "" for n in nodes if n.get("type") == "TextField" and n.get("AXLabel") in ("Titre", "Title")]


def new_reminder(udid):
    subprocess.run(["xcrun", "simctl", "terminate", udid, REMINDERS], capture_output=True)
    subprocess.run(["xcrun", "simctl", "launch", udid, REMINDERS], check=True, capture_output=True)
    time.sleep(2.5)
    subprocess.run(["axe", "tap", "--label", "Rappel", "--udid", udid], check=True, capture_output=True)
    time.sleep(1.5)


def apple_points(lang, sentence, taps, nodes):
    frames = apple_keys(nodes)
    if "e" not in frames:
        raise SystemExit(f"sentence {sentence}: Apple's keyboard is not on its letter page")
    first = "a" if lang == "fr" else "q"
    if min(frames.values(), key=lambda f: (f["y"], f["x"])) != frames.get(first):
        raise SystemExit(f"sentence {sentence}: the top row does not start with {first!r}; switch to the {lang} keyboard")
    unit = frames["e"]["width"]
    points = []
    for key, dx, dy, _ in taps:
        f = frames[key]
        points.append((f["x"] + f["width"] / 2 + dx * unit, f["y"] + f["height"] / 2 + dy * f["height"]))
    return points


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--lang", required=True)
    parser.add_argument("--keyboard", choices=["apple", "dictus"], required=True)
    parser.add_argument("--bench", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--taps", help="dictus: the taps.tsv the in-process replay wrote")
    parser.add_argument("--grid-top", type=float, help="dictus: screen y of the key grid's top edge, in points")
    args = parser.parse_args()
    if args.keyboard == "dictus" and (args.taps is None or args.grid_top is None):
        parser.error("--keyboard dictus needs --taps and --grid-top")
    os.makedirs(args.out, exist_ok=True)

    with open(os.path.join(args.bench, "corpus", f"{args.lang}.txt"), encoding="utf-8") as f:
        sentences = [line.strip() for line in f if line.strip()]
    runs = {}
    with open(os.path.join(args.bench, "runs", f"{args.lang}.tsv"), encoding="utf-8") as f:
        for r in csv.DictReader((line for line in f if not line.startswith("#")), delimiter="\t"):
            runs.setdefault(int(r["sentence"]), []).append((r["key"], float(r["dx"]), float(r["dy"]), int(r["t_ms"])))
    replayed = {}
    if args.taps:
        with open(args.taps, encoding="utf-8") as f:
            for r in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
                if r["lang"] == args.lang:
                    replayed.setdefault(int(r["sentence"]), []).append((float(r["x"]), float(r["y"]) + args.grid_top))

    out = ["lang\tsentence\tintended\tfinal"]
    for s, intended in enumerate(sentences):
        new_reminder(args.udid)
        nodes = tree(args.udid)
        before = titles(nodes)
        if before.count("") != 1:
            raise SystemExit(f"sentence {s}: expected one empty reminder title, found {before}")
        slot = before.index("")
        points = apple_points(args.lang, s, runs[s], nodes) if args.keyboard == "apple" else replayed[s]
        # The run's own rhythm. Back to back, with no pause, the Dictus keyboard dropped
        # three letters in twenty sentences that the in-process replay typed.
        steps = []
        times = [t for _, _, _, t in runs[s]]
        for i, (x, y) in enumerate(points):
            if i > 0:
                steps += ["--step", f"sleep {(times[i] - times[i - 1]) / 1000:.3f}"]
            steps += ["--step", f"tap -x {x:.2f} -y {y:.2f}"]
        subprocess.run(["axe", "batch", "--udid", args.udid] + steps, check=True, capture_output=True)
        final = titles(tree(args.udid))[slot].strip()
        out.append(f"{args.lang}\t{s}\t{intended}\t{final}")
        print(f"{s}\t{final}", flush=True)

    with open(os.path.join(args.out, "texts.tsv"), "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
