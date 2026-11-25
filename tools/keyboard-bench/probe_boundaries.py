#!/usr/bin/env python3
"""
probe_boundaries.py -- Where does a tap between two Dictus keys go? (#954)

Sweeps taps across each boundary of the Dictus top row, in 0.1 pt steps from 1.2 pt
left of the boundary to 1.2 pt right, on the real keyboard in a simulator. A tap on
"q" (second row, first key) precedes every probe, so a probe that types nothing shows
up as two "q" in a row. Prints, per boundary, the letter each probe typed ("_" for
nothing) and the band of x that typed nothing.

The boundaries are where the in-process replay puts them (main.swift, `grid`, which
lays the page out with DictusCore's `KeyPlaneGeometry` as the keyboard does): Apple's
keycaps start 6.5 pt in with 6 pt between them, so on a 402 pt wide keyboard key k's
target starts at 3.5 + k * 39.5 pt (the first and last targets reach the edges). Before
that geometry, key k started at k * 401/10 + k/9 pt.

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
# KeyPlaneGeometry.apple(.standard, .portrait): side inset, gap, row pitch, row 1's keycap.
SIDE = 6.5
GAP = 6
ROW_PITCH = 54
ROW1_CAP_TOP = 8
KEY_HEIGHT = 43


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--grid-top", type=float, required=True)
    args = parser.parse_args()
    start = SIDE - GAP / 2
    unit = (WIDTH - 2 * start) / KEYS
    top_y = args.grid_top + ROW1_CAP_TOP + KEY_HEIGHT / 2
    q = (round(start + unit / 2, 2), top_y + ROW_PITCH)

    for k in range(1, KEYS):
        boundary = start + k * unit
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
