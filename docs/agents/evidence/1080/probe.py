"""#1080: which key a keyboard types at given screen points, after a given word.

Usage: python3 -I probe.py <axe> <udid> 0 0 <points-file> <keys.json>
The focused field is the Settings search field. For each line `context x y` of the
points file: clear the field with backspace taps, type the context by tapping the key
centres of keys.json, tap (x, y), and print the field before and after the tap, and
whether the keyboard is still up (a Return in a search field runs the search and
closes it)."""
import json, subprocess, sys, time
AXE, UDID, FX, FY, PTS = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), sys.argv[5]
KEYS = {}  # letter -> centre, filled from argv[6] json if given
if len(sys.argv) > 6:
    KEYS = json.load(open(sys.argv[6]))

def ax(*a):
    return subprocess.run([AXE, *a, "--udid", UDID], capture_output=True, text=True)

def nodes():
    out = ax("describe-ui").stdout
    res = []
    def w(n):
        res.append(n)
        for c in n.get("children", []): w(c)
    d = json.loads(out)
    for n in d if isinstance(d, list) else [d]: w(n)
    return res

def field_value():
    for n in nodes():
        if n.get("type") in ("TextField", "SearchField", "TextArea"):
            v = n.get("AXValue")
            return v
    return None

def keyboard_up():
    return any(n.get("AXLabel") in ("C", "c", "Clavier suivant") and n.get("type") == "Button" for n in nodes())

def tap(x, y):
    ax("tap", "-x", f"{x:.1f}", "-y", f"{y:.1f}")
    time.sleep(0.35)

for line in open(PTS):
    line = line.strip()
    if not line or line.startswith("#"): continue
    ctx, x, y = line.split()
    x, y = float(x), float(y)
    # clear: focus field, delete up to 12 chars
    if not keyboard_up():
        f = next(n["frame"] for n in nodes() if n.get("type") in ("TextField", "SearchField", "TextArea"))
        tap(f["x"] + f["width"] / 2, f["y"] + f["height"] / 2)
        time.sleep(0.8)
    for _ in range(9):
        tap(*KEYS["backspace"])
    for ch in ctx:
        tap(*KEYS[ch])
    before = field_value()
    tap(x, y)
    time.sleep(0.4)
    after = field_value()
    print(f"{ctx}\t{x:.1f}\t{y:.1f}\tbefore={before!r}\tafter={after!r}\tkeyboard_up={keyboard_up()}", flush=True)
