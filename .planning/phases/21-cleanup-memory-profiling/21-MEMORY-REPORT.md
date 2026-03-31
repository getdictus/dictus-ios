# Phase 21: Memory Profiling Report

**Device:** iPhone de Bob (iPhone 15 Pro Max equivalent, chip D84AP, 6 cores, 7.47 GB RAM)
**iOS Version:** 26.3.1
**Build:** 1.2 (4)
**Date:** 2026-03-31
**Tool:** Xcode Instruments (Allocations + Leaks + os_signpost)

## Results

| Operation | Duration | Peak Memory | Steady State | Leaks | Pass/Fail |
|-----------|----------|-------------|--------------|-------|-----------|
| Idle (keyboard visible) | 30s | ~15 MiB | 14.65 MiB | ~20 (system) | PASS |
| Rapid typing | 30s | ~22 MiB | 21.87 MiB | 0 | PASS |
| Dictation (recording) | 30s | ~15 MiB | 14.93 MiB | 0 | PASS |
| Dictation (transcription) | - | - | - | - | N/A (runs in DictusApp) |
| Text prediction (active) | 30s | ~21 MiB | 21.13 MiB | 0 | PASS |
| Emoji picker browsing | 30s | ~139 MiB | 139.31 MiB | 0 | **FAIL** |
| Combined peak scenario | 60s | ~43 MiB | 43.39 MiB | 0 | PASS |

**Debug Navigator baseline (DictusApp):** 62.5 MB (DictusKeyboard extension process not visible in Debug Navigator)
**Instruments overhead estimate:** Not calculable -- keyboard extension not listed in Debug Navigator

**Pass criterion:** Peak Memory < 50 MiB in ALL operations
**Overall result:** **FAIL** -- Emoji picker at 139 MiB exceeds 50 MiB limit by 2.8x

## Leak Analysis

All ~20 leaks detected during the idle run are iOS system internals, not Dictus code:
- `UIViewServiceDeputyManager`
- `_UIAsyncInvocation`
- `NSLock`
- `BSServiceConnection`

These are known UIKit/Foundation system-level leaks that appear in any keyboard extension. No leaks were detected in any Dictus code path. Subsequent runs (typing, dictation, prediction, emoji, combined) showed 0 leaks.

**Verdict:** No application-level memory leaks.

## Signposter Verification

| Interval | Captured | Median Latency | Target |
|----------|----------|---------------|--------|
| touchDown (highlight + haptic) | **No** | - | <= 16.67ms |
| touchUp (insertText) | **No** | - | <= 33ms |

**Custom signposts** from `com.pivi.dictus.keyboard` subsystem (KeyTapSignposter) were **not visible** in the os_signpost instrument.

**System signposts** were visible:
- `keyboardPerf.UI / keyboard.complete`: 4 intervals, avg 28.93s (session duration)
- `keyboardPerf.UI / keyboard.becomeFirstResponder`: 4 intervals, avg 18.95 us
- One 10.00 ms interval observed during combined run

**Root cause hypothesis:** The os_signpost instrument may require explicit subsystem filtering configuration, or the signposter code path may not be reached in the current UIKit key handling flow (KeyTapSignposter was written for the UICollectionView-based keyboard but may not be wired into the touch handling chain). Investigation needed in a future phase.

## Remediation Required

### Critical: Emoji Picker Memory (139 MiB)

The emoji picker consumes 139 MiB, nearly 3x the 50 MiB keyboard extension limit. iOS will jetsam-kill the extension under real-world conditions (Instruments disables jetsam limits, masking this in profiling).

**Likely causes:**
1. All emoji data loaded into memory at once (EmojiData + EmojiSearchFR + EmojiStore.allEmojiNames)
2. LazyHGrid may pre-render more cells than visible
3. French search keyword dictionary (~200 terms + pre-computed Unicode names) held in memory

**Recommended fixes (prioritized):**
1. **Lazy loading:** Load emoji data per-category instead of all at once
2. **Pagination:** Only load visible + nearby categories in the grid
3. **Search index optimization:** Build search index on-demand, not at picker open
4. **Memory release:** Deallocate emoji data when picker closes

### Non-critical: Signposter Not Captured

KeyTapSignposter intervals not visible in Instruments. Needs investigation:
1. Verify KeyTapSignposter is actually called in the touch handling chain
2. Check if subsystem filter in Instruments was correctly set to `com.pivi.dictus.keyboard`
3. Add a test signpost emission to confirm the mechanism works

## Summary

| Metric | Value | Status |
|--------|-------|--------|
| Idle memory | 14.65 MiB | Good |
| Typing memory | 21.87 MiB | Good |
| Dictation memory | 14.93 MiB | Good |
| Prediction memory | 21.13 MiB | Good |
| Emoji picker memory | 139.31 MiB | **Critical** |
| Combined peak | 43.39 MiB | Good |
| Application leaks | 0 | Good |
| System leaks | ~20 (UIKit internals) | Expected |
| Signposter capture | Not visible | Needs investigation |

The keyboard extension performs well within the 50 MiB limit for all core operations (typing, dictation, predictions). The emoji picker is the sole memory outlier and requires optimization before public beta. The signposter instrumentation needs wiring verification.
