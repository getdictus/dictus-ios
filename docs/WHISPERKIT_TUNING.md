# WhisperKit Investigation Notes

Working knowledge base for Dictus' WhisperKit integration. **This is investigation in progress — not a prescriptive config guide.** Captures what we know, what we tried, what failed, and the open questions for the audit kicked off by issue #163.

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

## 7. What the audit should cover (proposed scope)

When we restart from a clean context to do this properly:

### Read the canonical Argmax integration
- `Examples/WhisperAX/` in the WhisperKit repo. How does it construct `WhisperKit`, what `DecodingOptions` does it pass, what's its threading model.
- The Argmax paper's actual configuration (ICML 2025 — `arxiv.org/html/2507.10860v1`). Identify what they measured and how.
- Argmax's benchmark page methodology — batch vs streaming, audio characteristics, device state.

### Audit our integration against the canonical
- Compare `DictationCoordinator` + `WhisperKitEngine` + `TranscriptionService` against WhisperAX's flow.
- List every divergence and its rationale (or lack thereof).

### Per-model status
- Validate small / medium / parakeet are actually working well (user reports them as "OK", but never benchmarked rigorously). Out-of-scope tweaks could affect them too.
- Measure batch wall-clock for each on a known audio.

### Version question
- Check `Package.resolved` history: when was 0.16 pinned, and why (commit message / PR).
- Read 0.17 / 0.18 / 1.0 changelogs for items relevant to turbo, long-form, or perf.
- If upgrade is desirable, plan migration: regression-test all four models, watch for `usePrefillCache` removal impact, package rename.

### Decide
- Does turbo on iOS via WhisperKit batch mode have a viable path, or do we accept it as a permanent limitation?
- If permanent: how do we surface to users (cap audio at 28s? show a warning? remove turbo from the catalog on iOS-only?).
- If viable: which hypothesis above do we attack first?

---

## 8. References

- Issue #163 (this branch's reason for existing): https://github.com/getdictus/dictus-ios/issues/163
- Issue #144 (related, fixed in PR #164): https://github.com/getdictus/dictus-ios/issues/144
- WhisperKit source 0.16.0: https://github.com/argmaxinc/WhisperKit/tree/v0.16.0
- WhisperKit paper (ICML 2025): https://arxiv.org/html/2507.10860v1
- Argmax `promptTokens` empty-result bug: https://github.com/argmaxinc/WhisperKit/issues/372
- HuggingFace `argmaxinc/whisperkit-coreml` (model repo): https://huggingface.co/argmaxinc/whisperkit-coreml
- WhisperAX example (canonical integration): https://github.com/argmaxinc/WhisperKit/tree/main/Examples/WhisperAX
