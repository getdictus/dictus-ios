---
phase: 16-testflight-deployment
plan: 03
status: complete
started: 2026-03-27
completed: 2026-03-27
requirements: [TF-03, TF-04, TF-09]
---

# Plan 16-03 Summary: Archive, Upload & TestFlight Distribution

## Objective

Archive the app, upload to App Store Connect, distribute via TestFlight.

## What was built

**TestFlight private beta is live.** Build 1.2 (1) uploaded and available to internal testers.

## Key decisions

- **Private beta only** (no public TestFlight link) — Pierre wants to rework the keyboard before going public
- **App Group migrated** from `group.com.pivi.dictus` to `group.solutions.pivi.dictus` (old ID taken by personal team)
- **App icons alpha channel removed** — App Store Connect rejects icons with transparency
- **CFBundleDisplayName added** to DictusWidgets Info.plist (required by App Store Connect)
- **No encryption compliance** — Dictus uses no custom encryption (ML only)
- **Versioning strategy documented** in DEVELOPMENT.md — semantic versioning + git tags

## Deviations from plan

- Plan expected public TestFlight link + README update — deferred (Pierre's decision)
- Plan expected 4 DEVELOPMENT_TEAM entries — actually 6 (includes DictusWidgets)
- App Group migration was unplanned — required because old ID was claimed by personal team
- Two upload attempts: first rejected (icon alpha + missing CFBundleDisplayName), second succeeded

## Artifacts

- TestFlight build: 1.2 (1) on App Store Connect
- Git tag: `v1.2.0-beta.1`
- Internal testing group: "Team PIVI" (2 testers)
- App Store Connect app ID: 6761262378

## Commits

- `b5fffe8` chore(16): migrate App Group
- `da98f0a` chore(16): update URLs
- `11ff932` chore(16): Xcode project sync
- `9d7e397` fix(16): remove alpha channel, add CFBundleDisplayName
- `ba5b028` docs(16): add versioning strategy
