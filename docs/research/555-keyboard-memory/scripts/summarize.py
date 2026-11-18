import sys, statistics
# summarize.py <run dir>: footprint per phase from samples.tsv and phases.tsv (MB = 2^20 bytes).
d = sys.argv[1]
ph = {}
for line in open(f"{d}/phases.tsv"):
    t, name = line.split("\t"); ph[name.strip()] = int(t)
s = [(int(t), int(p), int(b)) for t, p, b in (l.split("\t") for l in open(f"{d}/samples.tsv") if l.count("\t") == 2 and l.split("\t")[2].strip())]
def win(a, b): return [x[2] / 1048576 for x in s if ph[a] <= x[0] <= ph[b]]
rest = win("rest-start", "rest-end"); fr = win("rest-end", "fr-end"); en = win("fr-end", "en-end"); rest2 = win("rest2-start", "rest2-end")
pids = sorted({x[1] for x in s})
print(f"pids {pids} samples {len(s)}")
print(f"rest median {statistics.median(rest):.1f}")
print(f"fr typing: peak {max(fr):.1f} end {fr[-1]:.1f}")
print(f"en typing: peak {max(en):.1f} end {en[-1]:.1f}")
print(f"rest after median {statistics.median(rest2):.1f}")
print(f"session peak {max(x[2] for x in s)/1048576:.1f}")
