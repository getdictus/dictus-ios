"""Phase 1 table: decode time, RTF, WebContent memory and WER per clip, for
each bench JSONL given, against dictus-test-voices and against the native
Parakeet v3 text (FluidAudio, Core ML) captured for #932.

    python3 -I scripts/score.py ~/dev/dictus-test-voices <bench.jsonl>...

Tokenizing and alignment are tools/closing-phrase-bench/score.py's, so the WER
is computed exactly as the #932 report computes it.
"""
import json
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "../../.."))
sys.path.insert(0, os.path.join(REPO, "tools/closing-phrase-bench"))
from score import align, tokens  # noqa: E402

NATIVE_TSV = os.path.join(REPO, "docs/research/932-invented-closing-phrases/before-parakeet-v3.tsv")
SHORTS = ["fr-01-spoken-punctuation", "fr-02-appointment-numbers", "fr-03-shopping", "fr-04-question-mark"]


def wer(ref, hyp, prefix=False):
    r, h = tokens(ref, "fr"), tokens(hyp, "fr")
    errors, _, n = align(r, h, prefix=prefix)
    return errors / max(n, 1)


def main():
    corpus, files = sys.argv[1], sys.argv[2:]
    manifest = json.load(open(os.path.join(corpus, "manifest.json")))
    refs = {os.path.basename(c["file"])[:-4]: c["text"] for c in manifest["clips"]}
    refs["fr-concat-4short"] = " ".join(refs[s] for s in SHORTS)
    refs["fr-long-first60s"] = refs["fr-long-01-workday-sync-fix"]
    native = {}
    for line in open(NATIVE_TSV, encoding="utf-8"):
        f = line.rstrip("\n").split("\t")
        if f[0] == "parakeet-v3" and f[4] == "clean" and f[3] == "fr":
            native[os.path.basename(f[2])[:-4]] = f[6]

    for path in files:
        events = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]
        print(f"\n### {os.path.basename(path)}\n")
        for model in dict.fromkeys(e["model"] for e in events if e.get("type") == "modelLoaded"):
            load = next(e for e in events if e.get("type") == "modelLoaded" and e["model"] == model)
            rows = [e for e in events if e.get("type") == "benchResult" and e["model"] == model]
            mem = [e.get("webContentFootprintMB") for e in events
                   if e.get("model", model) == model and e.get("webContentFootprintMB")]
            print(f"**{model}**: load {load['totalMs']} ms (fetch {load['fetchMs']}, settle {load.get('settleMs', 0)}, "
                  f"create {load['createMs']}), wasm heap {load['heapBytes'] >> 20} MB, "
                  f"WebContent at load {load.get('webContentFootprintMB', '?')} MB\n")
            print("| clip | audio s | decode ms (median) | RTF | WER webview | WER native Parakeet | text (webview) |")
            print("|---|---|---|---|---|---|---|")
            for clip in dict.fromkeys(r["clip"] for r in rows):
                runs = [r for r in rows if r["clip"] == clip]
                key = clip[:-4]
                ms = statistics.median(r["decodeMs"] for r in runs)
                text = runs[-1]["text"]
                prefix = key == "fr-long-first60s"
                w = wer(refs[key], text, prefix)
                n = f"{wer(refs[key], native[key]):.1%}" if key in native else "n/a"
                print(f"| {key} | {runs[0]['audioSec']:.1f} | {ms:.0f} | {ms / 1000 / runs[0]['audioSec']:.2f} "
                      f"| {w:.1%} | {n} | {text[:70]}{'…' if len(text) > 70 else ''} |")
            if mem:
                print(f"\nWebContent footprint over the run: max {max(mem)} MB, last {mem[-1]} MB")


if __name__ == "__main__":
    main()
