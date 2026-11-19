#!/bin/bash
# Fetches and builds everything the spike bundles, into .deps/ (gitignored):
# emsdk 4.0.23, sherpa-onnx at a pinned sha compiled to WebAssembly (browser
# build, MAXIMUM_MEMORY raised to 4 GB), two sherpa-onnx NeMo transducer
# models, and the French clips of dictus-test-voices. About 20 minutes and
# 2.5 GB the first time; a rerun only redoes the staging.
set -euo pipefail
cd "$(dirname "$0")"
SHERPA_SHA=5ec231c44557607346a596c6255b08cfa7c78fe8
CORPUS=${CORPUS:-$HOME/dev/dictus-test-voices}
REL=https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models
mkdir -p .deps/dl .deps/models .deps/clips

if [ ! -d .deps/emsdk ]; then
  git clone -q --depth 1 https://github.com/emscripten-core/emsdk.git .deps/emsdk
  (cd .deps/emsdk && ./emsdk install 4.0.23 && ./emsdk activate 4.0.23)
fi

if [ ! -f .deps/sherpa-onnx/build-wasm-simd-web/install/bin/wasm/web/sherpa-onnx-wasm-web.wasm ]; then
  [ -d .deps/sherpa-onnx ] || git clone -q https://github.com/k2-fsa/sherpa-onnx.git .deps/sherpa-onnx
  git -C .deps/sherpa-onnx checkout -q "$SHERPA_SHA"
  # Emscripten's default cap is 2 GB; Parakeet's heap reaches 1.5 GB on a
  # 72 s clip, so leave room up to wasm32's 4 GB.
  sed -i '' 's/-s ALLOW_MEMORY_GROWTH=1")/-s ALLOW_MEMORY_GROWTH=1 -sMAXIMUM_MEMORY=4GB")/' .deps/sherpa-onnx/wasm/wasm-common.cmake
  (cd .deps/sherpa-onnx && source ../emsdk/emsdk_env.sh >/dev/null && ./build-wasm-simd-web.sh)
fi

for m in sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8 sherpa-onnx-nemo-fast-conformer-transducer-en-de-es-fr-14288-int8 \
         sherpa-onnx-nemo-fast-conformer-transducer-be-de-en-es-fr-hr-it-pl-ru-uk-20k-int8; do
  if [ ! -d ".deps/models/$m" ]; then
    curl -sSL -o ".deps/dl/$m.tar.bz2" "$REL/$m.tar.bz2"
    tar xjf ".deps/dl/$m.tar.bz2" -C .deps/models
  fi
done

V=$CORPUS/elevenlabs/fr
cp "$V"/fr-0[1-4]-*.wav "$V/fr-long-01-workday-sync-fix.wav" .deps/clips/
printf "file '%s'\n" "$V/fr-01-spoken-punctuation.wav" "$V/fr-02-appointment-numbers.wav" \
  "$V/fr-03-shopping.wav" "$V/fr-04-question-mark.wav" > .deps/concat.txt
ffmpeg -loglevel error -y -f concat -safe 0 -i .deps/concat.txt -c pcm_s16le .deps/clips/fr-concat-4short.wav
ffmpeg -loglevel error -y -i "$V/fr-long-01-workday-sync-fix.wav" -t 15 -c pcm_s16le .deps/clips/fr-long-first15s.wav
ffmpeg -loglevel error -y -i "$V/fr-long-01-workday-sync-fix.wav" -t 60 -c pcm_s16le .deps/clips/fr-long-first60s.wav

scripts/stage-web.sh
xcodegen -q
echo "setup done"
