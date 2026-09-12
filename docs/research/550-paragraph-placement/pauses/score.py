#!/usr/bin/env python3
"""Score candidate paragraphing rules against boundaries.json.

Reported, never barred. The constants below were chosen after seeing the data
and this round does not claim they generalise. Their only job is to make the
two rules comparable on the same sixteen points.

Usage: python3 score.py
"""
import json

DATA = json.load(open('boundaries.json'))['fixtures']
SPONTANEOUS = [k for k, v in DATA.items() if v['register'] == 'spontaneous']


def median(xs):
    if not xs:
        return None
    s = sorted(xs)
    n = len(s)
    return s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2


def confusion(fires, keys):
    tp = fp = fn = 0
    for k in keys:
        f = DATA[k]
        want = set(f['reference'])
        for b in f['boundaries']:
            hit = fires(k, b)
            if hit and b['after'] in want:
                tp += 1
            elif hit:
                fp += 1
            elif b['after'] in want:
                fn += 1
    return tp, fp, fn


def absolute(threshold):
    return lambda k, b: b['silence'] >= threshold


def contrast(floor, factor):
    def fires(k, b):
        if b['silence'] < floor:
            return False
        others = [o['silence'] for o in DATA[k]['boundaries'] if o['after'] != b['after']]
        if not others:
            return False          # a single boundary offers no comparison
        m = median(others)
        if m == 0:
            return True
        return b['silence'] / m >= factor
    return fires


def row(label, fires):
    for scope, keys in (('all five', list(DATA)), ('spontaneous only', SPONTANEOUS)):
        tp, fp, fn = confusion(fires, keys)
        print(f"  {label:26s} {scope:18s} found {tp}  invented {fp}  missed {fn}")


def main():
    print("Absolute threshold on the silence at a sentence boundary")
    for t in (0.50, 0.85, 1.00, 1.20, 1.40):
        row(f"threshold {t:.2f}s", absolute(t))
    print()
    print("Contrast against the same dictation's other boundaries")
    for floor, factor in ((1.00, 1.5), (1.00, 1.3), (0.80, 1.5)):
        row(f"floor {floor:.2f}s x{factor}", contrast(floor, factor))
    print()
    print("Mid-sentence silences the boundary condition rejects")
    for k, f in DATA.items():
        for d in f['longMidSentenceSilences']:
            print(f"  fixture {k}: {d:.2f}s")


if __name__ == '__main__':
    main()
