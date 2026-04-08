# Phase 17: Bug Fixes - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix 3 known v1.2 beta bugs before the keyboard architecture change (Phase 18+). These bugs exist in the current codebase and should be fixed while the code is familiar, before the UIKit keyboard rebuild changes the landscape.

Requirements: FIX-01, FIX-02, plus a newly identified cold start overlay bug (FIX-03).

</domain>

<decisions>
## Implementation Decisions

### Dynamic Island REC desync (FIX-01 — issue #60)
- Bug is intermittent, not reliably reproducible — happens after both cancel and transcription completion
- Approach is twofold: (1) audit LiveActivityManager state machine code for missed transitions or race conditions, (2) reinforce logging so next occurrence provides diagnostic data
- Add a post-recording watchdog: if the Dynamic Island stays on REC state after DictationCoordinator has signaled recording stopped, force transition back to standby after ~10 seconds
- No recording duration limit — the watchdog only activates after the recording has ended, not during
- The watchdog logs a detailed error when it fires so we can trace the root cause

### Export logs performance + UX (FIX-02 — issue #61)
- Two problems: no visual feedback during export AND export is too slow even with small log files (a few hours of logs)
- Investigate and optimize `PersistentLog.exportContent()` — likely NSFileCoordinator overhead or inefficient file reading
- Add a spinner/loading indicator during export — Claude decides placement (inline on button vs overlay) based on export duration after optimization. User leans toward overlay if export still takes >1-2 seconds
- Implement log retention: 7 days max, auto-prune older entries
- The share sheet behavior stays the same (temp file → UIActivityViewController)

### Overlay grise au cold start (FIX-03 — new, needs issue creation)
- Scenario: cold start dictation → user does swipe-back to return to keyboard → recording overlay appears grayed out, waveform flat, non-responsive. DI shows REC correctly. Returning to DictusApp and coming back again unblocks it
- Frequency: ~1 out of 3 cold starts. Hypothesis: timing-dependent — fast swipe-back may arrive before app has fully synced recording state to keyboard
- Phase approach: (1) user performs targeted manual tests before fix work (fast vs slow swipe-back, wait in app vs immediate return), (2) reinforce logs around cold start audio bridge timing, (3) fix based on test results
- The overlay should either show a valid recording state or a clear "connecting..." state — never a grayed-out dead state

### Testing strategy
- Add unit tests for LiveActivityManager state machine transitions (valid and invalid paths, race conditions, watchdog behavior)
- Provide a manual test checklist for Pierre to validate on device: single recording, cancel, chain recordings, cold start with fast/slow swipe-back, export logs
- This is the first time unit tests are added to the project — establish the test target and patterns

### Claude's Discretion
- Exact watchdog timeout duration (around 10s, can adjust based on code analysis)
- Export spinner placement (inline ProgressView vs fullscreen overlay) based on measured export time after optimization
- Log retention implementation approach (prune on write, prune on export, or background task)
- Unit test framework setup and file organization
- How to handle the cold start overlay "connecting" intermediate state

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Dynamic Island state machine
- `DictusApp/LiveActivityManager.swift` — Full state machine with phase transitions, watchdog target file
- `DictusCore/Sources/DictusCore/DictusLiveActivityAttributes.swift` — ContentState.Phase enum shared with widget
- `DictusWidgets/DictusLiveActivity.swift` — Widget rendering of DI states
- `DictusApp/DictationCoordinator.swift` — Calls LiveActivityManager transitions, source of recording state changes

### Export logs
- `DictusApp/Views/SettingsView.swift` — `exportLogs()` function, isExporting flag, share sheet
- `DictusCore/Sources/DictusCore/PersistentLog.swift` — `exportContent()`, file I/O, NSFileCoordinator

### Cold start audio bridge
- `DictusApp/Audio/UnifiedAudioEngine.swift` — Audio engine lifecycle, cold start handling
- `DictusApp/DictationCoordinator.swift` — Recording state management, keyboard↔app sync
- `DictusApp/Views/SwipeBackOverlayView.swift` — Swipe-back UX during cold start

### GitHub issues
- Issue #60 — Dynamic Island stuck on REC
- Issue #61 — Export logs slow with no spinner
- Issue #62 — Keyboard rebuild (context for why bugs are fixed before architecture change)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LiveActivityManager` state machine with `validateTransition()` — already has phase validation, needs watchdog addition
- `PersistentLog` with `exportContent()` and `coordinatedWrite()` — needs optimization, not rewrite
- `isExporting` @State flag in SettingsView — spinner integration point exists

### Established Patterns
- State updated BEFORE async work to prevent races (`currentPhase = .recording` before `Task {}`) — pattern from #49
- `PersistentLog.log()` for typed, privacy-safe logging — use same enum pattern for new watchdog logs
- Darwin notifications for cross-process signaling between keyboard and app
- App Group UserDefaults for state sharing between keyboard extension and app

### Integration Points
- `DictationCoordinator` calls `LiveActivityManager.transitionToRecording()` / `endWithResult()` / `endWithFailure()` — watchdog hooks in here
- `PersistentLog.exportContent()` called from `SettingsView.exportLogs()` — optimization happens in DictusCore
- Cold start flow: keyboard → Darwin notification → DictusApp activates → audio bridge → swipe-back → keyboard overlay resumes

</code_context>

<specifics>
## Specific Ideas

- Pierre says: "la prochaine fois que ca m'arrive, je note quand et je partage les logs" — logging must be good enough that exported logs tell the story of a DI desync
- The grayed overlay screenshot shows: timer running (00:02), "En ecoute..." label visible, waveform nearly flat, buttons X and checkmark present but overlay appears non-responsive
- Pierre suspects swipe-back speed matters — fast swipe may break timing. Wants to do targeted tests before coding the fix
- Even a few hours of logs makes export painfully slow — suggests a fundamental I/O issue, not just file size

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 17-bug-fixes*
*Context gathered: 2026-03-27*
