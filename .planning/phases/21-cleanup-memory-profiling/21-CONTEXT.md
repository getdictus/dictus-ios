# Phase 21: Cleanup & Memory Profiling - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove all old SwiftUI keyboard code from the extension, verify the keyboard extension stays under the 50MB memory budget on a real device across all operations, and confirm existing OSSignposter instrumentation produces data in Instruments. Quality gate phase -- no new features, blocks public beta (Phase 22).

</domain>

<decisions>
## Implementation Decisions

### LegacyCompat cleanup
- Move useful types (KeyMetrics, DeviceClass, KeySound, KeyPopup) out of LegacyCompat.swift into proper permanent file(s)
- Delete the placeholder `KeyboardView` struct from LegacyCompat (it's a dead stub)
- Delete LegacyCompat.swift itself once types are extracted
- File organization for extracted types: Claude's discretion based on consumer analysis

### Old SwiftUI file deletion
- Delete all 5 named files: KeyButton.swift, KeyRow.swift, KeyboardView.swift (Views/), SpecialKeyButton.swift, AccentPopup.swift
- Also clean all SwiftUI keyboard references from KeyboardRootView -- it should only reference the UIKit keyboard
- Follow the dependency chain: delete any types/functions that become unreferenced after the 5 files are removed

### Dead code audit scope
- Named files + their dependency chain (not a full extension-wide audit)
- Clean project.pbxproj: remove PBXBuildFile, PBXFileReference, PBXGroup entries for all deleted files
- Quick check DictusCore for types only referenced by deleted files -- remove if found

### Memory profiling
- Profile all 4 operation modes: typing (rapid input), dictation (recording + transcription), text prediction (suggestions active), emoji picker
- Profile each separately AND in combination (peak scenario)
- Test device: iPhone 15 Pro Max
- Include Leaks instrument alongside memory footprint measurement
- Pass criterion: peak memory stays under 50MB during all operations
- Document results in a markdown report in the phase directory (per-operation measurements, peak usage, pass/fail)

### Signposter instrumentation
- Existing KeyTapSignposter is sufficient -- covers touchDown-to-highlight, touchDown-to-haptic, touchUp-to-insertText
- No additional signposter instrumentation needed (dictation/prediction latency not required)
- Verify the existing signposter produces data in Instruments during the memory profiling session (os_signpost template)

### Claude's Discretion
- File organization for extracted LegacyCompat types (single file vs split by concern)
- Order of deletion and refactoring steps
- Memory report format and level of detail
- How to handle any unexpected compilation errors after file deletion

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Files to delete
- `DictusKeyboard/Views/KeyButton.swift` -- Old SwiftUI key button with accent popup
- `DictusKeyboard/Views/KeyRow.swift` -- Old SwiftUI key row using KeyButton
- `DictusKeyboard/Views/KeyboardView.swift` -- Old SwiftUI keyboard view using KeyRow
- `DictusKeyboard/Views/SpecialKeyButton.swift` -- Old SwiftUI special key with accent popup
- `DictusKeyboard/Views/AccentPopup.swift` -- Old SwiftUI accent popup overlay

### Files to refactor
- `DictusKeyboard/LegacyCompat.swift` -- Extract useful types, delete file
- `DictusKeyboard/KeyboardRootView.swift` -- Remove any SwiftUI keyboard references

### LegacyCompat consumers (need types after extraction)
- `DictusKeyboard/Views/EmojiPickerView.swift` -- Uses KeyMetrics, KeyPopup
- `DictusKeyboard/Views/EmojiCategoryBar.swift` -- Uses KeyMetrics
- `DictusKeyboard/DictusKeyboardBridge.swift` -- Uses KeySound

### Existing instrumentation
- `DictusKeyboard/TouchHandling/KeyTapSignposter.swift` -- OSSignposter for touch pipeline latency

### Architecture context
- `.planning/phases/18-keyboard-base/18-CONTEXT.md` -- UIKit keyboard architecture decisions
- `.planning/phases/20-feature-reintegration/20-CONTEXT.md` -- Feature wiring decisions, emoji integration

### Project file
- `Dictus.xcodeproj/project.pbxproj` -- Must clean references to deleted files

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `KeyTapSignposter`: Complete OSSignposter instrumentation for touch pipeline -- just needs Instruments verification
- `GiellaKeyboardView` (Vendored/Views/KeyboardView.swift): The real UIKit keyboard -- NOT to be deleted (different file from old SwiftUI KeyboardView)

### Established Patterns
- Xcode project file editing: PBXBuildFile + PBXFileReference + PBXGroup + PBXSourcesBuildPhase (done in Phase 18 for vendored files)
- UIKit keyboard is fully wired via DictusKeyboardBridge -- no SwiftUI keyboard code is in the active path

### Integration Points
- EmojiPickerView, EmojiCategoryBar, DictusKeyboardBridge depend on LegacyCompat types -- must extract before deleting
- KeyboardRootView may still reference old SwiftUI KeyboardView type -- needs cleanup
- project.pbxproj has entries for all old files -- must remove to prevent ghost references

</code_context>

<specifics>
## Specific Ideas

- LegacyCompat.swift header says "This file will be removed in Phase 18 Plan 02" -- it's overdue for cleanup
- Two KeyboardView.swift files exist (Views/ and Vendored/Views/) -- only delete the SwiftUI one in Views/
- Memory profiling session doubles as signposter verification -- run os_signpost instrument alongside Allocations/Leaks

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 21-cleanup-memory-profiling*
*Context gathered: 2026-03-30*
