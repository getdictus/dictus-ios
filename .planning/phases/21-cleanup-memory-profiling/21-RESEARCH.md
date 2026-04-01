# Phase 21: Cleanup & Memory Profiling - Research

**Researched:** 2026-03-30
**Domain:** iOS keyboard extension dead code removal, memory profiling, OSSignposter instrumentation
**Confidence:** HIGH

## Summary

Phase 21 is a quality gate with three discrete workstreams: (1) delete old SwiftUI keyboard files and clean LegacyCompat, (2) profile the keyboard extension memory on a real device across all operation modes, and (3) verify the existing OSSignposter instrumentation produces data in Instruments. No new features are introduced.

The codebase analysis confirms all 5 old SwiftUI files (KeyButton, KeyRow, KeyboardView, SpecialKeyButton, AccentPopup) are self-contained -- they reference each other but are NOT referenced by any active code paths. The only dependency chain risk is LegacyCompat.swift, whose types (KeyMetrics, KeySound, DeviceClass, KeyPopup) are actively used by EmojiPickerView, EmojiCategoryBar, and DictusKeyboardBridge. These types MUST be extracted before LegacyCompat is deleted.

**Primary recommendation:** Extract LegacyCompat types first, delete old SwiftUI files, clean pbxproj, then profile memory and verify signposter in a single Instruments session.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Move useful types (KeyMetrics, DeviceClass, KeySound, KeyPopup) out of LegacyCompat.swift into proper permanent file(s)
- Delete the placeholder KeyboardView struct from LegacyCompat
- Delete LegacyCompat.swift itself once types are extracted
- Delete all 5 named files: KeyButton.swift, KeyRow.swift, KeyboardView.swift (Views/), SpecialKeyButton.swift, AccentPopup.swift
- Clean all SwiftUI keyboard references from KeyboardRootView (it should only reference UIKit keyboard)
- Clean project.pbxproj: remove PBXBuildFile, PBXFileReference, PBXGroup entries for deleted files
- Dead code audit scope: named files + dependency chain only (not full extension-wide audit)
- Profile all 4 operation modes: typing, dictation, text prediction, emoji picker (separately AND combined)
- Test device: iPhone 15 Pro Max
- Include Leaks instrument alongside memory footprint measurement
- Pass criterion: peak memory stays under 50MB during all operations
- Document results in a markdown report in the phase directory
- Existing KeyTapSignposter is sufficient -- no additional instrumentation needed
- Verify existing signposter produces data in Instruments during memory profiling session

### Claude's Discretion
- File organization for extracted LegacyCompat types (single file vs split by concern)
- Order of deletion and refactoring steps
- Memory report format and level of detail
- How to handle any unexpected compilation errors after file deletion

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| os (OSSignposter) | System framework | Performance signposting | Apple's recommended approach for latency measurement |
| AudioToolbox | System framework | SystemSoundID for key sounds | Used by KeySound enum |
| AVFoundation | System framework | Audio session | Used by LegacyCompat import (can be removed after cleanup) |

### Instruments Templates Needed
| Template | Purpose | When to Use |
|----------|---------|-------------|
| Allocations | Track memory footprint over time | During all 4 operation modes |
| Leaks | Detect retain cycles and leaked objects | Alongside Allocations |
| os_signpost | Capture OSSignposter intervals | Verify KeyTapSignposter data |

No new dependencies needed for this phase.

## Architecture Patterns

### Recommended File Organization for Extracted Types

**Recommendation: Single file `KeyboardMetrics.swift`**

All 4 types (KeyMetrics, DeviceClass, KeySound, KeyPopup) share a common concern: keyboard layout/feedback constants. They are small (total ~90 lines), tightly coupled (KeyPopup uses KeyMetrics, KeyMetrics uses DeviceClass), and consumed together. A single file reduces pbxproj churn and keeps related constants discoverable.

```
DictusKeyboard/
├── KeyboardMetrics.swift        # NEW: DeviceClass, KeyMetrics, KeySound, KeyPopup (extracted from LegacyCompat)
├── KeyboardRootView.swift       # CLEANED: no SwiftUI keyboard references
├── LegacyCompat.swift           # DELETED
├── Views/
│   ├── KeyButton.swift          # DELETED
│   ├── KeyRow.swift             # DELETED
│   ├── KeyboardView.swift       # DELETED (SwiftUI one)
│   ├── SpecialKeyButton.swift   # DELETED
│   ├── AccentPopup.swift        # DELETED
│   ├── EmojiPickerView.swift    # UNCHANGED (uses KeyMetrics, KeyPopup)
│   ├── EmojiCategoryBar.swift   # UNCHANGED (uses KeySound)
│   └── ...
├── DictusKeyboardBridge.swift   # UNCHANGED (uses KeySound)
├── Vendored/Views/
│   └── KeyboardView.swift       # UNCHANGED (this is GiellaKeyboardView -- UIKit, NOT deleted)
```

### Deletion Order Pattern

Safe deletion order that keeps the project compilable at each step:

1. **Extract first:** Create KeyboardMetrics.swift with types from LegacyCompat
2. **Delete placeholder:** Remove the dead `KeyboardView` struct from LegacyCompat
3. **Delete LegacyCompat:** Now empty of useful code, remove file + pbxproj entry
4. **Delete old SwiftUI files:** KeyButton, KeyRow, KeyboardView (Views/), SpecialKeyButton, AccentPopup -- these only reference each other
5. **Clean pbxproj:** Remove all PBXBuildFile, PBXFileReference, PBXGroup entries for deleted files
6. **Build verify:** Confirm clean compilation

### pbxproj Entries to Remove

Identified from codebase analysis:

**PBXBuildFile (Sources section):**
- `AA000031` -- KeyButton.swift
- `AA000032` -- SpecialKeyButton.swift
- `AA000033` -- KeyRow.swift
- `AA000034` -- KeyboardView.swift (Views/)
- `AA000070` -- AccentPopup.swift
- `CC000000` -- LegacyCompat.swift

**PBXFileReference:**
- `AA100031` -- KeyButton.swift
- `AA100032` -- SpecialKeyButton.swift
- `AA100033` -- KeyRow.swift
- `AA100034` -- KeyboardView.swift (Views/)
- `AA100070` -- AccentPopup.swift
- `CC100000` -- LegacyCompat.swift

**PBXGroup (Views children):**
- Lines referencing AA100031, AA100032, AA100033, AA100034, AA100070

**PBXGroup (DictusKeyboard children):**
- Line referencing CC100000

**PBXSourcesBuildPhase:**
- Lines referencing AA000031-AA000034, AA000070, CC000000

**CRITICAL: Do NOT remove CC000009/CC100009** -- these are the Vendored KeyboardView.swift (GiellaKeyboardView), which is the active UIKit keyboard.

### Anti-Patterns to Avoid
- **Deleting before extracting:** If LegacyCompat is deleted before types are moved, EmojiPickerView/Bridge will fail to compile
- **Deleting the wrong KeyboardView.swift:** Two files named KeyboardView.swift exist -- only delete the one in `Views/` (AA100034), NOT the one in `Vendored/Views/` (CC100009)
- **Leaving ghost pbxproj entries:** Xcode may still compile but shows warnings; clean removal prevents confusion

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Memory measurement | Custom malloc tracking | Xcode Instruments Allocations template | Precise, low-overhead, shows live footprint graph |
| Leak detection | Manual retain cycle debugging | Xcode Instruments Leaks template | Automatic detection with backtrace |
| Latency measurement | print(Date()) timestamps | OSSignposter (already implemented) | Sub-microsecond precision, zero overhead when not profiling |
| pbxproj editing | Manual text editing only | Careful grep-based identification + targeted removal | pbxproj has strict formatting; identify IDs first, then remove lines |

## Common Pitfalls

### Pitfall 1: Wrong KeyboardView.swift Deleted
**What goes wrong:** Deleting the Vendored KeyboardView.swift (GiellaKeyboardView) instead of the old SwiftUI one
**Why it happens:** Both files have the same filename
**How to avoid:** Identify by pbxproj IDs -- AA100034 is Views/ (DELETE), CC100009 is Vendored/Views/ (KEEP)
**Warning signs:** If GiellaKeyboardView type suddenly unresolved, wrong file was deleted

### Pitfall 2: Instruments Inflates Extension Memory
**What goes wrong:** Memory readings are higher than real-world because Instruments attaches to the process and removes the system memory limit
**Why it happens:** Apple's profiler disables the jetsam limit when attached
**How to avoid:** Use the Memory Debugger in Xcode (Debug Navigator > Memory) for a quick baseline, then use Instruments for detailed analysis. Note both readings.
**Warning signs:** Extension using 80MB+ without being killed = profiler attached

### Pitfall 3: AVFoundation Import Unnecessary After Cleanup
**What goes wrong:** LegacyCompat imports AVFoundation but the extracted types only need UIKit + AudioToolbox
**Why it happens:** Original file imported it for legacy audio session code
**How to avoid:** Only import what the extracted types actually need: `import SwiftUI` (for Color in KeyMetrics), `import UIKit` (for UIScreen in DeviceClass), `import AudioToolbox` (for SystemSoundID in KeySound)

### Pitfall 4: Profiling on Simulator Instead of Device
**What goes wrong:** Memory measurements are meaningless -- simulator uses host Mac's memory allocator with different characteristics
**Why it happens:** Convenience of not connecting a device
**How to avoid:** Decision is locked: iPhone 15 Pro Max only. Profile via Cmd+I with device connected.

### Pitfall 5: Signposter Data Not Visible
**What goes wrong:** os_signpost instrument shows no data even though KeyTapSignposter is in the code
**Why it happens:** Need to use the "os_signpost" instrument (not just "Points of Interest"), and must tap keys during the recording session
**How to avoid:** Add "os_signpost" instrument to the Instruments template, filter by subsystem "com.pivi.dictus.keyboard" and category "KeyPress", type rapidly for 10+ seconds

## Code Examples

### Extracted KeyboardMetrics.swift

```swift
// DictusKeyboard/KeyboardMetrics.swift
// Keyboard layout constants and feedback types extracted from LegacyCompat.
// Used by EmojiPickerView, EmojiCategoryBar, DictusKeyboardBridge.

import SwiftUI
import UIKit
import AudioToolbox

// MARK: - Device Class

/// Device class for adaptive keyboard layout.
enum DeviceClass {
    case compact    // iPhone SE
    case standard   // iPhone 14/15/16
    case large      // iPhone Plus/Max

    static let current: DeviceClass = {
        let h = UIScreen.main.bounds.height
        if h <= 667 { return .compact }
        else if h <= 852 { return .standard }
        else { return .large }
    }()
}

// MARK: - Key Metrics

/// Shared key dimension constants, computed once per device class.
enum KeyMetrics {
    // ... (identical to current LegacyCompat content)
}

// MARK: - Key Sound

/// 3-category system sounds for key feedback.
enum KeySound {
    static let letter: SystemSoundID = 1104
    static let delete: SystemSoundID = 1155
    static let modifier: SystemSoundID = 1156
}

// MARK: - Key Popup

/// Minimal popup view for emoji key labels.
struct KeyPopup: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 24))
            .padding(6)
            .background(KeyMetrics.letterKeyColor)
            .cornerRadius(KeyMetrics.keyCornerRadius)
    }
}
```

### Memory Report Template

```markdown
# Phase 21: Memory Profiling Report

**Device:** iPhone 15 Pro Max
**iOS Version:** [version]
**Build:** [build number]
**Date:** [date]
**Tool:** Xcode Instruments (Allocations + Leaks + os_signpost)

## Results

| Operation | Duration | Peak Memory | Steady State | Leaks | Pass/Fail |
|-----------|----------|-------------|--------------|-------|-----------|
| Idle (keyboard visible) | 30s | ?MB | ?MB | 0 | |
| Rapid typing | 30s | ?MB | ?MB | 0 | |
| Dictation (recording) | 30s | ?MB | ?MB | 0 | |
| Dictation (transcription) | 10s | ?MB | ?MB | 0 | |
| Text prediction (active) | 30s | ?MB | ?MB | 0 | |
| Emoji picker browsing | 30s | ?MB | ?MB | 0 | |
| Combined peak scenario | 60s | ?MB | ?MB | 0 | |

**Pass criterion:** Peak memory < 50MB in ALL operations
**Overall result:** [PASS/FAIL]

## Signposter Verification

| Interval | Captured | Median Latency | Target |
|----------|----------|---------------|--------|
| touchDown (highlight) | Yes/No | ?ms | <= 16.67ms |
| touchDown (haptic) | Yes/No | ?ms | <= 16.67ms |
| touchUp (insertText) | Yes/No | ?ms | <= 33ms |

## Notes
[Observations, concerns, follow-up items]
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SwiftUI keyboard grid | UIKit UICollectionView (giellakbd-ios) | Phase 18 (2026-03-27) | Zero dead zones, lower memory |
| LegacyCompat stubs | Direct type definitions in permanent file | Phase 21 (now) | Clean codebase, no migration debt |
| os_signpost function API | OSSignposter class API | iOS 15+ | Type-safe, structured intervals |

## Open Questions

1. **Instruments memory overhead on extensions**
   - What we know: Instruments disables jetsam limits when attached, inflating readings
   - What's unclear: Exact overhead delta between Instruments-attached and real-world usage
   - Recommendation: Take a Debug Navigator baseline reading first (without Instruments), then do the detailed Instruments session. If Instruments shows 45-50MB but Debug Navigator shows 35MB, we know the overhead is ~10-15MB and real usage is safe.

2. **DictusCore types only referenced by deleted files**
   - What we know: CONTEXT.md says "quick check DictusCore for types only referenced by deleted files"
   - What's unclear: Whether any DictusCore types are orphaned
   - Recommendation: Grep DictusCore for types used in the 5 deleted files, check if those types are used anywhere else. Low risk -- the deleted files are self-contained SwiftUI views.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Xcode Instruments + manual device profiling |
| Config file | None -- Instruments is an external tool |
| Quick run command | `xcodebuild build -scheme DictusKeyboard -destination 'platform=iOS,name=iPhone 15 Pro Max'` |
| Full suite command | Instruments profiling session (manual -- requires physical device) |

### Phase Requirements -> Test Map

This is a quality gate with no feature requirement IDs. Validation is:

| Check | Behavior | Test Type | Automated? |
|-------|----------|-----------|------------|
| Compilation | Project compiles after all deletions | Build | `xcodebuild build` |
| No orphan refs | pbxproj has no references to deleted files | Grep | `grep -c 'AA100031\|AA100032\|AA100033\|AA100034\|AA100070\|CC100000' project.pbxproj` should return 0 |
| Memory under 50MB | Peak memory in all operations < 50MB | Manual (Instruments) | No -- requires device + Instruments |
| No leaks | Leaks instrument shows 0 leaks | Manual (Instruments) | No -- requires device + Instruments |
| Signposter data | os_signpost instrument captures KeyPress intervals | Manual (Instruments) | No -- requires device + Instruments |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme DictusKeyboard -destination generic/platform=iOS` (compilation check)
- **Phase gate:** Full Instruments profiling session on device

### Wave 0 Gaps
None -- no test infrastructure needed. Validation is build success + manual Instruments session.

## KeyboardRootView Analysis

Current KeyboardRootView.swift is already clean:
- No reference to the old SwiftUI `KeyboardView` type
- No reference to `KeyButton`, `KeyRow`, `SpecialKeyButton`, or `AccentPopup`
- Comment on line 140 says "No KeyboardView here -- it's UIKit"
- The placeholder `KeyboardView` struct in LegacyCompat is NOT used by KeyboardRootView

**Conclusion:** KeyboardRootView requires no cleanup beyond removing the `import` of LegacyCompat (which will happen implicitly since the types move to KeyboardMetrics.swift and are imported by name resolution).

## Sources

### Primary (HIGH confidence)
- Codebase analysis: LegacyCompat.swift, KeyboardRootView.swift, KeyTapSignposter.swift, project.pbxproj
- [Apple: OSSignposter documentation](https://developer.apple.com/documentation/os/ossignposter) -- API reference
- [Apple: Gathering information about memory use](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use) -- Instruments workflow
- [Apple: Recording Performance Data](https://developer.apple.com/documentation/os/recording-performance-data) -- signpost usage

### Secondary (MEDIUM confidence)
- [Swift Dev Journal: Measuring memory with Instruments](https://swiftdevjournal.com/measuring-your-apps-memory-usage-with-instruments/) -- practical walkthrough
- [Apple Developer Forums: Keyboard extension memory](https://developer.apple.com/forums/thread/85478) -- extension-specific profiling notes
- [Pol Piella: os_signposts profiling](https://www.polpiella.dev/time-profiler-instruments/) -- signpost template usage

## Metadata

**Confidence breakdown:**
- Dead code identification: HIGH -- verified by grep across entire DictusKeyboard directory
- pbxproj entries: HIGH -- exact IDs extracted from file
- Type extraction: HIGH -- consumer analysis confirms which types are needed
- Memory profiling workflow: MEDIUM -- standard Instruments approach, but extension-specific nuances (jetsam override) noted
- Signposter verification: HIGH -- existing code is well-documented, just needs Instruments run

**Research date:** 2026-03-30
**Valid until:** 2026-04-30 (stable domain -- Instruments and OSSignposter APIs are mature)
