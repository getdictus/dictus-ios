# Go/no-go: Parakeet in WebKit (keyboard extension, hidden WKWebView)

2026-11-20, branch `spike/webview-parakeet`. All figures come from the iOS 26.5
simulator (iPhone 15 Pro Max device type) on an M-series Mac. **No iPhone was
measured**: the device build is ready and not installed (install command at the
end). Method, sources and the device protocol are in [README.md](README.md).

## Verdict

**Parakeet 0.6B in WebKit: NO-GO.** It works, but it's too heavy and too slow
for a keyboard.

- **Memory.** WebContent peaks at **1.53–1.55 GB** and stays there.
  - That's above WebKit's own 1.5 GB soft limit for iPhone.
  - The headroom under the measured 2 GB hard kill
    ([forum 823061](https://developer.apple.com/forums/thread/823061)) is only
    about 0.45 GB.
  - The wasm heap never shrinks, and it reaches 1.49 GB after a 72 s clip.
- **Speed.**
  - A 60 s French dictation takes **23 s** to decode on an M-series core.
  - WebAssembly runs on one thread here. Threads need cross-origin isolation,
    and a page served by `WKURLSchemeHandler` doesn't get it
    (`crossOriginIsolated=false`, measured).
  - An A17 Pro won't be faster than a Mac core, so on the phone a minute of
    speech means a wait of about 20–30 s.
  - The native app runs Parakeet on the Neural Engine, which WebKit can't reach.
- **Quality.** On the corpus it's Parakeet's, drift included.
  - On short clips it equals native: 8.0 % vs 10.0 % WER.
  - On ≥15 s of French it drifts into English exactly as the native first pass
    does (#623). The native retry would have to be rebuilt in JS.

**The smallest useful model: conditional GO, as a second-tier engine, not as
Parakeet.**

- **Parakeet 110M doesn't qualify.** sherpa-onnx's only 110M Parakeet
  (`parakeet_tdt_ctc_110m-en`) is English-only.
- **The "redux" 0.6B isn't lighter.** Its encoder is the same 652 MB.
- **The smallest useful French models are FastConformer transducers**, 114M
  parameters, int8, 136 MB:
  - `fastconformer-14288` (en/de/es/fr);
  - `fastconformer-20k` (10 European languages).
- **What they do:**
  - WebContent **0.50 GB** loaded, **0.82 GB** peak after 60 s.
  - **RTF 0.08–0.10**: 60 s decodes in **5.5 s**.
  - No drift: **6–8 % WER on the long French clip**, against 83 % for native
    Parakeet's first pass.
- **What they cost on short dictations: 26 % WER**, against 8–10 % for
  Parakeet.
  - Numbers come out spelled out ("quatorze mars à neuf heures trente").
  - The first word or two is often dropped.
  - Part of that 26 % is number formatting, so this is an upper bound on how
    much worse they are.
- **Whether it holds on a phone is still open.** The device run must answer
  three things:
  - Does `getUserMedia` capture inside the keyboard?
  - Does WebContent survive in a keyboard client?
  - What is the real iPhone RTF?

What's already established, in the simulator:

- **The keyboard stays small.** While it streams a 650 MB model to WebContent
  and decodes, the keyboard process stays at **18–31 MB**, against a ceiling of
  ~68 MB.
- **It inserts text** through `textDocumentProxy` **without Full Access**.

## Numbers (simulator, one thread, fresh app launch per model)

Corpus: `dictus-test-voices@6eeeb0f`, French. The clips used:

| clip | what it is |
|---|---|
| 5 s | the 4 short clips (4.1–5.1 s) |
| 15 s | the first 15.0 s of `fr-long-01` |
| 18 s | the 4 short clips concatenated |
| 60 s | the first 60.0 s of `fr-long-01` |
| 72 s | the whole `fr-long-01` |

- **Decode** is the median of 2 runs.
- **Load** runs from page ready to recognizer ready. It includes a deliberate
  2 s pause that keeps the load peak down. Without it, WebContent peaked at
  2.15 GB on the Mac.
- **Memory** is WebContent `phys_footprint`.
- **WER** is computed as in #932 (`tools/closing-phrase-bench/score.py`). The
  15 s and 60 s cuts are scored against the best-aligning prefix of the
  reference.
- **Native** is FluidAudio Parakeet v3 (Core ML), first pass, from
  `docs/research/932-invented-closing-phrases/before-parakeet-v3.tsv`. It only
  exists for the 5 corpus clips.

### Load and memory

| model | size | load | WebContent at load (peak) | after 5 s | after 15 s | after 60 s | wasm heap max |
|---|---|---|---|---|---|---|---|
| Parakeet TDT 0.6B v3 int8 | 670 MB | 3.6 s | **1535 MB** (1547) | 1537 MB | 997 MB¹ | 1425 MB | 1493 MB |
| FastConformer 14288 int8 | 138 MB | 2.7 s | 493 MB | 503 MB | 547 MB | 820 MB | 729 MB |
| FastConformer 20k int8 | 138 MB | 3.2 s | 517 MB | 500 MB | 546 MB | 816 MB | 729 MB |

¹ The 15 s reading falls while WebKit is releasing the JS copy of the model
file. The settled ("steady") figure is the 5 s column for each model: 1.54 GB,
0.50 GB and 0.50 GB.

The host process (app or keyboard) stays at 18–49 MB in every run.

### Decode time

| model | 5 s (×4 clips) | 15 s | 18 s | 60 s | 72 s | RTF |
|---|---|---|---|---|---|---|
| Parakeet 0.6B v3 | 1.50–1.86 s | 5.42 s | 6.57 s | **23.26 s** | 27.36 s | 0.36–0.39 |
| FastConformer 14288 | 0.34–0.40 s | 1.20 s | 1.49 s | 5.51 s | 6.60 s | 0.08–0.09 |
| FastConformer 20k | 0.31–0.39 s | 1.18 s | 1.39 s | 5.49 s | 6.83 s | 0.08–0.10 |

Mac baseline, same wasm under Node 22: Parakeet decodes 4.4 / 18.4 / 60 s in
1.5 / 6.2 / 21.9 s. That matches the simulator, so the simulator WebKit is not
adding a penalty. macOS WKWebView off screen is throttled by WebKit, 2–4× slower;
those timings are not used.

### WER (aggregate over words)

| | 4 short clips (50 words) | 5 corpus clips, long included (278 words) | 15 s cut | 60 s cut |
|---|---|---|---|---|
| **native Parakeet v3 (Core ML)** | 10.0 % | 69.8 % (long clip drifts) | n/a | n/a |
| Parakeet v3, WebKit | **8.0 %** | 79.5 % (same drift) | drifts (120 %) | drifts |
| FastConformer 14288, WebKit | 26.0 % | **9.7 %** | 10.9 % | 7.9 % |
| FastConformer 20k, WebKit | 26.0 % | 10.1 % | **6.5 %** | **7.4 %** |

Per-clip texts: `results/sim-v2-table.md`. Raw data:
`results/sim-v2-<model>.jsonl`.

Two notes on the long-clip figures:

- The native app reruns a drifting Parakeet decode on shorter windows (#623),
  which this bench doesn't. The 70–80 % figures are first passes, for both
  native and WebKit.
- The corpus is ElevenLabs French. Pierre's own recordings folder is empty.

## Phase 0 facts that bound the verdict

Sources are in [README.md](README.md#phase-0-desk-check).

- **WebContent on iPhone:** WebKit assumes 1.5 GB soft and 2 GB hard, and a
  kill at 2048 MB was measured on iOS 26. The increased-memory entitlement
  doesn't apply to WebContent.
- **WebAssembly memory:** wasm32 is capped at 4 GiB. In the simulator one
  `WebAssembly.Memory` reached 2.5 GB.
- **No threads:** a `WKURLSchemeHandler` page is a secure context, but it isn't
  cross-origin isolated, so there's no `SharedArrayBuffer`. Measured on iOS
  26.5, and the same was reported on an iPad. The workaround would be a
  loopback HTTP server inside the keyboard. Not tried, and on its own it would
  at best divide the 23 s by the core count.
- **WebGPU** is exposed in WKWebView. The only Parakeet WebGPU path, parakeet.js,
  runs the encoder in fp32: 2.4 GB, over the WebContent ceiling.

## Device build: ready, not installed

A standalone spike app plus keyboard: `com.pivi.dictus.spike` and
`com.pivi.dictus.spike.keyboard`, with no App Group.

- **Size:** 941 MB, with all three models inside the keyboard bundle.
- **Signing:** the team wildcard profile, which lists the iPhone 15 Pro Max.
  The signature verifies, and the profile expires 2027-08-06.
- **Doesn't touch Dictus:** it never replaces Dictus on the phone.

**Install command, only after Pierre's written "go install":**

```bash
xcrun devicectl device install app --device 00008130-000465E62E43001C \
  /Users/pierreviviere/.t3/worktrees/dictus/spike-webview-parakeet/tools/webview-asr-spike/build/DerivedData/Build/Products/Debug-iphoneos/SpikeApp.app
```

To rebuild from a fresh clone of the branch:

```bash
cd tools/webview-asr-spike && ./setup.sh
xcodebuild build -project WebViewAsrSpike.xcodeproj -scheme SpikeApp -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData
```

The test protocol is in [README.md](README.md#device-test-protocol-pierre). It
covers:

- the in-app bench;
- the keyboard without and then with Full Access;
- 5 / 15 / 60 s dictations in Notes, Messages, WhatsApp and Safari;
- 10 dictations with battery % before and after;
- two cold starts;
- the FastConformers.

Since Parakeet 0.6B is already a no-go, the device run matters mostly for three
questions:

- **Capture:** does `getUserMedia` work in the keyboard's WebContent at all,
  with and without Full Access?
- **Survival:** does a 0.5 GB WebContent survive under a keyboard client?
- **Speed:** what is a FastConformer's real iPhone RTF?
