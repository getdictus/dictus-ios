#!/bin/bash
# Copies the sherpa-onnx build output and JS wrapper next to the spike page,
# and stages the models the keyboard bundles.
set -euo pipefail
cd "$(dirname "$0")/.."
B=.deps/sherpa-onnx/build-wasm-simd-web/install/bin/wasm/web
cp "$B/sherpa-onnx-wasm-web.js" "$B/sherpa-onnx-wasm-web.wasm" web/
cp .deps/sherpa-onnx/wasm/asr/sherpa-onnx-asr.js web/

# The keyboard bundles the models as a `models` folder reference. Hard links,
# not symlinks (a folder reference copies a symlink as a symlink), so staging
# costs no disk space. `ln -f` makes a rerun a no-op.
for pair in parakeet-v3:sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8 \
            fastconformer-14288:sherpa-onnx-nemo-fast-conformer-transducer-en-de-es-fr-14288-int8; do
  name=${pair%%:*}
  src=.deps/models/${pair#*:}
  mkdir -p ".deps/bundle/models/$name"
  for f in encoder.int8.onnx decoder.int8.onnx joiner.int8.onnx tokens.txt; do
    ln -f "$src/$f" ".deps/bundle/models/$name/$f"
  done
done
du -sh .deps/bundle/models/*
