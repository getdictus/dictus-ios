---
phase: 22-public-testflight
plan: 02
subsystem: infra
tags: [testflight, privacy-manifest, github-release, beta, app-store-connect]

# Dependency graph
requires:
  - phase: 22-01
    provides: Emoji picker memory fix (under 50 MB budget for Beta App Review)
provides:
  - Privacy manifests with all required-reason APIs (UserDefaults, FileTimestamp, ActiveKeyboards)
  - Version 1.3 build 5 across all targets
  - Submission prep document with Full Access justification and App Store Connect texts
  - README with TestFlight public link and install instructions
  - GitHub Release v1.3.0-beta with release notes
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Privacy manifest pattern for required-reason APIs (xcprivacy files per target)

key-files:
  created:
    - .planning/phases/22-public-testflight/22-SUBMISSION-PREP.md
  modified:
    - DictusApp/PrivacyInfo.xcprivacy
    - DictusKeyboard/PrivacyInfo.xcprivacy
    - DictusApp/Info.plist
    - DictusKeyboard/Info.plist
    - DictusWidgets/Info.plist
    - README.md

key-decisions:
  - "FileTimestamp C617.1 for PersistentLog attributesOfItem, ActiveKeyboards 3EC4.1 for activeInputModes (DictusApp only)"
  - "Tester limit set to 250 for initial public beta"
  - "GitHub Release tagged v1.3.0-beta as pre-release"

patterns-established:
  - "Per-target privacy manifests: DictusApp gets all APIs, DictusKeyboard only APIs it actually uses"

requirements-completed: [TF-01, TF-02, TF-03, TF-04]

# Metrics
duration: 3min
completed: 2026-04-07
---

# Phase 22 Plan 02: Public TestFlight Submission Summary

**Privacy manifests updated, version bumped to 1.3 build 5, public TestFlight link live (b55atKYX), GitHub Release v1.3.0-beta published**

## Performance

- **Duration:** 3 min (Task 1 previously completed, Task 2 human action, Task 3 automated)
- **Started:** 2026-04-07T20:58:42Z
- **Completed:** 2026-04-07T21:01:45Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments
- Privacy manifests declare all required-reason APIs (UserDefaults CA92.1, FileTimestamp C617.1, ActiveKeyboards 3EC4.1) eliminating ITMS-91053 rejection risk
- Version 1.3 build 5 set across all 3 targets (DictusApp, DictusKeyboard, DictusWidgets)
- Submission prep document created with Full Access justification, bilingual descriptions, and step-by-step Xcode Archive instructions
- Public TestFlight link live: https://testflight.apple.com/join/b55atKYX
- README updated with TestFlight install instructions and dual feedback channels (TestFlight + GitHub Issues)
- GitHub Release v1.3.0-beta published as pre-release with full release notes

## Task Commits

Each task was committed atomically:

1. **Task 1: Update privacy manifests, bump version, draft submission texts** - `69be2d5` (feat)
2. **Task 2: Archive, upload, and create public TestFlight link** - human action (no code commit)
3. **Task 3: Update README and create GitHub Release** - `3b77614` (feat)

## Files Created/Modified
- `DictusApp/PrivacyInfo.xcprivacy` - Added FileTimestamp C617.1 and ActiveKeyboards 3EC4.1
- `DictusKeyboard/PrivacyInfo.xcprivacy` - Added FileTimestamp C617.1
- `DictusApp/Info.plist` - Version 1.3 build 5
- `DictusKeyboard/Info.plist` - Version 1.3 build 5
- `DictusWidgets/Info.plist` - Version 1.3 build 5
- `README.md` - TestFlight section with public link and install instructions
- `.planning/phases/22-public-testflight/22-SUBMISSION-PREP.md` - Submission prep with justification texts

## Decisions Made
- FileTimestamp (C617.1) added to both targets since PersistentLog runs via DictusCore in both
- ActiveKeyboards (3EC4.1) added only to DictusApp since UITextInputMode.activeInputModes is used only in KeyboardSetupPage
- Tester limit set to 250 (within 100-500 range from context decisions)

## Deviations from Plan

None - plan executed exactly as written. Task 1 was previously committed; Task 2 was human action; Task 3 followed plan instructions.

## Issues Encountered
None

## User Setup Required

Build was archived and uploaded to App Store Connect by Pierre. Public Beta group created with public link (tester limit: 250). Beta App Review approved.

## Next Phase Readiness
- Dictus v1.3 public beta is live and installable via TestFlight
- GitHub Release v1.3.0-beta available for social media announcement
- Phase 22 (Public TestFlight) is fully complete
- Development continues on develop branch for v1.4 milestone

## Self-Check: PASSED

All files verified present, all commits found, GitHub Release confirmed.

---
*Phase: 22-public-testflight*
*Completed: 2026-04-07*
