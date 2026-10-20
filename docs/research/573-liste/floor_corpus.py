#!/usr/bin/env python3
"""Build and score corpus C, the short-input floor measurement (bars.md §6).

Corpus C is the maintainer's own dictations, read from his polish debug exports. They are
private messages and stay out of the repository: `build` writes the fixture file wherever
it is told (never under docs/), and `score` writes only numbers — a hash of each text, its
length, and how many bullets each run produced.

    # 1. Fixtures from the exports (paths to the export JSON files, any number):
    python3 floor_corpus.py build /tmp/573-floor-corpus.json ~/exports/*.json

    # 2. The run, 2 per dictation, transcript language detected:
    cd DictusCore && .build/debug/polish-harness fidelity /tmp/573-floor-corpus.json \
        --mode notes --runs 2 --json /tmp/573-floor-capture.json > /dev/null

    # 3. The curve and the per-dictation numbers that get committed:
    python3 floor_corpus.py score /tmp/573-floor-corpus.json /tmp/573-floor-capture.json floor/
"""

import hashlib
import json
import re
import sys
from pathlib import Path

MAX_CHARACTERS = 300
GRID = list(range(50, 301, 25))


def text_id(raw):
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:10]


def build(out_path, export_paths):
    seen = {}
    exports = 0
    for path in export_paths:
        try:
            data = json.loads(Path(path).read_text())
        except (OSError, ValueError):
            continue
        if not isinstance(data, dict) or "events" not in data:
            continue
        exports += 1
        for event in data["events"]:
            raw = event.get("raw")
            if raw and len(raw) <= MAX_CHARACTERS:
                seen.setdefault(raw, event.get("timestamp"))
    fixtures = [{"id": text_id(raw), "lang": "auto", "sttEngine": "PK", "raw": raw}
                for raw in sorted(seen, key=len)]
    Path(out_path).write_text(json.dumps(fixtures, ensure_ascii=False, indent=1))
    print(f"{exports} exports read, {len(fixtures)} distinct dictations of ≤ {MAX_CHARACTERS} "
          f"characters written to {out_path}")


def bullets(output):
    """Bullet lines after the title, which is how decision 2's shape counts points."""
    return sum(1 for line in output.split("\n") if line.startswith("- "))


def score(corpus_path, capture_path, out_dir):
    lengths = {f["id"]: len(f["raw"]) for f in json.loads(Path(corpus_path).read_text())}
    runs = [r for r in json.loads(Path(capture_path).read_text()) if r.get("hasEngineOutput", True)]
    per_text = {}
    for r in runs:
        per_text.setdefault(r["fixture"], []).append({
            "run": r["run"], "outcome": r["outcome"], "rejectedCheck": r.get("rejectedCheck"),
            "bullets": bullets(r["output"]),
        })
    rows = [{"id": key, "characters": lengths[key], "runs": sorted(value, key=lambda v: v["run"])}
            for key, value in per_text.items()]
    rows.sort(key=lambda row: (row["characters"], row["id"]))
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    (out / "per-dictation.json").write_text(json.dumps(rows, indent=1))

    flat = [(row["characters"], run["bullets"]) for row in rows for run in row["runs"]]
    lines = [f"Corpus C: {len(rows)} dictations, {len(flat)} scored runs "
             f"({len(lengths) - len(rows)} dictations with no engine output in any run).", ""]
    lines.append("Runs with ≤ 1 bullet / runs, per length bucket:")
    for low in range(0, MAX_CHARACTERS, 25):
        cell = [b for c, b in flat if low <= c < low + 25]
        if cell:
            lone = sum(b <= 1 for b in cell)
            lines.append(f"  {low:3}-{low + 24:3}  {lone:3}/{len(cell):<3}  ({100 * lone / len(cell):3.0f} %)")
    lines += ["", "Floor F   A(F) lone dash-lines left ≥ F   B(F) lists lost < F   A+B"]
    best = None
    for floor in GRID:
        a = sum(1 for c, b in flat if c >= floor and b <= 1)
        b = sum(1 for c, b in flat if c < floor and b >= 2)
        lines.append(f"  {floor:3}      {a:4}                          {b:4}                {a + b:4}")
        if best is None or a + b < best[1]:
            best = (floor, a + b)
    lines += ["", f"Decision rule (bars.md §6): minimum A+B, ties to the lower F → F = {best[0]}"]
    report = "\n".join(lines)
    (out / "curve.txt").write_text(report + "\n")
    print(report)


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "build":
        build(sys.argv[2], sys.argv[3:])
    elif len(sys.argv) == 5 and sys.argv[1] == "score":
        score(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        print(__doc__)
        raise SystemExit(2)


if __name__ == "__main__":
    main()
