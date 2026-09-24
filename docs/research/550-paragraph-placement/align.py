import subprocess, re, sys, unicodedata

def silences(path, noise, dmin=0.20):
    out = subprocess.run(["ffmpeg","-hide_banner","-nostats","-i",path,"-af",
        f"silencedetect=noise={noise}dB:d={dmin}","-f","null","-"],
        capture_output=True, text=True).stderr
    st = [float(m) for m in re.findall(r"silence_start: ([\d.]+)", out)]
    en = [float(m) for m in re.findall(r"silence_end: ([\d.]+)", out)]
    iv = list(zip(st, en))
    merged = []                       # merge touching intervals
    for s, e in iv:
        if merged and s - merged[-1][1] < 0.02: merged[-1][1] = e
        else: merged.append([s, e])
    return [(s, e) for s, e in merged if e - s >= dmin]

def duration(path):
    return float(subprocess.run(["ffprobe","-v","error","-show_entries","format=duration",
        "-of","csv=p=0",path], capture_output=True, text=True).stdout.strip())

def analyse(name, path, text, breaks, noise=-25):
    D = duration(path)
    sil = silences(path, noise)
    # speech = complement, trimmed of leading/trailing silence
    lead = sil[0][1] if sil and sil[0][0] < 0.3 else 0.0
    tail = sil[-1][0] if sil and sil[-1][1] > D - 0.3 else D
    inner = [(s, e) for s, e in sil if s >= lead and e <= tail]
    speech = (tail - lead) - sum(e - s for s, e in inner)
    sents, pos, i = [], [], 0
    for m in re.finditer(r"[^.!?…]+[.!?…]+", text):
        i = m.end(); sents.append(m.group().strip()); pos.append(i)
    N = len(text)
    def t_of(c):                       # char -> time, walking speech only
        target = speech * c / N; t = lead; acc = 0.0
        for s, e in inner:
            seg = s - t
            if acc + seg >= target: return t + (target - acc)
            acc += seg; t = e
        return t + (target - acc)
    print(f"\n### {name}   {D:.1f}s   speech {speech:.1f}s   {len(sents)} sentences   noise {noise}dB")
    for k, c in enumerate(pos[:-1]):
        t = t_of(c)
        near = [(s, e) for s, e in inner if s - 0.9 <= t <= e + 0.9]
        d = max((e - s for s, e in near), default=0.0)
        mark = "  <<< TYPELESS BREAK" if k in breaks else ""
        tag = f"pause {d:.2f}s" if d else "no pause"
        print(f"  boundary {k+1} @ ~{t:5.1f}s  {tag:>12}   after «…{sents[k][-34:]}»{mark}")
    other = []
    for s, e in inner:
        mid = (s + e) / 2
        if not any(abs(t_of(c) - mid) < 1.1 for c in pos[:-1]): other.append((s, e - s))
    if other:
        print("  mid-sentence pauses: " + ", ".join(f"{s:.1f}s/{d:.2f}" for s, d in other))
