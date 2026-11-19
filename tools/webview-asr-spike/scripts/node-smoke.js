// Node smoke test of the browser build: same wasm, same JS wrapper, same
// MEMFS loading path as web/spike.js. Usage: node scripts/node-smoke.js <modelDir> <wav>...
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const root = path.join(__dirname, '..');
const built = path.join(root, '.deps/sherpa-onnx/build-wasm-simd-web/install/bin/wasm/web');
global.SherpaOnnx = require(path.join(built, 'sherpa-onnx-wasm-web.js'));
vm.runInThisContext(fs.readFileSync(path.join(root, '.deps/sherpa-onnx/wasm/asr/sherpa-onnx-asr.js'), 'utf8').replace(/if \(typeof process == 'object'[\s\S]*$/, 'globalThis.OfflineRecognizer = OfflineRecognizer;'));
(async () => {
  const [modelDir, ...wavs] = process.argv.slice(2);
  const t = () => Number(process.hrtime.bigint() / 1000000n);
  const Module = await SherpaOnnx({ locateFile: (p) => path.join(built, p) });
  const start = t();
  Module.FS.mkdir('/m');
  for (const f of ['encoder.int8.onnx', 'decoder.int8.onnx', 'joiner.int8.onnx', 'tokens.txt'])
    Module.FS.writeFile('/m/' + f, new Uint8Array(fs.readFileSync(path.join(modelDir, f))), { canOwn: true });
  const rec = new OfflineRecognizer({ featConfig: { sampleRate: 16000, featureDim: 80 }, modelConfig: { transducer: { encoder: '/m/encoder.int8.onnx', decoder: '/m/decoder.int8.onnx', joiner: '/m/joiner.int8.onnx' }, tokens: '/m/tokens.txt', numThreads: 1, provider: 'cpu', debug: 0, modelType: 'nemo_transducer' }, decodingMethod: 'greedy_search' }, Module);
  console.log(JSON.stringify({ load_ms: t() - start, heap_mb: Module.HEAPU8.buffer.byteLength >> 20, rss_mb: process.memoryUsage().rss >> 20, handle: rec.handle }));
  for (const w of wavs) {
    const b = fs.readFileSync(w); const n = (b.length - 44) >> 1; const s = new Float32Array(n);
    for (let i = 0; i < n; i++) s[i] = b.readInt16LE(44 + 2 * i) / 32768;
    const s0 = t(); const st = rec.createStream(); st.acceptWaveform(16000, s); rec.decode(st); const r = rec.getResult(st); st.free();
    console.log(JSON.stringify({ wav: path.basename(w), sec: n / 16000, decode_ms: t() - s0, heap_mb: Module.HEAPU8.buffer.byteLength >> 20, text: r.text }));
  }
})();
