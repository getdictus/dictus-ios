# Phase 37 — On-device validation

**Issue:** [#104](https://github.com/getdictus/dictus-ios/issues/104) — Re-test Whisper Turbo and add device compatibility gating.

**Date:** 2026-04-22 → 2026-04-23.

**Device under test:** iPhone 15 Pro Max (`iPhone16,2`), 8 GB RAM marketed (7.47 GB reported by OS), iOS 26.3.1, A17 Pro.

---

## First attempt (rev 76c5663)

**Catalog identifier tested:** `openai_whisper-large-v3_turbo` (non-quantized).

### Stage 1 — Download

```
14:58:24  modelDownloadStarted name=openai_whisper-large-v3_turbo size=0MB
15:00:03  modelDownloadCompleted name=openai_whisper-large-v3_turbo
```

**Verdict:** PASS. 99 seconds. No network or disk-space issue.

### Stage 2 — Prewarm / CoreML init

```
15:00:03  modelCompilationStarted name=openai_whisper-large-v3_turbo
```

Then from the Xcode console (these are framework-level errors, not emitted via PersistentLog):

```
ANE model load has failed for on-device compiled macho. Must re-compile the E5 bundle. @ GetANEFModel
E5RT: ANE model load has failed for on-device compiled macho. Must re-compile the E5 bundle. (13)
[Espresso::handle_ex_plan] exception=ANECF error: failed to load ANE model
    file:///.../openai_whisper-large-v3_turbo/TextDecoder.mlmodelc/model.mil
    Error=createProgramInstanceForModel:...: Program load failure (0x20004)
Error plan build: -1.
```

**No `modelCompilationCompleted`. No `modelDownloadFailed`. `await WhisperKit(config)` never returned.**

The Settings UI stayed in "Optimization…" indefinitely. Force-quit required.

**Verdict:** FAIL (hang — worse than a clean throw).

### Stage 3 — Transcription runtime

Not reached. Prewarm never completed.

---

## Root cause

`openai_whisper-large-v3_turbo` (non-quantized, ~950 MB as-measured) is **not an iPhone-compatible WhisperKit variant**. Argmax's authoritative [`config.json`](https://huggingface.co/argmaxinc/whisperkit-coreml/blob/main/config.json) lists it **only** under macOS / M-series identifier groups. The iPhone families (identifiers `iPhone15`, `iPhone16`, `iPhone17`, `iPhone18`, which map to the iPhone 14 Pro through iPhone 17 hardware generations) list the following quantized Turbo variants as supported:

```
openai_whisper-large-v2_turbo_955MB
openai_whisper-large-v3_turbo_954MB        ← the correct one for us
distil-whisper_distil-large-v3_turbo_600MB
openai_whisper-large-v3-v20240930_turbo_632MB
```

The ANE on Apple's mobile chips (A17 Pro included) cannot load the non-quantized `TextDecoder.mlmodelc` regardless of chip generation — its memory layout exceeds the mobile ANE budget, producing the `E5 bundle` load failure at CoreML program-instance creation time (`0x20004`). This aligns with Argmax maintainer feedback on [WhisperKit #268](https://github.com/argmaxinc/WhisperKit/issues/268) — the same class of hang was observed on iPhone 13 Pro with the same non-quantized identifier, with WhisperKit init stuck "infinitely".

**This was also the root cause of the 2026-03 removals** (commits `9cbc243`, `d70d62a`). The retest on 2026-04-22 reproduced the exact same failure mode.

---

## Corrective action (rev a2b7a91 — Commit 3 of Phase 37)

1. **Catalog identifier switched** to `openai_whisper-large-v3_turbo_954MB` in `DictusCore/Sources/DictusCore/ModelInfo.swift` — the variant Argmax explicitly lists as iPhone-supported.
2. **Gate lowered to `physicalMemoryGB >= 6`** in `ModelInfo.isSupported(on:)`, matching Argmax's per-device support list (all iPhone 14+ families with 6 GB RAM or more).
3. **120-second timeout** added on `WhisperKit(config)` in `ModelManager.downloadWhisperKitModel` via `withPrewarmTimeout`. If CoreML compilation hangs (ANE failure or otherwise), the task is cancelled, `.error` state is set, `cleanupModelFiles` runs, and a `modelPrewarmTimeout` LogEvent is emitted — no more indefinite UI spinner.
4. **ModelInfoTests updated** — new assertions reflect that Turbo is now gated-in from 6 GB.

---

## Pending re-validation

After rebuilding from `a2b7a91` onward, re-run the 3-stage protocol on iPhone 15 Pro Max:

- Stage 1 — download of `..._954MB` (expected PASS, similar ~100 s timing).
- Stage 2 — prewarm (**expected PASS** per Argmax compatibility matrix). If it hangs again, the 120 s timeout fires and we know definitively that the compatibility matrix is lying for this device.
- Stage 3 — 10 consecutive 10–30 s dictations (memory, thermal, latency).

Document outcome in a follow-up section of this file.

---

## What we can NOT answer without more devices

- Whether the `_954MB` variant behaves acceptably on 6 GB RAM devices (iPhone 14 Pro / 15 / 15 Plus / etc.). Argmax claims yes; we cannot verify without hardware access.
- Whether thermal throttling kicks in during sustained dictation on any tier.

These remain open for TestFlight-driven observation once Turbo ships.

---

## Sources

- [WhisperKit config.json (device_support section)](https://huggingface.co/argmaxinc/whisperkit-coreml/resolve/main/config.json)
- [WhisperKit Issue #268 — Unable to load model (or very very slow)](https://github.com/argmaxinc/WhisperKit/issues/268)
- Dictus [issue #104](https://github.com/getdictus/dictus-ios/issues/104) + m13v's initial comment flagging `os_proc_available_memory` + Pierre's 3-stage checkpoint insight.
