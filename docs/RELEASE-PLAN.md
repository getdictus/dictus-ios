# Release plan — Dictus

What ships next, and why. Complements [VERSIONING.md](VERSIONING.md), which says *how* to number a release; this file says *what* the current and next cycles are.

**Scope.** One page. It holds decisions that no issue owns and that the code cannot show. It does not list work in order — that is [ROADMAP.md](ROADMAP.md), which holds the ordered queue and points back here for the reasoning. When a decision here is superseded, edit the line rather than appending, so the file never becomes a log. Git history keeps the record.

Last reviewed: 2026-10-22.

## Where things stand

| | |
| --- | --- |
| App Store | **1.9.0 (build 36)**, released 2026-09-24 with a phased rollout, tag `v1.9.0` |
| Current cycle | **2.0.0**, the Dictus Pro launch. No 2.0.0 build cut yet: `develop` still says 1.9.0 (36) |
| Gate | The open lines of [ROADMAP.md](ROADMAP.md) "Now": #512 step 2, #279 the flip |
| `PremiumFlags.paywallVisible` | `true` on `develop` since PR #776 (2026-10-24, refs #279) |

What shipped since the last review, one line each (the detail is on the issues and in git history):

- **1.8.1 (29)**, 2026-09-06: the Turbo preparation fixes (#405, #406, #428). Build 28 was abandoned (#460); build numbers never repeat.
- **1.8.2 (30)**, cut 2026-09-07, tag `v1.8.2` and GitHub Release on 2026-09-14: the bug backlog (#483, #459, #515, #417, #492, #438).
- **1.9.0 (36)**, 2026-09-24: auto-return to the source app (#23), Nemotron 3.5 for French (#558), and two fixes on that path: a cold-start dictation lost while the model compiles (#542) and auto-return resolving nothing ~20 % of the time (#543). Written as a 1.8.3 patch, cut as a MINOR on 2026-09-16 because a new engine and a feature a returning user notices are both MINOR in [VERSIONING.md](VERSIONING.md). Builds 31 and 32 never uploaded (package resolution, PR #566); 33 to 36 were successive TestFlight builds of the same 1.9.0.

## The two surfaces are not the same audience

This is the rule the rest of the plan follows from.

**TestFlight is where the product is built.** Its ~190 testers signed up to watch that happen. Unfinished Pro surfaces, greyed features and rough edges are the point, not a leak. StoreKit runs in sandbox there, so the paywall and the purchase flow can be exercised end to end, for real, before Apple ever sees them.

**The App Store is what has been announced.** It shows only what Dictus is prepared to claim publicly. The product page currently sells an app that is free, open source, and asks for no account. Until monetisation is announced deliberately, nothing on that surface may say otherwise. A user who long-presses the mic and reads "Dictus Pro" learns of a business model before its author has stated it, and the App Store page carries the reviews that mistake would cost.

`PremiumFlags.paywallVisible` is the valve between the two. One constant decides whether the product looks free or freemium, and it is the gate every Pro entry point must consult. #460 exists because the Smart Mode fan does not.

## 2.0.0 — the Pro launch

MAJOR, per VERSIONING.md's own table: *premium launch, breaking UX shift*. The version is set once, by the first `scripts/cut-testflight.sh 2.0.0`, and then stays frozen across every TestFlight build of the campaign; only the build number moves.

**1.9.0 shipped between 1.8.2 and 2.0.0**, decided by Pierre on 2026-09-14. That decision replaced the earlier line "no App Store release between 1.8.2 and 2.0.0". 1.9.0 carries the one-version Parakeet migration resource that 2.0.0 removes (#769).

How the campaign runs:

- Pro work stays on `develop`. **No long-lived Pro branch**: `feature/premium` was tried and cost merge pain no solo maintainer should pay twice.
- TestFlight builds go out as the work lands, not once at the end. Testers exercising a half-built paywall in sandbox is the cheapest bug-finding available.
- `paywallVisible` flips to `true` in #279's PR, the one that walks every Pro entry point. That is the PR that turns this cycle into a MAJOR.
- A `#if DEBUG` entitlement override lets Pro features be tested on device while the flag is down (#460). It must not exist in a Release build.

**Scope is the ordered list in [ROADMAP.md](ROADMAP.md) "Now".** Two decisions changed it since 2026-09-05, when it was first fixed:

- **The onboarding rebuild is in the gate.** #450 was descoped out of the launch on 2026-09-05; on 2026-10-04 Pierre merged #450, #494 and #451 into #649, one onboarding rebuild that gates 2.0.0. Its sub-issues #675-#686 are closed; its acceptance criteria are audited before the cut.
- **The 2.0.0 App Store listing is ready, not uploaded.** #643 produced the screenshots and copy for en-GB, fr-FR, de-DE and es-ES (PR #645), with slide 1 redrawn in #758 (PR #759). They go to App Store Connect with the 2.0.0 submission, and they describe Pro and the trial, so they ship only with #279.

Open, to settle before the flag flips: the last day of the lifetime founder window in `PremiumFlags` (#350), which depends on a release date that does not exist yet.

## Standing rules

- **Every App Store release goes out phased.** Decided 2026-09-06, after 1.8.1 became the first one that did; 1.7.1, 1.7.2 and 1.8.0 all went to everyone at once. The reason is that Apple has no rollback — a shipped version cannot be withdrawn, and pausing a rollout only stops it spreading further, it takes nothing back from anyone who already has it. Limiting exposure is the only protection that exists. It costs no user the fix, because phasing governs *automatic* updates only: a manual update from the product page, and every new install, get the latest build on day one regardless. Create it before releasing (`asc versions phased-release create --version-id <id> --state INACTIVE`), then `--state COMPLETE` to finish early once the release looks safe.
- Never cut a TestFlight build while an App Store version of the same marketing version is awaiting review. A rejection ships as the same version plus the next build.
- Read the App Store product page *before* `review submit`, never after. A released version rejects an edit to its description or keywords at the API, so a wrong sentence cannot be corrected on its own schedule — it waits for a submission that exists for another reason. 1.8.1 shipped one for exactly this reason (#488).
- The archive is pinned by `build/N`, never by a branch tip. `promote-to-appstore.sh N` enforces this; do not work around it.
- App Store screenshots and listing copy are version-scoped like the description: the 2.0.0 set (#643) is uploaded with the 2.0.0 submission, not before.
