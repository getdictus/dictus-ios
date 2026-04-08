# Phase 22: Public TestFlight - Research

**Researched:** 2026-03-31
**Domain:** iOS Keyboard Extension Memory Optimization, Apple Beta App Review, TestFlight Distribution
**Confidence:** HIGH

## Summary

Phase 22 has two distinct challenges: (1) fixing the emoji picker memory bloat that makes the keyboard extension use 139 MiB (2.8x the 50 MiB jetsam limit), and (2) preparing and submitting for Beta App Review with proper privacy manifests, Full Access justification, and external TestFlight distribution.

The emoji picker memory issue is a well-documented CoreText problem: each emoji glyph consumes ~65KB when rendered as a `Text` view, and CoreText caches these glyphs in `NSCache` without releasing them until a memory warning fires. With ~1,800 emojis in the current `flatItems` array rendered in a `LazyHGrid`, the glyph cache grows to ~120-139 MiB. The recommended fix is a combination of category-based pagination (only load one category at a time) and NSCache swizzling to force cache eviction on dismiss.

The Beta App Review and TestFlight setup is procedural but requires careful attention to privacy manifests (the codebase uses two additional required-reason APIs beyond UserDefaults that are not yet declared) and a well-written Full Access justification.

**Primary recommendation:** Fix emoji memory first via pagination + cache eviction, then audit privacy manifests, then archive and submit for Beta App Review, and finally create external group with public link.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Emoji picker memory optimization is a prerequisite -- MUST be fixed before Beta App Review submission
- Include emoji optimization as the first plan of Phase 22
- No fallback -- emoji picker must fit in memory budget, keep iterating until it works
- After optimization, re-profile on device to confirm it passes the 50 MB budget
- Claude writes Full Access justification text
- Claude audits codebase for required-reason APIs and updates privacy manifests
- Claude drafts App Store Connect description text in French + English
- Plan includes step-by-step Xcode Archive + Upload instructions
- Version bump and build number increment as per existing workflow
- Create GitHub Release tagged `v1.3.0-beta` with pre-release badge
- Claude drafts release notes for GitHub Release
- Public TestFlight link (anyone with link can install), up to 10,000 testers
- Set initial tester cap in 100-500 range
- Feedback channels: TestFlight built-in feedback AND GitHub Issues
- Mention both feedback channels in README TestFlight section
- Issue templates already exist from Phase 15.2

### Claude's Discretion
- Emoji picker optimization approach (pagination, image caching, lazy rendering, etc.)
- Full Access justification text tone and content
- App Store Connect description text
- README TestFlight section format and install instructions depth
- GitHub Release notes content and formatting
- Exact tester cap number within 100-500 range

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TF-01 | App passes Beta App Review with complete Privacy Manifests | Privacy manifest audit findings (3 required-reason APIs identified), Full Access justification guidance |
| TF-02 | External testing group created in App Store Connect | TestFlight external group creation steps documented |
| TF-03 | Public TestFlight link active and shareable | Public link creation with tester cap configuration documented |
| TF-04 | README updated with public TestFlight link and install instructions | README line 69 placeholder identified, standard open-source TestFlight section format researched |
</phase_requirements>

## Standard Stack

### Core (no new dependencies)
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Xcode | 16+ | Archive and upload to App Store Connect | Required for TestFlight distribution |
| App Store Connect | - | External group, public link, Beta App Review | Apple's distribution platform |
| GitHub Releases | - | Tagged release with notes | Standard open-source release practice |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| Instruments (Allocations) | Memory profiling after emoji fix | Validate optimization passes 50 MiB budget |
| `vmmap` | Dirty memory breakdown | If Instruments numbers need clarification |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftUI Text emoji rendering | UIImage-based emoji sprites | Much more complex, sprites would need generation; pagination is simpler and sufficient |
| NSCache swizzling | Reduce emoji count | Loses functionality; swizzling is proven (SwiftKey article) |
| Category pagination | Keep full LazyHGrid | Full grid is the root cause of 139 MiB; must paginate |

## Architecture Patterns

### Emoji Picker Memory Fix Strategy

**The Problem:**
CoreText renders each emoji character as a ~65KB glyph bitmap and caches it in `NSCache`. The current `EmojiPickerView` builds a `flatItems` array of ALL ~1,800 emojis and feeds them to a single `LazyHGrid`. Even though `LazyHGrid` is "lazy" for view creation, once the user scrolls through categories, CoreText has cached hundreds of glyphs and never releases them. The 139 MiB measurement confirms this: ~1,800 emojis x ~65KB/glyph = ~117 MiB of glyph cache alone.

**Recommended Approach: Category Pagination + Cache Eviction**

1. **Category Pagination (PRIMARY fix):** Instead of one continuous horizontal grid with all emojis, show only the selected category's emojis at a time. When the user taps a category in `EmojiCategoryBar`, replace the grid content entirely. This limits visible emojis to the largest category (~230 emojis for "Objects") = ~15 MiB max glyph cache at any time.

2. **Force Cache Eviction on Category Switch:** When switching categories, the old SwiftUI views are destroyed, but CoreText's `NSCache` retains glyph bitmaps. Use `NSCache.removeAllObjects()` via the swizzling technique documented in the SwiftKey article, or simpler: post a simulated memory warning via `UIApplication.shared` -- but this is NOT available in keyboard extensions. Instead, track CoreText caches via method swizzling on `NSCache.setObject(_:forKey:)` and call `removeAllObjects()` on tracked caches when switching categories.

3. **Fallback if swizzling is too complex:** Just pagination alone should reduce peak memory from 139 MiB to ~15-20 MiB (largest single category). Only add cache eviction if profiling shows pagination alone is insufficient.

**Implementation Pattern:**

```swift
// BEFORE: One flat array of ALL emojis
private var flatItems: [EmojiGridItem] {
    var items: [EmojiGridItem] = []
    for cat in categories {
        for (i, emoji) in cat.emojis.enumerated() {
            items.append(...)
        }
    }
    return items
}

// AFTER: Only selected category's emojis
private var currentCategoryEmojis: [EmojiGridItem] {
    if selectedCategoryID == "recents" {
        return recentEmojis.enumerated().map { ... }
    }
    guard let cat = categories.first(where: { $0.id == selectedCategoryID }) else { return [] }
    return cat.emojis.enumerated().map { ... }
}
```

The grid changes from horizontal scrolling across all categories to showing one category at a time with the category bar as the navigation mechanism. This matches how Apple's own emoji keyboard works on macOS.

### Privacy Manifest Updates Required

The codebase audit reveals **2 additional required-reason APIs** beyond the already-declared UserDefaults:

| API | Where Used | Category | Reason Code | Justification |
|-----|-----------|----------|-------------|---------------|
| `UserDefaults` | Everywhere (App Group) | `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` | Already declared in both manifests |
| `FileManager.attributesOfItem(atPath:)` | `PersistentLog.swift` (3 call sites) | `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` | Accessing file size within app group container for log trimming |
| `UITextInputMode.activeInputModes` | `KeyboardSetupPage.swift` (DictusApp only) | `NSPrivacyAccessedAPICategoryActiveKeyboards` | `3EC4.1` | Custom keyboard app checking if its keyboard is installed |

**Action:** Add `NSPrivacyAccessedAPICategoryFileTimestamp` with reason `C617.1` to BOTH privacy manifests (PersistentLog runs in both targets via DictusCore). Add `NSPrivacyAccessedAPICategoryActiveKeyboards` with reason `3EC4.1` to DictusApp's privacy manifest only.

### Version Bump

Current version: `1.2` (build `4`) across all 3 Info.plist files + DictusWidgets.
Target version: `1.3` (build `5`).
Files to update:
- `DictusApp/Info.plist`
- `DictusKeyboard/Info.plist`
- `DictusWidgets/Info.plist`

### Xcode Archive + Upload Flow

Step-by-step instructions for Pierre (who does this in the App Store Connect portal and Xcode, not from Claude):

1. Select **DictusApp** scheme, set destination to **Any iOS Device (arm64)**
2. **Product > Archive** (builds release configuration)
3. When archive completes, **Organizer** window opens
4. Select the archive, click **Distribute App**
5. Choose **App Store Connect** > **Upload**
6. Follow prompts (signing, entitlements auto-resolved)
7. Wait for processing in App Store Connect (~5-15 min)
8. In App Store Connect > TestFlight, the new build appears
9. Add build to external testing group > **Submit for Beta App Review**

### External Testing Group + Public Link

1. In App Store Connect > TestFlight > sidebar, click (+) next to **External Testing**
2. Name the group (e.g., "Public Beta")
3. Add the approved build to the group
4. Under Testers tab, click **Create Public Link**
5. Select **Open to Anyone**
6. Set **Tester Limit** to 250 (recommended starting point within 100-500 range)
7. Copy the link -- this is the public TestFlight URL
8. Replace README placeholder at line 69

### README TestFlight Section

Replace the placeholder at line 69 (`_link coming soon_`) with the actual URL. Standard format for open-source iOS beta:

```markdown
## Beta Testing

Join the beta via TestFlight: [Install Dictus Beta](https://testflight.apple.com/join/XXXXX)

**Requirements:** iPhone 12 or later, iOS 17.0+

**How to install:**
1. Tap the link above on your iPhone
2. Install TestFlight if you don't have it
3. Open Dictus and follow the onboarding
4. Enable the keyboard: Settings > General > Keyboard > Keyboards > Add > Dictus
5. Allow Full Access when prompted (required for microphone)

**Give feedback:**
- Shake your device in Dictus to send feedback via TestFlight
- Or open an issue on [GitHub](https://github.com/getdictus/dictus-ios/issues)
```

### GitHub Release

Tag: `v1.3.0-beta` (pre-release)
Content: Release notes summarizing features since v1.2, known limitations, install instructions via TestFlight link.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Emoji glyph memory management | Custom image-based emoji rendering | Category pagination (limit visible emojis) | CoreText caching is the root cause; reducing what's rendered is simpler and proven |
| Privacy manifest format | Manual plist editing | Xcode privacy manifest editor or careful plist XML | Format is strict; typos cause ITMS rejections |
| TestFlight distribution | Any custom beta distribution | App Store Connect TestFlight | Apple's official channel, required for public beta |

## Common Pitfalls

### Pitfall 1: LazyHGrid Still Caches All Rendered Glyphs
**What goes wrong:** Developers assume `LazyHGrid` means only visible emojis consume memory. In reality, once an emoji scrolls into view, CoreText caches its glyph permanently until memory warning.
**Why it happens:** SwiftUI lazy containers manage view lifecycle, not CoreText glyph caches.
**How to avoid:** Pagination -- never have more than one category's worth of emojis in the grid at once.
**Warning signs:** Memory stays high even after scrolling back to a small category.

### Pitfall 2: Privacy Manifest Rejection (ITMS-91053)
**What goes wrong:** Build rejected with "Missing API declaration" error.
**Why it happens:** Required-reason APIs used in code but not declared in PrivacyInfo.xcprivacy.
**How to avoid:** Audit ALL Swift files for `attributesOfItem`, `creationDate`, `modificationDate`, `activeInputModes`, `systemUptime`, disk space APIs before submission.
**Warning signs:** Any `FileManager.attributesOfItem` or `UITextInputMode.activeInputModes` call without matching privacy manifest entry.

### Pitfall 3: Beta App Review Rejection for Full Access
**What goes wrong:** Apple rejects because the Full Access justification is vague or the keyboard appears to work without it.
**Why it happens:** Apple wants to know exactly WHY Full Access is needed and that the keyboard has basic functionality without it.
**How to avoid:** Clearly state microphone access is the reason (speech-to-text dictation). Emphasize that typing works without Full Access, but dictation requires it.
**Warning signs:** Justification text that mentions "enhanced features" without specifics.

### Pitfall 4: Build Number Not Incremented
**What goes wrong:** App Store Connect rejects the upload because build number already exists.
**Why it happens:** Forgetting to increment CFBundleVersion across all 3 Info.plist files.
**How to avoid:** Always bump all 3 plists together: DictusApp, DictusKeyboard, DictusWidgets.
**Warning signs:** Upload error mentioning duplicate build number.

### Pitfall 5: NSCache Swizzling in Keyboard Extension
**What goes wrong:** Method swizzling may trigger App Review warnings or unexpected behavior.
**Why it happens:** Swizzling is technically allowed but can be flagged.
**How to avoid:** Try pagination alone first. Only add swizzling if pagination doesn't reduce memory enough. SwiftKey uses this technique in production, so it passes review.
**Warning signs:** Memory still high after pagination (>30 MiB with single category visible).

### Pitfall 6: Forgetting DictusWidgets Plist
**What goes wrong:** Version mismatch between targets.
**Why it happens:** DictusWidgets has its own Info.plist that's easy to forget.
**How to avoid:** Always update all 3 plists: DictusApp, DictusKeyboard, DictusWidgets.

## Code Examples

### Privacy Manifest Entry for File Timestamp API

```xml
<!-- Add to both DictusApp/PrivacyInfo.xcprivacy and DictusKeyboard/PrivacyInfo.xcprivacy -->
<dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array>
        <string>C617.1</string>
    </array>
</dict>
```

### Privacy Manifest Entry for Active Keyboards API

```xml
<!-- Add to DictusApp/PrivacyInfo.xcprivacy ONLY -->
<dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryActiveKeyboards</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array>
        <string>3EC4.1</string>
    </array>
</dict>
```

### Category-Based Emoji Grid (Pagination Pattern)

```swift
// Replace flatItems with single-category data source
private var currentCategoryEmojis: [EmojiGridItem] {
    if selectedCategoryID == "recents" {
        return recentEmojis.enumerated().map { i, emoji in
            EmojiGridItem(id: "recents_\(i)", emoji: emoji, categoryID: "recents")
        }
    }
    guard let cat = categories.first(where: { $0.id == selectedCategoryID }) else {
        return []
    }
    return cat.emojis.enumerated().map { i, emoji in
        EmojiGridItem(id: "\(cat.id)_\(i)", emoji: emoji, categoryID: cat.id)
    }
}

// Grid now uses currentCategoryEmojis instead of flatItems
// No more ScrollViewReader + scrollTo -- category bar directly switches content
```

### Full Access Justification Text (Draft)

```
Dictus is an on-device speech-to-text keyboard. Full Access is required
to access the device microphone for voice dictation. All speech recognition
runs locally on-device via Apple CoreML (WhisperKit). No keystroke data,
audio, or transcription is transmitted off-device. The keyboard provides
full typing functionality without Full Access; only the dictation feature
requires it.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single continuous emoji grid | Category-paginated grid | Ongoing best practice | Prevents CoreText glyph cache from growing unbounded |
| No privacy manifests | Required-reason API declarations mandatory | May 2024 | App Store rejects uploads without proper manifests |
| Email-only TestFlight | Public TestFlight links | 2023 | Anyone with link can join, no email collection needed |

## Open Questions

1. **Will pagination alone be sufficient?**
   - What we know: Largest category (Objects) has ~220 emojis = ~14 MiB glyph cache. Previous categories' caches may persist.
   - What's unclear: Whether CoreText releases caches when SwiftUI views are fully removed from hierarchy.
   - Recommendation: Implement pagination first, re-profile. If memory stays above 30 MiB, add NSCache eviction via swizzling.

2. **Beta App Review timeline**
   - What we know: First external build requires full review. Subsequent builds for same version may not.
   - What's unclear: Current review turnaround time (historically 24-48 hours for TestFlight).
   - Recommendation: Submit early, don't block on review wait time.

3. **WhisperKit / FluidAudio privacy manifests**
   - What we know: SPM dependencies may have their own required-reason APIs.
   - What's unclear: Whether WhisperKit or FluidAudio use file timestamp, disk space, or boot time APIs internally.
   - Recommendation: Check if these packages include their own PrivacyInfo.xcprivacy. If not, their API usage must be declared in the app's manifest. Xcode should warn during archive.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Xcode Instruments (Allocations) + manual verification |
| Config file | N/A -- Instruments profiling is manual |
| Quick run command | `xcodebuild build -scheme DictusApp -destination 'generic/platform=iOS'` |
| Full suite command | Manual: Instruments profiling on device + App Store Connect upload verification |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TF-01 | Privacy manifests complete, Beta App Review passes | manual-only | Xcode archive + upload validates manifests; Beta App Review is human review | N/A |
| TF-02 | External testing group exists | manual-only | Created in App Store Connect portal | N/A |
| TF-03 | Public TestFlight link active | manual-only | Link tested in browser/TestFlight app | N/A |
| TF-04 | README has TestFlight link | smoke | `grep -q "testflight.apple.com" README.md` | N/A |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme DictusApp -destination 'generic/platform=iOS'` (build succeeds)
- **Per wave merge:** Instruments memory profiling on device (emoji picker < 50 MiB)
- **Phase gate:** Successful upload to App Store Connect + Beta App Review approval + public link active

### Wave 0 Gaps
None -- this phase is primarily manual (App Store Connect operations, Instruments profiling). No test infrastructure needed beyond build verification.

## Sources

### Primary (HIGH confidence)
- [CoreText Emoji Memory Retention in SwiftKey iOS Keyboard Extension](https://medium.com/@mohasalah/core-text-emoji-rendering-memory-issue-1c6a227d592d) - Root cause analysis, ~65KB per glyph, NSCache swizzling solution
- [High Memory Usage of Emojis on iOS](https://vinceyuan.github.io/high-memory-usage-of-emojis-on-ios/) - Confirms glyph caching never releases, keyboard extension memory limits
- [Apple: Invite External Testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/) - Official TestFlight external group + public link documentation
- [Apple: Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) - Required-reason API categories
- [Apple: TN3183 Adding Required Reason API Entries](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest) - How to add entries to privacy manifests

### Secondary (MEDIUM confidence)
- [Apple Privacy Manifest Overview (Bugfender)](https://bugfender.com/blog/apple-privacy-requirements/) - Complete list of 5 API categories and reason codes
- [Apple Privacy Manifest (Anand Sharma)](https://medium.com/@anand_sharma/apples-privacy-manifest-33bfde782764) - Reason codes per category: C617.1 for file metadata, 3EC4.1 for active keyboards

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new dependencies, well-documented Apple workflows
- Architecture (emoji fix): HIGH - CoreText glyph caching is thoroughly documented; pagination is proven approach
- Architecture (TestFlight): HIGH - Official Apple documentation followed
- Pitfalls: HIGH - Based on documented rejection reasons and known iOS behaviors
- Privacy manifests: MEDIUM - Reason codes verified across multiple sources but Apple docs require JS to load; cross-verified with 3 independent articles

**Research date:** 2026-03-31
**Valid until:** 2026-04-30 (stable domain -- Apple processes don't change frequently)
