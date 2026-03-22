# Git & Release Workflow — Dictus

Guide for managing branches, releases, and TestFlight/App Store distribution.

## Branch strategy

```
main (production)              <- App Store + TestFlight public
  |
  +-- develop                  <- Daily integration, internal TestFlight builds
  |     |
  |     +-- feature/xxx       <- New feature (one branch per feature/issue)
  |     +-- fix/xxx           <- Bug fix
  |     +-- chore/xxx         <- Maintenance, refactoring, docs
  |
  +-- release/x.y.z           <- Release preparation (freeze, QA, bugfix only)
  |
  +-- hotfix/xxx               <- Critical production fix (branches from main)
```

## Branch roles

| Branch | Purpose | Who merges here | TestFlight | App Store |
|---|---|---|---|---|
| `main` | Stable production code | release/* and hotfix/* only | Public beta | Yes |
| `develop` | Integration of ongoing work | feature/*, fix/*, chore/* | Internal testing | No |
| `feature/*` | Single feature development | Developer (PR to develop) | No | No |
| `fix/*` | Bug fix | Developer (PR to develop) | No | No |
| `release/x.y.z` | Pre-release freeze & QA | Bugfixes only (no new features) | QA testing | When ready |
| `hotfix/*` | Critical fix on production | Developer (PR to main) | If needed | Yes |

## Workflow: Feature development

```
1. git checkout develop
2. git pull origin develop
3. git checkout -b feature/my-feature
4. ... work, commit frequently ...
5. Push + open PR to develop
6. Code review (if applicable) + merge
```

## Workflow: Preparing a release

```
1. develop is stable and ready
2. git checkout develop
3. git checkout -b release/1.2.0
4. Bump version number in Xcode (CFBundleShortVersionString)
5. Bump build number (CFBundleVersion)
6. QA testing on this branch — only bugfixes allowed, no new features
7. Fix any issues directly on release/1.2.0
8. When ready:
   a. Merge release/1.2.0 into main
   b. Tag: git tag v1.2.0
   c. Merge main back into develop (to sync bugfixes)
   d. Delete release/1.2.0
```

## Workflow: Hotfix (critical production bug)

```
1. git checkout main
2. git checkout -b hotfix/fix-crash
3. Fix the issue
4. Merge into main + tag (v1.2.1)
5. Merge main back into develop
6. Delete hotfix branch
```

## Version numbering

We follow [Semantic Versioning](https://semver.org/):

```
MAJOR.MINOR.PATCH

1.0.0  — First App Store release
1.1.0  — New feature added (e.g., custom vocabulary)
1.1.1  — Bug fix on 1.1.0
2.0.0  — Major breaking change (rare for mobile apps)
```

**Xcode specifics:**
- `CFBundleShortVersionString` = marketing version (1.2.0) — shown to users
- `CFBundleVersion` = build number (1, 2, 3...) — must increment for every TestFlight upload
- Build number resets are allowed per marketing version but keeping it incrementing is simpler

## TestFlight distribution

TestFlight has two tester groups:

### Internal testing (up to 100 testers)
- Team members only (requires App Store Connect access)
- No Apple review needed
- Builds available immediately after processing
- Use for: daily develop builds, quick iteration

### External testing (up to 10,000 testers)
- Public link, anyone can join
- Requires Apple Beta App Review (lighter than full review, usually < 24h)
- Use for: public beta from main or release/* branches
- Builds expire after 90 days

### Recommended TestFlight setup for Dictus

| Group | Source branch | Purpose |
|---|---|---|
| Internal — Dev team | `develop` | Latest features, may be unstable |
| External — Beta testers | `main` or `release/*` | Stable builds for public testing |

## App Store submission

```
1. main is tagged with vX.Y.Z
2. Archive in Xcode: Product > Archive
3. Upload to App Store Connect
4. Fill in release notes, screenshots, metadata
5. Submit for review (usually 24-48h)
6. Once approved: release manually or set auto-release
```

## Commit message convention

Format: `type: short description`

```
feat: add custom vocabulary import
fix: resolve crash on long dictation
chore: bump WhisperKit to 0.17.0
refactor: extract SubscriptionManager to DictusCore
docs: update release workflow guide
```

Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `style`, `perf`

## Current phase (pre-release)

While waiting for Apple Developer enrollment:

```
main          <- Single stable branch (current setup)
  |
  +-- feature/*   <- Feature branches as needed
```

Once the Developer account is active:
1. Create `develop` from `main`
2. Start working on `develop`
3. `main` becomes the production branch
4. Set up TestFlight internal + external groups

## Quick reference

```bash
# Start a new feature
git checkout develop && git pull
git checkout -b feature/my-feature

# Finish a feature
git push -u origin feature/my-feature
# Open PR to develop on GitHub

# Start a release
git checkout develop && git pull
git checkout -b release/1.2.0

# Ship the release
git checkout main && git merge release/1.2.0
git tag v1.2.0 && git push origin main --tags
git checkout develop && git merge main
git branch -d release/1.2.0

# Emergency hotfix
git checkout main && git pull
git checkout -b hotfix/fix-crash
# ... fix, commit ...
git checkout main && git merge hotfix/fix-crash
git tag v1.2.1 && git push origin main --tags
git checkout develop && git merge main
```
