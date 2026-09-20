# Issue governance patterns from large open-source repositories

> Research note only. The canonical Dictus policy is [`docs/ISSUE-GOVERNANCE.md`](../ISSUE-GOVERNANCE.md); recommendations in this note are inputs to that synthesis, not repository rules.

## Purpose and method

This note compares Kubernetes, Home Assistant Core, and VS Code using only first-party contributor documentation, repository configuration, GitHub metadata, templates, and workflows. The goal is not to copy their scale-specific machinery; it is to identify the smallest governance patterns that would make Dictus issues clearer, more actionable, and easier for humans or agents to pick up.

## Executive synthesis

The three projects separate **classification**, **decision state**, **priority**, **ownership**, and **delivery timing** instead of asking one label to express everything. Kubernetes makes those dimensions explicit with label families; VS Code combines type/area labels with milestones that encode acceptance and scheduling; Home Assistant relies more on component ownership, waiting states, issue forms, and automated maintenance.[1] [12] [16]

The strongest reusable pattern is a visible intake funnel:

1. capture enough evidence with a structured form;
2. classify the issue;
3. decide whether it is accepted, waiting on the reporter, waiting on a maintainer, or closed with a reason;
4. assign priority only after acceptance;
5. move accepted work into a release or short execution queue;
6. require tests and human review before merge.

For Dictus, this can be implemented with roughly a dozen labels, one current-release milestone, saved GitHub searches, and two conservative automations. A project board is optional until concurrent work makes a milestone insufficient.

## Comparison at a glance

| Dimension | Kubernetes | Home Assistant Core | VS Code | Small-project lesson |
|---|---|---|---|---|
| Intake | New issues automatically receive `needs-triage`; triagers replace it with an outcome such as `triage/accepted`.[1] | A required bug form asks for problem, versions, installation type, integration, diagnostics, configuration, logs, and extra context; feature ideas are routed to Discussions.[6] [7] | Triage is shared by an inbox tracker, area owners, and a bot, with a stated goal of making the outcome legible to reporters.[16] | Require reproducibility facts at filing time and keep one explicit untriaged state. |
| Taxonomy | Namespaced families distinguish `kind/*`, `area/*`, `sig/*`, `priority/*`, `triage/*`, and `lifecycle/*`.[1] [4] | Labels mix type, component/integration, workflow (`in progress`, `needs-more-information`, `waiting-for-*`), contribution readiness, and merge signals.[12] | Every issue should have a type and feature-area label; special labels cover closure reasons, importance, contribution readiness, planning, and test plans.[16] [19] | Keep dimensions separate, but do not reproduce hundreds of area labels. |
| Priority / severity | Five priority levels range from `critical-urgent` through `important-*` and `backlog` to `awaiting-more-evidence`, with operational definitions.[1] | The public taxonomy does not expose a comparably formal issue-priority ladder; prioritization is more contextual, while PR review favors bug fixes, code quality, small changes, and tests over new features.[9] [12] | `important` is reserved for data loss, extension breakage, critical security/performance, or unusable UI; milestones then determine when accepted work is scheduled.[16] [17] | Use a short impact ladder and keep scheduling separate from severity. |
| Human-decision states | `triage/needs-information`, `triage/not-reproducible`, `triage/duplicate`, `triage/unresolved`, and `triage/accepted` encode decisions.[1] [4] | `needs-more-information`, `waiting-for-reply`, `waiting-for-diagnostics`, `waiting-for-test-hardware`, and `waiting-for-upstream` identify who or what must unblock work.[12] | `needs more info`, `under-discussion`, `Backlog Candidates`, `Backlog`, and closure labels such as `*out-of-scope` make uncertainty and rejection explicit.[16] | Dictus should distinguish “waiting on reporter” from “needs maintainer/product decision.” |
| Planning | Release milestones and project boards are used for release tracking; issue priority is still represented independently.[1] [5] | Open milestones are primarily release-oriented, and the review guide says maintainers tag hotfixes with the next patch milestone.[9] [13] | `Backlog Candidates`, `Backlog`, `On Deck`, and numbered release milestones form a progression from community review to acceptance to scheduling.[16] [20] | A milestone should mean delivery intent, not merely “accepted someday.” |
| Stale handling | At 90 days without activity, automation applies `lifecycle/stale`; `lifecycle/frozen` exempts durable issues, and inactive items can eventually close.[1] | Issues become stale after 90 days and close 7 days later; `no-stale` and `help-wanted` are exempt, and new activity removes staleness. PRs use a separate 60-day threshold.[8] | Missing-information issues close after 7 days; `Backlog Candidates` close after 60 days unless they gain enough community support to move to `Backlog`.[16] | Timeouts should target explicit waiting states and include exemptions, not indiscriminately close the whole backlog. |
| Ownership | SIG labels assign organizational ownership; directory `OWNERS` files distinguish reviewers from approvers and drive automatic reviewer selection.[1] [3] | A generated `CODEOWNERS` file requests reviewers based on touched components and tests; bots are expected to notify appropriate reviewers.[9] [11] | Feature-area labels route issues, and contributors are told to coordinate before working on significant or already-scheduled issues.[16] [18] | Use CODEOWNERS for risky paths and one domain label per issue; do not create a committee structure. |
| Automation | Bots apply labels from comment commands, assign reviewers, run presubmits, enforce required/blocking labels, and merge through Tide only after tests and approvals.[2] [3] | Automation handles stale cleanup, draft conversion after requested changes, code-owner routing, and candidate duplicate suggestions; the duplicate workflow only comments and applies `potential-duplicate`, leaving confirmation to humans.[8] [9] [14] | Bots apply canned triage outcomes, monitor information requests and candidate backlogs, while PR workflows run compile/hygiene and broad platform test jobs.[16] [21] | Automate reminders, routing, and checks; keep scope, priority, duplicate, and close decisions human-confirmed. |
| Merge / test gates | Merge requires CLA, passing end-to-end/presubmit tests, reviewer `lgtm`, owner approval, and absence of blocking labels such as hold or rebase-needed.[2] [3] | Contributors must test and watch CI; the PR template states tests must pass, requests tests for new behavior, and captures breaking change/docs/dependency obligations.[10] [15] | PRs must be associated with an issue and explain how to test; contribution guidance emphasizes accepted issues and coordination, while the PR workflow runs compile, hygiene, lint/type checks, and OS-specific test suites.[18] [21] [22] | Require a linked issue, green CI, one human approval, and regression tests for fixes. |

## Repository findings

### Kubernetes: orthogonal labels and explicit gates

Kubernetes has the clearest formal model. Intake starts with `needs-triage`; triage then establishes kind, priority, and SIG ownership, with acceptance represented separately by `triage/accepted`.[1] This avoids a common failure mode where “bug,” “urgent,” “owned,” and “ready” are conflated.

Its five-level priority ladder is useful because each level describes an expected response: `critical-urgent` means active, top-priority work before the next release; `important-soon` should be staffed soon; `important-longterm` can span releases; `backlog` is desirable but unstaffed; and `awaiting-more-evidence` preserves plausible ideas without pretending commitment.[1] The transferable principle is not the number of labels but the explicit contract behind each one.

Kubernetes also separates issue governance from merge authority. `OWNERS` identifies reviewers and approvers by code area; automation suggests reviewers, but merge requires the configured approval labels, no blocking labels, and passing presubmits.[2] [3] Dictus does not need two formal reviewer classes, but it should preserve the underlying rule: issue acceptance is not merge approval, and CI is necessary but not sufficient.

**Do not copy:** SIG hierarchies, comment-command infrastructure, five priority levels, or a merge pool. They solve scale and permission constraints that a small iOS repository does not have.

### Home Assistant Core: evidence-first intake and ownership routing

Home Assistant’s issue form front-loads evidence. It distinguishes bugs from feature suggestions and requires environment/version fields while prompting for diagnostics, configuration, logs, and the responsible integration.[6] [7] This is especially relevant to Dictus because keyboard-extension failures, transcription failures, device/model differences, and privacy/permission failures need different reproduction data.

Its workflow vocabulary is operational rather than abstract: labels such as `waiting-for-diagnostics`, `waiting-for-reply`, `waiting-for-test-hardware`, and `waiting-for-upstream` identify the blocker, while `easy-fix`, `good first issue`, and `help-wanted` identify contribution readiness.[12] The generated CODEOWNERS file then routes code review to owners of the touched subsystem and its tests.[11]

Home Assistant uses narrow, transparent automation. Its stale workflow treats issues and PRs differently, exempts intentionally durable or community-ready work, and gives a warning window.[8] Its duplicate detector narrows candidates by integration and recency, then posts suggestions under `potential-duplicate` rather than silently closing an issue.[14] That is a good boundary for agentic automation: retrieval and recommendation are automated; consequential judgment remains human.

**Do not copy:** one label per integration, aggressive repository-wide duplicate AI, or a blanket stale policy from day one. Dictus has only a few meaningful domains and likely lacks enough issue volume to justify these systems.

### VS Code: acceptance and scheduling encoded by milestones

VS Code’s distinctive idea is that a milestone communicates product intent. `Backlog Candidates` means the team has not accepted the work and is waiting for community signal; `Backlog` means the team favors the work but has not scheduled it; `On Deck` is a sparse short list; numbered milestones mean scheduled release work.[16] [20] This makes “open” far less ambiguous.

The model is paired with disciplined closure reasons (`*duplicate`, `*as-designed`, `*not-reproducible`, `*out-of-scope`, questions, upstream) and an `under-discussion` state for unresolved classification.[16] [19]

The single `important` label is reserved for severe impact rather than being applied to anything popular.[16] Monthly planning then assigns accepted work to release milestones, adds explicit plan/test-plan items, and handles critical bugs during an endgame phase.[17]

VS Code also uses bounded community signals: candidate feature requests can graduate after sufficient reactions, but otherwise close after a defined review period.[16] Dictus should borrow the visible “candidate versus accepted” distinction, but not hard-code a vote threshold until it has enough users for reactions to be meaningful.

**Do not copy:** monthly endgame bureaucracy, separate plan-item/testplan-item issues for ordinary changes, or popularity as an automatic priority signal.

## Recommended lightweight model for Dictus

### 1. Keep five independent dimensions

Retain the existing canonical workflow labels - `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix` - and add only labels that answer a different question:

- **Type:** `bug`, `feature`, `maintenance`, `documentation`
- **Impact:** `priority/critical`, `priority/high`, `priority/normal`
- **Domain:** `keyboard-extension`, `transcription-models`, `app-settings`, `privacy-permissions`, `build-release`
- **Resolution reason:** `duplicate`, `not-reproducible`, `out-of-scope`, `upstream`
- **Lifecycle exception:** `no-stale`

Avoid adding a priority label during raw intake. First establish reproducibility and acceptance. “Critical” should be reserved for data loss/privacy exposure, a release/build blocker, or the keyboard being unusable for a broad set of users - the same discipline seen in Kubernetes and VS Code.[1] [16]

### 2. Define a small state machine

Use one primary workflow state at a time:

```text
new -> needs-triage
needs-triage -> needs-info | ready-for-human | ready-for-agent | closed(reason)
needs-info -> needs-triage (reporter replied) | closed(not-reproducible)
ready-for-human -> ready-for-agent | milestone/current-release | closed(wontfix/out-of-scope)
ready-for-agent -> in-progress/assigned -> PR -> done
```

`ready-for-human` should mean a product, UX, privacy, architecture, or release decision is required - not merely that an agent has failed. `ready-for-agent` should mean scope and acceptance criteria are clear, affected files are reasonably bounded, and a verifier/test strategy is stated. This mirrors the large projects’ separation of evidence, acceptance, ownership, and execution without importing their organizational hierarchy.[1] [12] [16]

### 3. Use milestones sparingly

Create only:

- a **current release** milestone for committed work;
- optionally **next release** when planning genuinely spans two versions.

Leave accepted but unscheduled work without a milestone and query it through `ready-for-agent` / `ready-for-human`. Do not use a milestone as a generic backlog container unless Dictus needs the VS Code-style distinction between candidate and accepted work.[16] [20]

Add a GitHub Project only when the team needs cross-issue views such as Inbox → Deciding → Ready → In progress → In review → Done. Until then, labels plus a milestone and saved searches are cheaper and less likely to drift.

### 4. Automate only deterministic transitions first

Recommended first automations:

1. **Needs-info reminder:** after 7 days, comment once; after 14 days with no reporter response, close with `not-reproducible` or return to triage. Reopening on new evidence must be easy. VS Code’s seven-day window proves the pattern, while Dictus can choose a more forgiving total window.[16]
2. **Stale review:** after 60–90 days, flag only `needs-triage`, `needs-info`, or abandoned `in-progress` work for human review. Exempt `priority/critical`, `no-stale`, `ready-for-agent`, current milestones, and issues with linked open PRs. Kubernetes and Home Assistant both use explicit lifecycle exemptions.[1] [8]

Later, automation may suggest duplicates or domain labels, but it should not close issues, assign priority, or declare `wontfix` without human confirmation. Home Assistant’s suggestion-only duplicate workflow is the safer precedent.[14]

### 5. Establish simple merge gates

For non-trivial PRs require:

- a linked accepted issue;
- green build/test/lint checks;
- one human approval;
- a regression test for bug fixes when practical;
- explicit manual verification steps for keyboard-extension behavior that CI cannot exercise;
- privacy/security review for microphone, App Group, analytics, model-download, or network changes;
- updated user-facing docs or release notes for behavior changes.

These gates preserve the common core of all three projects: issue traceability, automated checks, domain-aware human review, and proof of behavior.[2] [15] [21]

## Suggested recurring triage routine

A 20-minute weekly pass is enough initially:

1. Open the `needs-triage` saved search, oldest first.
2. Confirm type and one domain.
3. Request missing evidence or reproduce the bug.
4. Record a human decision: close with reason, `ready-for-human`, or accepted.
5. Add impact only to accepted bugs.
6. Add the current milestone only when there is credible delivery intent.
7. Make agent-ready issues executable by adding acceptance criteria, likely files/subsystems, test expectations, and explicit non-goals.
8. Review stalled assignees and linked PRs before any stale action.

This follows Kubernetes’ advice to triage frequently in small batches and VS Code’s emphasis on making the expected outcome clear, while remaining proportionate to a small iOS project.[1] [16]

## Adoption order

1. Document label definitions and mutual exclusions.
2. Upgrade bug/feature forms with Dictus-specific evidence fields.
3. Create saved searches for intake, human decisions, agent-ready work, current release, and waiting-on-reporter.
4. Define the weekly triage routine and one accountable maintainer.
5. Add the needs-info reminder after the manual flow is stable.
6. Add stale review only after observing backlog behavior for several weeks.
7. Add CODEOWNERS or path-based review rules only for truly risky boundaries such as the keyboard extension, App Group/privacy code, and release configuration.

## Sources

[1]: https://www.kubernetes.dev/docs/guide/issue-triage
[2]: https://www.kubernetes.dev/docs/guide/pull-requests
[3]: https://github.com/kubernetes/community/blob/main/contributors/guide/owners.md
[4]: https://github.com/kubernetes/kubernetes/labels
[5]: https://github.com/kubernetes/kubernetes/milestones
[6]: https://github.com/home-assistant/core/blob/dev/CONTRIBUTING.md
[7]: https://github.com/home-assistant/core/blob/dev/.github/ISSUE_TEMPLATE/bug_report.yml
[8]: https://github.com/home-assistant/core/blob/dev/.github/workflows/stale.yml
[9]: https://developers.home-assistant.io/docs/review-process
[10]: https://developers.home-assistant.io/docs/development_submitting
[11]: https://github.com/home-assistant/core/blob/dev/CODEOWNERS
[12]: https://github.com/home-assistant/core/labels
[13]: https://github.com/home-assistant/core/milestones
[14]: https://github.com/home-assistant/core/blob/dev/.github/workflows/detect-duplicate-issues.yml
[15]: https://github.com/home-assistant/core/blob/dev/.github/PULL_REQUEST_TEMPLATE.md
[16]: https://github.com/microsoft/vscode/wiki/Issues-Triaging
[17]: https://github.com/microsoft/vscode/wiki/Development-Process
[18]: https://github.com/microsoft/vscode/wiki/How-to-Contribute
[19]: https://github.com/microsoft/vscode/labels
[20]: https://github.com/microsoft/vscode/milestones
[21]: https://github.com/microsoft/vscode/blob/main/.github/workflows/pr.yml
[22]: https://github.com/microsoft/vscode/blob/main/.github/pull_request_template.md
