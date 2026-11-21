#!/usr/bin/env bash
# Builds llama.cpp, CPU only, as a static xcframework for DictusCore (#996).
#
# Usage: tools/keyboard-lm/build-llama.sh
#
# Clones llama.cpp at LLAMA_COMMIT into ~/dev/swipe-models/llama-<commit>/src, builds it
# for the iOS device, the iOS Simulator (arm64 and x86_64) and macOS, merges each
# platform's libraries into one archive, and writes
# ~/dev/swipe-models/llama-<commit>/llama.xcframework. Then copies it to
# DictusCore/LocalLlama/llama.xcframework (gitignored), where DictusCore/Package.swift
# looks for it. Rerunning reuses the clone and rebuilds.
#
# Without that copy, DictusCore is built without llama.cpp and the keyboard's language
# model compiles out: CI and every build that did not run this script.
#
# GGML_METAL=OFF: with Metal compiled in, llama_backend_init compiles ggml's Metal
# shaders, 11 to 15 s on the simulator even with no layer on the GPU (#996 spike).
set -euo pipefail

LLAMA_COMMIT=4783b1145c7073bb809f4c282ff4853cbfe42954
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOME_DIR="${LLAMA_HOME:-$HOME/dev/swipe-models/llama-${LLAMA_COMMIT:0:7}}"
SRC="$HOME_DIR/src"
OUT="$HOME_DIR/llama.xcframework"
DEST="$ROOT/DictusCore/LocalLlama/llama.xcframework"

if [[ ! -d "$SRC/.git" ]]; then
    mkdir -p "$SRC"
    git -C "$SRC" init -q
    git -C "$SRC" remote add origin https://github.com/ggml-org/llama.cpp
fi
if [[ "$(git -C "$SRC" rev-parse -q --verify HEAD || true)" != "$LLAMA_COMMIT" ]]; then
    git -C "$SRC" fetch -q --depth 1 origin "$LLAMA_COMMIT"
    git -C "$SRC" checkout -q --detach FETCH_HEAD
fi

# The xcframework is written by hand rather than by `xcodebuild -create-xcframework`,
# which refuses an existing output: a rebuild overwrites each file in place.
# slice-identifier sdk system architectures platform variant
PLATFORMS=(
    "ios-arm64 iphoneos iOS arm64 ios -"
    "ios-arm64_x86_64-simulator iphonesimulator iOS arm64;x86_64 ios simulator"
    "macos-arm64 macosx Darwin arm64 macos -"
)
SLICES=""
for spec in "${PLATFORMS[@]}"; do
    read -r NAME SDK SYSTEM ARCHS PLATFORM VARIANT <<<"$spec"
    B="$HOME_DIR/build-$NAME"
    P="$OUT/$NAME"
    echo "== $NAME" >&2
    SYSTEM_ARGS=(-DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 -DCMAKE_SYSTEM_NAME=iOS)
    [[ $SYSTEM == Darwin ]] && SYSTEM_ARGS=(-DCMAKE_OSX_DEPLOYMENT_TARGET=14.0)
    cmake -S "$SRC" -B "$B" -G Xcode "${SYSTEM_ARGS[@]}" \
        -DCMAKE_OSX_SYSROOT="$SDK" -DCMAKE_OSX_ARCHITECTURES="$ARCHS" \
        -DBUILD_SHARED_LIBS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_BUILD_SERVER=OFF -DLLAMA_BUILD_COMMON=OFF \
        -DLLAMA_BUILD_APP=OFF -DLLAMA_CURL=OFF -DLLAMA_OPENSSL=OFF \
        -DGGML_METAL=OFF -DGGML_BLAS=ON -DGGML_OPENMP=OFF -DGGML_NATIVE=OFF \
        -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO > "$B.cmake.log" 2>&1 \
        || { tail -20 "$B.cmake.log" >&2; exit 1; }
    cmake --build "$B" --config Release --target llama -- -sdk "$SDK" -quiet > "$B.build.log" 2>&1 \
        || { tail -20 "$B.build.log" >&2; exit 1; }
    # The headers sit in their own folder: Xcode copies every package's xcframework
    # headers into one include directory, where a top-level module.modulemap collides.
    mkdir -p "$P/Headers/llama"
    # One archive per platform, so the xcframework has one library per slice.
    LIBS=()
    while IFS= read -r lib; do LIBS+=("$lib"); done < <(find "$B" -name '*.a' -path '*Release*' | sort)
    xcrun libtool -static -no_warning_for_no_symbols -o "$P/libllama.a" "${LIBS[@]}"
    cp "$SRC/include/llama.h" "$SRC"/ggml/include/*.h "$P/Headers/llama/"
    cat > "$P/Headers/llama/module.modulemap" <<'MAP'
module llama {
    header "llama.h"
    link "c++"
    link framework "Accelerate"
    export *
}
MAP
    ARCH_XML=""
    for a in ${ARCHS//;/ }; do ARCH_XML+="<string>$a</string>"; done
    VARIANT_XML=""
    [[ $VARIANT != - ]] && VARIANT_XML="<key>SupportedPlatformVariant</key><string>$VARIANT</string>"
    SLICES+="<dict><key>HeadersPath</key><string>Headers</string><key>LibraryIdentifier</key><string>$NAME</string><key>LibraryPath</key><string>libllama.a</string><key>SupportedArchitectures</key><array>$ARCH_XML</array><key>SupportedPlatform</key><string>$PLATFORM</string>$VARIANT_XML</dict>"
done

cat > "$OUT/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>AvailableLibraries</key><array>$SLICES</array><key>CFBundlePackageType</key><string>XFWK</string><key>XCFrameworkFormatVersion</key><string>1.0</string></dict></plist>
PLIST
plutil -lint "$OUT/Info.plist" >&2
echo "$LLAMA_COMMIT" > "$OUT/LLAMA_COMMIT"
mkdir -p "$DEST"
cp -R "$OUT/." "$DEST/"
echo "$DEST"
