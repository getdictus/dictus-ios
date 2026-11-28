#!/usr/bin/env python3
"""Type the a/à corpus on Apple's French keyboard in Reminders, word by word.
After each word's space, read the title back. Before the space that commits an a/à
token, screenshot and OCR the predictive bar. Writes one JSON line per sentence."""
import json, subprocess, sys, time, unicodedata, os
U, corpus, out = sys.argv[1], sys.argv[2], sys.argv[3]
start = int(sys.argv[4]) if len(sys.argv) > 4 else 0
HERE = os.path.dirname(os.path.abspath(__file__))
INTERVAL = 0.17

def nodes():
    d = json.loads(subprocess.run(["axe", "describe-ui", "--udid", U], capture_output=True, text=True, timeout=30).stdout)
    out = []
    def w(n):
        out.append(n); [w(c) for c in n.get("children", [])]
    [w(n) for n in (d if isinstance(d, list) else [d])]
    return out

def frames(ns):
    f = {}
    for n in ns:
        l, fr = n.get("AXLabel"), n.get("frame")
        if n.get("type") == "Button" and l and fr and fr["height"] > 0:
            f[l if len(l) > 1 else l.lower()] = (fr["x"] + fr["width"] / 2, fr["y"] + fr["height"] / 2)
    return f

def title(ns):
    v = [n.get("AXValue") or "" for n in ns if n.get("type") == "TextField" and n.get("AXLabel") == "Titre"]
    return v[0] if v else None

def fold(w):
    return "".join(c for c in unicodedata.normalize("NFD", w) if not unicodedata.combining(c))

def is_target(w):
    f = fold(w).lower()
    return f == "a" or f.endswith("'a")

def new_reminder():
    subprocess.run(["xcrun", "simctl", "terminate", U, "com.apple.reminders"], capture_output=True)
    subprocess.run(["xcrun", "simctl", "launch", U, "com.apple.reminders"], check=True, capture_output=True, timeout=30)
    time.sleep(2.5)
    subprocess.run(["axe", "tap", "--label", "Rappel", "--udid", U], check=True, capture_output=True, timeout=30)
    time.sleep(1.5)

def batch(points):
    steps = []
    for i, (x, y, pause) in enumerate(points):
        if i: steps += ["--step", f"sleep {pause:.2f}"]
        steps += ["--step", f"tap -x {x:.1f} -y {y:.1f}"]
    subprocess.run(["axe", "batch", "--udid", U] + steps, check=True, capture_output=True, timeout=60)

def ocr_bar(tag):
    png = os.path.join(out + ".shots", f"{tag}.png")
    subprocess.run(["xcrun", "simctl", "io", U, "screenshot", png], capture_output=True, timeout=30)
    slots = subprocess.run([os.path.join(HERE, "ocr", "ocr"), png, "0.615", "0.675"], capture_output=True, text=True).stdout
    band = subprocess.run([os.path.join(HERE, "ocr", "band"), png, "0.615", "0.675"], capture_output=True, text=True).stdout.strip()
    s = dict(l.split("\t", 1) for l in slots.splitlines() if "\t" in l)
    return {"left": s.get("0", ""), "middle": s.get("1", ""), "right": s.get("2", ""), "band": band}

def run_sentence(s, sentence):
    for attempt in range(3):
        new_reminder()
        ns = nodes()
        if title(ns) == "" and "e" in frames(ns):
            break
    else:
        raise RuntimeError("no empty title")
    letters = frames(ns)
    words = sentence.split()
    states, bars = [], {}
    for j, w in enumerate(words):
        typed = fold(w).lower()
        for part_i, part in enumerate(typed.split("'")):
            if part_i:
                # Apostrophe: 123 page, ', back to letters (this simulator stays on 123).
                batch([letters["nombres"] + (0,)]); time.sleep(0.4)
                f2 = frames(nodes())
                batch([f2["'"] + (0,)]); time.sleep(0.4)
                f3 = frames(nodes())
                if "e" not in f3:
                    batch([f3["lettres"] + (0,)]); time.sleep(0.4)
            if part:
                batch([letters[c] + (INTERVAL,) for c in part])
        if is_target(w):
            time.sleep(0.6)
            bars[j] = ocr_bar(f"{s:03d}-{j}")
        batch([letters[" "] + (0,)])
        time.sleep(0.6)
        states.append(title(nodes()))
    return states, bars

os.makedirs(out + ".shots", exist_ok=True)
rows = [l.rstrip("\n").split("\t") for l in open(corpus, encoding="utf-8") if l.strip() and not l.startswith("#")][1:]
mode = "w" if start == 0 else "a"
with open(out, mode, encoding="utf-8") as fo:
    for s, row in enumerate(rows):
        case, sentence = row[0], row[1]
        if s < start: continue
        for tries in range(4):
            try:
                states, bars = run_sentence(s, sentence)
                break
            except Exception as e:
                print(f"sentence {s}: retry after {type(e).__name__}: {e}", flush=True)
        else:
            raise SystemExit(f"sentence {s}: failed 4 times")
        rec = {"s": s, "case": case, "sentence": sentence, "states": states, "bars": bars}
        fo.write(json.dumps(rec, ensure_ascii=False) + "\n"); fo.flush()
        print(s, states[-1], {k: v["band"] for k, v in bars.items()}, flush=True)
