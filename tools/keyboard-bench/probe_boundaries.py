#!/usr/bin/env python3
"""
probe_boundaries.py -- Where does a tap between two Dictus keys go? (#954)

Sweeps taps across each boundary of the Dictus top row, in 0.1 pt steps from 1.2 pt
left of the boundary to 1.2 pt right, on the real keyboard in a simulator. A tap on
"q" (second row, first key) precedes every probe, so a probe that types nothing shows
up as two "q" in a row. Prints, per boundary, the letter each probe typed ("_" for
nothing) and the band of x that typed nothing.

The boundaries are where the in-process replay puts them (main.swift, `grid`): key k
starts at k * 401/10 + k/9 pt on a 402 pt wide keyboard.

Same setup as sim_replay.py --keyboard dictus: the Dictus keyboard showing in
Reminders, French AZERTY, --grid-top read off a screenshot.

Usage:
    python3 -I tools/keyboard-bench/probe_boundaries.py --udid <udid> --grid-top 583.2
"""

import argparse
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim_replay  # noqa: E402

WIDTH = 402
KEYS = 10


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--grid-top", type=float, required=True)
    args = parser.parse_args()
    row_height = 54
    top_y = args.grid_top + row_height / 2
    q = (round((WIDTH - 1) / KEYS / 2, 2), args.grid_top + row_height * 1.5)
    unit = (WIDTH - 1) / KEYS
    gap = 1 / (KEYS - 1)

    for k in range(1, KEYS):
        boundary = k * unit + k * gap
        xs = [round(boundary - 1.2 + 0.1 * i, 2) for i in range(25)]
        sim_replay.new_reminder(args.udid)
        steps = []
        for x in xs:
            steps += ["--step", f"tap -x {q[0]} -y {q[1]:.2f}", "--step", "sleep 0.2",
                      "--step", f"tap -x {x} -y {top_y:.2f}", "--step", "sleep 0.2"]
        steps += ["--step", f"tap -x {q[0]} -y {q[1]:.2f}"]
        subprocess.run(["axe", "batch", "--udid", args.udid] + steps, check=True, capture_output=True)
        typed = [t for t in sim_replay.titles(sim_replay.tree(args.udid)) if t.lower().startswith("q")][-1]
        results = typed[1:].lower().split("q")[:-1]
        dead = [x for x, r in zip(xs, results) if r == ""]
        band = f"{min(dead)}-{max(dead)} pt" if dead else "none"
        print(f"boundary {k} at {boundary:.2f} pt\tdead {band}\t{''.join(r or '_' for r in results)}", flush=True)


if __name__ == "__main__":
    main()
