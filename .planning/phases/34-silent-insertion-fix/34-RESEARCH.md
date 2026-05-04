# Phase 34: Silent Insertion Fix — Research

**Researched:** 2026-04-15
**Domain:** iOS keyboard-extension text insertion via `UITextDocumentProxy`, cross-process App Group wiring, SwiftUI-hosted toolbar banner UX, `ActivityKit` Dynamic Island states
**Confidence:** HIGH for existing-code findings (read directly from source), MEDIUM-HIGH for `UITextDocumentProxy` predicate behavior (well-documented Apple API, but on-device verification required for the exact "stale-proxy" semantics that cause #118)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Diagnostic instrumentation**
- Always-on probe wraps every `insertText()` call on both warm path (`KeyboardState.handleTranscriptionReady`) and cold start Audio Bridge insertion path.
- Probe fields: privacy-safe only — counts (`documentContextBeforeInput.count` before/after, `transcription.count`), booleans (`hasText` before/after, `hasFullAccess`, `isKeyboardVisible`), timing deltas (ms since Darwin notification, ms since recording stopped), and session/controller identifiers. **Never log raw transcription text or document context strings.**
- Emitted via existing `PersistentLog` / `LogEvent` pipeline so it exports through the current log-dump UX.
- Claude has discretion on exact field set and `LogEvent` case naming, subject to the constraints above (minimal runtime impact, privacy-safe).

**Fix strategy**
- Primary pattern: **validate → insert → verify → retry → escalate.**
  1. Pre-check proxy health before insertion (`documentContextBeforeInput != nil`, `hasFullAccess`, active session/controller present).
  2. Call `insertText()`.
  3. Verify by computing post-delta (`documentContextBeforeInput.count` after minus before) and comparing to `transcription.count`.
  4. On empty-delta or delta mismatch, retry up to **3 times with 50 / 100 / 200 ms backoff** (≈350 ms total worst case).
  5. If all retries fail, escalate to loud-fail UX.
- No queue-on-resume behavior. If the extension is not live/visible when the transcription lands, go straight to loud-fail — queueing risks wrong-field flush, stale flush across app switches, and flushes into password/URL fields.
- Existing 100 ms UserDefaults retry stays (it solves a different problem: App Group propagation lag).

**Loud-fail UX**
- **Dynamic Island:** error icon + short `Dictus` label (expanded view: short error line). Does not carry the actionable recovery message.
- **Toolbar banner:** reuses existing error-banner pattern. Actionable copy pointing to DictusApp. Auto-hide after **4 seconds**. Accompanied by error haptic via `HapticFeedback`.
  - FR: `Insertion impossible. Retrouvez votre transcription dans Dictus.`
  - EN: `Couldn't insert. Find your transcription in Dictus.`
- **DictusApp home:** dedicated "last transcription" card always visible when a recent transcription exists in the App Group. Shows the text (or a preview) and a copy-to-clipboard button. This is the recovery surface users are directed to.
- No auto-copy to system pasteboard (privacy + surprise behavior).
- No repeated-failure escalation in v1 — ship minimal, observe real-world rate via logs, revisit later if needed.

**Verification**
- **50-run success criterion:** scripted manual run on a real iPhone. Documented protocol (target apps: Notes, Messages, Safari address bar; warm + cold + chained scenarios spread across the 50). Log review confirms zero silent drops (probe reports insertion success on all 50).
- **#118 repro matrix:** covered as a checklist inside the fix PR description, listing each scenario (warm same-app, cold start, backgrounded keyboard, rapid chained) and the observed result.
- **Regression guard on 3 insertion paths** (warm Darwin, cold start Audio Bridge, chained): Claude's discretion — recommended approach is to let the PR repro matrix cover all three paths explicitly and add a `test-matrix.md` inside the phase directory if scope allows.
- **Rollout:** ship probe instrumentation and fix in the same build. Bug is critical (STAB-01), do not delay the fix for a probe-only build.

### Claude's Discretion
- Exact probe field set (subject to privacy + low-overhead constraints).
- Exact `LogEvent` case names and structure.
- Exact proxy health-check predicates (which `UITextDocumentProxy` properties best indicate a live input session).
- Whether to add a `test-matrix.md` artifact or keep the repro list PR-side only.
- Final FR/EN wording polish if the proposed copy needs tightening for the existing banner widget.

### Deferred Ideas (OUT OF SCOPE)
- Tappable banner → URL-scheme deep-link into DictusApp "last transcription" view. Considered, kept out of scope for v1 (adds URL scheme handling + routing). Revisit if banner-tap rate is low in telemetry.
- Repeated-failure escalation (Full Access nudge, anonymous failure counter, "reinstall keyboard" hint). Out of scope for v1 — will reconsider once real-world failure rate is measured from the probe.
- Transcription history view in DictusApp. Out of scope — premium/Pro scope per REQUIREMENTS.md Out of Scope table (#70).
- Queue-on-resume for transcriptions that land while the keyboard is suspended. Rejected after weighing wrong-field / stale-flush / password-field hazards.
- Automated XCUITest harness for the 3 insertion paths. Deferred — manual scripted run chosen for v1 velocity; revisit if regressions recur.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STAB-01 | Transcription text is always inserted into the target app when dictation completes (fixes silent insertion failure, issue #118) | Existing code map (§Existing Code — Authoritative Insertion Paths), probe design respecting `LogEvent` privacy model (§Probe Design), shared insertion helper pattern (§Architecture — Shared Insert Helper), retry backoff budget (§Timing & UX), loud-fail UX wiring points across Dynamic Island, toolbar banner, DictusApp home (§Loud-Fail UX Integration), validation plan (§Validation Architecture). |
</phase_requirements>

## Summary

Issue #118 is a silent no-op on `controller?.textDocumentProxy.insertText(transcription)` at `KeyboardState.swift:341`. Logs prove the call is made (`keyboardTextInserted` fires, haptic fires, status goes `transcribing → ready`) but no text lands in the host field. The current pipeline has zero post-insertion verification — we assume success because `insertText` does not throw.

The fix is well-scoped: wrap both warm-path insertion (`KeyboardState.handleTranscriptionReady:341` and the 100 ms retry at `:363-383`) and the cold-start variant in a single shared helper that (1) validates proxy health, (2) inserts, (3) verifies via `documentContextBeforeInput` delta, (4) retries 3× with 50/100/200 ms backoff, (5) escalates to a loud-fail UX (Dynamic Island error variant, toolbar banner, DictusApp "last transcription" card with copy-to-clipboard). The probe produces privacy-safe structured `LogEvent` entries on every attempt so real-world failure rate can be measured and issue #118 can be definitively closed by log inspection rather than user perception.

**Primary recommendation:** Add one shared `InsertTranscriptionHelper` (or an extension method on `UIInputViewController`) consumed by both call sites. Instrument through the existing `PersistentLog` / `LogEvent` pipeline with three new cases (`keyboardInsertProbe`, `keyboardInsertRetry`, `keyboardInsertFailed`). Drive loud-fail UX from a new `@Published` error flag on `KeyboardState` that `KeyboardRootView` forwards to `ToolbarView.statusMessage` (pattern already exists) plus a one-shot DI "insertion failed" phase variant and a DictusApp home card fed by the existing `SharedKeys.lastTranscription` / `lastTranscriptionTimestamp` that `DictationCoordinator` already writes.

## Standard Stack

No new dependencies required. Everything runs on iOS frameworks already in use:

### Core (Already In Project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| UIKit `UITextDocumentProxy` | iOS 17+ | The only Apple-sanctioned text-field proxy inside a keyboard extension | Only surface Apple exposes for writing into the host app from an extension |
| UIKit `UIInputViewController` | iOS 17+ | `hasFullAccess`, `hasText`, `textDocumentProxy` properties | Canonical keyboard-extension host class |
| Foundation `UserDefaults(suiteName:)` | iOS 17+ | App Group cross-process store (`group.solutions.pivi.dictus`) | Already the app/keyboard transport; no change needed |
| `DictusCore.PersistentLog` + `LogEvent` | In-repo | Privacy-safe structured logging into App Group file | Existing pipeline consumed by log-dump UX; add cases, don't fork |
| `DictusCore.HapticFeedback` | In-repo | Centralized `UINotificationFeedbackGenerator` + impact generators | Already has `textInserted` success idiom; add an error-haptic wrapper |
| `ActivityKit` `Activity<DictusLiveActivityAttributes>` | iOS 17+ | Dynamic Island phase updates | Already wired in `LiveActivityManager`; extend the existing `.failed` phase or add a short variant |
| SwiftUI `Text` + `ToolbarView.statusMessage` | In-repo | Existing red-text error banner in the keyboard chrome | Already a documented pattern in `ToolbarView.swift:38-43`, reuse verbatim |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Wrap both call sites in a shared helper | Add retry logic inline at each site | Duplicates logic; #118-class bugs recur when only one path is fixed. Rejected. |
| Check only `documentContextBeforeInput` delta | Additionally inspect `hasText` before/after and `hasFullAccess` | Multiple redundant signals catch more failure modes (context=nil vs. Full Access revoked vs. proxy disconnected). Probe is already privacy-safe, low cost. Keep multi-signal. |
| Queue-on-resume when keyboard suspended | Loud-fail only | Queueing risks wrong-field / password-field / stale flushes. User explicitly rejected in CONTEXT.md. Honored. |
| Auto-copy to `UIPasteboard.general` | None | Privacy + surprise. User explicitly rejected. Honored. |

**No `npm install` / `swift package` additions.** All work is internal refactor + instrumentation.

## Architecture Patterns

### Recommended Structure (Additive, In Existing Folders)

```
DictusKeyboard/
├── KeyboardState.swift              # MODIFY: handleTranscriptionReady -> call helper
├── KeyboardViewController.swift     # MODIFY: any cold-start insertion wiring -> call helper
├── TextInsertion/                   # NEW folder
│   └── InsertTranscriptionHelper.swift   # NEW: single helper owning validate/insert/verify/retry
└── Views/
    └── ToolbarView.swift            # MODIFY (minimal): statusMessage wiring already exists
DictusCore/Sources/DictusCore/
├── LogEvent.swift                   # MODIFY: add .keyboardInsertProbe / .keyboardInsertRetry / .keyboardInsertFailed
└── HapticFeedback.swift             # MODIFY: add insertionFailed() using UINotificationFeedbackGenerator(.error)
DictusApp/
├── DictationCoordinator.swift       # NO CHANGE (already writes SharedKeys.lastTranscription + timestamp)
└── Views/HomeView.swift             # MODIFY: transcriptionCard is already there; source-of-truth shift
                                      # to App Group (read lastTranscription at scene-active + onReceive)
```

### Pattern 1: Shared Insert Helper (Single Point Of Truth)
**What:** One function called from both warm and cold-start paths. It owns validation, insertion, verification, retry scheduling, probe logging, and escalation.

**When to use:** Any time the keyboard extension needs to write transcribed text into the host field. Other insertion paths (normal keystroke from `DictusKeyboardBridge.handleInputKey`, emoji, predictions) do NOT use this helper — they remain untouched. The helper is ONLY for the transcription-insertion contract where silent failure has been observed.

**Signature (recommended):**
```swift
// DictusKeyboard/TextInsertion/InsertTranscriptionHelper.swift
// Source: new, modeled on the existing 100ms retry at KeyboardState.swift:363-383

import UIKit
import DictusCore

enum InsertTranscriptionResult {
    case success(attempts: Int, deltaChars: Int)
    case failed(lastError: InsertionFailureReason, attempts: Int)
}

enum InsertionFailureReason: String {
    case proxyNil
    case contextUnavailable      // documentContextBeforeInput == nil
    case noFullAccess
    case keyboardNotVisible
    case noDelta                 // insertText returned, count didn't change
    case deltaMismatch           // count changed by wrong amount
}

struct InsertTranscriptionHelper {
    /// Call site: warm path (KeyboardState.handleTranscriptionReady)
    ///            and cold start Audio Bridge insertion path.
    /// Returns synchronously after the FIRST success or FINAL failure.
    /// Retries are scheduled on the main queue with 50/100/200 ms backoff.
    static func insertTranscription(
        _ transcription: String,
        controller: UIInputViewController?,
        isKeyboardVisible: Bool,
        sessionID: String?,
        darwinToInsertMs: Int,
        path: InsertionPath,  // .warmDarwin | .coldStartBridge
        onComplete: @escaping (InsertTranscriptionResult) -> Void
    )
}
```

Callers at `KeyboardState.swift:341` and `:370` become:
```swift
InsertTranscriptionHelper.insertTranscription(
    transcription,
    controller: self.controller,
    isKeyboardVisible: self.isKeyboardVisible,
    sessionID: self.activeSessionID,
    darwinToInsertMs: /* compute */,
    path: .warmDarwin
) { [weak self] result in
    switch result {
    case .success:
        HapticFeedback.textInserted()
        self?.onTranscriptionInserted?()
        // reset dictation state as today
    case .failed(let reason, let attempts):
        HapticFeedback.insertionFailed()
        self?.escalateInsertionFailure(reason: reason, attempts: attempts)
    }
}
```

### Pattern 2: Validation Predicates (Proxy Health Check)
**What:** Cheap, synchronous checks on `UITextDocumentProxy` + controller before calling `insertText`. If any predicate fails, skip the attempt and count it as a validation fail.

**Recommended predicate set** (Claude's discretion per CONTEXT.md):

| Predicate | Source | Meaning | Pitfall |
|-----------|--------|---------|---------|
| `controller != nil` | weak controller ref | Controller hasn't been deallocated mid-transcription | Controller recreated during swipe-back cold start (documented in `project_fix03_cold_start_diagnosis.md`) |
| `controller.hasFullAccess == true` | `UIInputViewController.hasFullAccess` | Full Access is granted; without it, many proxy operations degrade | User could have revoked Full Access mid-session; already used at `KeyboardRootView.swift:105,143` |
| `controller.textDocumentProxy.documentContextBeforeInput != nil` | `UITextDocumentProxy` | Input session is live and proxy is connected to a field. `nil` = no active input connection | This is the STRONGEST signal for the issue #118 "stale proxy" hypothesis |
| `isKeyboardVisible == true` | `KeyboardState.isKeyboardVisible` | Our extension believes it owns the input surface right now | False positives during rapid controller swap; acceptable — the fallback is loud-fail, not data loss |

Predicates used **for probe context, not as hard gates** (except `controller != nil`):
- `controller.hasText` — Apple's own "is there any text" flag. Cheap boolean, useful before/after.
- `controller.textDocumentProxy.documentContextAfterInput?.count` — included in probe for completeness; not used as a gate.

**Rationale for not using `hasFullAccess` as a hard gate:** the extension's Info.plist already requires `RequestsOpenAccess=true` (per CLAUDE.md). In production this is effectively always true once the user passes onboarding. But if a user toggles it off while the keyboard is up, we want to fall through to loud-fail rather than retry uselessly — so treat `hasFullAccess == false` as a terminal `.noFullAccess` failure and go straight to escalation.

### Pattern 3: Verify-by-Delta
**What:** Read `documentContextBeforeInput?.count` immediately before and immediately after `insertText`. If `after - before == transcription.count`, the proxy accepted and committed the write. Any other outcome = silent drop candidate.

**When to use:** Every insertion attempt.

**Caveats** (MEDIUM confidence — requires on-device validation):
- `documentContextBeforeInput` returns the text **preceding the cursor in the currently visible window** (documented Apple behavior, but the window size is unspecified). For long pre-cursor context, iOS may cap this at ~1000 chars. A perfectly successful insertion could therefore produce `after == before` in the pathological case where both are already at the cap. Mitigation: treat `after >= before + 1` AND `transcription.count > 0` as provisional success, and additionally check `controller.hasText` transitioned from `false → true` when `before == 0`.
- In a password or secure field, `documentContextBeforeInput` always returns `nil`. The pre-check `documentContextBeforeInput != nil` already filters this (we do not want to dictate into a password field anyway).
- In some RTL / emoji-heavy cases `String.count` (Character count) disagrees with `utf16.count`. Recommendation: use `transcription.utf16.count` and `after.utf16.count` in the delta check, since `insertText` is specified against UTF-16-indexed strings at the proxy boundary.

### Pattern 4: Retry Schedule
**Locked by CONTEXT.md:** 3 retries, 50 / 100 / 200 ms backoff, total ≈ 350 ms. Implementation sketch:

```swift
// All on main queue via DispatchQueue.main.asyncAfter
let backoffs: [TimeInterval] = [0.050, 0.100, 0.200]
```

Total budget (50 + 100 + 200 ms delay + 4 attempts × ~1 ms insertion work) ≈ 354 ms worst case. This sits comfortably inside:
- **User UX budget:** the existing overlay-to-idle transition takes ~100-200 ms; users will perceive the retry window as part of the dismissal animation.
- **Watchdog budget:** `KeyboardState.stopWatchdog()` is called before dictation transitions to idle; the new retry window does not interact with watchdog timers.
- **Live Activity budget:** no ActivityKit updates during the retry window — the DI transition to `.ready` or `.failed` only happens after the helper reports result.

### Pattern 5: Loud-Fail Escalation
**What:** If helper returns `.failed`, three surfaces activate in parallel:
1. **Toolbar banner** — set `KeyboardState.statusMessage` to the localized FR/EN string from CONTEXT.md, with a 4-second auto-clear (pattern already exists at `KeyboardState.swift:273-277`, currently used for dictation errors). Accompanied by `HapticFeedback.insertionFailed()`.
2. **Dynamic Island** — extend `LiveActivityManager` with an `endWithInsertionFailure()` that transitions `.transcribing → .failed` carrying a very short label (expanded region only). The state machine already allows `.transcribing → .failed` (`LiveActivityStateMachine.swift:32-39`); no rule change needed. Auto-returns to standby after 3 s like existing `endWithFailure()`.
3. **DictusApp "last transcription" card** — already renders at `HomeView.swift:132-163` keyed to `coordinator.lastResult`. The transcription has already been written to `SharedKeys.lastTranscription` by `DictationCoordinator.swift:398-399` before the keyboard attempts insertion, so the card is guaranteed to have fresh content. **Gap to close:** the card's source of truth must become the App Group key, not only `coordinator.lastResult` (in-memory). On scene-active or on `NotificationCenter didBecomeActive`, HomeView must re-read `SharedKeys.lastTranscription` + `SharedKeys.lastTranscriptionTimestamp` so that a user returning to DictusApp after a failed insertion sees the content even if the coordinator instance was discarded.

### Anti-Patterns to Avoid
- **Hand-rolled `Timer.scheduledTimer` for backoff.** Use `DispatchQueue.main.asyncAfter` — matches the existing pattern at `KeyboardState.swift:363` and keeps cancellation implicit (the success branch simply no-ops subsequent work).
- **Modifying `DictusKeyboardBridge.handleInputKey`'s `insertText` call** (`DictusKeyboardBridge.swift:190`) with any of this logic. Normal keystrokes have different failure characteristics (single-char, user sees immediate feedback) and adding retry/probe there would regress latency. Leave it alone.
- **Touching the Darwin notification / App Group transport.** Out of scope per CONTEXT.md domain boundary. The transport works; the proxy call at the tail is the bug.
- **Removing the existing `:363-383` 100 ms UserDefaults retry.** It solves a different problem (App Group propagation lag for `lastTranscription` key). The new helper sits INSIDE the success branch of that retry.
- **Blocking the main thread during backoff.** `DispatchQueue.main.asyncAfter` is non-blocking. Do not use `Thread.sleep` or `RunLoop.current.run(until:)`.
- **Queueing failed transcriptions for later flush.** Explicitly forbidden by CONTEXT.md (`## Deferred Ideas`).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Structured log events | A parallel "insertion diagnostics" logger | Extend `LogEvent` with new cases; log via `PersistentLog.log(_:)` | Entire export pipeline, os.log forwarding, file coordination, 7-day retention already exist. New sink = duplicated code + missed privacy guards (see `LogPrivacyTests.swift`). |
| Error haptic | New `UINotificationFeedbackGenerator` at the call site | Add `HapticFeedback.insertionFailed()` using the existing pre-allocated `notificationGenerator` with `.error` | Avoids the 2-5 ms generator-creation overhead documented at `HapticFeedback.swift:20-23`. |
| Timer-based retry | `Timer.scheduledTimer` with invalidate tracking | `DispatchQueue.main.asyncAfter` with a success flag | Matches existing pattern; no timer-lifecycle bugs. |
| Dynamic Island failure variant | A new `ActivityKit` attribute struct | Reuse existing `.failed` phase in `DictusLiveActivityAttributes.ContentState.Phase`; extend the compact/minimal glyph copy | `.failed` already renders an X + `xmark` icon (`DictusLiveActivity.swift:94-97, 66-69`). Adding a parallel phase requires widget extension rebuild + store review risk. |
| Toolbar error banner | A new SwiftUI overlay | Reuse `ToolbarView.statusMessage` which already renders red caption text at `ToolbarView.swift:38-43`, driven by `KeyboardState.statusMessage` with 3-second auto-clear precedent at `KeyboardState.swift:273-277` | Literal pattern reuse; no UI regression risk. Only change: bump the auto-clear to 4 s per CONTEXT.md, bind a new FR/EN string, and trigger from the insertion-failure path. |
| DictusApp "last transcription" card | New SwiftUI card | Reuse `HomeView.transcriptionCard(result:)` at `HomeView.swift:132-163` | Already shows a tappable glass card with "Copied!" feedback and `dictusGlass()` styling. Only change: broaden its data source to include App Group read so it survives coordinator discard. |

**Key insight:** Every piece of UI, logging infrastructure, and haptic plumbing this phase needs already exists in the repo. The work is (a) one new helper (one file), (b) three new `LogEvent` cases, (c) one new `HapticFeedback` method, (d) minor wiring changes. No new frameworks, no new UI components, no new architectural layers.

## Common Pitfalls

### Pitfall 1: `documentContextBeforeInput` Windowing
**What goes wrong:** Assuming `documentContextBeforeInput.count` reflects the full text preceding the cursor. It does not — it reflects a bounded window (documented by Apple but size-unspecified, commonly cited as ~1000 chars in the iOS community, MEDIUM confidence — **needs on-device validation**). For transcriptions appended at the end of a long document, `before` may already be at the cap and `after` may also be at the cap, producing `delta == 0` despite a successful insertion.

**Why it happens:** Apple designed the window for autocorrect / predictive text, not for full-document diffing.

**How to avoid:** Use a combination of signals:
1. `delta >= transcription.utf16.count` → definitely success.
2. `delta > 0` AND `delta < transcription.utf16.count` → provisional success (windowing suspected). Log but do not retry.
3. `delta == 0` AND `controller.hasText` transitioned `false → true` → success (empty field case).
4. `delta == 0` AND `controller.hasText` unchanged AND `before == after > 0` (both non-empty, no change) → **true silent drop**, retry.

**Warning signs:** Probe log shows many `delta < transcription.count` on long-text fields (Notes) but insertion visibly worked. Means we need to tune the classifier, not escalate those.

### Pitfall 2: Controller Recreation During Swipe-Back (Cold Start)
**What goes wrong:** During swipe-back cold-start return, iOS destroys and recreates the `KeyboardViewController` (documented in `MEMORY.md` → `project_fix03_cold_start_diagnosis.md`). The `weak controller` reference on `KeyboardState` becomes `nil` between the Darwin notification arriving and the insertion attempt.

**Why it happens:** `UIInputViewController` lifecycle is owned by iOS, not our code. Swipe-back triggers a full re-hosting.

**How to avoid:**
- Probe `controller == nil` as `InsertionFailureReason.proxyNil`.
- The helper's retry schedule naturally gives 350 ms for the new controller to re-register via `registerControllerAppearance` at `KeyboardState.swift:390-401`. Each retry re-reads `self.controller` (which is mutated by the new controller's `viewDidLoad`-driven assignment in `KeyboardViewController.swift:196-201`... wait — that assignment doesn't currently exist on init; it only happens via `KeyboardRootView.onAppear` at `:204`).
- **Gap to verify during planning:** confirm that between the moment `handleTranscriptionReady` first runs and the moment the recreated controller's `KeyboardRootView.onAppear` fires (which is what currently restores `state.controller`), at least one of the 3 retries lands in the window where `state.controller` is non-nil. If not, the helper will still loud-fail (correct behavior), and the DictusApp card + banner become the sole recovery surface.

**Warning signs:** Log shows `keyboardInsertFailed reason=proxyNil path=coldStartBridge` with all 3 retries exhausted on cold-start scenarios. Means retry budget is insufficient for cold-start specifically; potential follow-up is raising cold-start retry count without raising warm-path count (deferred to v1.8 per "no repeated-failure escalation in v1").

### Pitfall 3: Concurrent Duplicate Darwin Notifications
**What goes wrong:** Issue #118's attached log shows 7 duplicate `statusChanged recording→transcribing source=micButton` entries (lines 1220-1232). The current `handleTranscriptionReady` already mitigates this via the "clear-before-insert" pattern at `KeyboardState.swift:334-339`. If we're not careful, the retry helper could re-trigger insertion for an already-cleared key, wasting attempts.

**Why it happens:** Darwin notifications can be coalesced or repeated; the App Group UserDefaults clear-then-insert pattern is the working defense.

**How to avoid:**
- The helper receives the transcription as an **argument**, not by re-reading `SharedKeys.lastTranscription` on each retry. The caller reads once (at `:332` today), clears (at `:338`), then the helper operates on the captured string.
- The helper's success path must NOT re-clear the App Group key (already cleared by caller).
- The helper's failure path must NOT re-write the App Group key (transcription is already there from `DictationCoordinator` — that's what `HomeView` card reads).

**Warning signs:** Probe shows the same `sessionID` attempting insertion multiple times = caller bug, not helper bug.

### Pitfall 4: Toolbar Banner Covering Suggestion Bar
**What goes wrong:** `ToolbarView.swift:30-56` renders banner / language switcher / suggestion bar inside the same ZStack+HStack. Setting `statusMessage` displaces the language switcher / suggestion bar (`.frame(maxWidth: .infinity)`). Right after a failed insertion, the user typing their next word would momentarily lose their suggestion bar.

**Why it happens:** Pattern is already used for dictation errors (`KeyboardState.swift:270-277`). It's acceptable there because errors are rare.

**How to avoid:** Already baked into the existing pattern (`statusMessage` auto-clears after 3 s; we're setting to 4 s per CONTEXT.md). Test that the suggestion bar returns after the banner clears — existing `ToolbarView` architecture handles this by reading `suggestions.isEmpty` fresh on every render.

**Warning signs:** User reports "my suggestions disappeared after a dictation" — check for a leaked `statusMessage` (forgot to clear in the 4 s `asyncAfter`).

### Pitfall 5: DI `.failed → .standby` Race With Keyboard Banner
**What goes wrong:** `LiveActivityManager.endWithFailure()` already auto-returns to `.standby` after 3 s (`LiveActivityManager.swift:463-474`). The keyboard banner's 4 s auto-clear is independent. If the user happens to start a new recording at 3.5 s, DI will be `.standby` (about to become `.recording`) while the banner is still showing "Insertion impossible".

**Why it happens:** Two independent auto-dismiss timers in two processes.

**How to avoid:** This is acceptable — the banner is purely a nudge, and a new recording attempt starting a new session implicitly supersedes the previous failure. No explicit coordination needed. The DictusApp "last transcription" card continues to show the prior transcription regardless of banner state.

**Warning signs:** Only problematic if the user reports banner persisting into the next dictation. If observed, drop banner auto-clear to 3 s to match DI.

## Code Examples

### Existing Warm Path — What We're Wrapping
`DictusKeyboard/KeyboardState.swift:328-385` (read directly from source):
```swift
private func handleTranscriptionReady() {
    logProbe("handleTranscriptionReady", details: sessionDetails())
    refreshFromDefaults()

    if let transcription = defaults.string(forKey: SharedKeys.lastTranscription),
       !transcription.isEmpty {
        defaults.removeObject(forKey: SharedKeys.lastTranscription)
        defaults.synchronize()

        controller?.textDocumentProxy.insertText(transcription)   // <-- #118 silent drop site
        PersistentLog.log(.keyboardTextInserted)
        HapticFeedback.textInserted()
        onTranscriptionInserted?()

        stopWatchdog()
        dictationStatus = .idle
        waveformEnergy = []
        recordingElapsed = 0
        statusMessage = nil
        lastTranscription = nil
        activeSessionID = nil
    } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            /* 100 ms UserDefaults retry — stays unchanged */
            /* inside: self.controller?.textDocumentProxy.insertText(transcription) */
        }
    }
}
```

**Target after Phase 34:** both `insertText` call sites go through the shared helper.

### Existing Structured LogEvent — Pattern For New Cases
`DictusCore/Sources/DictusCore/LogEvent.swift:101` (diagnosticProbe — the existing extensible probe case):
```swift
case diagnosticProbe(component: String, instanceID: String, action: String, details: String)
// formatted: "component=\(component) instanceID=\(instanceID) action=\(action) details=\(details)"
```

**Recommended new cases (Claude discretion — naming only):**
```swift
// Inside LogEvent enum, under // MARK: Keyboard
case keyboardInsertProbe(
    path: String,               // "warmDarwin" | "coldStartBridge"
    sessionID: String,
    attempt: Int,               // 0 = first try, 1-3 = retries
    transcriptionCount: Int,    // utf16 count
    hasFullAccess: Bool,
    hasTextBefore: Bool,
    hasTextAfter: Bool,
    beforeCount: Int,           // -1 if nil
    afterCount: Int,            // -1 if nil
    keyboardVisible: Bool,
    darwinToInsertMs: Int       // ms between Darwin notification and insertText call
)

case keyboardInsertRetry(
    path: String,
    sessionID: String,
    attempt: Int,
    reason: String              // InsertionFailureReason.rawValue
)

case keyboardInsertFailed(
    path: String,
    sessionID: String,
    totalAttempts: Int,
    finalReason: String
)
```

All parameters are counts / booleans / identifiers / durations / enum rawValues. **No raw transcription content. No document context strings.** Matches the privacy model enforced by `LogPrivacyTests.swift`.

### Existing Error-Haptic-Free HapticFeedback — Pattern For New Method
`DictusCore/Sources/DictusCore/HapticFeedback.swift:128-134` (textInserted — existing success idiom):
```swift
public static func textInserted() {
    #if canImport(UIKit) && !os(macOS)
    guard isEnabled() else { return }
    notificationGenerator.notificationOccurred(.success)
    notificationGenerator.prepare()
    #endif
}
```

**Recommended new method (add right below `textInserted`):**
```swift
/// Error notification feedback when transcription insertion fails.
/// Uses the same pre-allocated notificationGenerator as textInserted()
/// to avoid the 2-5 ms generator-creation overhead.
public static func insertionFailed() {
    #if canImport(UIKit) && !os(macOS)
    guard isEnabled() else { return }
    notificationGenerator.notificationOccurred(.error)
    notificationGenerator.prepare()
    #endif
}
```

### Existing Status-Message Banner — Pattern For Loud-Fail Toolbar
`DictusKeyboard/KeyboardState.swift:270-277` (statusMessage with 3 s auto-clear for dictation errors) and `DictusKeyboard/Views/ToolbarView.swift:38-43`:
```swift
// KeyboardState (existing dictation-failure path)
if status == .failed, let errorMsg = defaults.string(forKey: SharedKeys.lastError) {
    statusMessage = errorMsg
    defaults.removeObject(forKey: SharedKeys.lastError)
    defaults.synchronize()
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
        self?.statusMessage = nil
    }
}

// ToolbarView rendering
if let message = statusMessage {
    Text(message)
        .font(.caption)
        .foregroundColor(.red)
        .lineLimit(1)
        .frame(maxWidth: .infinity)
}
```

**Extension for Phase 34:** call the same `statusMessage = "Insertion impossible. Retrouvez votre transcription dans Dictus."` (FR, with EN fallback based on `SharedKeys.language`) from the helper's `.failed` callback, with `asyncAfter(deadline: .now() + 4)` per CONTEXT.md.

### Existing DI Failure Phase — Pattern For Insertion-Failed Variant
`DictusApp/LiveActivityManager.swift:445-475`:
```swift
func endWithFailure() {
    guard isEnabled else { return }
    guard validateTransition(to: .failed) else { return }
    guard let activity = currentActivity else { return }
    autoDismissTask?.cancel()
    PersistentLog.log(.liveActivityTransition(from: "transcribing", to: "failed"))
    currentPhase = .failed
    Task {
        let state = DictusLiveActivityAttributes.ContentState(phase: .failed)
        await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(self.staleInterval)))
    }
    autoDismissTask = Task {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        guard !Task.isCancelled else { return }
        guard currentPhase == .failed else { return }
        await returnToStandby()
    }
}
```

**Gap:** this function is **only called by `DictationCoordinator.handleError`** in DictusApp — the keyboard cannot call it directly (keyboard extension has no ActivityKit access in a write-path; only DictusApp owns `LiveActivityManager`).

**Integration approach:** the keyboard writes a flag to App Group (`SharedKeys.lastError = "insertionFailed:<sessionID>"` or a new dedicated key) **plus** posts a new Darwin notification (e.g., `DarwinNotificationName.insertionFailed`). DictusApp observes the notification and calls `LiveActivityManager.shared.endWithFailure()`. DI's `.failed` phase already renders the X icon. Expanded region can pick up the new flag to show "Insertion failed — open Dictus" if desired.

**Simplification option (recommended for v1):** since `DictationCoordinator` has **already** transitioned DI to `.ready` before insertion is attempted (`DictationCoordinator.swift:405` `LiveActivityManager.shared.endWithResult(preview: finalText)`), the DI is already back to `.standby` by the time the 350 ms retry window expires. Re-entering `.failed` from `.standby` is allowed by the state machine (`LiveActivityStateMachine.swift:37-38` — `.standby: [.recording, .idle]` — **wait, `.failed` is NOT an allowed transition from `.standby`**). **This is a state machine gap that must be closed during planning** — either add `.standby → .failed` to `validTransitions`, or pre-announce the DI state before insertion (hold `.ready` until insertion confirmed, then go to `.standby`; if it fails, transition directly from `.ready → .failed`, which IS allowed — `.ready` has no outgoing `.failed` edge either — actually looking again at `LiveActivityStateMachine.swift:32-39`, the allowed set is `.ready: [.standby, .recording]`, so `.ready → .failed` is ALSO not allowed).

**Actionable recommendation for planner:** add one new valid transition edge in `LiveActivityStateMachine.validTransitions`: `.standby: [.recording, .idle, .failed]` (or `.ready: [.standby, .recording, .failed]` depending on when the transition is signaled). Unit-test coverage exists for this state machine (`LiveActivityStateMachineTests.swift`), so adding an edge is low-risk.

### DictusApp Home — Existing Transcription Card
`DictusApp/Views/HomeView.swift:132-163` (transcriptionCard already implemented, including copy-to-clipboard):
```swift
private func transcriptionCard(result: String) -> some View {
    Button {
        UIPasteboard.general.string = result
        HapticFeedback.recordingStopped()
        showCopiedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopiedFeedback = false
        }
    } label: { /* "Last transcription" label + text */ }
}
```

**Gap to close in Phase 34:** the card is guarded by `if let result = coordinator.lastResult` at `HomeView.swift:33`. This binding disappears when `coordinator` is discarded or `lastResult` is cleared (it IS cleared at `DictationCoordinator.swift:234` on the NEXT dictation start). For recovery UX we want the card visible as long as `SharedKeys.lastTranscription` exists in App Group and its timestamp is within (say) 5 minutes (matching the coordinator's init-time purge at `DictationCoordinator.swift:97-102`).

**Recommended fix:**
```swift
// In HomeView, add a computed property:
private var recoverableTranscription: String? {
    if let inMemory = coordinator.lastResult { return inMemory }
    guard let text = AppGroup.defaults.string(forKey: SharedKeys.lastTranscription),
          let ts = AppGroup.defaults.object(forKey: SharedKeys.lastTranscriptionTimestamp) as? Double,
          Date().timeIntervalSince1970 - ts < 300 else { return nil }
    return text
}
// Then: if let result = recoverableTranscription { transcriptionCard(result: result) }
```

### Existing Cold-Start Audio Bridge Insertion Path — CORRECTION
**CONTEXT.md assumption:** a separate cold-start Audio Bridge insertion path exists in `KeyboardViewController` / `KeyboardState`.

**Actual finding (HIGH confidence, read directly from `DictusKeyboard/KeyboardViewController.swift` 556 lines + `DictusKeyboard/KeyboardState.swift` 523 lines):** there is **only ONE insertion call site** in the keyboard that writes transcribed text — `KeyboardState.handleTranscriptionReady` at lines 341 and 370. Cold start does NOT have a separate insertion path; after the URL-scheme wake, DictusApp completes transcription, writes to `SharedKeys.lastTranscription`, posts `DarwinNotificationName.transcriptionReady`, and the keyboard's observer at `KeyboardState.swift:96-103` calls the **same** `handleTranscriptionReady` path used for warm recording.

`grep` confirms: `insertText` appears in the keyboard only in `DictusKeyboardBridge` (keystrokes) and `KeyboardState` (transcription). No separate "cold start Audio Bridge" insertion call site exists in the codebase as written.

**Implication for the helper:** one insertion path means one call site to wrap, not two. The `path` parameter in the probe can still carry `.warmDarwin` vs. `.coldStartBridge` by inspecting `AppGroup.defaults.bool(forKey: SharedKeys.coldStartActive)` at the moment of insertion — this preserves the diagnostic value CONTEXT.md wants (distinguishing the two operational scenarios in the log) without requiring two physical call sites.

**Recommendation for planner:** confirm with the user (or note in the plan) that the "cold start Audio Bridge insertion path" referenced in CONTEXT.md refers to the same `handleTranscriptionReady` code path, differentiated only by the `coldStartActive` flag. If that assumption is wrong, planning has to re-scope — but I found no evidence of a second call site.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Fire-and-forget `insertText` with no verification | Validate → insert → verify → retry → escalate | Phase 34 | Proves insertion success per dictation; eliminates silent-drop class of bugs. |
| Free-text `os.log` | Typed `LogEvent` enum with privacy-enforced structure | Phase 11-15.2 (pre-existing) | Every new probe case adds privacy guarantees by construction. |
| Single-path transcription insertion | Shared helper consumed by all paths | Phase 34 | Bugs in one code path no longer re-surface via the other. |

**Deprecated / Outdated:**
- Assumption that "`keyboardTextInserted` in logs = user saw the text" — disproved by issue #118 repro log. Retain the log event but treat it as "call site executed," not "text landed."

## Open Questions

1. **Does the retry budget (350 ms) survive controller recreation during cold-start swipe-back?**
   - What we know: controller is recreated; new controller re-registers via `viewWillAppear → registerControllerAppearance`; `state.controller` is re-assigned via `KeyboardRootView.onAppear`. Time from controller-recreated to re-assignment is empirically ≤100 ms in normal cases (inferred from existing cold-start diagnostics, not instrumented).
   - What's unclear: whether 350 ms is enough in the worst case (slow device, thermal throttle).
   - Recommendation: land the 350 ms budget as specified; use the probe to measure real-world distribution; if cold-start `proxyNil` failures exceed some threshold in logs, raise cold-start-specific retry count in v1.8.

2. **Does `documentContextBeforeInput` have a hard character cap, and what is it exactly?**
   - What we know: the window is bounded (Apple docs), commonly cited as ~1000 chars in community threads (MEDIUM confidence).
   - What's unclear: the exact cap across iOS versions, whether it varies by host app.
   - Recommendation: implement the delta classifier (Pitfall 1 above) with the multi-signal fallback. Instrument probe logs with actual `before/after/transcription.utf16.count` values so we can empirically measure the cap on our actual devices.

3. **Is there a measurable latency regression from the pre-/post-insertion reads of `documentContextBeforeInput`?**
   - What we know: `documentContextBeforeInput` is cheap in practice (synchronous, no IPC beyond the already-established host-app channel).
   - What's unclear: whether calling it twice per attempt × 4 attempts has perceptible impact.
   - Recommendation: measure with the probe's `darwinToInsertMs` field after shipping. If pre/post reads exceed ~5 ms combined, defer post-read to the next run loop cycle.

4. **Should the Dynamic Island "insertion failed" state be distinct from the existing `.failed` phase, or reuse it?**
   - What we know: `.failed` already exists, renders X + exclamation glyphs, auto-returns to `.standby` after 3 s.
   - What's unclear: whether users will confuse "transcription failed" (network/model error) with "insertion failed" (proxy drop).
   - Recommendation: reuse the existing `.failed` phase in v1. Add the distinguishing nuance in the expanded region's label text. If user testing shows confusion, split in v1.8.

5. **Does the `LiveActivityStateMachine` currently permit the `.standby → .failed` (or `.ready → .failed`) transition the insertion-failure signaling needs?**
   - What we know: `validTransitions` map in `LiveActivityStateMachine.swift:32-39` does NOT include either edge.
   - What's unclear: which source phase we'll be in at the moment insertion fails. Empirically, by the time the 350 ms retry window expires, `DictationCoordinator` has already called `endWithResult` which transitions `.transcribing → .ready → .standby` (1 s auto-dismiss).
   - Recommendation: add `.standby → .failed` (or `.ready → .failed`, whichever matches the actual timing) to `validTransitions`, and extend `LiveActivityStateMachineTests.swift` with coverage for the new edge. Small change, unit-testable.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest via SwiftPM (macOS-based `swift test` for DictusCore; device-hosted XCTest available for UI targets but not currently configured for DictusKeyboard / DictusApp — no test targets in those Xcode targets) |
| Config file | `DictusCore/Package.swift` (SPM); no Xcode test targets for DictusKeyboard or DictusApp |
| Quick run command | `swift test --package-path DictusCore --filter LogEventTests` (≈ 2 s locally) |
| Full suite command | `swift test --package-path DictusCore` (≈ 10-20 s locally, runs all existing unit tests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STAB-01 | New `LogEvent` cases format privacy-safely (no raw transcription leaked) | unit | `swift test --package-path DictusCore --filter LogPrivacyTests` | ✅ extend existing |
| STAB-01 | New `LogEvent` cases have correct level + subsystem mapping | unit | `swift test --package-path DictusCore --filter LogEventTests` | ✅ extend existing |
| STAB-01 | `LiveActivityStateMachine` allows the new transition edge (`.standby → .failed` or `.ready → .failed`) | unit | `swift test --package-path DictusCore --filter LiveActivityStateMachineTests` | ✅ extend existing |
| STAB-01 | `InsertTranscriptionResult` classifier correctly interprets delta (success / windowing / silent drop) | unit | `swift test --package-path DictusCore --filter InsertionClassifierTests` | ❌ Wave 0 — new file in DictusCore |
| STAB-01 | `HapticFeedback.insertionFailed()` compiles on iOS and no-ops on macOS | unit | `swift test --package-path DictusCore` (will fail to compile if wrong) | ✅ implicit via existing compile-guard idiom |
| STAB-01 | Warm insert succeeds into empty Notes field 50×/50 on real iPhone | manual scripted | `./tools/phase34-repro.sh` (new helper script) or PR checklist | ❌ Wave 0 — manual protocol document |
| STAB-01 | Cold-start insert succeeds into Messages field 50×/50 on real iPhone (interleaved with warm) | manual scripted | same | ❌ Wave 0 — manual protocol document |
| STAB-01 | Chained rapid recordings insert correctly 50×/50 | manual scripted | same | ❌ Wave 0 — manual protocol document |
| STAB-01 | On induced failure (e.g., swipe to a view without focusable field between Darwin notify and insert), loud-fail UX fires: DI glyph changes, toolbar banner appears (FR/EN), error haptic, DictusApp home card shows the transcription with Copy button | manual scripted | PR checklist with scripted failure induction | ❌ Wave 0 — manual protocol document |
| STAB-01 | Probe logs show structured `keyboardInsertProbe` entries with non-empty `sessionID`, non-zero `transcriptionCount`, numeric `darwinToInsertMs`, privacy-safe (no text / context string) | log-inspection | `cat exported-log.txt \| grep keyboardInsertProbe \| head -10` | ❌ Wave 0 — addressed by manual protocol |

### Sampling Rate
- **Per task commit:** `swift test --package-path DictusCore` (full DictusCore suite; ≈ 10-20 s)
- **Per wave merge:** Same — there is no separate integration suite for keyboard / app today. On-device manual smoke (5 dictations across 3 apps) required before merging any wave that touches insertion.
- **Phase gate:** 50-run scripted manual protocol on real iPhone per CONTEXT.md before `/gsd:verify-work`. Log review confirms probe reports success on all 50 AND no unexpected loud-fail escalations.

### Wave 0 Gaps

- [ ] `DictusCore/Tests/DictusCoreTests/InsertionClassifierTests.swift` — covers the delta-classifier logic (success / windowed-success / silent-drop / delta-mismatch). The classifier itself lives in a new source file in DictusCore (e.g., `InsertionClassifier.swift`) so it is pure-logic and testable on macOS.
- [ ] Extend `DictusCore/Tests/DictusCoreTests/LogEventTests.swift` with level/subsystem assertions for `.keyboardInsertProbe`, `.keyboardInsertRetry`, `.keyboardInsertFailed`.
- [ ] Extend `DictusCore/Tests/DictusCoreTests/LogPrivacyTests.swift` to include the three new events in the `allEvents` fixture so the privacy invariants auto-enforce no text leaks.
- [ ] Extend `DictusCore/Tests/DictusCoreTests/LiveActivityStateMachineTests.swift` to cover the new allowed transition edge.
- [ ] `.planning/phases/34-silent-insertion-fix/test-matrix.md` (or the PR description) — the 50-run matrix protocol: 3 host apps × warm/cold/chained × scenario matrix, with pass/fail checkboxes.
- [ ] **No test framework install needed.** Existing DictusCore XCTest via SwiftPM is sufficient; keyboard/app work is validated by the manual protocol.

## Sources

### Primary (HIGH confidence)
- `/Users/pierreviviere/dev/dictus/DictusKeyboard/KeyboardState.swift` — read in full, lines 1-523 (insertion path, retry pattern, status message pattern, session tracking)
- `/Users/pierreviviere/dev/dictus/DictusKeyboard/KeyboardViewController.swift` — read in full, lines 1-556 (controller lifecycle, hasFullAccess, hostingHeightConstraint, onTranscriptionInserted wiring at 196-201)
- `/Users/pierreviviere/dev/dictus/DictusKeyboard/DictusKeyboardBridge.swift` — read in full, lines 1-697 (proxy usage patterns, insertText call sites confirmed limited to keystrokes)
- `/Users/pierreviviere/dev/dictus/DictusKeyboard/KeyboardRootView.swift` — read in full, lines 1-372 (ToolbarView wiring, hasFullAccess binding, state.controller assignment)
- `/Users/pierreviviere/dev/dictus/DictusKeyboard/Views/ToolbarView.swift` — read in full, lines 1-88 (statusMessage banner pattern)
- `/Users/pierreviviere/dev/dictus/DictusCore/Sources/DictusCore/PersistentLog.swift` — read in full, lines 1-321 (NSFileCoordinator writes, os.log forwarding, privacy-safe API)
- `/Users/pierreviviere/dev/dictus/DictusCore/Sources/DictusCore/LogEvent.swift` — read in full, lines 1-501 (enum extension pattern, privacy model, subsystem/level mapping)
- `/Users/pierreviviere/dev/dictus/DictusCore/Sources/DictusCore/HapticFeedback.swift` — read in full, lines 1-182 (pre-allocated generators, `.success` success idiom to mirror for `.error`)
- `/Users/pierreviviere/dev/dictus/DictusCore/Sources/DictusCore/LiveActivityStateMachine.swift` — read in full, lines 1-71 (transition validation; gap in `.standby → .failed`)
- `/Users/pierreviviere/dev/dictus/DictusCore/Sources/DictusCore/DictusLiveActivityAttributes.swift` — read in full (phase enum)
- `/Users/pierreviviere/dev/dictus/DictusApp/LiveActivityManager.swift` — read in full, lines 1-644 (endWithFailure pattern, watchdog)
- `/Users/pierreviviere/dev/dictus/DictusApp/DictationCoordinator.swift` — read in full, lines 1-751 (lastTranscription write at 398-399, cleanupRecordingKeys preserves key at 514-519)
- `/Users/pierreviviere/dev/dictus/DictusApp/Views/HomeView.swift` — read in full, lines 1-200 (existing transcriptionCard + copy-to-clipboard)
- `/Users/pierreviviere/dev/dictus/DictusCore/Sources/DictusCore/SharedKeys.swift` — read in full, lines 1-90 (App Group key catalog)
- `/Users/pierreviviere/dev/dictus/DictusCore/Tests/DictusCoreTests/LogEventTests.swift`, `LogPrivacyTests.swift` — test patterns to extend
- `/Users/pierreviviere/dev/dictus/DictusWidgets/DictusLiveActivity.swift` — read lines 1-150 (DI failure glyphs already present)
- GitHub issue #118 body via `gh issue view 118 --repo getdictus/dictus-ios --json` — full repro log, hypothesis, proposed probe sketch
- `/Users/pierreviviere/dev/dictus/.planning/phases/34-silent-insertion-fix/34-CONTEXT.md` — locked decisions
- `/Users/pierreviviere/dev/dictus/.planning/REQUIREMENTS.md` — STAB-01 definition
- `/Users/pierreviviere/dev/dictus/.planning/config.json` — `nyquist_validation: true`, `parallelization: true`, `commit_docs: true`

### Secondary (MEDIUM confidence)
- Apple `UITextDocumentProxy` documented behavior (training-data-backed): `insertText` is a non-throwing void call, silently no-ops on a disconnected proxy. `documentContextBeforeInput` is nil in secure fields and windowed for long documents. **Needs on-device verification during implementation for the exact windowing cap.**
- `UIInputViewController.hasFullAccess` reflects the user's toggle in Settings → Keyboards → Dictus → Allow Full Access; required for `UIPasteboard` and reliable proxy behavior. HIGH confidence on semantics, MEDIUM on edge-case behavior when toggled mid-session.
- ActivityKit state machine: transitions not in `validTransitions` are rejected and logged (confirmed by `LiveActivityManager.validateTransition` source).

### Tertiary (LOW confidence)
- Community claim that `documentContextBeforeInput` caps at ~1000 characters. Needs on-device validation via the probe itself once shipped. Flagged in Open Questions #2.
- Claim that `insertText` may fail silently during UIInputView transitions even when `documentContextBeforeInput` is non-nil. Asserted by issue #118's hypothesis — accepted as working hypothesis, to be proved/disproved by the probe.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are already in the project and exercised in production.
- Architecture: HIGH for existing code paths (read directly from source); MEDIUM for the prescribed helper shape (recommended pattern, not yet built).
- Pitfalls: HIGH for #2 (controller recreation — corroborated by existing project memory `project_fix03_cold_start_diagnosis.md`), #3 (duplicate Darwin — corroborated by #118 log), #5 (DI state machine — read directly from source); MEDIUM for #1 (documentContextBeforeInput windowing — training-data claim requiring on-device validation), #4 (banner/suggestion bar interaction — correct in theory, needs eyes during validation).
- **Key correction:** the "cold-start Audio Bridge insertion path" referenced in CONTEXT.md does not exist as a separate call site — there is only one `insertText(transcription)` call site in the keyboard, at `KeyboardState.swift:341` (+ its 100 ms retry twin at `:370`). The planner should confirm with the user or proceed with the single-call-site assumption.

**Research date:** 2026-04-15
**Valid until:** 2026-05-15 (30 days — stable iOS APIs, locked CONTEXT decisions, no dependency churn expected)
