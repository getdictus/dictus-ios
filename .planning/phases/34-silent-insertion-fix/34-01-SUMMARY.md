---
phase: 34-silent-insertion-fix
plan: 01
subsystem: testing

tags: [logging, haptics, state-machine, classifier, dictuscore, tdd, xctest]

# Dependency graph
requires: []
provides:
  - "LogEvent.keyboardInsertProbe/Retry/Failed cases for privacy-safe insertion probe logging"
  - "HapticFeedback.insertionFailed() error-haptic method"
  - "LiveActivityStateMachine edges: .standby -> .failed and .ready -> .failed"
  - "InsertionClassifier pure-logic type with 6 outcomes (success/windowedSuccess/emptyFieldSuccess/silentDrop/deltaMismatch/proxyDead)"
affects: [34-02, 34-03, 34-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Privacy-by-construction logging: new LogEvent cases accept only counts/booleans/identifiers/durations — no raw text parameters"
    - "Pure-logic classifier extraction pattern: delta-interpretation policy isolated from UIKit for macOS-based unit testing"
    - "Pre-allocated UINotificationFeedbackGenerator reuse for error haptic (matches existing success-haptic idiom)"

key-files:
  created:
    - "DictusCore/Sources/DictusCore/InsertionClassifier.swift"
    - "DictusCore/Tests/DictusCoreTests/InsertionClassifierTests.swift"
    - ".planning/phases/34-silent-insertion-fix/deferred-items.md"
  modified:
    - "DictusCore/Sources/DictusCore/LogEvent.swift"
    - "DictusCore/Sources/DictusCore/HapticFeedback.swift"
    - "DictusCore/Sources/DictusCore/LiveActivityStateMachine.swift"
    - "DictusCore/Tests/DictusCoreTests/LogEventTests.swift"
    - "DictusCore/Tests/DictusCoreTests/LogPrivacyTests.swift"
    - "DictusCore/Tests/DictusCoreTests/LiveActivityStateMachineTests.swift"

key-decisions:
  - "Use xcodebuild iOS Simulator instead of 'swift test' — DictusCore Package.swift only declares iOS 17, and Design/ActivityKit code does not compile for macOS"
  - "Log pre-existing AccentedCharacter/FrequencyDictionary test failures as deferred (out of STAB-01 scope)"
  - "InsertionClassifier.classify is static/pure (no stored state) — enables in-line use from the keyboard helper without allocator churn"

patterns-established:
  - "Insertion probe event shape: path / sessionID / attempt / counts / bools / timing — reusable across warm and cold-start paths"
  - "Proxy-dead sentinel: caller passes -1 for beforeCount/afterCount when documentContextBeforeInput is nil — classifier detects via count < 0"

requirements-completed: []  # STAB-01 shipped end-to-end in Plan 34-03 (helper) + 34-04 (UX); 34-01 only provides foundations

# Metrics
duration: 10min
completed: 2026-04-16
---

# Phase 34 Plan 01: DictusCore Foundations for Insertion Fix Summary

**Privacy-safe log probe cases, error haptic, state-machine failure edges, and a pure-logic InsertionClassifier with 11 unit tests — all Wave 0 foundations for the keyboard insertion helper (Plan 34-03)**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-16T05:24:27Z
- **Completed:** 2026-04-16T05:34:07Z
- **Tasks:** 3 (all TDD: RED → GREEN per task)
- **Files modified:** 6
- **Files created:** 3

## Accomplishments

- Three new privacy-safe `LogEvent` cases (`keyboardInsertProbe`, `keyboardInsertRetry`, `keyboardInsertFailed`) with exact format strings, correct subsystem (`.keyboard`) and level mapping (debug/warning/error)
- `HapticFeedback.insertionFailed()` fires `.error` on the pre-allocated `notificationGenerator` — matches the existing `textInserted()` idiom (no new allocator, no extra latency)
- `LiveActivityStateMachine` now permits `.standby -> .failed` and `.ready -> .failed`, unblocking insertion-failure signaling after `DictationCoordinator` has already transitioned through `.transcribing -> .ready -> .standby`
- `InsertionClassifier` pure-logic type classifies post-insertion state into 6 outcomes — macOS-testable (no UIKit), 11 unit tests covering every branch including unicode and proxy-dead edge cases

## Task Commits

Each task followed TDD (RED test commit, then GREEN implementation commit):

1. **Task 1 RED:** `370549f` — test(34-01): add failing tests for keyboardInsert log events
2. **Task 1 GREEN:** `ef81893` — feat(34-01): add keyboardInsertProbe/Retry/Failed log events
3. **Task 2 RED:** `87eda70` — test(34-01): add failing tests for standby/ready to failed transitions
4. **Task 2 GREEN:** `e219be5` — feat(34-01): add insertionFailed haptic and failed transition edges
5. **Task 3 RED:** `dd9b81b` — test(34-01): add failing tests for InsertionClassifier
6. **Task 3 GREEN:** `8043b46` — feat(34-01): add InsertionClassifier pure-logic delta classifier

## Files Created/Modified

### Created
- `DictusCore/Sources/DictusCore/InsertionClassifier.swift` — Pure-logic `InsertionOutcome` enum + `InsertionClassifier.classify(...)` static function
- `DictusCore/Tests/DictusCoreTests/InsertionClassifierTests.swift` — 11 tests covering all 6 outcomes + unicode edge case
- `.planning/phases/34-silent-insertion-fix/deferred-items.md` — Log of pre-existing test failures out of scope

### Modified
- `DictusCore/Sources/DictusCore/LogEvent.swift` — Added 3 cases + extended `subsystem`, `level`, `name`, `message` exhaustive switches
- `DictusCore/Sources/DictusCore/HapticFeedback.swift` — Added `insertionFailed()` using pre-allocated `notificationGenerator`
- `DictusCore/Sources/DictusCore/LiveActivityStateMachine.swift` — Added `.failed` to `.standby` and `.ready` outgoing edge sets; added code comment citing Phase 34 STAB-01 rationale
- `DictusCore/Tests/DictusCoreTests/LogEventTests.swift` — 3 new tests (exact message string, level, subsystem)
- `DictusCore/Tests/DictusCoreTests/LogPrivacyTests.swift` — Extended `allEvents` fixture with 3 new sample cases
- `DictusCore/Tests/DictusCoreTests/LiveActivityStateMachineTests.swift` — 4 new transition tests (2 allowed, 2 still-rejected)

## API shipped

### LogEvent cases (DictusCore/Sources/DictusCore/LogEvent.swift)

```swift
case keyboardInsertProbe(
    path: String,               // "warmDarwin" | "coldStartBridge"
    sessionID: String,
    attempt: Int,               // 0 = first try, 1-3 = retries
    transcriptionCount: Int,    // utf16 count of transcription
    hasFullAccess: Bool,
    hasTextBefore: Bool,
    hasTextAfter: Bool,
    beforeCount: Int,           // documentContextBeforeInput.utf16.count or -1 if nil
    afterCount: Int,            // documentContextBeforeInput.utf16.count or -1 if nil
    keyboardVisible: Bool,
    darwinToInsertMs: Int       // ms between Darwin notification and insertText call
)  // .debug / .keyboard

case keyboardInsertRetry(
    path: String,
    sessionID: String,
    attempt: Int,
    reason: String              // InsertionFailureReason rawValue
)  // .warning / .keyboard

case keyboardInsertFailed(
    path: String,
    sessionID: String,
    totalAttempts: Int,
    finalReason: String
)  // .error / .keyboard
```

Exact format strings verified by `test_keyboardInsertProbe_formatsAllFields`, `test_keyboardInsertRetry_formatsAllFields`, `test_keyboardInsertFailed_formatsAllFields`.

### HapticFeedback.insertionFailed()

```swift
public static func insertionFailed() {
    #if canImport(UIKit) && !os(macOS)
    guard isEnabled() else { return }
    notificationGenerator.notificationOccurred(.error)
    notificationGenerator.prepare()
    #endif
}
```

### LiveActivityStateMachine transitions (updated)

```swift
private let validTransitions: [Phase: Set<Phase>] = [
    .idle: [.standby],
    .standby: [.recording, .idle, .failed],      // +.failed
    .recording: [.transcribing, .standby],
    .transcribing: [.ready, .failed],
    .ready: [.standby, .recording, .failed],     // +.failed
    .failed: [.standby, .recording, .idle]
]
```

### InsertionClassifier public API

```swift
public enum InsertionOutcome: Equatable, Sendable {
    case success            // delta == transcription.utf16.count
    case windowedSuccess    // 0 < delta < transcription.utf16.count (Apple windowing cap)
    case emptyFieldSuccess  // before == 0 && hasText flipped false -> true
    case silentDrop         // no change, non-empty field — retry
    case deltaMismatch      // negative or implausibly large delta — retry
    case proxyDead          // beforeCount < 0 || afterCount < 0 — proxy disconnected
}

public enum InsertionClassifier {
    public static func classify(
        beforeCount: Int,
        afterCount: Int,
        transcriptionUtf16Count: Int,
        hasTextBefore: Bool,
        hasTextAfter: Bool
    ) -> InsertionOutcome
}
```

## Test results

### New tests added
- `LogEventTests`: 3 new tests (all format/level/subsystem) — total 37, 0 failures
- `LogPrivacyTests`: existing tests re-verified with 3 new fixture entries — total 3, 0 failures
- `LiveActivityStateMachineTests`: 4 new transition tests — total 21, 0 failures
- `InsertionClassifierTests`: 11 new tests — total 11, 0 failures

### Combined Plan 34-01 suite (74 tests)
```
Executed 74 tests, with 0 failures (0 unexpected) in 0.064 (0.101) seconds
** TEST SUCCEEDED **
```

## Decisions Made

- **Test runner: xcodebuild iOS Simulator, not `swift test`** — Plan specified `swift test --package-path DictusCore` but the DictusCore Package.swift declares only iOS 17 and contains Design/SwiftUI code (iOS 26 `glassEffect`) and `ActivityKit` code (iOS-only) that do not compile for macOS. Switched to `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` which exercises the exact same XCTest target, runs in 6-10s, and matches the verification path that Plans 34-02 through 34-04 will need for any test touching DictusCore. Documented in deferred-items so future planners know the correct command.
- **Pre-existing test failures out of scope** — 10 tests in `AccentedCharacterTests` + `FrequencyDictionaryTests` were already failing on `develop` before any Phase 34 work. They test stale expectations about accent-variant counts and `FrequencyDictionary.rank(for:)` semantics, and have no relation to STAB-01. Logged to `.planning/phases/34-silent-insertion-fix/deferred-items.md` and deferred to a future cleanup issue. Honoring the "SCOPE BOUNDARY" rule: only fix issues directly caused by current changes.
- **`InsertionClassifier` as enum with static method** — Chose `enum InsertionClassifier` (no cases, just static function namespace) over `struct` because the classifier is pure policy with no instance state. Matches Swift idiom for namespacing pure functions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Switched verification command from `swift test` to `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator'`**
- **Found during:** Task 1 RED (first test run)
- **Issue:** Plan's `swift test --package-path DictusCore` command fails — the package contains iOS-26-only SwiftUI (`glassEffect`), SwiftUI macOS-incompatible animation APIs, and `ActivityKit` (unavailable on macOS). Without a `macOS` platform declaration, SwiftPM tries to build for macOS 10.13 where SwiftUI is not even available.
- **Fix:** Used `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` which matches the platform declared in Package.swift. Runs in 6-10 s per test invocation, same XCTest semantics as `swift test` on a non-UI package.
- **Files modified:** None (command-only change)
- **Verification:** All 4 verification runs (LogEventTests, LogPrivacyTests, LiveActivityStateMachineTests, InsertionClassifierTests) succeed with the xcodebuild command.
- **Impact:** Plans 34-02, 34-03, 34-04 should use the same xcodebuild command for any DictusCore test. Updating plan verification commands is out of scope for 34-01 — documented in this Summary for the plan-executor of later plans to pick up.

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope creep. The substitute command produces identical XCTest output and is what the plan's author intended; the plan's research (34-RESEARCH.md) asserted `swift test` works but did not validate against the actual Package.swift platform declaration.

## Issues Encountered

- **Pre-existing test failures surfaced by the first full-suite run.** 10 tests in `AccentedCharacterTests` and `FrequencyDictionaryTests` fail on `develop` before any Phase 34 change. Confirmed out-of-scope and logged to `deferred-items.md`. Passing all Plan 34-01 tests (74 total) is the success criterion that was met.
- **Stale stash conflict during regression verification.** When I ran `git stash` to baseline pre-existing failures, a months-old stash (`wip-localizable-autogen-premium`) auto-merged and created a conflict in `DictusApp/Localizable.xcstrings`. Resolved by checking out HEAD version. No committed changes affected.

## User Setup Required

None — purely additive source + test changes inside DictusCore. No entitlements, Info.plist, or App Group changes.

## Next Phase Readiness

- **Plan 34-02 (App Group recovery fallback in HomeView)** — already committed as `2171b31` by a prior session (before this plan's execution). Not blocked by 34-01.
- **Plan 34-03 (DictusKeyboard insertion helper)** — **unblocked.** Can consume:
  - `LogEvent.keyboardInsertProbe/Retry/Failed` for structured logging
  - `HapticFeedback.insertionFailed()` for the error-haptic on terminal failure
  - `LiveActivityStateMachine.transition(to: .failed)` from `.standby` or `.ready` for Dynamic Island error state
  - `InsertionClassifier.classify(...)` for post-insertion delta interpretation
- **Plan 34-04 (banner/UX wiring + DictusApp recovery card)** — unblocked; will consume the insertion-failed signal produced by Plan 34-03.

**Recommendation for plan-executor of 34-03/04:** use `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` instead of `swift test` wherever the plan's verification command says the latter.

## Self-Check

Verifying all claims:

### Files created
- `/Users/pierreviviere/dev/dictus/DictusCore/Sources/DictusCore/InsertionClassifier.swift` — FOUND
- `/Users/pierreviviere/dev/dictus/DictusCore/Tests/DictusCoreTests/InsertionClassifierTests.swift` — FOUND
- `/Users/pierreviviere/dev/dictus/.planning/phases/34-silent-insertion-fix/deferred-items.md` — FOUND

### Commits
- `370549f` (Task 1 RED) — FOUND in git log
- `ef81893` (Task 1 GREEN) — FOUND in git log
- `87eda70` (Task 2 RED) — FOUND in git log
- `e219be5` (Task 2 GREEN) — FOUND in git log
- `dd9b81b` (Task 3 RED) — FOUND in git log
- `8043b46` (Task 3 GREEN) — FOUND in git log

## Self-Check: PASSED

---
*Phase: 34-silent-insertion-fix*
*Completed: 2026-04-16*
