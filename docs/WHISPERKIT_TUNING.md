# WhisperKit Investigation Notes

Working knowledge base for Dictus' WhisperKit integration. Captures what we know, what we tried, what failed, what worked, and the questions still open after the audit kicked off by issue #163.

**Status**: #163 resolved (turbo no longer truncates long audio). Wider audit #168 partially complete — see Section 9.

Pinned version: WhisperKit **0.16.0** (`Package.resolved`).
Local source checkout: `~/Library/Developer/Xcode/DerivedData/Dictus-*/SourcePackages/checkouts/WhisperKit/Sources/WhisperKit/Core/`.

---

## 1. Symptoms that triggered this investigation

- **Issue #163 — turbo truncates long audio.** `openai_whisper-large-v3_turbo_954MB` returns truncated or empty transcriptions on audio > ~28s. `openai_whisper-small` handles the same audio cleanly. Pattern non-deterministic.
- **Perceived slowness across the board on turbo, even on short audio.** A 2.7s audio took 17s to transcribe in one of our tests; an 8s audio took 6s; ratios well below the ~5× realtime sometimes cited for iPhone 15 Pro Max with turbo.

---

## 2. Architecture context — why we are stuck in batch mode

Dictus runs Whisper inference in the **main app**, not in the keyboard extension (~50 MB memory ceiling). The pipeline is:

1. Keyboard extension sends a Darwin notification to the app.
2. App captures audio in `UnifiedAudioEngine` and accumulates samples in `audioSamples: [Float]`.
3. User taps stop → `UnifiedAudioEngine.collectSamples()` returns the full buffer.
4. `TranscriptionService.transcribe(audioSamples:)` → `WhisperKitEngine.transcribe(audioSamples:language:)` → `whisperKit.transcribe(audioArray: audioSamples, decodeOptions: options)`.
5. App writes result to App Group, notifies keyboard, keyboard inserts text.

**Batch mode is structural here.** Streaming (where text appears live during recording) would require feeding audio frames into WhisperKit as they arrive and surfacing partial results back across the keyboard ↔ app process boundary. Not practical with the current keyboard-extension memory limit and Darwin-notification IPC.

**Important consequence**: Argmax's published benchmarks (5×–7× realtime on iPhone 15 Pro for turbo, "0.46s latency" in the ICML paper) are **streaming-mode numbers**. They are not directly comparable to our batch wall-clock measurements. The realistic batch ceiling on this device is unknown — needs to be researched or measured in a controlled spike.

Streaming might be revisited later for **Dictus Desktop** where the architecture is different. Out of scope for iOS.

---

## 3. The DecodingOptions surface (WhisperKit 0.16)

Constructor in `Sources/WhisperKit/Core/Configurations.swift`. Parameters we care about:

### `task: DecodingTask` (we use `.transcribe`)
Transcription vs translation. `.transcribe` keeps source language.

### `language: String?` (we read from App Group, "fr" or "en")
BCP-47 hint. Honored only when `usePrefillPrompt = true` (see below).

### `temperature: Float` (we use 0.0)
Greedy decoding base. 0.0 = deterministic, picks most probable token at each step.

### `temperatureIncrementOnFallback` (default 0.2) + `temperatureFallbackCount` (default 5)
Standard Whisper degenerate-output guardrail. After each decode, if `compressionRatio > 2.4` (text too repetitive) or `avgLogprob < -1.0` (model too unsure), re-decode with `temperature += 0.2`. Up to `temperatureFallbackCount` retries. **Each fallback is a full re-decode of the segment** — default 5 means up to 6 decodes per problematic segment.

### `usePrefillPrompt: Bool` (we use true)
Prepends the special tokens `<|startoftranscript|> <|fr|> <|transcribe|>` before decoding so the model knows the task and language up front.

**Critical**: setting this to `false` triggers `detectLanguage = !usePrefillPrompt` inside `TextDecoder.swift`, which **overrides our `language` parameter** and falls back to auto-detection. We need French forced (mixed FR/EN dictation), so `true` is mandatory for our use case.

Source: `Sources/WhisperKit/Core/TextDecoder.swift` — `detectLanguage = detectLanguage ?? !usePrefillPrompt`.

### `usePrefillCache: Bool` (we use true)
Pre-seeds the KV cache for the prefill prompt tokens so the decoder skips re-encoding them every chunk. Small per-call latency win. **Removed in WhisperKit v1.0+** when the prefill model was merged into the main decoder. Will need adjustment when we upgrade.

### `skipSpecialTokens: Bool` (we use true)
Strips `<|fr|>`, `<|notimestamps|>`, etc. from the output text. Cosmetic.

### `chunkingStrategy: ChunkingStrategy?` (we leave nil)
`.vad` activates internal VAD-based chunking for long-form audio. `.none` (or nil = default) disables. **Tested `.vad` and observed regressions** — see Section 5.

### `noSpeechThreshold: Float` (default 0.6)
Per-segment, if predicted `no_speech_prob > threshold`, segment is dropped (treated as silence). Lower = more permissive.

### `compressionRatioThreshold: Float` (default 2.4) / `logProbThreshold: Float` (default -1.0)
Trigger conditions for the temperature fallback cascade.

### `concurrentWorkerCount: Int` (default 4 on iOS, 16 on macOS)
Parallel decoding workers across chunks. Higher = more parallelism but more peak memory.

### `promptTokens: [Int]?` / `prefixTokens: [Int]?` (we don't use)
For custom vocabulary biasing. **Argmax issue #372**: `promptTokens` reportedly causes empty transcriptions in some configurations. Untested by us.

These three parameters (`usePrefillPrompt`, `promptTokens`, `prefixTokens`) are orthogonal — using one doesn't preclude another.

---

## 4. WhisperKitConfig and ModelComputeOptions

### What we pass

```swift
WhisperKitConfig(
    model: modelName,
    verbose: false,
    prewarm: true,
    load: true,
    download: true
)
```

`computeOptions` is left as `nil`. **Verified in source**: `WhisperKit.swift:58` — `modelCompute = config.computeOptions ?? ModelComputeOptions()`. So nil falls back to defaults.

### Defaults (verified, `Models.swift:94-124`)

iOS 17+ defaults inside `ModelComputeOptions()`:

| Component | Compute |
|---|---|
| Mel spectrogram | `.cpuAndGPU` |
| Audio encoder | `.cpuAndNeuralEngine` |
| Text decoder | `.cpuAndNeuralEngine` |
| Prefill | `.cpuOnly` |

So we are already targeting Neural Engine for both encoder and decoder by default. **An earlier hypothesis was that we were missing `computeOptions` and that was causing the speed gap — that hypothesis is wrong.** Adding an explicit `ModelComputeOptions()` would be a no-op.

### Open question on speed

If ANE is targeted by default and we still measure 0.86×–1.26× realtime on iPhone 15 Pro Max, then either:
1. We are not actually running on ANE despite the targeting (need to verify via Instruments / os_signpost).
2. The model isn't fully warmed up (`prewarm: true` may only do part of the work).
3. There is overhead in our chain (`UnifiedAudioEngine` → `TranscriptionService` → `WhisperKitEngine`) we haven't measured.
4. WhisperKit 0.16 has an unfixed perf issue on turbo that later versions resolve.
5. Batch mode genuinely caps lower than streaming benchmarks suggest.

**Need an audit, not a guess.** See Section 7.

---

## 5. What we tried on `fix/163-turbo-long-audio-truncation` and what we observed

### Attempt 1 — Add VAD chunking + temperature fallback explicit + threshold loosening

Config:
```swift
chunkingStrategy = .vad
temperatureIncrementOnFallback = 0.2
temperatureFallbackCount = 5
noSpeechThreshold = 0.3
logProbThreshold = -1.5
```

**Test result (logs 32, iPhone 15 Pro Max)**:
- 35s audio with two repeated paragraphs separated by "je répète".
- `diagnosticProbe ... segments=8 chars=284 audioSec=34.92 lastSegmentEndSec=18.50`
- `transcriptionCompleted words=50 duration=30012ms`
- Transcribed only the first paragraph (0–18.5s). Second paragraph silently dropped.
- Speed: 30s wall clock for 35s audio = **0.86× realtime**.

Diagnosis: VAD chunking did chunk, but the decoder stopped at the first chunk boundary. Matches m13v's hypothesis #1 (boundary repetition penalty in the distilled turbo decoder reads chunk 2's overlapped prefix as already-emitted content and emits `<|endoftext|>` early).

### Attempt 2 — Tighten thresholds, lower fallback count, adaptive worker count

Config delta from attempt 1:
```swift
temperatureFallbackCount = 2          // was 5
noSpeechThreshold = 0.4               // was 0.3
logProbThreshold = (default -1.0)     // was -1.5
concurrentWorkerCount = adaptive 4/6/8
```

**Test result (logs 33, iPhone 15 Pro Max, three runs)**:

| Run | Audio | transcribeMs | Ratio | lastSegmentEndSec | chars | Verdict |
|---|---|---|---|---|---|---|
| 1 — short | 7.90s | 6250 | 1.26× | 7.90 | 158 | OK but slow |
| 2 — very short | 2.70s | 17160 | **0.16×** | **27.74** | 37 | Hallucinated timestamps + cascade fired |
| 3 — long, different content | 38.52s | 28000 | 1.37× | 38.52 | **0** | **Empty result error** |

**Observations**:
- The long-audio case **regressed** vs attempt 1 — went from "first paragraph kept" to "empty result". Tightening filters made it worse, not better. The empty result with `lastSegmentEndSec ≈ audioSec` indicates the decoder produced segments with empty `.text` — early `<|endoftext|>` emission across all chunks, **not** post-decode filtering.
- The very-short audio case (2.7s) showing `lastSegmentEndSec = 27.74` is the model hallucinating timestamps far past the actual audio length. Cascade fired and burned 17s of wall clock on what should be a sub-second decode. Suggests `chunkingStrategy = .vad` introduces overhead even on audio that doesn't need chunking.
- Speed never approached the published benchmarks at any setting.

### Decision: roll back all DecodingOptions tuning

Both attempts caused regressions in different forms. No subset of the tweaks demonstrated a measurable win. Reverted to the original baseline:

```swift
let options = DecodingOptions(
    task: .transcribe,
    language: language,
    temperature: 0.0,
    usePrefillPrompt: true,
    usePrefillCache: true,
    skipSpecialTokens: true
)
```

This is the state on `fix/163-turbo-long-audio-truncation` after rollback.

### Kept on the branch

- **Diagnostic probe** in both `WhisperKitEngine.transcribe` (`SpeechModelProtocol.swift`) and `TranscriptionService.transcribe` (legacy path). Logs `results=N segments=M chars=X audioSec=Y lastSegmentEndSec=Z` for every transcribe. Useful for future investigation.
- **`DeviceCapabilities.recommendedConcurrentWorkerCount`** — adaptive 4/6/8 worker count helper based on RAM tier and thermal state. Not currently wired (DecodingOptions reverted), but available infrastructure for when we re-enable concurrent workers in a validated config.
- **This document.**

---

## 6. Hypotheses still open

Listed by likelihood of being load-bearing, based on what we've seen.

### H1 — Boundary repetition penalty in distilled turbo (m13v's hypothesis #1)
With any chunking that produces overlap, turbo's 4-layer decoder treats chunk N's prefix as repeated content from chunk N-1 and stops decoding early. Cause of the empty-result and truncation patterns. WhisperKit doesn't expose a flag to disable cross-chunk text carryover. Workarounds: manual chunking (split the audio in our own code, call `transcribe()` per chunk independently with no carryover) or different model.

### H2 — Batch-mode realistic ceiling unknown for this device + model
Argmax benchmarks are streaming. We have no rigorous batch-mode benchmark for turbo on iPhone 15 Pro Max. Possible that 1–2× realtime IS the ceiling in batch — or possible that we're 3–4× below the achievable batch ceiling. Need a controlled measurement.

### H3 — Prewarm doesn't fully warm
`prewarm: true` claims to preload, but the very-short (2.7s) audio took 17s in test 2. If prewarm were complete, that should be sub-second. Possibly the first transcribe after prewarm still pays a JIT cost. Worth measuring "first transcribe" vs "subsequent transcribes" wall clock.

### H4 — WhisperKit 0.16 has perf or correctness issues fixed upstream
We pinned 0.16 in early March 2026. Latest is past v1.0. Changelog includes turbo-specific fixes we haven't audited. Upgrading is non-trivial (v1.0 has breaking changes — `usePrefillCache` removed, `TextDecoderContextPrefill` removed, package renamed) but might resolve issues.

### H5 — Issue is specific to this turbo variant (`_954MB`)
There is also `openai_whisper-large-v3-v20240930_turbo_632MB` (newer compression of same architecture) and `distil-whisper_distil-large-v3_turbo_600MB` (further distillation). Untested in Dictus. Architecturally similar — distil decoder issue may persist — but mass and quantization differ.

### H6 — Custom code in our chain adds overhead
`UnifiedAudioEngine.collectSamples` returns a fresh `[Float]`, passed through `TranscriptionService` to `WhisperKitEngine`. Three function frames. Probably negligible but never profiled.

### H7 — ANE not actually used despite defaults
Configured to target ANE (`.cpuAndNeuralEngine`), but the runtime may fall back to CPU/GPU if a kernel doesn't compile. Need Instruments os_signpost capture to confirm.

---

## 7. Audit findings (issue #168) and resolution of #163

The audit launched parallel research on four axes. Results below.

### Codebase audit
Our integration was **minimal** — `WhisperKitConfig(prewarm:true, load:true, download:true)` one-shot, and `DecodingOptions` with only six explicit fields (`task`, `language`, `temperature=0`, `usePrefillPrompt=true`, `usePrefillCache=true`, `skipSpecialTokens=true`). All other parameters (chunkingStrategy, sampleLength, thresholds, concurrentWorkerCount, ...) were left to SDK defaults.

### WhisperAX canonical audit (v0.16.0 + main HEAD)
Two clones in `/tmp/whisperkit-016/` and `/tmp/whisperkit-latest/`. Key finding: **WhisperAX's AppStorage default for `chunkingStrategy` is `.vad`** (`Examples/WhisperAX/WhisperAX/Views/ContentView.swift:57`), explicitly passed into every `DecodingOptions`. The SDK default is `nil`, so callers who omit it (us) fall through to `TranscribeTask`'s seek loop **without** VAD-aware boundaries. WhisperAX has **zero turbo-specific branches** anywhere — turbo is just a model-name string.

Result merging: WhisperAX uses `TranscriptionUtilities.mergeTranscriptionResults`. **For text output, the algorithm is identical** to our `.map(.text).joined(" ")` (`TranscriptionUtilities.swift:81`). Not a load-bearing divergence.

### Version audit (0.16.0 → 1.0.0)
Reviewed every release between March 2025 (0.16.0) and May 2026 (1.0.0). **Zero PRs touch the transcription / decoder / long-form / turbo path.** All four releases ship adjacent features (TTSKit, SpeakerKit, Swift 6 concurrency) or breaking cleanup. **Upgrading does not fix #163.** Recommendation: stay on 0.16.0 for now, schedule v1.0.0 migration as a separate task (package URL change, `supressTokens` typo fix, `MLTensor.asXArray` → `await toXArray()`, `usePrefillCache` removal — none affecting our use case).

### External audit (paper + Argmax issues)
- ICML 2025 paper benchmarks are **streaming-only on M3 Max desktop**, not batch on iPhone. The "5×–7× realtime" marketing claim does not appear in the paper itself. Our batch RTF on iPhone is structurally outside Argmax's optimization envelope.
- Maintainer ZachNagengast (Argmax) confirms in [issue #372](https://github.com/argmaxinc/argmax-oss-swift/issues/372) that distilled turbo "**does not hold up as well for various features**". Issues [#167](https://github.com/argmaxinc/argmax-oss-swift/issues/167), [#285](https://github.com/argmaxinc/argmax-oss-swift/issues/285), [#109](https://github.com/argmaxinc/argmax-oss-swift/issues/109) document recurring patterns of empty / truncated / looped outputs on turbo. Argmax's only suggested workaround is tuning `DecodingOptions` thresholds.

### Variant A — `chunkingStrategy: .vad` in isolation

Earlier #163 attempts (Section 5) combined `.vad` with threshold tweaks (`noSpeechThreshold`, `logProbThreshold`, `temperatureFallbackCount`) and regressed. The hypothesis was that the threshold tweaks, not `.vad`, caused the regression. Validated by isolating `.vad`:

```swift
DecodingOptions(
    task: .transcribe,
    language: language,
    temperature: 0.0,
    usePrefillPrompt: true,
    usePrefillCache: true,
    skipSpecialTokens: true,
    chunkingStrategy: .vad   // ← only change vs baseline
)
```

**Validation on iPhone 15 Pro Max** (Variant A, 2026-05-09):

| Model | Audio | Wall clock | RTF | lastSegEnd / audioSec | Verdict |
|---|---|---|---|---|---|
| small | 35.02 s | 2.03 s | 17.3× | 34.54 / 35.02 | ✓ complete |
| medium | 4.40 s | 1.83 s | 2.40× | 4.24 / 4.40 | ✓ complete |
| medium | 23.51 s | 5.26 s | 4.47× | 23.20 / 23.51 | ✓ complete |
| medium | 33.62 s | 8.08 s | 4.16× | 33.40 / 33.62 | ✓ complete |
| turbo | 5.20 s | 2.19 s | 2.38× | 5.20 / 5.20 | ✓ complete |
| turbo | 25.72 s | 8.91 s | 2.88× | 25.70 / 25.72 | ✓ complete |
| turbo | 33.52 s | 12.40 s | 2.70× | 33.52 / 33.52 | ✓ **complete (was: 71 words / 8 words)** |

Compared to the pre-#163 logs: turbo 33.4 s went from 71 words (last sentence missing) to **106 words complete**, and turbo 31.9 s from 8 words (catastrophic) to consistent full transcription.

**Bonus**: turbo wall-clock improved ~2× vs the earlier `.vad`+thresholds attempt. Likely because the threshold tweaks were triggering temperature-fallback cascades (full re-decodes), which are no longer firing.

**No regression** on small / medium. No errors / fallbacks / cancels in the run logs.

Per-model decoding architecture (axis C of #168) is **not needed** — `.vad` works for all four Whisper variants. The single shared `WhisperKitEngine` stays as-is.

---

## 8. Open questions still live after #163

The audit answered most of #168, but two threads remain:

### Q1 — Turbo's absolute slowness on iPhone
Variant A confirms turbo at **2.7× RTF** while small runs at **17×** on the same device. Turbo is *slower* than medium in batch mode despite the distilled decoder. Likely structural (large encoder + ANE specialization slowness — see Argmax [#301](https://github.com/argmaxinc/argmax-oss-swift/issues/301), [#304](https://github.com/argmaxinc/argmax-oss-swift/issues/304)), not a Dictus bug. Tracked as a separate issue with concrete next steps: test alternative quantizations (`large-v3-v20240930_turbo_632MB`, `distil-whisper_distil-large-v3_turbo_600MB`), confirm ANE-utilisation via Instruments, and surface "slow but accurate" UX cues in the model picker.

### Q2 — WhisperKit upgrade as standalone hygiene
v1.0.0 brings package URL change + Swift 6 + minor breaking renames. None of it helps any current bug, but staying on the supported branch is good housekeeping. To be planned as its own issue when bandwidth allows.

---

## 9. References

- Issue #163 (resolved by Variant A): https://github.com/getdictus/dictus-ios/issues/163
- Issue #168 (the wider audit, this document's home): https://github.com/getdictus/dictus-ios/issues/168
- Issue #144 (related, fixed in PR #164): https://github.com/getdictus/dictus-ios/issues/144
- WhisperKit source 0.16.0: https://github.com/argmaxinc/WhisperKit/tree/v0.16.0
- WhisperKit paper (ICML 2025): https://arxiv.org/html/2507.10860v1
- Argmax `promptTokens` empty-result bug: https://github.com/argmaxinc/WhisperKit/issues/372
- HuggingFace `argmaxinc/whisperkit-coreml` (model repo): https://huggingface.co/argmaxinc/whisperkit-coreml
- WhisperAX example (canonical integration): https://github.com/argmaxinc/WhisperKit/tree/main/Examples/WhisperAX
