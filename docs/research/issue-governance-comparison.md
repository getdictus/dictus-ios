# Issue governance patterns for Dictus

Date: 2026-09-20

## Question

How should Dictus combine issue triage, product prioritisation, agent implementation and human validation without inventing a private process that established open-source projects have not tested?

This note compares public, primary-source evidence from GitHub itself and established repositories. It separates observed practice from the smaller operating model proposed for Dictus.

## GitHub's native model

GitHub Projects is designed as a synchronized table, board and roadmap over issues and pull requests, with saved views, custom fields and automation.[1] [2] GitHub's own guidance recommends one source of truth for each fact, small issues and PRs, explicit dependency links, customized views, column limits and automatic updates for mechanical state.[1]

Milestones are the native repository-level grouping for a release or other outcome. They expose scope, completion and an ordered list of issues and PRs.[4] They are therefore a good fit for Dictus releases, but not enough on their own for separate agent, decision and validation queues.

Built-in Project workflows can set status when items are added, closed or merged and can auto-add or archive matching items.[3] This supports a clean separation: GitHub performs deterministic bookkeeping, while an agent performs semantic triage and product-aware recommendations.

Protected branches can require reviews, status checks and resolved conversations before merge.[5] These controls matter for agent work because a claim in a PR description is not equivalent to a check rerun on the exact head commit.

### Pattern to adopt

- Milestone for release membership.
- Roadmap or Project rank for exact order.
- Labels for stable routing and urgency.
- Project status and views for daily work.
- Required checks and independent review for mergeability.
- A single owner for each field to avoid roadmap, labels and Project values disagreeing.

## T3 Code

Pierre's issue [#11950](https://github.com/pingdotgg/t3code/issues/11950) provides a concrete public trace. A repository member posted a source-grounded triage note six minutes after filing and applied `bug`, `accepted` and `via-triage`.[6] A Devin integration appeared later, and PR [#12002](https://github.com/pingdotgg/t3code/pull/12002) states that it was written by Claude through the Devin harness.[7]

The PR did not rely only on generated code. It included focused unit tests, a simulator reproduction, before/after visual evidence and multiple automated checks. It was merged 6 hours 49 minutes after the issue opened.[6] [7]

T3 Code also ships a public triage playbook. It tells an agent to gather local evidence, match the installed version to source, search upstream, prefer a confirmed duplicate over a new issue, redact secrets and obtain explicit user approval before filing.[8]

### Observed boundary

The public timeline proves fast AI-assisted triage and AI-assisted implementation. It does not prove that every new issue automatically starts an implementation agent. The `accepted` decision was applied by a repository member before the Devin-authored PR appeared.[6] [7]

### Pattern to adopt

- Automate evidence gathering and recommendation aggressively.
- Preserve an explicit acceptance or scheduling gate before implementation.
- Require tests and environment-appropriate evidence in the PR.
- Treat the issue as support and product context, not merely a prompt for code generation.

## Dictus baseline before adoption

Snapshot from the GitHub API on 2026-09-20:

- 102 open issues;
- 27 labelled `ready-for-agent`;
- 29 labelled `ready-for-human`;
- 20 labelled `needs-triage`;
- 8 labelled `needs-info`;
- 19 open issues with no canonical triage state;
- 20 open issues with no priority;
- 49 open issues with no milestone;
- one issue, #368, carrying both `ready-for-agent` and `ready-for-human`.

The repository already has the core strategic layers:

- `docs/RELEASE-PLAN.md` for release intent;
- `docs/ROADMAP.md` for an ordered active lane;
- milestones for `2.0.0 - Dictus Pro`, the keyboard campaign and `Someday`;
- detailed issue briefs and grilling decisions;
- #534 for running the existing test suite as required CI;
- #535 for a repeatable headless simulator smoke test.

The missing layer is operational routing. `ready-for-agent` currently mixes "specified" with the temptation to read it as "start now". `ready-for-human` mixes human implementation with issues that still need product decisions. The proposed model separates those meanings.

## OpenClaw

OpenClaw's scale is much larger than Dictus, but its boundary model is directly relevant. Structured issue forms collect evidence and route support or security reports away from ordinary product issues. Its labels separate type, product surface, priority, impact, evidence state, automation eligibility and human gates rather than trying to encode all of them in one status.[9] [10]

The ClawSweeper design keeps model workers away from mutation credentials. AI workers analyze and recommend; deterministic scripts own comments, labels, pushes, closure and merges through bounded credentials. Repair and automerge are opt-in, exact-head and fail-closed.[11]

OpenClaw also has explicit human-gate labels such as product decision, maintainer review and security review. Its public maintainer guidance keeps rejection, out-of-scope decisions and uncertain expected behavior under human authority.[10] [11]

### Pattern to adopt

- Separate evidence, product decision, scheduling and implementation readiness.
- Let AI produce structured recommendations and evidence.
- Let bounded deterministic code apply allowed transitions.
- Keep product, privacy, release and exception decisions human-owned.
- Do not copy OpenClaw's hundreds of labels; copy the independent dimensions.

## Hermes Agent

Hermes's repository already exposes a `needs-decision` state distinct from reporter information, reproducibility and external blocking. Its instructions allow automated closure only for evidence-based outcomes such as already implemented or not reproducible, while taste and product-scope decisions stay with maintainers.[12]

Hermes Kanban demonstrates the runtime equivalent of this distinction. Durable tasks can be ready, running, blocked, in review or done; blockers record a reason and an unblock condition; repeated identical blockers trip a circuit breaker instead of causing endless retries. Human comments and unblocks can resume the same durable task later.[13]

Hermes webhooks provide immediate event-driven wake-ups with HMAC verification, idempotency and capability restrictions. Authenticated issue text is still treated as untrusted, and event-triggered agents do not receive broad tools unless a human configures them.[14]

### Pattern to adopt

- Add `needs-decision` for unfinished product grilling.
- Persist the question, evidence and unblock condition on GitHub, then stop the worker.
- Resume from a webhook or reconciliation pass only after the external state changes.
- Keep a concurrency cap and bounded retry count.

## Kubernetes, Home Assistant and VS Code

Kubernetes provides the clearest formal separation of kind, priority, ownership and triage outcome. New issues start in `needs-triage`; acceptance, missing information and other outcomes are separate labels. Priority describes response expectations rather than implementation convenience.[15]

Home Assistant front-loads environment, version, component, diagnostics and logs in its bug form.[16] Its duplicate workflow narrows and suggests candidates, but does not silently decide that two reports are the same.[17]

VS Code uses visible planning stages to distinguish unaccepted candidates, accepted backlog, a sparse near-term queue and scheduled release milestones. Its triage guidance also makes waiting for information, discussion and closure reasons explicit.[18]

### Pattern to adopt

- Intake should collect Dictus version/build, iOS/device, model, affected app or keyboard surface, reproduction and redacted logs.
- Priority is assigned after the report is understood.
- Accepted does not mean scheduled.
- A current release milestone means delivery intent.
- A small ordered queue is distinct from the general accepted backlog.
- Duplicate automation suggests and cites; it does not close on similarity alone.

## What Dictus should use

The common pattern across these repositories is not a particular bot or label name. It is a chain of custody:

```text
structured intake
  -> evidence-backed triage
  -> explicit product acceptance
  -> ordered scheduling gate
  -> isolated implementation
  -> exact-head tests and independent review
  -> simulator/device/product evidence selected by risk
  -> human-controlled release
```

The resulting lightweight Dictus model is documented in [`docs/ISSUE-GOVERNANCE.md`](../ISSUE-GOVERNANCE.md). It deliberately keeps the existing milestones and priority labels, adds a distinct `needs-decision` state, keeps scheduling in `docs/ROADMAP.md` rather than in a second approval label, and limits the initial implementation queue to one issue.

## Sources

[1]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/best-practices-for-projects "Best practices for GitHub Projects"
[2]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects "About GitHub Projects"
[3]: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations "GitHub Projects built-in automations"
[4]: https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/about-milestones "About GitHub milestones"
[5]: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches "About protected branches"
[6]: https://github.com/pingdotgg/t3code/issues/11950 "T3 Code issue #11950"
[7]: https://github.com/pingdotgg/t3code/pull/12002 "T3 Code PR #12002"
[8]: https://github.com/pingdotgg/t3code/blob/main/.github/triage/PLAYBOOK.md "T3 Code triage playbook"
[9]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/CONTRIBUTING.md "OpenClaw contribution guide"
[10]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.agents/skills/openclaw-pr-maintainer/references/triage.md "OpenClaw maintainer triage guide"
[11]: https://github.com/openclaw/openclaw/blob/e63393bddc3a3f6748acd8ad873a96a7a3af9702/.agents/skills/clawsweeper/SKILL.md "OpenClaw ClawSweeper"
[12]: https://github.com/NousResearch/hermes-agent/blob/02c7ae956e42891d5e337a921b45de0a6067146d/AGENTS.md "Hermes Agent repository instructions"
[13]: https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban "Hermes Kanban"
[14]: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/webhooks "Hermes webhooks"
[15]: https://www.kubernetes.dev/docs/guide/issue-triage "Kubernetes issue triage"
[16]: https://github.com/home-assistant/core/blob/dev/.github/ISSUE_TEMPLATE/bug_report.yml "Home Assistant bug form"
[17]: https://github.com/home-assistant/core/blob/dev/.github/workflows/detect-duplicate-issues.yml "Home Assistant duplicate suggestion workflow"
[18]: https://github.com/microsoft/vscode/wiki/Issues-Triaging "VS Code issue triage"
