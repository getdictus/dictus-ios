#!/usr/bin/env python3
"""Silence detection and speech segmentation for the #550 pause round.

Reads 16 kHz mono WAV files from ./wav and writes segments.json: for each
fixture, the interior silences and the complementary speech segments.

The segments are meant to be cut and transcribed one by one, so that every
pause is bracketed by its exact text on both sides. Nothing here interpolates
a character offset from a speaking rate; that is what limited fixture 7.

Usage:
    ffmpeg -i "Texte A - Pause.m4a" -ac 1 -ar 16000 "wav/Texte A - Pause.wav"
    python3 detect.py
"""
import wave, array, math, glob, os, json

HOP = 0.010          # frame step, seconds
WIN = 0.025          # frame window, seconds
FRAC = 0.55          # threshold placed this far from the noise floor to the speech peak
MERGE_MAXGAP = 0.25  # two silences separated by less than this...
MERGE_DROP = 10.0    # ...and by a peak this many dB under speech level are one silence
MINSIL = 0.25        # silences shorter than this are not reported


def pct(xs, p):
    s = sorted(xs)
    k = (len(s) - 1) * p
    f = int(k)
    c = min(f + 1, len(s) - 1)
    return s[f] + (s[c] - s[f]) * (k - f)


def analyse(path):
    w = wave.open(path, 'rb')
    sr = w.getframerate()
    a = array.array('h')
    a.frombytes(w.readframes(w.getnframes()))
    hop, win = int(sr * HOP), int(sr * WIN)
    nf = (len(a) - win) // hop + 1

    db = []
    for i in range(nf):
        seg = a[i * hop:i * hop + win]
        s = 0
        for v in seg:
            s += v * v
        db.append(20 * math.log10(math.sqrt(s / len(seg)) / 32768.0 + 1e-9))

    # The five fixtures span 20.0 dB to 33.7 dB of dynamic range. A single
    # absolute threshold in dB does not work across them, so it is placed
    # relative to each recording's own floor and peak.
    floor, peak = pct(db, 0.10), pct(db, 0.95)
    thr = floor + (peak - floor) * FRAC
    speech = [d for d in db if d >= thr]
    level = pct(speech, 0.50) if speech else peak
    dur = len(a) / sr

    sil = [d < thr for d in db]
    runs, i = [], 0
    while i < len(sil):
        if sil[i]:
            j = i
            while j < len(sil) and sil[j]:
                j += 1
            runs.append([i * HOP, j * HOP])
            i = j
        else:
            i += 1

    # The breath rule. A single pause is otherwise reported as two: measured at
    # 12 dB under speech in fixture A and 15 to 19 dB in fixture D.
    merged = []
    for r in runs:
        if merged:
            gs, ge = merged[-1][1], r[0]
            gi, gj = int(gs / HOP), max(int(ge / HOP), int(gs / HOP) + 1)
            top = max(db[gi:gj]) if gj > gi else floor
            if ge - gs <= MERGE_MAXGAP and top < level - MERGE_DROP:
                merged[-1][1] = r[1]
                continue
        merged.append(r)

    inter = [(s, e) for s, e in merged
             if e - s >= MINSIL and s > 0.10 and e < dur - 0.15]
    return inter, dur, floor, peak, thr, level


def main():
    out = {}
    for p in sorted(glob.glob('wav/*.wav')):
        name = os.path.basename(p)[:-4]
        inter, dur, fl, pk, thr, lvl = analyse(p)
        segs, prev = [], 0.0
        for s, e in inter:
            segs.append((prev, s))
            prev = e
        segs.append((prev, dur))
        out[name] = {
            'duration': round(dur, 3),
            'noiseFloorDb': round(fl, 1),
            'speechPeakDb': round(pk, 1),
            'thresholdDb': round(thr, 1),
            'silences': [[round(s, 3), round(e, 3), round(e - s, 3)] for s, e in inter],
            'segments': [[round(a, 3), round(b, 3)] for a, b in segs],
        }
        print(f"{name:18s} range={pk-fl:4.1f}dB thr={thr:6.1f}dB  {len(inter)} silences")
    json.dump(out, open('segments.json', 'w'), indent=1)


if __name__ == '__main__':
    main()
