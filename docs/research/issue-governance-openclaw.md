# OpenClaw public issue governance and agent workflow

> Research note only. The canonical Dictus policy is [`docs/ISSUE-GOVERNANCE.md`](../ISSUE-GOVERNANCE.md); recommendations in this note are inputs to that synthesis, not repository rules.

**Research date:** 2026-09-20
**Repository:** `openclaw/openclaw`
**Source snapshot:** default-branch commit `e63393bddc3a3f6748acd8ad873a96a7a3af9702`

## Scope and method

This note uses only first-party OpenClaw GitHub sources: repository documentation, issue forms, labels, public issues, organization projects, milestones, workflows, rulesets, agent skills, and maintainer guidance. File citations are pinned to the inspected commit. Live GitHub surfaces are described as a 2026-09-20 snapshot.

The sections titled **Observed practice** report what the sources explicitly show. Sections titled **Inference for Dictus** are recommendations derived from those observations, not claims about OpenClaw policy.

## Executive summary

OpenClaw treats issue governance as a layered control system rather than a single board:

1. Structured forms and routing rules improve evidence at intake and divert support or security reports away from public issues.[1] [2] [3]
2. Labels encode several independent dimensions: type/component, priority, impact, issue or PR quality, evidence state, automation eligibility, and a human-decision escape hatch.[29]
3. Deterministic automation handles mechanical policy; an AI reviewer analyzes issues and PRs; deterministic code owns mutations; maintainers retain product, security, merge, and release authority.[6] [7] [22]
4. Agent-authored changes are explicitly accepted, but they use the same issue linkage, proof, CI, review, and human judgment as human-authored changes.[1] [4]
5. Roadmap intent is communicated through broad focus areas, labels, and release machinery rather than repository milestones: the repository has no milestones, and the two public organization projects are for the Windows Companion App and ClawHub rather than the core backlog.[1] [11] [12]
6. The strongest reusable pattern for Dictus is not OpenClaw's full label count or automation footprint. It is the separation of **evidence**, **machine recommendation**, **deterministic action**, and **human authority**.

## 1. Issue intake and routing

### Observed practice

- OpenClaw publishes an explicit routing table. Product defects go to the bug form, documentation defects to a docs form, feature or architecture work to a feature request or prior Discord discussion, support questions to Discord, and vulnerabilities to a private security path.[1]
- Blank issues are disabled. The issue chooser exposes Discord links for onboarding and support, reducing non-actionable support traffic in the tracker.[21]
- The bug form enforces one issue per submission and requires a bug subtype, observed summary, deterministic reproduction, expected and actual behavior, exact version, OS, model, provider/routing chain, and impact. It repeatedly tells reporters not to speculate and to write `NOT_ENOUGH_INFO` when evidence is insufficient.[2]
- The docs form similarly requires an affected path or URL, verification steps, expected versus actual content, impact, and evidence.[1]
- The feature form asks for the user problem, proposed solution, alternatives, impact, evidence or prior art, and whether the reporter plans to implement it. The form says that self-implemented features move faster.[3]
- Contribution guidance makes a deliberate asymmetry: bugs and very small fixes may go directly to a PR, while agent-authored or otherwise non-trivial work should create or reuse an issue first. New features and architecture changes should start with an issue or discussion because many proposals are declined or redirected to plugins.[1]
- Reporters are told not to guess whom to tag. Issue forms, labels, automation, and `CODEOWNERS` should route work; direct maintainer mentions are reserved for an owned-path decision.[1]

### Inference for Dictus

Adopt a small, enforced intake contract:

- **Bug:** observed summary, shortest repro, expected/actual, Dictus build, iOS/device, keyboard/app surface, model/backend, impact, redacted evidence.
- **Feature:** problem, affected user, proposed behavior, alternatives, impact, implementation intent.
- **Support:** route away from GitHub unless it reveals a reproducible defect or documentation gap.
- **Security/privacy:** private reporting path, never a public issue.
- Disable blank issues. Require one problem per issue.
- Keep `NOT_ENOUGH_INFO` as a valid answer. It is safer than encouraging reporters or agents to invent context.

## 2. Triage states, priority, and ownership

### Observed practice

OpenClaw's public labels page exposed 366 active labels in the inspected snapshot. The taxonomy is multi-axis rather than one linear status:[29]

| Axis | Examples | Meaning |
| --- | --- | --- |
| Type | `bug`, `bug:crash`, `bug:behavior`, `enhancement`, `docs` | What kind of work it is |
| Surface | `app: ios`, `gateway`, `agents`, channel and extension labels | Where it belongs |
| Priority | `P0`, `P1`, `P2`, `P3` | Emergency through speculative/cleanup |
| Impact | `impact:ux-release-blocker`, `impact:ux-friction`, `impact:security`, `impact:message-loss` | Why the work matters |
| Evidence/readiness | `clawsweeper:source-repro`, `clawsweeper:needs-info`, `clawsweeper:needs-live-repro`, `clawsweeper:fix-shape-clear` | What is known and what proof is missing |
| Automation eligibility | `clawsweeper:queueable-fix`, `clawsweeper:no-new-fix-pr`, `clawsweeper:linked-pr-open` | Whether an automated fix should proceed |
| Human gate | `clawsweeper:needs-maintainer-review`, `clawsweeper:needs-product-decision`, `clawsweeper:needs-security-review`, `clawsweeper:human-review` | Why automation must stop |
| PR state | `status: waiting on author`, `status: needs proof`, `status: ready for maintainer look`, `status: automerge armed` | Who or what acts next |

The priority labels have explicit descriptions: P0 covers emergencies such as data loss, security bypass, crash loops, or unusable core runtime; P1 is a high-priority user-facing bug, regression, or broken workflow; P2 is normal backlog with limited blast radius; P3 is cleanup, docs, polish, ergonomics, or speculative work.[27]

A closed governance proposal, issue #13241, shows how the taxonomy evolved in public. ClawSweeper repeatedly separated machine-observable facts from governance decisions, leaving lifecycle policy, priority authority, cadence, and visible cycle priorities for maintainer judgment. The issue was eventually closed as completed after P0-P3 and ClawSweeper triage labels were present, while acknowledging that some policy remained a maintainer choice.[20]

Maintainer triage instructions impose ownership safeguards:

- Similarity is not proof of duplication.
- An assignment less than six hours old is active ownership; older assignment is a hint rather than an absolute veto.
- Preserve co-assignees.
- Product rejection and out-of-scope decisions remain maintainer judgment.
- For a fixed or superseded issue, verify that current `main` supplies equivalent or better behavior before closing it.[5]

### Inference for Dictus

Do **not** copy 366 labels. Reuse the axes with a much smaller vocabulary:

- **Type:** `bug`, `enhancement`, `docs`.
- **Priority:** `P0` through `P3`, with written semantics.
- **Workflow:** retain Dictus's existing `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`.
- **Evidence:** add at most `reproduced` and `needs-device-proof` if those distinctions repeatedly matter.
- **Surface:** use only stable product boundaries such as `app`, `keyboard-extension`, `speech-model`, and `release`.

Treat workflow labels as answers to concrete questions:

1. Is the report understandable and reproducible?
2. Is the expected behavior already decided?
3. Is implementation safe for an agent?
4. Does a human need to make a product, privacy, App Store, or release decision?
5. Who owns the next action?

Priority should reflect user harm and blast radius, not reporter urgency or implementation size. A short diff can still be high risk; OpenClaw's triage guide explicitly warns against equating small diffs with low risk.[5]

## 3. Roadmap and release goals

### Observed practice

- `CONTRIBUTING.md` names broad current focus areas: channel stability, onboarding/error-message UX, skills via ClawHub, and token/compaction performance.[1]
- The core repository's milestones page shows zero open and zero closed milestones.[11]
- The organization projects page shows two public open projects - Windows Companion App and ClawHub - not a core issue roadmap.[12]
- Therefore, the public issue tracker does not expose release scope through milestones. Priority and focus are visible mainly through labels, contribution guidance, issue discussion, release branches/tags, and release validation workflows.[1] [11] [12]
- Release execution is deliberately separate from ordinary issue priority. Full Release Validation binds exact Validation and Tooling SHAs, distinguishes beta/stable/full profiles, records child evidence, and rejects mismatched source identity. Publishing is a separate mutating workflow with protected release refs and environment approval.[13]
- The release-maintainer instructions require explicit approval for version changes and irreversible publication, distinguish prepare authority from publish authority, prohibit weakening gates to manufacture success, and make the active release - not unrelated work - the work queue.[24]

### Inference for Dictus

Use two planning layers:

1. **Backlog priority** on issues (`P0`-`P3`).
2. **Release target** as a small, explicit field or milestone for the next TestFlight/App Store train.

OpenClaw's absence of core milestones is an observed choice, not evidence that milestones are bad. Dictus is smaller and can benefit from one active release milestone if it stays curated. Keep broad product direction in a short roadmap document, and keep a release milestone narrowly limited to committed scope.

Separate “important” from “ships in this release.” A P1 may miss the train if proof is incomplete; a P2 may be required because it unblocks submission or migration.

## 4. Automation and human decision points

### Observed practice

OpenClaw divides automation into two principal layers:

- **Barnacle** is deterministic GitHub triage. It handles known queue rules such as empty PR bodies, missing evidence, unsupported refactor/test-only changes, unrelated branch content, plugin routing, and the 20-open-PR cap. It can label, comment, or close without executing contributor code.[6] [22]
- **ClawSweeper** is AI-assisted review and maintenance. It reviews issues and PRs, evaluates proof, leaves durable comments, and can enter bounded repair or automerge flows. Its positive result is supporting evidence, never maintainer approval.[6]

The ClawSweeper trust boundary is explicit:

- Model workers do not receive mutation credentials.
- Review workers run with stripped secret/token environments.
- Deterministic scripts own comments, labels, pushes, PR creation, closure, and merge through short-lived GitHub App tokens.
- Write and merge gates default closed.[7]

The dispatch workflow listens to issue, comment, PR, review, and `main` push events. It acknowledges new non-draft PRs, debounces bursts, sends bounded event data to the separate ClawSweeper repository, and routes recognized commands. The trusted target workflow does not check out or execute contributor PR code.[8]

Maintainers can request review, explanation, repair, autofix, automerge, or stop actions. Autofix and automerge are opt-in. Automerge requires a clean review of the exact current head, green checks, GitHub mergeability, a non-draft PR, no human-review label, and open merge gates. If gates are closed, automation marks the PR merge-ready instead of merging.[7]

Human authority remains explicit at several points:

- Product rejection, out-of-scope decisions, and unclear expected behavior.[5]
- Maintainer opt-in for repair/automerge and the ability to stop automation.[7]
- Security-sensitive changes: command approval for external authors plus independent SecOps `CODEOWNERS` review for protected security paths.[1] [14] [15]
- Merge and CI enforcement: active rulesets protect `main`, require the OpenClaw CI gate, dismiss stale code-owner approvals, and protect release refs; the ClawSweeper merge-authorization rule was only in evaluation mode at the snapshot.[16]
- Release preparation versus irreversible publication.[24]

Stale handling is not a single indiscriminate timer:

- Unassigned ordinary issues/PRs are marked stale after 14 inactive days and closed seven days later.
- Assigned issues use 30 days plus ten; assigned PRs use 27 days open plus seven.
- Enhancements, maintainers, pinned/security/no-stale items, bugs, and several ClawSweeper-ready states are exempt from ordinary issue closure.
- Inactive bugs are instead marked for ClawSweeper verification, with an explicit invariant that inactivity alone must not close a bug.
- Closed issues are locked after 48 hours of inactivity.[9]

Duplicate cleanup also shows a safety pattern: the “duplicate after merge” workflow is manual-dispatch, names the already-landed PR and candidate duplicates, and defaults to dry-run until `apply` is explicitly true.[23]

### Inference for Dictus

Implement automation in this order:

1. **Deterministic intake checks:** required fields, duplicate hints, stale policy, label transitions.
2. **Read-only agent assessment:** summarize evidence, reproduce when feasible, recommend priority and next state.
3. **Deterministic state mutation:** a small trusted script applies an allowed transition after validating current issue state.
4. **Human gates:** expected behavior, privacy/security, App Store policy, monetization, destructive migration, merge, and release.

Do not let an LLM directly own labels, closure, or merge credentials. Let it produce a structured recommendation; validate the schema and current SHA/state; let trusted code apply only allowed actions.

For Dictus, stale automation should be modest:

- Never close a confirmed bug only because discussion stopped.
- `needs-info` may close after a warning if the reporter does not respond.
- `ready-for-human` and release-blocking issues should be exempt.
- Dry-run and cap every new bulk automation before enabling mutation.

## 5. Agent-authored development workflow

### Observed practice

OpenClaw explicitly welcomes Codex, Claude, and other AI-assisted PRs without requiring an AI label or disclosure. They are “first-class citizens” but follow the same quality and review standards.[1]

The expected path is:

1. Create or reuse an issue for agent-authored or non-trivial work.[1]
2. Keep the PR narrowly focused and visibly link it with `Closes #…` or `Related: #…`.[1] [4]
3. Keep the PR body durable and current: problem, user impact, why the change was made, and evidence. Do not hide risks, migrations, or evidence gaps.[1] [4]
4. Run local build/check/test gates and surface-specific validation. UI changes require before/after screenshots.[1]
5. When available, run an independent `autoreview` before requesting review and address accepted/actionable findings.[1] [18]
6. Treat bot feedback like normal review feedback. Update the branch, PR description, evidence, and CI before asking for `@clawsweeper re-review`; repeated empty review requests are queue noise.[6]
7. Maintainers still decide readiness and merge timing.[6]

The `autoreview` helper adds useful safeguards: explicit Git scope, isolated reviewers, sanitized authentication, structured JSON validation, source-integrity checks, no partial clean verdict after a failed pass, and result states that distinguish clean, findings, filtered, incorrect, incomplete, and reviewer unavailable. Findings are advice to verify, not instructions to apply blindly.[18]

Repository-level agent instructions reinforce the same pattern: reproduce through the actual entry point when feasible, identify the single owner of behavior, remove competing paths, prove the intended flow, preserve unrelated work, and never treat a pre-existing red test as noise.[17]

### Inference for Dictus

A reusable Dictus issue-to-agent contract could be:

```text
needs-triage
  -> needs-info                missing evidence
  -> ready-for-human           product/privacy/App Store decision
  -> ready-for-agent           expected behavior and acceptance criteria are clear

ready-for-agent
  -> assigned + branch/PR      agent claims current unowned work
  -> ready-for-human           PR has evidence, CI, review summary, and known gaps
  -> needs-info                reproduction or requirements proved insufficient
```

Require the agent to publish a compact evidence record in the PR:

- linked issue and acceptance criteria;
- files/surfaces changed;
- tests actually run and results;
- simulator/device proof and screenshots where applicable;
- review findings accepted, rejected, or unresolved;
- residual risks and unrun checks;
- exact head SHA reviewed.

For iOS, “green unit tests” are not enough for keyboard-extension behavior. Preserve a human/device gate for microphone permissions, keyboard memory constraints, App Group sharing, onboarding, real dictation latency, and App Store-sensitive behavior.

## 6. Validation and release confidence

### Observed practice

OpenClaw separates ordinary PR evidence from release authorization:

- PR evidence can include focused tests, CI, screenshots, recordings, terminal output, live observations, redacted logs, and artifact links.[1] [4]
- Release validation binds immutable source identities and collects independent child workflow results rather than treating one green lane as universal proof.[13]
- Beta, stable, and full profiles have different coverage. Stable/full require broader provider and soak coverage; beta defers some confidence work but keeps release-critical lanes.[13] [25]
- Required failures cannot be waived by success elsewhere. Deferred or omitted checks are not “passed.” Exact-source successful evidence should be reused rather than rerun merely for ceremony.[25]
- A Codex-based release-validation skill may analyze a published tag, but it writes a schema-validated artifact first; a separate trusted publisher downloads and validates that artifact before creating or updating the campaign issue.[19]

### Inference for Dictus

Use a small evidence matrix keyed to change surface:

| Surface | Minimum PR proof | Additional release proof |
| --- | --- | --- |
| Pure docs | docs/build sanity, link check | none |
| Core logic | focused unit tests + relevant suite | clean full test run |
| App UI | tests where meaningful + before/after simulator screenshots | target-device smoke |
| Keyboard extension | focused tests + extension launch/manual flow | real device, memory and permission smoke |
| Speech model/backend | deterministic sample corpus and timing | supported-device performance/accuracy sample |
| Persistence/migration | old-state fixture to new-state proof | upgrade from last public build |
| Privacy/security | threat/privacy review + explicit human approval | release owner sign-off |

Record skipped checks as gaps, not as success. Bind agent review and release evidence to the exact commit being merged or shipped.

## 7. Recommended minimal Dictus model

### Inference for Dictus

The smallest useful adaptation is:

1. **Three issue forms:** bug, feature, docs; blank issues disabled.
2. **Five existing workflow labels:** `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`.
3. **Four priority labels:** P0-P3 with one-sentence definitions.
4. **A few stable surface labels:** app, keyboard extension, speech/model, release.
5. **One trusted triage action:** validate form completeness, suggest duplicates, and move only among allowed workflow states.
6. **One agent execution contract:** only `ready-for-agent`, unassigned or explicitly delegated, issue-linked PR, current body/evidence, exact-head review.
7. **One human merge/release gate:** machine review is advisory; humans own expected behavior, exception decisions, merge, and publishing.
8. **One stale policy:** close abandoned `needs-info`; never inactivity-close confirmed bugs or `ready-for-human` work.
9. **One release milestone at a time:** unlike OpenClaw's public core tracker, Dictus can use a milestone because the smaller team benefits from explicit near-term scope.

## 8. What not to copy

### Inference for Dictus

- Do not copy OpenClaw's label volume. Its taxonomy reflects a very large, multi-platform repository and extensive automation.
- Do not introduce ratings, playful status names, or many overlapping readiness labels until a real queue-management problem requires them.
- Do not build AI automerge first. Start with read-only triage and structured evidence.
- Do not use stale closure to compensate for unclear ownership or missing prioritization.
- Do not conflate issue priority, agent readiness, PR readiness, and release inclusion; they answer different questions.
- Do not let a model's confident prose bypass a missing reproduction, current-state check, trusted mutation path, or human product decision.

## Bottom line

OpenClaw's reusable governance pattern is a chain of custody:

> structured evidence at intake → explicit issue state → bounded agent analysis → deterministic mutation → exact-head validation → human merge/release authority

For Dictus, the value lies in preserving those boundaries with a small label set and a simple workflow, not reproducing OpenClaw's scale.

## Sources

[1]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/CONTRIBUTING.md "OpenClaw CONTRIBUTING.md"
[2]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.github/ISSUE_TEMPLATE/bug_report.yml "OpenClaw bug issue form"
[3]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.github/ISSUE_TEMPLATE/feature_request.yml "OpenClaw feature request form"
[4]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.github/pull_request_template.md "OpenClaw pull request template"
[5]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.agents/skills/openclaw-pr-maintainer/references/triage.md "OpenClaw maintainer triage reference"
[6]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/docs/reference/pull-request-review-flow.md "OpenClaw pull request review flow"
[7]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.agents/skills/clawsweeper/SKILL.md "OpenClaw ClawSweeper skill"
[8]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.github/workflows/clawsweeper-dispatch.yml "OpenClaw ClawSweeper dispatch workflow"
[9]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.github/workflows/stale.yml "OpenClaw stale workflow"
[11]: https://github.com/openclaw/openclaw/milestones "OpenClaw milestones"
[12]: https://github.com/orgs/openclaw/projects "OpenClaw organization projects"
[13]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/docs/ci/release-validation/full-release-validation.md "OpenClaw full release validation"
[14]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.github/CODEOWNERS "OpenClaw CODEOWNERS"
[15]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.github/workflows/security-review.yml "OpenClaw security review workflow"
[16]: https://api.github.com/repos/openclaw/openclaw/rulesets "OpenClaw repository rulesets API"
[17]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/AGENTS.md "OpenClaw AGENTS.md"
[18]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.agents/skills/autoreview/SKILL.md "OpenClaw autoreview skill"
[19]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.github/workflows/release-validation-skill-runner.yml "OpenClaw release validation skill runner"
[20]: https://github.com/openclaw/openclaw/issues/13241 "OpenClaw issue #13241: issue triage and priority framework"
[21]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.github/ISSUE_TEMPLATE/config.yml "OpenClaw issue template configuration"
[22]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.github/workflows/auto-response.yml "OpenClaw Barnacle auto-response workflow"
[23]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.github/workflows/duplicate-after-merge.yml "OpenClaw duplicate PR after merge workflow"
[24]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.agents/skills/release-openclaw-maintainer/SKILL.md "OpenClaw release maintainer skill"
[25]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.agents/skills/release-openclaw-maintainer/references/validation.md "OpenClaw release validation and confidence reference"
[27]: https://api.github.com/repos/openclaw/openclaw/labels?per_page=100&page=3 "OpenClaw labels API (page 3)"
[29]: https://github.com/openclaw/openclaw/labels "OpenClaw labels"
