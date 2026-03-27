---
phase: 16-testflight-deployment
plan: 01
subsystem: infra
tags: [code-signing, privacy-manifest, xcode, testflight, apple-developer]

# Dependency graph
requires:
  - phase: 15.3-keyboard-optimization
    provides: "Stable keyboard build ready for distribution"
provides:
  - "Professional code signing (Team ID 9B8B36C2FA) across all targets"
  - "Privacy Manifests (UserDefaults CA92.1) for DictusApp and DictusKeyboard"
  - "MARKETING_VERSION 1.2 for all targets"
  - "Bilingual privacy policy (PRIVACY.md)"
  - "App Store Review checklist (REVIEW-CHECKLIST.md)"
affects: [16-testflight-deployment]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Privacy Manifest with NSPrivacyAccessedAPICategoryUserDefaults CA92.1"]

key-files:
  created:
    - DictusApp/PrivacyInfo.xcprivacy
    - DictusKeyboard/PrivacyInfo.xcprivacy
    - PRIVACY.md
    - .planning/phases/16-testflight-deployment/REVIEW-CHECKLIST.md
  modified:
    - Dictus.xcodeproj/project.pbxproj

key-decisions:
  - "Updated all 6 DEVELOPMENT_TEAM entries (DictusApp + DictusKeyboard + DictusWidgets, Debug + Release) not just 4 as plan estimated"
  - "MARKETING_VERSION was already 1.2 from prior work -- no change needed"
  - "PrivacyInfo.xcprivacy, PRIVACY.md, and REVIEW-CHECKLIST.md already existed from prior setup -- only signing migration was new work"

patterns-established:
  - "Privacy Manifest: identical xcprivacy for app and extension targets declaring UserDefaults CA92.1"

requirements-completed: [TF-01, TF-02, TF-05]

# Metrics
duration: 2min
completed: 2026-03-27
---

# Phase 16 Plan 01: TestFlight Prep Summary

**Professional signing migration (Team ID 9B8B36C2FA), Privacy Manifests with UserDefaults CA92.1, bilingual privacy policy, and App Store Review checklist**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-27T12:07:22Z
- **Completed:** 2026-03-27T12:09:01Z
- **Tasks:** 2 (1 checkpoint resolved, 1 auto)
- **Files modified:** 1 (signing migration only; 4 files pre-existed)

## Accomplishments
- Migrated DEVELOPMENT_TEAM from personal (QN58279822) to professional (9B8B36C2FA) across all 6 build configurations
- Verified Privacy Manifests, MARKETING_VERSION 1.2, PRIVACY.md, and REVIEW-CHECKLIST.md all present and correct
- All verification checks passed (zero old Team ID references, valid XML, pbxproj references intact)

## Task Commits

Each task was committed atomically:

1. **Task 1: Get Team ID from Pierre** - checkpoint (no commit, Team ID 9B8B36C2FA received)
2. **Task 2: Signing migration, Privacy Manifests, version bump, privacy policy, and review checklist** - `bcfa646` (chore)

## Files Created/Modified
- `Dictus.xcodeproj/project.pbxproj` - DEVELOPMENT_TEAM updated to 9B8B36C2FA in all 6 build settings
- `DictusApp/PrivacyInfo.xcprivacy` - Privacy Manifest (pre-existing, verified)
- `DictusKeyboard/PrivacyInfo.xcprivacy` - Privacy Manifest (pre-existing, verified)
- `PRIVACY.md` - Bilingual privacy policy (pre-existing, verified)
- `.planning/phases/16-testflight-deployment/REVIEW-CHECKLIST.md` - App Store Review checklist (pre-existing, verified)

## Decisions Made
- Plan estimated 4 DEVELOPMENT_TEAM occurrences but project has 6 (includes DictusWidgets Debug/Release) -- updated all 6 for consistency
- MARKETING_VERSION was already 1.2 from prior work -- no modification needed
- PrivacyInfo.xcprivacy files, PRIVACY.md, and REVIEW-CHECKLIST.md already existed with correct content -- only signing migration was new work

## Deviations from Plan

None - plan executed as written. The pre-existing files (PrivacyInfo, PRIVACY.md, REVIEW-CHECKLIST.md) were verified rather than re-created.

## Issues Encountered
None.

## User Setup Required
None - Apple Developer enrollment was completed by Pierre prior to this execution.

## Next Phase Readiness
- Project is ready to open in Xcode, build, and archive with professional signing
- Privacy Manifests included in both app and keyboard targets
- Version shows 1.2 across all targets
- Ready for Plan 02 (archive and upload to App Store Connect)

---
*Phase: 16-testflight-deployment*
*Completed: 2026-03-27*
