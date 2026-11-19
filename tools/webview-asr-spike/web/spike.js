// webview-asr-spike page: microphone capture + sherpa-onnx offline recognizer,
// both inside WebKit's WebContent process. Native code drives it through the
// window.spike* functions and listens on the `spike` message handler.
'use strict';

const t0 = performance.now();
const now = () => performance.now();
const logEl = document.getElementById('log');

// One channel out of the page. In a WKWebView it goes to native code; in a
// plain browser (Safari baseline) it is kept in window.spikeEvents and logged.
window.spikeEvents = [];
function post(message) {
  message.t = Math.round(now() - t0);
  window.spikeEvents.push(message);
  const line = JSON.stringify(message);
  if (logEl) logEl.textContent += line + '\n';
  try {
    window.webkit.messageHandlers.spike.postMessage(message);
  } catch (_) {
    console.log(line);
  }
}
const log = (text, extra = {}) => post({ type: 'log', text, ...extra });

let Module = null;
let recognizer = null;
let loadedModel = null;

const heapBytes = () => (Module && Module.HEAPU8 ? Module.HEAPU8.buffer.byteLength : 0);

function wasmSimdSupported() {
  // Smallest module using a v128 instruction (i8x16.splat in a function).
  const bytes = new Uint8Array([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 96, 0, 1, 123, 3, 2, 1, 0,
    10, 8, 1, 6, 0, 65, 0, 253, 15, 11,
  ]);
  try { return WebAssembly.validate(bytes); } catch (_) { return false; }
}

window.spikeEnv = function () {
  const env = {
    type: 'env',
    href: location.href,
    userAgent: navigator.userAgent,
    isSecureContext: window.isSecureContext,
    crossOriginIsolated: window.crossOriginIsolated === true,
    sharedArrayBuffer: typeof SharedArrayBuffer !== 'undefined',
    wasmSimd: wasmSimdSupported(),
    webgpu: typeof navigator.gpu !== 'undefined',
    getUserMedia: !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia),
    audioSession: typeof navigator.audioSession !== 'undefined',
    hardwareConcurrency: navigator.hardwareConcurrency,
  };
  post(env);
  return env;
};

// How large a WebAssembly.Memory this WebContent process will hand out. Grows a
// throwaway memory 256 MB at a time; virtual reservation only, pages untouched.
window.spikeProbeWasmMemory = function () {
  const page = 65536;
  const step = (256 * 1024 * 1024) / page;
  let reached = 0;
  let error = null;
  try {
    const memory = new WebAssembly.Memory({ initial: step, maximum: 65536 });
    reached = memory.buffer.byteLength;
    for (;;) {
      memory.grow(step);
      reached = memory.buffer.byteLength;
      if (reached >= 4 * 1024 * 1024 * 1024 - step * page) break;
    }
  } catch (e) {
    error = String(e);
  }
  post({ type: 'wasmMemoryProbe', maxBytes: reached, error });
  return reached;
};

async function ensureModule() {
  if (Module) return Module;
  const start = now();
  Module = await SherpaOnnx({
    locateFile: (path) => path,
    print: (text) => log(text),
    printErr: (text) => log(text, { stderr: true }),
  });
  post({ type: 'wasmReady', ms: Math.round(now() - start), heapBytes: heapBytes() });
  return Module;
}

async function fetchBytes(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`fetch ${url}: HTTP ${response.status}`);
  return new Uint8Array(await response.arrayBuffer());
}

// Loads a file into one buffer through a throwaway worker (fetch-worker.js),
// then hands that buffer to MEMFS as the file's contents. Fetching on the page
// left ~600 MB of response garbage in WebContent until the next GC (measured);
// terminating the worker frees it at once. No MEMFS growth copies either.
function fetchInWorker(url) {
  return new Promise((resolve, reject) => {
    const worker = new Worker('fetch-worker.js');
    worker.onmessage = (event) => {
      worker.terminate();
      if (event.data.error) reject(new Error(event.data.error)); else resolve(event.data.buffer);
    };
    worker.onerror = (event) => { worker.terminate(); reject(new Error('worker: ' + event.message)); };
    worker.postMessage({ url });
  });
}

async function streamIntoMemfs(url, path) {
  const buffer = await fetchInWorker(url);
  Module.FS.writeFile(path, new Uint8Array(0));
  const node = Module.FS.lookupPath(path).node;
  node.contents = buffer;
  node.usedBytes = buffer.byteLength;
  return buffer.byteLength;
}

const MODEL_FILES = ['encoder.int8.onnx', 'decoder.int8.onnx', 'joiner.int8.onnx', 'tokens.txt'];

// Fetches the model through the page's origin (a WKURLSchemeHandler in the
// app, a static server in Safari), writes it into Emscripten's MEMFS (JS-side
// typed arrays, not the wasm heap), builds the recognizer, then drops the
// files so only ONNX Runtime's copy remains.
window.spikeLoadModel = async function (name, options = {}) {
  try {
    if (loadedModel === name && recognizer) {
      post({ type: 'modelLoaded', model: name, cached: true, heapBytes: heapBytes() });
      return;
    }
    await ensureModule();
    if (recognizer) { recognizer.free(); recognizer = null; loadedModel = null; }
    const start = now();
    const dir = `/m-${name}`;
    try { Module.FS.mkdir(dir); } catch (_) {}
    let bytes = 0;
    for (const file of MODEL_FILES) {
      bytes += await streamIntoMemfs(`models/${name}/${file}`, `${dir}/${file}`);
      post({ type: 'phase', phase: 'fetched ' + file, heapBytes: heapBytes() });
    }
    const fetchMs = now() - start;
    // Let WebKit release the fetch workers' memory before ONNX Runtime grows
    // the wasm heap: without this pause both peaks add up (measured on Mac).
    const settleMs = options.settleMs ?? 2000;
    if (settleMs) await new Promise((resolve) => setTimeout(resolve, settleMs));
    post({ type: 'phase', phase: 'settled', heapBytes: heapBytes() });
    const createStart = now();
    recognizer = new OfflineRecognizer({
      featConfig: { sampleRate: 16000, featureDim: 80 },
      modelConfig: {
        transducer: {
          encoder: `${dir}/encoder.int8.onnx`,
          decoder: `${dir}/decoder.int8.onnx`,
          joiner: `${dir}/joiner.int8.onnx`,
        },
        tokens: `${dir}/tokens.txt`,
        numThreads: 1,
        provider: 'cpu',
        debug: 0,
        modelType: 'nemo_transducer',
      },
      decodingMethod: 'greedy_search',
    }, Module);
    const createMs = now() - createStart;
    if (!recognizer.handle) throw new Error('SherpaOnnxCreateOfflineRecognizer returned null');
    const peakHeap = heapBytes();
    post({ type: 'phase', phase: 'recognizer created', heapBytes: peakHeap });
    if (!options.keepFiles) for (const file of MODEL_FILES) Module.FS.unlink(`${dir}/${file}`);
    setTimeout(() => post({ type: 'phase', phase: 'model files dropped +5s', heapBytes: heapBytes() }), 5000);
    loadedModel = name;
    post({
      type: 'modelLoaded', model: name, bytes,
      fetchMs: Math.round(fetchMs), settleMs, createMs: Math.round(createMs),
      totalMs: Math.round(now() - start), heapBytes: peakHeap,
    });
  } catch (e) {
    post({ type: 'error', where: 'loadModel', model: name, message: String(e && e.stack || e), heapBytes: heapBytes() });
  }
};

function transcribe(samples, sampleRate) {
  const start = now();
  const stream = recognizer.createStream();
  stream.acceptWaveform(sampleRate, samples);
  recognizer.decode(stream);
  const result = recognizer.getResult(stream);
  stream.free();
  return { text: (result.text || '').trim(), decodeMs: Math.round(now() - start) };
}

// Minimal PCM WAV reader: 16-bit or float32, any channel count (first channel).
function parseWav(bytes) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let offset = 12, format = 1, channels = 1, sampleRate = 16000, bits = 16;
  while (offset + 8 <= view.byteLength) {
    const id = String.fromCharCode(...bytes.subarray(offset, offset + 4));
    const size = view.getUint32(offset + 4, true);
    const body = offset + 8;
    if (id === 'fmt ') {
      format = view.getUint16(body, true);
      channels = view.getUint16(body + 2, true);
      sampleRate = view.getUint32(body + 4, true);
      bits = view.getUint16(body + 14, true);
    } else if (id === 'data') {
      const frameBytes = (bits / 8) * channels;
      const frames = Math.floor(Math.min(size, view.byteLength - body) / frameBytes);
      const out = new Float32Array(frames);
      for (let i = 0; i < frames; i++) {
        const p = body + i * frameBytes;
        out[i] = format === 3 ? view.getFloat32(p, true) : view.getInt16(p, true) / 32768;
      }
      return { samples: out, sampleRate };
    }
    offset = body + size + (size & 1);
  }
  throw new Error('no data chunk');
}

// Phase 1: decode clips served next to the page; one `benchResult` per decode.
window.spikeRunBench = async function (clips, repeats = 1) {
  try {
    if (!recognizer) throw new Error('no model loaded');
    for (const clip of clips) {
      const { samples, sampleRate } = parseWav(await fetchBytes(clip.url));
      for (let run = 0; run < repeats; run++) {
        const r = transcribe(samples, sampleRate);
        post({
          type: 'benchResult', model: loadedModel, clip: clip.id, run,
          audioSec: +(samples.length / sampleRate).toFixed(2),
          decodeMs: r.decodeMs, rtf: +(r.decodeMs / 1000 / (samples.length / sampleRate)).toFixed(3),
          heapBytes: heapBytes(), text: r.text,
        });
      }
    }
    post({ type: 'benchDone', model: loadedModel });
  } catch (e) {
    post({ type: 'error', where: 'bench', message: String(e && e.stack || e), heapBytes: heapBytes() });
  }
};

// ---- Microphone capture (technique of stephancill/ios-keyboard-dictation, MIT) ----
let lastHeartbeat = now();
window.spikeHeartbeat = () => { lastHeartbeat = now(); };
let capture = null;

window.spikeStartCapture = async function () {
  if (capture) return;
  const audioSession = navigator.audioSession;
  const previousType = audioSession ? audioSession.type : 'auto';
  const state = { chunks: [], frames: 0, sampleRate: 48000, stopping: false, startedAt: now() };
  capture = state;
  const cleanup = () => {
    if (state.stopping) return;
    state.stopping = true;
    clearInterval(state.watchdog);
    if (state.processor) { state.processor.onaudioprocess = null; state.processor.disconnect(); }
    if (state.source) state.source.disconnect();
    if (state.sink) state.sink.disconnect();
    if (state.stream) state.stream.getTracks().forEach((t) => t.stop());
    if (state.context) state.context.close().catch(() => {});
    try { if (audioSession) audioSession.type = previousType; } catch (_) {}
  };
  state.cleanup = cleanup;
  const interrupted = (reason) => {
    if (state.stopping) return;
    cleanup();
    capture = null;
    post({ type: 'captureInterrupted', reason });
  };
  try {
    try { if (audioSession) audioSession.type = 'play-and-record'; } catch (_) {}
    const gumStart = now();
    state.stream = await navigator.mediaDevices.getUserMedia({
      audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
    });
    if (state.stopping) { state.stream.getTracks().forEach((t) => t.stop()); return; }
    state.stream.getAudioTracks()[0].onended = () => interrupted('track-ended');
    state.context = new AudioContext({ latencyHint: 'interactive' });
    await state.context.resume();
    state.sampleRate = state.context.sampleRate;
    state.processor = state.context.createScriptProcessor(4096, 1, 1);
    state.sink = state.context.createGain();
    state.sink.gain.value = 0;
    state.processor.connect(state.sink);
    state.sink.connect(state.context.destination);
    state.source = state.context.createMediaStreamSource(state.stream);
    state.source.connect(state.processor);
    state.context.onstatechange = () => {
      if (state.context.state !== 'running') interrupted('context-' + state.context.state);
    };
    if (audioSession) audioSession.onstatechange = () => {
      if (audioSession.state === 'interrupted') interrupted('audio-session-interrupted');
    };
    lastHeartbeat = now();
    state.watchdog = setInterval(() => {
      if (now() - lastHeartbeat > 3000) interrupted('native-heartbeat-expired');
    }, 500);
    state.processor.onaudioprocess = (event) => {
      const input = event.inputBuffer.getChannelData(0);
      state.chunks.push(new Float32Array(input));
      state.frames += input.length;
    };
    post({ type: 'captureStarted', sampleRate: state.sampleRate, getUserMediaMs: Math.round(now() - gumStart) });
  } catch (e) {
    cleanup();
    capture = null;
    post({ type: 'captureFailed', reason: `${e.name}: ${e.message}` });
  }
};

// Stops the microphone and transcribes what it recorded, in this process.
window.spikeStopCapture = function () {
  const state = capture;
  capture = null;
  if (!state) { post({ type: 'error', where: 'stop', message: 'not capturing' }); return; }
  state.cleanup();
  const samples = new Float32Array(state.frames);
  let offset = 0;
  for (const chunk of state.chunks) { samples.set(chunk, offset); offset += chunk.length; }
  state.chunks = [];
  const audioSec = samples.length / state.sampleRate;
  if (!recognizer) {
    post({ type: 'error', where: 'stop', message: 'model not loaded', audioSec });
    return;
  }
  // Let the stop message reach native code before the synchronous decode.
  setTimeout(() => {
    try {
      const r = transcribe(samples, state.sampleRate);
      post({
        type: 'transcript', model: loadedModel, text: r.text,
        audioSec: +audioSec.toFixed(2), decodeMs: r.decodeMs,
        rtf: +(r.decodeMs / 1000 / Math.max(audioSec, 0.01)).toFixed(3),
        sampleRate: state.sampleRate, heapBytes: heapBytes(),
      });
    } catch (e) {
      post({ type: 'error', where: 'transcribe', message: String(e && e.stack || e), heapBytes: heapBytes() });
    }
  }, 0);
};

window.addEventListener('pagehide', () => { if (capture) capture.cleanup(); });
window.addEventListener('error', (e) => post({ type: 'error', where: 'window', message: String(e.message) }));
window.addEventListener('unhandledrejection', (e) => post({ type: 'error', where: 'promise', message: String(e.reason) }));

window.spikeEnv();
post({ type: 'ready' });
