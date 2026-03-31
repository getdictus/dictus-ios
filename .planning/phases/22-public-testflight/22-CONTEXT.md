# Phase 22: Public TestFlight - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Make Dictus available as a public TestFlight beta that anyone can install. This includes: fixing the emoji picker memory blocker (139 MiB), passing Beta App Review, creating an external testing group with a public link, updating the README, and creating a GitHub Release with release notes for social media announcement.

Requirements: TF-01, TF-02, TF-03, TF-04

</domain>

<decisions>
## Implementation Decisions

### Emoji picker memory optimization
- The emoji picker currently uses 139 MiB -- nearly 3x the 50 MB extension budget
- This MUST be fixed before submitting to Beta App Review -- it's a prerequisite, not optional
- Include as the first plan of Phase 22 (not a separate phase)
- Claude researches and decides the optimization approach (pagination, image-based rendering, lazy loading, etc.)
- No fallback -- the emoji picker must fit in the memory budget. Keep iterating until it works
- After optimization, re-profile on device to confirm it passes the 50 MB budget

### Beta App Review preparation
- Claude writes the Full Access justification text (tone and content at Claude's discretion, based on what Apple expects)
- Claude audits the codebase for required-reason APIs beyond UserDefaults (file timestamps, disk space, system boot time, etc.) and updates privacy manifests if needed
- Claude drafts App Store Connect description text in French + English for Pierre to paste into the portal
- Plan includes step-by-step Xcode Archive + Upload instructions (Pierre doesn't remember the exact flow from Phase 16)
- Version bump and build number increment as per existing workflow

### README & launch communications
- Claude decides the README TestFlight section format (standard for open-source iOS apps with TestFlight betas)
- Create a GitHub Release tagged `v1.3.0-beta` (pre-release tag with "Pre-release" badge -- standard practice for beta distributions)
- Claude drafts release notes for the GitHub Release
- Pierre will use release notes as basis for social media posts (Twitter/X, Reddit, etc.)

### External group setup
- Public TestFlight link (anyone with the link can install) -- up to 10,000 testers
- Set an initial tester cap (100-500 range) to manage feedback volume -- can increase later
- Feedback channels: both TestFlight built-in feedback AND GitHub Issues
- Mention both feedback channels in the README TestFlight section
- Issue templates already exist from Phase 15.2 -- no new templates needed

### Claude's Discretion
- Emoji picker optimization approach (pagination, image caching, lazy rendering, etc.)
- Full Access justification text tone and content
- App Store Connect description text
- README TestFlight section format and install instructions depth
- GitHub Release notes content and formatting
- Exact tester cap number within 100-500 range

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Privacy manifests
- `DictusApp/PrivacyInfo.xcprivacy` -- Current privacy manifest for main app (UserDefaults CA92.1)
- `DictusKeyboard/PrivacyInfo.xcprivacy` -- Current privacy manifest for keyboard extension (UserDefaults CA92.1)

### Emoji picker (memory blocker)
- `DictusKeyboard/Views/EmojiPickerView.swift` -- Main emoji picker view with LazyHGrid (source of 139 MiB usage)
- `DictusKeyboard/Views/EmojiCategoryBar.swift` -- Category bar component
- `DictusKeyboard/Models/EmojiData.swift` -- Emoji data source
- `.planning/phases/21-cleanup-memory-profiling/21-02-SUMMARY.md` -- Memory profiling report identifying the 139 MiB blocker

### README
- `README.md` -- Current README with "link coming soon" placeholder at line 69

### Prior TestFlight context
- `.planning/phases/21-cleanup-memory-profiling/21-CONTEXT.md` -- Memory profiling decisions and emoji blocker identification

### Project metadata
- `.planning/REQUIREMENTS.md` -- TF-01 through TF-04 requirement definitions
- `DEVELOPMENT.md` -- Development guide (for archive/upload instructions context)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Privacy manifests: Both targets already have `PrivacyInfo.xcprivacy` with UserDefaults declaration -- may need additions after audit
- GitHub issue templates: Already created in Phase 15.2 -- ready for beta tester bug reports
- Version/build management: Established workflow for bumping CFBundleVersion across all 3 Info.plist files

### Established Patterns
- Build upload: Xcode Archive + Upload to App Store Connect (done once in Phase 16 for private beta)
- Privacy policy: `https://www.getdictus.com/en/privacy` already set in App Store Connect
- Team ID: 9B8B36C2FA (Apple Developer Program, Individual)

### Integration Points
- App Store Connect: External testing group creation, public link generation, tester cap setting
- GitHub: Release creation with tag, README update
- README line 69: Replace `_link coming soon_` placeholder with actual TestFlight link

</code_context>

<specifics>
## Specific Ideas

- Pierre wants step-by-step Xcode upload instructions (not familiar enough with the flow to do it from memory)
- Social media announcement planned -- release notes should be written to double as announcement material
- Tester cap to start small and increase -- Pierre wants to manage feedback volume
- Both TestFlight built-in feedback AND GitHub Issues as feedback channels (mention both in README)

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 22-public-testflight*
*Context gathered: 2026-03-31*
