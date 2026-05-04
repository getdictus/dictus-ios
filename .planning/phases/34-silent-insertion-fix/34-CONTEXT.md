# Phase 34: Silent Insertion Fix - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Guarantee that transcribed text reaches the host app's text field on every dictation, across all existing insertion paths (warm insert via Darwin notification, cold start Audio Bridge, chained recording). When insertion fails anyway, surface the failure loudly so the user can recover the transcription from DictusApp and so the failure is diagnosable from logs.

In scope: `KeyboardState.handleTranscriptionReady` and the cold start Audio Bridge insertion path, diagnostic instrumentation, retry logic, user-facing failure UX, DictusApp retrieval surface, verification on real device.

Out of scope: Any redesign of the Darwin notification trigger, the App Group transport, or the recording pipeline. New capabilities (history, cloud sync, auto-paste to other apps). Telemetry escalation flows.

</domain>

<decisions>
## Implementation Decisions

### Diagnostic instrumentation
- Always-on probe wraps every `insertText()` call on both warm path (`KeyboardState.handleTranscriptionReady`) and cold start Audio Bridge insertion path.
- Probe fields: privacy-safe only — counts (`documentContextBeforeInput.count` before/after, `transcription.count`), booleans (`hasText` before/after, `hasFullAccess`, `isKeyboardVisible`), timing deltas (ms since Darwin notification, ms since recording stopped), and session/controller identifiers. **Never log raw transcription text or document context strings.**
- Emitted via existing `PersistentLog` / `LogEvent` pipeline so it exports through the current log-dump UX.
- Claude has discretion on exact field set and `LogEvent` case naming, subject to the constraints above (minimal runtime impact, privacy-safe).

### Fix strategy
- Primary pattern: **validate → insert → verify → retry → escalate.**
  1. Pre-check proxy health before insertion (`documentContextBeforeInput != nil`, `hasFullAccess`, active session/controller present).
  2. Call `insertText()`.
  3. Verify by computing post-delta (`documentContextBeforeInput.count` after minus before) and comparing to `transcription.count`.
  4. On empty-delta or delta mismatch, retry up to **3 times with 50 / 100 / 200 ms backoff** (≈350 ms total worst case).
  5. If all retries fail, escalate to loud-fail UX.
- No queue-on-resume behavior. If the extension is not live/visible when the transcription lands, go straight to loud-fail — queueing risks wrong-field flush, stale flush across app switches, and flushes into password/URL fields.
- Existing 100ms UserDefaults retry stays (it solves a different problem: App Group propagation lag).

### Loud-fail UX
- **Dynamic Island:** error icon + short `Dictus` label (expanded view: short error line). Does not carry the actionable recovery message.
- **Toolbar banner:** reuses existing error-banner pattern. Actionable copy pointing to DictusApp. Auto-hide after **4 seconds**. Accompanied by error haptic via `HapticFeedback`.
  - FR: `Insertion impossible. Retrouvez votre transcription dans Dictus.`
  - EN: `Couldn't insert. Find your transcription in Dictus.`
- **DictusApp home:** dedicated "last transcription" card always visible when a recent transcription exists in the App Group. Shows the text (or a preview) and a copy-to-clipboard button. This is the recovery surface users are directed to.
- No auto-copy to system pasteboard (privacy + surprise behavior).
- No repeated-failure escalation in v1 — ship minimal, observe real-world rate via logs, revisit later if needed.

### Verification
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Bug context
- `.planning/ROADMAP.md` §"Phase 34: Silent Insertion Fix" — phase goal, success criteria, REQ mapping (STAB-01)
- `.planning/REQUIREMENTS.md` §STAB-01 — requirement text
- GitHub issue #118 — full repro logs, hypotheses (stale `textDocumentProxy`), proposed pre/post probe sketch, related closed issues (#45, #16)

### Insertion code paths
- `DictusKeyboard/KeyboardState.swift` (handleTranscriptionReady at ~line 328; warm insertion path at :341; 100ms retry path at :363-383)
- `DictusKeyboard/KeyboardViewController.swift` — controller lifecycle, `textDidChange` integration, cold start wiring
- `DictusKeyboard/DictusKeyboardBridge.swift` — text-proxy utility access points (context reads, corrections, predictions)

### Logging + feedback
- `DictusCore/PersistentLog.swift` (and `LogEvent` definitions) — existing structured log event system the probe must plug into
- `DictusKeyboard/Views/ToolbarView.swift` — existing toolbar error-banner pattern the loud-fail UX reuses
- `DictusKeyboard/HapticFeedback.swift` — error haptic API (`HapticFeedback.textInserted()` shows the existing success pattern)

### Architecture context
- `.planning/PROJECT.md` Key Decisions — two-process architecture (keyboard ↔ app via App Group)
- `CLAUDE.md` — 50MB keyboard memory ceiling, App Group (`group.solutions.pivi.dictus`), no `UIApplication.shared` in extension
- Memory: `project_fix03_cold_start_diagnosis.md` — controller recreation during swipe-back (cold start Audio Bridge context)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PersistentLog` + `LogEvent` — structured logging already in place; add new cases (e.g. `.keyboardInsertProbe`, `.keyboardInsertFailed`) rather than new sinks.
- Toolbar error-banner pattern in `ToolbarView.swift` — reuse for the loud-fail message. Pattern is already familiar to users for other error states.
- `HapticFeedback` service — add/reuse an error haptic; `textInserted()` shows the existing idiom.
- 100ms UserDefaults-lag retry at `KeyboardState.swift:363` — separate problem (App Group propagation), leave in place; the new retry layer addresses proxy-disconnect silent drops.
- DictusApp home screen — already receives transcriptions via App Group; extend with a persistent "last transcription" card.

### Established Patterns
- Darwin notification + UserDefaults `SharedKeys.lastTranscription` → clear-before-insert to prevent duplicates (keep this pattern, do not touch).
- `controller?.textDocumentProxy.insertText()` as the single insertion call — wrap in a helper that embeds validate/verify/retry so both warm and cold paths use the same code.
- Stop-watchdog-before-setting-idle discipline in `handleTranscriptionReady` — preserve when adding retry branches.

### Integration Points
- `KeyboardState.handleTranscriptionReady` — primary hook for warm insertion path + probe + retry + escalation.
- Cold start Audio Bridge insertion (in `KeyboardViewController` / `KeyboardState`) — second call site for the same helper.
- `ToolbarView` — new banner state for "insertion failed" alongside existing error states.
- `KeyboardRootView` — may need to surface the failure banner state from `KeyboardState` to the toolbar.
- DictusApp root view — new "last transcription" card reading from App Group.
- Dynamic Island activity — extend existing DI state machine with an "insertion failed" variant (brief, auto-dismiss with transcribing end).

</code_context>

<specifics>
## Specific Ideas

- Treat the probe's output as the primary evidence for closing issue #118 — success criterion #1 ("50 consecutive dictations no silent drops") is verified by probe logs, not by user perception.
- Toolbar banner copy must be actionable (tell the user where to recover the text), not just informational ("Transcription non insérée" alone is rejected — user would assume the text is lost).
- The "last transcription" card in DictusApp is the real recovery surface; the banner is only a nudge. Card must always reflect the most recent transcription that exists in the App Group.
- Privacy bar: the probe never logs raw transcription text or document context strings. Counts, booleans, timings, identifiers only.

</specifics>

<deferred>
## Deferred Ideas

- Tappable banner → URL-scheme deep-link into DictusApp "last transcription" view. Considered, kept out of scope for v1 (adds URL scheme handling + routing). Revisit if banner-tap rate is low in telemetry.
- Repeated-failure escalation (Full Access nudge, anonymous failure counter, "reinstall keyboard" hint). Out of scope for v1 — will reconsider once real-world failure rate is measured from the probe.
- Transcription history view in DictusApp. Out of scope — premium/Pro scope per `.planning/REQUIREMENTS.md` Out of Scope table (#70).
- Queue-on-resume for transcriptions that land while the keyboard is suspended. Rejected after weighing wrong-field / stale-flush / password-field hazards.
- Automated XCUITest harness for the 3 insertion paths. Deferred — manual scripted run chosen for v1 velocity; revisit if regressions recur.

</deferred>

---

*Phase: 34-silent-insertion-fix*
*Context gathered: 2026-04-15*
