# Phase 14: Model Pipeline - Research

**Researched:** 2026-03-12
**Domain:** iOS model lifecycle management (download, CoreML compilation, device-aware selection)
**Confidence:** HIGH

## Summary

Phase 14 is a focused refinement phase with no new architectural patterns to introduce. The existing codebase already has solid model management infrastructure (`ModelManager`, `ModelInfo`, `ModelCardView`, `ModelManagerView`). The work consists of: (1) removing the Large Turbo v3 entry from the catalog, (2) making `isRecommended()` RAM-aware using `ProcessInfo.processInfo.physicalMemory`, (3) fixing the progress bar to show an indeterminate spinner during CoreML compilation instead of a stuck "0%", and (4) verifying that Parakeet routing and display names are correct (they appear to be already).

Three requirements (MODEL-03, MODEL-04, MODEL-06) were explicitly removed during the discussion phase. The `cleanupFailedModel()` method exists but needs verification that it covers FluidAudio's cache paths. The onboarding `ModelDownloadPage` currently hardcodes "openai_whisper-small" as the recommended model and needs updating to use the dynamic recommendation.

**Primary recommendation:** Treat this as a surgical code modification phase -- no new files, no new patterns. Modify 4 existing files (`ModelInfo.swift`, `ModelManager.swift`, `ModelCardView.swift`, `ModelDownloadPage.swift`) and verify 3 others.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Large Turbo v3 -- hard removal**: Remove entirely from `ModelInfo.allIncludingDeprecated` (not just deprecated). No users in beta yet, no backward compatibility concern. Delete the `openai_whisper-large-v3_turbo` entry.
- **Smart default model based on device RAM**: `ProcessInfo.processInfo.physicalMemory` to detect RAM. >=6 GB -> Parakeet v3 recommended. <=4 GB -> Small recommended. `isRecommended()` becomes dynamic. Onboarding pre-highlights recommended model. Model manager shows "Recommande" badge on RAM-appropriate model.
- **Progress bar bug fix**: For Parakeet, replace determinate progress bar with indeterminate ProgressView (spinner) during compilation. For WhisperKit, same fix during prewarm. Label says "Optimisation en cours..." with spinner, not "0%".
- **Parakeet routing (MODEL-07)**: Verify only, no rewrite expected unless bug found.
- **Parakeet display name (MODEL-08)**: Verify only. `ModelInfo` already shows `displayName: "Parakeet v3"`.
- **Retry with cleanup (MODEL-05)**: Verify existing `cleanupFailedModel()` works for Parakeet too.
- **FluidAudio cache behavior**: Persistent cache survives app deletion. Not a bug, beneficial for UX.

### Claude's Discretion
- Whether `isRecommended()` lives as a static func on ModelInfo or remains on ModelManager (CONTEXT suggests ModelInfo as catalog-level logic)
- Label phrasing: "Recommande pour votre iPhone" vs plain "Recommande"

### Deferred Ideas (OUT OF SCOPE)
- Background downloads with URLSession delegate (MODEL-F02)
- Smart queue for ANE (MODEL-F01)
- Full-screen download modal -- discussed and rejected
- MODEL-03: Onboarding step reorder -- removed
- MODEL-04: Full-screen modal during download -- removed
- MODEL-06: Mic disabled during compilation -- removed
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MODEL-01 | Large Turbo v3 gated/removed from catalog | Remove entry from `allIncludingDeprecated` array in ModelInfo.swift. Confirmed: no users in beta, safe hard delete. |
| MODEL-02 | CoreML compilation shows visible progress | Replace determinate `ProgressView(value:)` with indeterminate `ProgressView()` + "Optimisation en cours..." label during `.prewarming` state. Already partially done in ModelCardView (line 141-146) but needs the label text fix. |
| MODEL-03 | ~~Onboarding reorder~~ | **REMOVED** by user decision. No action. |
| MODEL-04 | ~~Full-screen modal~~ | **REMOVED** by user decision. No action. |
| MODEL-05 | Prewarming failure retry-with-cleanup | `cleanupFailedModel()` exists (ModelManager.swift:325). Verify FluidAudio cache cleanup. Error state UI already shows retry button (ModelCardView:178-201). |
| MODEL-06 | ~~Mic disabled during compilation~~ | **REMOVED** by user decision. No action. |
| MODEL-07 | Parakeet engine routing correct | Code inspection confirms: `DictationCoordinator.ensureParakeetReady()` creates `ParakeetEngine`, sets it via `transcriptionService.prepare(engine:)`. Routing is correct. Verify-only task. |
| MODEL-08 | Parakeet displays "Parakeet v3" | `ModelInfo` catalog line 160: `displayName: "Parakeet v3"` -- already correct. Grep for incorrect names in UI. Verify-only task. |
</phase_requirements>

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WhisperKit | 0.16.0+ | Speech-to-text (Whisper models) | Already integrated, SPM |
| FluidAudio | Latest | Parakeet STT engine | Already integrated, SPM |
| SwiftUI | iOS 17+ | All UI | Project standard |

### Supporting (no new dependencies)
No new libraries needed. All work uses existing Swift Foundation APIs:
- `ProcessInfo.processInfo.physicalMemory` -- returns `UInt64` (bytes), divide by `1_073_741_824` for GB
- `ProgressView()` (indeterminate) vs `ProgressView(value:total:)` (determinate) -- both SwiftUI native

## Architecture Patterns

### Existing Patterns to Follow

**Pattern 1: ModelState enum for lifecycle tracking**
Already in place. States: `.notDownloaded`, `.downloading`, `.prewarming`, `.ready`, `.error(String)`. The `.prewarming` state already triggers the indeterminate spinner in `ModelCardView`. The fix is about the label text and ensuring consistency.

**Pattern 2: @MainActor on ModelManager**
All `@Published` mutations happen on main thread. Any new computed properties or methods on `ModelManager` must respect this.

**Pattern 3: PersistentLog.log() for state transitions**
All model lifecycle events are logged. New RAM detection logic should log which tier was detected.

**Pattern 4: CatalogVisibility enum**
Used for soft deprecation (Tiny/Base). Not needed for Large Turbo removal since we're hard-deleting the entry entirely.

### Recommended Structure for isRecommended()

Move from `ModelManager.isRecommended(_:)` (currently hardcoded to "openai_whisper-small") to a `static func` on `ModelInfo`:

```swift
// ModelInfo.swift -- new static method
public static func recommendedIdentifier() -> String {
    let ramGB = ProcessInfo.processInfo.physicalMemory / 1_073_741_824
    if ramGB >= 6 {
        return "parakeet-tdt-0.6b-v3"
    } else {
        return "openai_whisper-small"
    }
}

public static func isRecommended(_ identifier: String) -> Bool {
    identifier == recommendedIdentifier()
}
```

**Why on ModelInfo (not ModelManager):** This is catalog-level logic (which model is best for this device). It doesn't depend on download state or any `@Published` properties. Putting it on `ModelInfo` makes it accessible from both `ModelManager` and `ModelDownloadPage` without passing around an `ObservableObject`.

### Anti-Patterns to Avoid
- **Don't use WhisperKit.recommendedModels()**: The current `isRecommended()` comment mentions this API but it returns WhisperKit-only recommendations and doesn't know about Parakeet. RAM-based gating is simpler and engine-agnostic.
- **Don't add new ModelState cases**: The existing `.prewarming` state is sufficient. Just fix the UI label.
- **Don't modify the download pipeline**: The Parakeet download path (`downloadParakeetModel`) and WhisperKit path (`downloadWhisperKitModel`) are working. Only the UI representation of the prewarm state needs fixing.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| RAM detection | Custom device model lookup table | `ProcessInfo.processInfo.physicalMemory` | System API, always accurate, no maintenance needed |
| Indeterminate progress | Custom spinning animation | SwiftUI `ProgressView()` (no value param) | Native, respects system accessibility settings |
| Model cleanup | Custom file walker | Existing `cleanupModelFiles()` | Already handles both App Group and WhisperKit paths |

## Common Pitfalls

### Pitfall 1: physicalMemory returns bytes, not GB
**What goes wrong:** Using `physicalMemory` directly in comparisons without division
**Why it happens:** The API returns `UInt64` in bytes (e.g., 6,442,450,944 for 6 GB)
**How to avoid:** Always divide by `1_073_741_824` (1024^3) before comparing
**Warning signs:** All models showing as "Recommande" or none showing

### Pitfall 2: FluidAudio cache path not in cleanupModelFiles()
**What goes wrong:** `cleanupFailedModel()` cleans WhisperKit paths but may not clean FluidAudio's persistent cache
**Why it happens:** FluidAudio manages its own cache location (not in App Group or Documents/huggingface)
**How to avoid:** Verify during implementation. FluidAudio's cache survives app deletion (per CONTEXT.md), so the cleanup may need to target FluidAudio's specific cache directory, or accept that FluidAudio's cache is self-managed (re-download is instant because cache persists)
**Warning signs:** Parakeet model stuck in error state, retry doesn't help

### Pitfall 3: ModelDownloadPage creates its own ModelManager instance
**What goes wrong:** `ModelDownloadPage` has `@StateObject private var modelManager = ModelManager()` -- a SEPARATE instance from the one used elsewhere
**Why it happens:** Each `@StateObject` creates an independent instance
**How to avoid:** This is actually fine for onboarding (isolated context). But the `recommendedModel` hardcoded to `"openai_whisper-small"` must be updated to use the dynamic `ModelInfo.recommendedIdentifier()`.
**Warning signs:** Onboarding always shows "Small" regardless of device RAM

### Pitfall 4: ModelCardView error retry doesn't call cleanupFailedModel
**What goes wrong:** The "Reessayer" button (line 182) only resets state to `.notDownloaded` without cleanup
**Why it happens:** Cleanup is on a separate trash button. The retry path should also cleanup first.
**How to avoid:** Make the retry button call `cleanupFailedModel()` before resetting to `.notDownloaded`, or at minimum call it at the start of `downloadModel()`.
**Warning signs:** Retry fails because corrupted partial files remain

## Code Examples

### RAM-based recommendation (to add to ModelInfo.swift)
```swift
// Source: ProcessInfo Apple docs + CONTEXT.md decision
public static func recommendedIdentifier() -> String {
    let ramGB = ProcessInfo.processInfo.physicalMemory / 1_073_741_824
    // >=6 GB: iPhone 12 Pro, 13 Pro, 14+, 15+, 16+
    // <=4 GB: iPhone 12, 12 mini, 13, 13 mini
    if ramGB >= 6 {
        return "parakeet-tdt-0.6b-v3"
    } else {
        return "openai_whisper-small"
    }
}
```

### Indeterminate progress during prewarm (already in ModelCardView, needs label fix)
```swift
// ModelCardView.swift -- .prewarming case (current code is almost correct)
case .prewarming:
    VStack(spacing: 2) {
        ProgressView()  // Already indeterminate -- good
        Text("Optimisation en cours...")  // Fix: was "Optimisation..."
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
```

### Dynamic onboarding model selection
```swift
// ModelDownloadPage.swift -- replace hardcoded model
private var recommendedModel: String {
    ModelInfo.recommendedIdentifier()
}

// Update the model card to show dynamic info
private var recommendedModelInfo: ModelInfo? {
    ModelInfo.forIdentifier(ModelInfo.recommendedIdentifier())
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded `isRecommended == "small"` | RAM-based dynamic recommendation | Phase 14 | Parakeet v3 becomes default on >=6GB devices |
| Large Turbo in catalog | Removed entirely | Phase 14 | Prevents OOM crashes on constrained devices |
| "0%" during compilation | Indeterminate spinner | Phase 14 | Fixes confusing UX |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual testing on device/simulator |
| Config file | None (no unit test framework configured) |
| Quick run command | Xcode build + manual verification |
| Full suite command | Xcode build + manual verification on device |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MODEL-01 | Large Turbo v3 not in catalog | manual | Build, verify `ModelInfo.all` does not contain "openai_whisper-large-v3_turbo" | N/A |
| MODEL-02 | Spinner during compilation | manual | Download model, observe UI during prewarm phase | N/A |
| MODEL-05 | Retry cleans up and re-attempts | manual | Force-kill during download, verify retry works | N/A |
| MODEL-07 | Parakeet routing correct | manual | Select Parakeet model, record, verify transcription | N/A |
| MODEL-08 | Display name "Parakeet v3" | manual | Grep codebase + visual check in model manager | N/A |

### Sampling Rate
- **Per task commit:** Xcode build succeeds (no compiler errors)
- **Per wave merge:** Manual device test of model download + prewarm flow
- **Phase gate:** Full flow: onboarding with dynamic recommendation, model download, prewarm spinner, Parakeet routing

### Wave 0 Gaps
None -- no test infrastructure to create. This phase is pure code modification with manual verification.

## Open Questions

1. **FluidAudio cache cleanup path**
   - What we know: FluidAudio caches models persistently (survives app deletion). `cleanupModelFiles()` cleans App Group + WhisperKit HuggingFace paths.
   - What's unclear: Does FluidAudio expose an API to clear its cache? Is it in `Caches/` or a custom location?
   - Recommendation: During implementation, check FluidAudio's `AsrModels` API for cache management. If no API exists, document that Parakeet cleanup only resets state (not files), which is acceptable since re-download is instant from cache.

2. **Onboarding model card content for Parakeet**
   - What we know: `ModelDownloadPage` hardcodes "Whisper Small" text and "~500 Mo" size.
   - What's unclear: If the recommended model becomes Parakeet v3, the card content needs to change dynamically (name, size, description).
   - Recommendation: Make the model card in `ModelDownloadPage` data-driven from `ModelInfo.forIdentifier()` instead of hardcoded strings.

## Sources

### Primary (HIGH confidence)
- Direct code inspection of `ModelInfo.swift`, `ModelManager.swift`, `ModelCardView.swift`, `ModelDownloadPage.swift`, `DictationCoordinator.swift`, `ParakeetEngine.swift`, `TranscriptionService.swift`
- CONTEXT.md decisions and code_context sections

### Secondary (MEDIUM confidence)
- Apple `ProcessInfo.physicalMemory` documentation (stable API since iOS 2.0)
- SwiftUI `ProgressView` documentation (indeterminate vs determinate)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new dependencies, all code already exists
- Architecture: HIGH - direct code inspection confirms all patterns
- Pitfalls: HIGH - identified from actual code reading (not hypothetical)

**Research date:** 2026-03-12
**Valid until:** 2026-04-12 (stable -- no external dependency changes expected)
