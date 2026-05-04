# Versioning — Dictus

How we number releases and tags. Complements [GIT_WORKFLOW.md](GIT_WORKFLOW.md).

## TL;DR

- One version line: `X.Y.Z` — [Semantic Versioning](https://semver.org/).
- No `-beta.N` suffix. TestFlight = our current distribution channel, not a sematic status.
- Each tag is a full release. If we promote a TestFlight build to App Store later, it's the **same build** (same tag, same `CFBundleVersion`).
- `CFBundleVersion` (Apple build number) always increments; never resets.

## When to bump each digit

| Bump | When | Example |
| --- | --- | --- |
| **PATCH** `X.Y.Z → X.Y.(Z+1)` | Bug fix, polish, perf tweak, no new user-facing feature | Fix #134 keyboard freeze → `1.6.1` |
| **MINOR** `X.Y.Z → X.(Y+1).0` | New user-facing feature, new supported language, new model in catalog | German layout → `1.7.0` |
| **MAJOR** `X.Y.Z → (X+1).0.0` | First public App Store release, premium launch, breaking UX shift | App Store public → `2.0.0` |

Rule of thumb: **ask "does a returning user notice something new?"** — if yes → MINOR at least. If they just notice things work better → PATCH.

## `CFBundleVersion` (Apple build number)

- Incremented on **every** TestFlight upload, even if `X.Y.Z` doesn't change (re-upload after an entitlement tweak, etc.).
- Never resets. `1 → 2 → 3 → ... → 13 → 14 → ...` regardless of the marketing version jump.
- Same build number across all three targets (App / Keyboard / Widgets) — automated bump covers them all.

## What shipped so far (historical — do not rewrite)

| Tag | `CFBundleShortVersionString` | `CFBundleVersion` | Notes |
| --- | --- | --- | --- |
| `v1.6.0-beta.1` → `v1.6.0-beta.4` | `1.6.0` (frozen across 4 betas) | 10 → 11 → 12 → 13 | Pre-switch-to-semver. Kept as-is for TestFlight release-note continuity. |

Next tag onward follows the rules below — we do **not** retro-rename `beta.1–4`.

## The next tag

Heuristic:

1. Since `v1.6.0-beta.4`, is the incoming change a fix-only patch?
   - Yes → `v1.6.1` (first clean-numbering patch after beta line).
   - No → step 2.
2. Is it a notable new feature (German layout, new model, visible UX)?
   - Yes → `v1.7.0`.
   - No → re-classify — probably patch.
3. Is it App Store public launch or premium launch?
   - Yes → `v2.0.0`.

Planned near-term:
- **`v1.7.0`** — German keyboard layout (new feature → MINOR).
- Fix #134 (retain cycle) will likely land inside `v1.7.0` alongside other work, not a standalone patch, unless it ships first on its own.

## TestFlight vs. App Store (Option A)

We use a **single distribution line**. There is no `-beta` parallel to a stable version.

```
develop ───┬──> TestFlight (internal)
           │
main ──────┴──> TestFlight (external, when we have it)
                └──> App Store (same build, promoted when validated)
```

- `develop` builds go to internal testers as they're uploaded.
- When a build is stabilised and we want public release, we merge `develop → main`, tag `vX.Y.Z`, and **that same archive** is the one we submit to App Store review.
- No "rebuild for production" — the tested bits are the shipped bits.

This keeps version numbers honest: `v1.6.1` on TestFlight = `v1.6.1` on App Store. No `.beta` suffix to strip.

## Release checklist

When `develop` is ready to ship:

1. Decide the tag per the heuristic above.
2. Bump `CFBundleShortVersionString` in all three Info.plists (App / Keyboard / Widgets) to the new `X.Y.Z`.
3. Bump `CFBundleVersion` by one across all three plists.
4. Commit: `chore: bump to X.Y.Z (build N)`.
5. Open PR `develop → main`, merge.
6. `git checkout main && git pull`.
7. `git tag -a vX.Y.Z -m "vX.Y.Z — short one-liner"` + `git push origin vX.Y.Z`.
8. Archive in Xcode, upload to App Store Connect.
9. Once accepted for TestFlight: `gh release create vX.Y.Z --title "..." --notes "..."` (use `--prerelease` only if the build is not intended for external TestFlight / App Store).
10. Merge `main → develop` to keep branches in sync.
11. **Sync `main` into `feature/premium`** — open a `sync/main-to-premium-vX.Y.Z` branch from `feature/premium`, `git merge origin/main --no-ff`, resolve any `.planning/` conflicts in favour of premium (`--ours`), open a PR into `feature/premium`, merge with `--merge` (never squash). Required as long as `feature/premium` is an active long-lived branch — drop this step if/when premium is retired or merged.

## Release-notes naming (GitHub + TestFlight)

- GitHub release title: `vX.Y.Z — short summary` (e.g. `v1.7.0 — German layout + keyboard stability fix`).
- TestFlight "What to Test" notes: user-facing bullets, English, no internal jargon, no issue numbers that testers can't click. Keep internal technical notes for the GitHub release body.

## Common mistakes to avoid

- ❌ Re-using a version number for a re-upload — always bump `CFBundleVersion` at minimum.
- ❌ Adding `-beta.N` to a new tag — obsolete convention, drops for all tags from `v1.6.1` onward.
- ❌ Letting `CFBundleVersion` drift between targets (App=13, Keyboard=11, Widgets=12 style) — always bump all three together.
- ❌ Tagging before the merge lands on `main` — the tag should point to a commit that is reachable from `main`.
