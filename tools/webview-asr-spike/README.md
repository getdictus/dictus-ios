# WebView ASR spike: Parakeet in WebAssembly, inside a keyboard's WKWebView

**Throwaway.** A standalone app + keyboard (`com.pivi.dictus.spike`,
`com.pivi.dictus.spike.keyboard`), in a project of its own. Nothing in
`Dictus.xcodeproj`, `DictusCore` or CI references this directory, and installing
it never replaces Dictus on the phone.

> Can a hidden WKWebView inside a keyboard extension both capture the mic
> (getUserMedia, technique of stephancill/ios-keyboard-dictation, MIT) and
> transcribe with Parakeet compiled to WebAssembly, in WebKit's WebContent
> process, outside the keyboard's ~68 MB ceiling (#555)?

Status 2026-11-19: phases 0 and 1 done (desk check, Mac, simulator). The device
build is ready but **not installed**. Every figure below comes from a Mac or a
simulator unless it says otherwise; none of them is an iPhone measurement.

## How it works

```
keyboard extension (≈30 MB)                      WebContent process (the model lives here)
  KeyboardViewController ── evaluateJavaScript ──▶ web/spike.js
  AsrWebHost: WKWebView 1×1 pt, alpha 0.01           getUserMedia → ScriptProcessor → Float32
  SpikeSchemeHandler: spikeasr://app/…  ◀── fetch ── fetch-worker.js (16 MB Range slices)
    streams web/ and models/ from the                 MEMFS → sherpa-onnx (wasm, SIMD, 1 thread)
    keyboard's own bundle, 1 MB at a time             OfflineRecognizer (nemo_transducer) → text
  textDocumentProxy.insertText ◀── postMessage {type: transcript} ──┘
```

- **sherpa-onnx compiled to WebAssembly** from `k2-fsa/sherpa-onnx@5ec231c`,
  browser build (`build-wasm-simd-web.sh`), emsdk 4.0.23, ONNX Runtime 1.28.2
  static SIMD. One change: `-sMAXIMUM_MEMORY=4GB`. The default is 2 GB, and
  Parakeet's heap reaches 1.5 GB on a 72 s clip.
- **Models.** `sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8` (642 MB; encoder 652 MB)
  and, as the small French fallback, `sherpa-onnx-nemo-fast-conformer-transducer-en-de-es-fr-14288-int8`
  (136 MB, 114M parameters).
- **Better than an App Group copy: the models ship inside the keyboard's bundle.**
  The keyboard reads them with no App Group, no Full Access and no copy step.
  The app reads the same files through its `PlugIns/` folder. This replaced the
  brief's App Group, which couldn't be signed anyway: `-allowProvisioningUpdates`
  answers "No Accounts", and the team wildcard profile can't carry a new App
  Group. That's the same wall `tools/ane-harness` hit for #268.
- **Loading the model without blowing WebContent's memory.** These were found
  by measurement:
  - A whole-file `fetch` left a second 650 MB in WebContent.
  - So each file is fetched in 16 MB `Range` slices, inside a throwaway worker
    that is terminated afterwards.
  - The resulting buffer is handed to MEMFS as the file's contents, so there
    is no copy.
  - A 2 s pause then lets WebKit release the worker's memory before ONNX
    Runtime grows the heap.
  - Load peak on the Mac: 2.15 GB → 1.50 GB.
  - A wasm heap never shrinks, so changing model reloads the page.

## Phase 0: desk check

Full notes are in the session report. **[D]** = documented or measured by
someone else, **[M]** = measured here.

- **sherpa-onnx WASM can run the NeMo TDT recognizer.**
  - Its browser app already handles `nemo_transducer`
    ([app-vad-asr.js](https://github.com/k2-fsa/sherpa-onnx/blob/master/wasm/vad-asr/app-vad-asr.js)) [D].
  - There's no prebuilt Parakeet browser build
    ([generate-vad-asr.py](https://github.com/k2-fsa/sherpa-onnx/blob/master/scripts/wasm/generate-vad-asr.py)) [D].
  - Someone reported Parakeet 0.6B v2 int8 failing in the nodejs WASM build
    with "failed to grow the heap"
    ([#2200](https://github.com/k2-fsa/sherpa-onnx/issues/2200)) [D].
  - **v3 int8 loads and transcribes here, with the 4 GB cap** [M].
- **The WebContent memory limit on iPhone is about 2 GB.**
  - Someone measured a kill at `ActiveHard 2048 MB` on an iPhone 17 Pro (12 GB)
    under iOS 26.3–26.4, and an Apple engineer confirmed that iPhones are stricter
    than iPads ([forum 823061](https://developer.apple.com/forums/thread/823061)) [D].
  - WebKit's own monitor assumes 1.5 GB soft and 2 GB hard on iPhone
    ([MemoryFootprintMonitor.cpp](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/MemoryFootprintMonitor.cpp)) [D].
  - The increased-memory entitlement doesn't apply to WebContent
    ([bug 274637](https://bugs.webkit.org/show_bug.cgi?id=274637)) [D].
  - The limit belongs to the WebContent process, not to its client. Whether a
    keyboard client changes it is **unknown until the device run**.
- **wasm32 memory is capped at 4 GiB**
  ([PageCount.h](https://github.com/WebKit/WebKit/blob/main/Source/JavaScriptCore/runtime/PageCount.h)) [D].
  - iOS 17 couldn't allocate more than about 1 GB, and that was later fixed by
    enlarging the memory region ([bug 269777](https://bugs.webkit.org/show_bug.cgi?id=269777),
    [269937](https://bugs.webkit.org/show_bug.cgi?id=269937)) [D].
  - Simulator on iOS 26.5: one `WebAssembly.Memory` grew to **2.5 GB** before
    `RangeError: Out of memory` [M].
- **There are no wasm threads in this setup.**
  - Page served by `WKURLSchemeHandler` on iOS 26.5: `isSecureContext=true`,
    `crossOriginIsolated=false`, no `SharedArrayBuffer`, even with COOP/COEP
    sent [M].
  - Someone measured the same on an iPad
    ([logos-workspace#287](https://github.com/logos-fleet/logos-workspace/issues/287)) [D].
  - Threads would need a loopback HTTP server inside the extension. Not tried.
- **SIMD is supported** (Safari 16.4+) [D, M].
- **WebGPU** is enabled in Safari 26
  ([bug 299237](https://bugs.webkit.org/show_bug.cgi?id=299237)) [D], and
  `navigator.gpu` is present in the simulator's WKWebView [M]. parakeet.js
  upgrades the encoder to fp32 on WebGPU, which is 2.4 GB
  ([parakeet.js](https://github.com/ysdede/parakeet.js)) [D]. Not tried.
- **getUserMedia works on a custom scheme.** `navigator.mediaDevices.getUserMedia`
  is exposed on the `spikeasr://` page, which is a secure context
  ([bug 220184](https://bugs.webkit.org/show_bug.cgi?id=220184)) [D, M]. The
  only evidence of capture inside a keyboard is stephancill (with Full Access,
  on a device, today) and Raycast as prior art [D].

Nothing here rules the idea out, so phases 1 and 2 went ahead.

## Phase 1: Mac and simulator

Corpus: `dictus-test-voices@6eeeb0f`, French ElevenLabs clips. The 4 short
clips (4–5 s), their concatenation (18.4 s; the brief asked for 15 s), the first
60 s of the long code-switched clip, and the whole 71.8 s clip. Pierre's own
recordings folder is empty.

WER is computed exactly as the #932 report does
(`tools/closing-phrase-bench/score.py`), against the manifest text. "Native" is
FluidAudio Parakeet v3 (Core ML) on the same clips, from
`docs/research/932-invented-closing-phrases/before-parakeet-v3.tsv`, first pass,
no #623 retry.

**iOS 26.5 simulator, iPhone 15 Pro Max, in-app WKWebView. Same page, same wasm
as the keyboard; M-series Mac CPU, one thread.**
Raw data: `results/sim-ios26.5-iphone15promax-fresh-page-per-model.jsonl`.

| model | clip | audio | decode | RTF | WER webview | WER native |
|---|---|---|---|---|---|---|
| parakeet-v3 | fr-01 | 4.4 s | 1.55 s | 0.35 | 10.0 % | 20.0 % |
| parakeet-v3 | fr-02 | 4.8 s | 1.67 s | 0.35 | 23.1 % | 23.1 % |
| parakeet-v3 | fr-03 | 4.1 s | 1.44 s | 0.35 | 0.0 % | 0.0 % |
| parakeet-v3 | fr-04 | 5.1 s | 1.90 s | 0.37 | 0.0 % | 0.0 % |
| parakeet-v3 | concat (≈15 s) | 18.4 s | 6.25 s | 0.34 | 76.0 % (drifts to English) | n/a |
| parakeet-v3 | first 60 s | 60.0 s | 22.2 s | 0.37 | English drift | n/a |
| parakeet-v3 | long | 71.8 s | 27.1 s | 0.38 | 95.2 % | 82.9 % (same drift) |
| fastconformer | fr-01 | 4.4 s | 0.34 s | 0.08 | 20.0 % | 20.0 % |
| fastconformer | fr-02 | 4.8 s | 0.37 s | 0.08 | 61.5 % (numbers spelled out) | 23.1 % |
| fastconformer | fr-03 | 4.1 s | 0.31 s | 0.08 | 7.1 % | 0.0 % |
| fastconformer | fr-04 | 5.1 s | 0.39 s | 0.08 | 15.4 % (first words dropped) | 0.0 % |
| fastconformer | concat | 18.4 s | 1.42 s | 0.08 | 28.0 % | n/a |
| fastconformer | first 60 s | 60.0 s | 5.27 s | 0.09 | 7.9 % | n/a |
| fastconformer | long | 71.8 s | 6.47 s | 0.09 | 6.1 % | 82.9 % |

**Load and memory, simulator** (WebContent `phys_footprint`, read from the host
with `proc_pid_rusage`):

| | parakeet-v3 | fastconformer |
|---|---|---|
| model load, page ready → recognizer | 3.1–3.8 s (2 s of it is the settle pause) | 2.6 s |
| WebContent, peak at load | 1.53 GB | 0.50 GB |
| WebContent after a 72 s decode | 1.57 GB (wasm heap 1.49 GB) | 0.76 GB |
| keyboard process during load and decode | **18–31 MB** | same order |
| host app process during the bench | 28–30 MB | 28–30 MB |

**The keyboard itself, in the simulator.** Without Full Access, the keyboard
loaded Parakeet v3 in its own WKWebView in 3.8 s (4.7 s from `viewDidLoad`), at
30 MB footprint (peak 31 MB). Its "report" key typed the figures into the host
field through `textDocumentProxy`. The simulator's microphone was not exercised
(it would go through the Mac's own microphone permission).

**Mac baselines** (same wasm):

- **Node 22 (V8):** Parakeet v3 loads in 1.4 s and decodes 4.4 / 18.4 / 60 s in
  1.5 / 6.2 / 21.9 s, with the heap at 819 → 1345 MB.
- **FastConformer under Node:** loads in 0.6 s and decodes the same clips in
  0.35 / 1.35 / 5.1 s.
- **macOS WKWebView (Safari's engine)** gave the same text, but timings 2–4×
  slower that got worse every run. WebKit throttles a page that's never on
  screen (`mac-bench/`), and the SPI preferences didn't lift it. Those timings
  aren't a baseline. The simulator page is visible, and its timings match Node's.

**What phase 1 says**

1. **It works mechanically.**
   - Parakeet v3 int8 loads and decodes in WebKit's WebContent, single-threaded.
   - The keyboard process stays at about 30 MB while 650 MB of model stream
     through it.
2. **The quality is Parakeet's, drift included.**
   - Short clips match native (equal or better).
   - On ≥18 s of French, the first pass drifts into pseudo-English, exactly
     as the native first pass does (#623).
   - The native app's drift retry would have to be ported.
3. **Speed is the problem.**
   - The decode runs at RTF 0.35–0.38 on an M-series core, with no threads
     available.
   - A 60 s dictation means a 22 s wait on a Mac core, before any phone penalty.
4. **Memory has little headroom for Parakeet.**
   - WebContent peaks at 1.53–1.57 GB. That's above WebKit's 1.5 GB soft limit,
     with 0.45 GB left under the 2 GB hard limit.
   - FastConformer sits at 0.5–0.76 GB.
5. **FastConformer 114M** is 4.5× faster (RTF 0.08–0.10) and doesn't drift on
   long French. On short clips it's worse: numbers come out spelled, and it
   drops the first words.

## Phase 2: device build (built, not installed)

Debug build for the iPhone 15 Pro Max `00008130-000465E62E43001C`, signed by the
team wildcard profile, which lists that device. 810 MB, models included.

```bash
cd tools/webview-asr-spike
./setup.sh                      # once: emsdk, wasm build, models, clips (.deps/)
xcodebuild build -project WebViewAsrSpike.xcodeproj -scheme SpikeApp -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData
# Install: only after Pierre's written "go install"
xcrun devicectl device install app --device 00008130-000465E62E43001C \
  build/DerivedData/Build/Products/Debug-iphoneos/SpikeApp.app
```

What each part logs (JSON lines, one per event):

- **The keyboard** logs page ready, model loaded (`fetchMs`, `createMs`,
  `totalMs`, wasm heap), each transcript (`audioSec`, `decodeMs`, `rtf`),
  capture failures and interruptions, and every
  `webViewWebContentProcessDidTerminate`. Each line also carries
  `keyboardFootprintMB` and `keyboardAvailableMB` (`os_proc_available_memory`).
  - **WebContent memory** is read with `proc_pid_rusage` on the pid from
    `_webProcessIdentifier` (SPI, spike only).
  - That works in the simulator. On a device the sandbox is expected to refuse
    it, in which case the line carries `webContentFootprintErrno` instead.
  - Without that, the WebContent figures are the wasm heap (a lower bound), the
    simulator footprints above, and, optionally, Instruments' Activity Monitor
    template from the Mac (no sysdiagnose).
- **Where the logs go:**
  - **The "report" key** types the session summary into the current field. It
    works with or without Full Access, with no cable.
  - **The unified log**, subsystem `com.pivi.dictus.spike` (Console.app,
    cable).
  - **The keyboard's own `Documents/keyboard.jsonl`.**
  - **The app's `Documents/`:** `devicectl device copy from --device
    00008130-000465E62E43001C --domain-type appDataContainer --domain-identifier
    com.pivi.dictus.spike --source Documents --destination results/device`.
    The Files app works too.

## Device test protocol (Pierre)

About 40 minutes. The phone stays plugged into a charger only for steps 1–3.

1. Open **ASR Spike**, tap **Allow microphone**, then **Run bench**. Wait for
   `allDone` (about 2 min). This is the device version of the simulator table,
   in the app's WebContent.
   - If the app vanishes mid-bench, that is a WebContent kill: note at which
     line.
2. Settings › General › Keyboard › Keyboards › Add New Keyboard › **Spike ASR**.
   Leave **Full Access OFF**.
3. **Without Full Access**, in Notes: long-press 🌐, pick Spike ASR, and wait
   for "Ready (parakeet-v3)".
   - Tap **Dictate**, say one sentence, tap **Stop**.
   - Then tap **report**. Note whether the microphone started or what error
     the status line shows.
4. Turn **Full Access ON** and unplug. Note the battery %.
5. **Ten dictations with Parakeet v3, Full Access on**, each a reading of the
   same French text:
   - Notes: 5 s, 15 s, 60 s
   - Messages: 5 s, 15 s
   - WhatsApp: 5 s, 15 s
   - Safari, address bar or a search field: 5 s, 15 s, 60 s

   Use a stopwatch for the durations. After each one, check the text was
   inserted. Note the wait between Stop and text.
6. **Cold start, twice:** swipe the host app away, reopen it, show the keyboard,
   and note the time until "Ready". Tap **report** to capture it.
7. Note the battery % after the ten. Tap **report** in Notes and keep that note.
8. Tap the model name to switch to **fastconformer-14288**. Repeat the 5 / 15 /
   60 s dictations in Notes, then **report**.
9. Send me the Notes text from every **report**, plus anything that vanished,
   froze or showed "WebContent terminated". If the cable is handy, also run the
   `devicectl … copy from` command above.

The questions this answers:

- Does capture work in the keyboard, with and without Full Access?
- Does WebContent survive 1.5 GB in a keyboard client?
- What are the iPhone RTF and the cold-load time?
- What does it cost in battery?
- Does it work across hosts?

## Repository map

| path | what |
|---|---|
| `web/` | the page: `spike.js` (capture, load, decode, bench), `fetch-worker.js`; staged wasm + sherpa JS (gitignored) |
| `Shared/` | `AsrWebHost` (WKWebView + bridge), `SpikeSchemeHandler` (Range-capable file streaming), `SpikeMetrics` (footprints, log) |
| `Keyboard/`, `App/` | the two targets; `project.yml` → `xcodegen` |
| `mac-bench/` | macOS WKWebView runner (throttled; see above) |
| `scripts/` | `stage-web.sh`, `score.py` (phase 1 table), `node-smoke.js` (Node baseline), `footprint-table.py` |
| `results/` | raw bench JSONL and the generated table |
