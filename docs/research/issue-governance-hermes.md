# Hermes Agent governance and automation patterns reusable by Dictus

> Research note only. The canonical Dictus policy is [`docs/ISSUE-GOVERNANCE.md`](../ISSUE-GOVERNANCE.md); recommendations in this note are inputs to that synthesis, not repository rules.

Date: 2026-09-20

Hermes source baseline inspected: `02c7ae956e42891d5e337a921b45de0a6067146d` (2026-08-25)

Scope: primary sources only from `NousResearch/hermes-agent` and the official Hermes documentation.

## Executive summary

Hermes uses two related but distinct governance layers:

1. **Public repository governance**: intake forms structure reports, the contribution guide publishes a priority order, and labels separate priority, type, component, workflow state, and automation risk.[1][3][6]
   Tracking issues can serve as dependency-ordered roadmaps, while CI combines automated checks with an explicit human-review gate for sensitive changes.[8][13][14]
2. **Runtime work governance**: a durable SQLite Kanban state machine governs task handoffs, retries, blockers, human intervention, review, and audit history.[9]
   Cron provides persistent scheduled execution, while webhooks and hooks provide event-driven activation with idempotency and capability controls.[10][11][15]

The strongest reusable idea for Dictus is not “automate everything.” It is **automate evidence gathering, routing, and repeatable state transitions while reserving product judgment and risky approvals for humans**. Hermes makes that boundary explicit in both its repository instructions and its runtime primitives.[2][9][14]

## Research method and limitations

- Repository files were inspected at the pinned commit above so file citations remain stable.
- Live labels and issue metadata were inspected through GitHub’s public repository/API surfaces on 2026-09-20.[6][7][8]
- The repository milestones API returned an empty array, so no repository milestones were observable at research time.[16]
- GitHub Projects v2 could not be fully enumerated because the available token lacked `read:project`. Therefore this note does **not** claim that Nous Research has no organization-level project boards. The two sampled governance issues had no project or milestone attached in their public metadata.[7][8]
- “Observed” below means directly present in a primary source. “Inference for Dictus” is a recommendation derived from those observations, not a claim about Hermes’s internal maintainer process.

## 1. Prioritization and issue taxonomy

### Observed practice

Hermes publishes an ordered contribution priority list: bug fixes first, then cross-platform compatibility, security hardening, performance/robustness, new skills, new tools, and documentation. It also tells contributors to search open and merged issues/PRs and the current source before starting, and to comment on larger issues to signal ownership.[1]

The live label catalog separates several independent dimensions instead of encoding everything in one status:

- **Priority:** `P0` through `P4`, with descriptions ranging from critical data-loss/security/crash-loop work to best-effort work.
- **Type:** `type/bug`, `type/feature`, `type/docs`, `type/perf`, `type/refactor`, `type/security`, `type/test`.
- **Component/area/platform/provider/tool:** examples include `comp/agent`, `comp/cron`, `area/sessions`, `platform/windows`, `provider/openai`, and `tool/terminal`.
- **Decision/blocking state:** `needs-decision`, `needs-repro`, `awaiting-reporter`, `blocked`.
- **Automation provenance/risk:** `sweeper:*` labels record disposition, blast radius, and specific risks such as caching, compatibility, message delivery, security boundaries, and session state.[6]

There is some observable taxonomy drift: the feature-request form requests the legacy `enhancement` label and the bug form requests `bug`, while the live taxonomy also uses `type/feature` and `type/bug`. The forms themselves collect useful structured data - problem/use case, proposed solution, alternatives, feature type and scope for features; reproducible steps, expected/actual behavior, component, platform and debug report for bugs - but their default labels are not fully aligned with the richer live taxonomy.[3][4][6]

Hermes sometimes uses a parent tracking issue as the roadmap. The plugin-interface tracker declares itself the “plan of record,” decomposes work into dependency-ordered phases, gives every sub-issue design constraints and acceptance criteria, and uses GitHub sub-issues to show completion.[8] The repository milestones endpoint, by contrast, had no entries at the time of inspection.[16]

### Inference for Dictus

Adopt a **small multidimensional label schema**, not one giant workflow label:

- `P0`–`P3` for urgency/impact;
- `type/*` for work kind;
- `area/*` for product surface (`keyboard`, `transcription`, `models`, `onboarding`, `privacy`, `release`);
- one workflow state from `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `blocked`;
- optional `risk/*` labels for privacy, data loss, App Store/release, migration, and extension-memory limits.

Keep priority definitions objective. For Dictus, a plausible mapping is:

- `P0`: privacy/data-loss/security issue, crash loop, or release-blocking keyboard failure;
- `P1`: core dictation or keyboard insertion broken without a workaround;
- `P2`: degraded behavior with a workaround;
- `P3`: polish, ergonomics, or non-blocking enhancement.

Use a tracking issue with sub-issues when sequence and dependency matter. Do not add milestones merely to imitate a conventional roadmap; Hermes demonstrates that a well-written plan-of-record issue can carry phases, constraints, and completion without them.[8][16]

Finally, make label names canonical in one checked-in file or sync script and validate templates against it. That is the direct lesson from the observable `enhancement`/`type/feature` drift.[4][6]

## 2. Triage policy and the human/automation boundary

### Observed practice

Hermes’s `AGENTS.md` is unusually explicit about automated triage authority. The triage sweeper may close only for three evidence-based reasons: already implemented on current `main`, cannot reproduce, or incoherent/insufficient to action. Taste-based “we do not want this” or “out of scope” decisions remain with a human maintainer, and ambiguous cases should stay open for human review.[2]

Issue #31016 shows the mechanism in practice: an automated sweeper comment cited current Kanban implementation and docs, concluded that the proposed durable-handoff mechanism already existed, closed the issue as not planned, and applied `sweeper:implemented-on-main`. The public issue preserves the reasoning and evidence trail.[7]

Hermes also distinguishes different kinds of waiting through labels: `needs-repro` asks for reproducibility, `awaiting-reporter` parks work pending reporter information or an experiment, `needs-decision` waits on maintainer judgment, and `blocked` waits on an external dependency or decision.[6]

The official automation-blueprints guide shows backlog triage and issue auto-labeling as agent-assisted workflows. Its nightly backlog example asks the agent to **suggest** priority/category labels and a triage note; its issue webhook example suggests labels and posts an initial response.[12] This is advisory automation rather than proof that every label is applied autonomously.

### Inference for Dictus

Define an explicit triage decision table:

| Situation | Automated action | Human action |
|---|---|---|
| Exact duplicate or already fixed on `main` with cited evidence | Comment, label, optionally close | Audit reversibility |
| Bug lacks reproducible steps/device/OS/logs | Apply `needs-info` or `needs-repro`; request specific evidence | Close only after an explicit inactivity policy |
| Implementation is safe, scoped, and acceptance criteria are complete | Apply `ready-for-agent` | Periodic sampling/audit |
| Product taste, UX trade-off, monetization, privacy policy, App Store risk, architecture direction | Summarize evidence and apply `ready-for-human`/`needs-decision` | Decide |
| External dependency or missing capability | Apply `blocked` with a concrete reason and unblock condition | Supply input or change direction |

Automation should always leave a short evidence record: what it checked, which commit/current behavior it compared, the reason for the transition, and how a human can reverse it. Hermes’s public sweeper comment is a good model.[2][7]

Do **not** let a model close an issue merely because it judges the feature undesirable. For Dictus, product scope and user-facing behavior are maintainer decisions, even if an agent prepares the comparison and recommendation.

## 3. Human-blocked work and durable queues

### Observed practice

Hermes Kanban is a durable SQLite-backed work queue rather than an in-process subagent call. Tasks have explicit states - `triage`, `todo`, `ready`, `running`, `blocked`, `review`, `done`, `archived` - plus assignee, priority, dependencies, comments, attempts, and optional idempotency keys. Parent links gate children until dependencies finish, and completed parents pass structured summaries and metadata to downstream workers.[9]

The docs distinguish a short-lived `delegate_task` function call from Kanban: Kanban survives restarts, supports block/unblock/re-run, preserves an audit trail, allows multiple agents over a task’s lifetime, and permits human comments/unblocks at any point.[9]

Blocking is reason-aware. A worker can classify a block as a dependency, missing human input, missing capability, or transient failure. Dependency work returns to `todo` and auto-resumes when parents complete; other blockers surface to a human. Repeated re-blocking for the same cause is routed to `triage` after a configured recurrence limit, preventing an automated unblock loop. Spawn/attempt failures also trip a configurable circuit breaker and auto-block rather than thrash.[9]

Review is a first-class state. A worker can request review with a durable summary; a reviewer can request changes and route the same task back to the original implementer. Boards may dispatch an agent reviewer by default or disable review dispatch for human-only review.[9]

The queue includes operational safeguards: atomic claims, stale-claim/crashed-worker recovery, heartbeats, per-board and per-profile concurrency caps, scheduled starts, idempotent creation, run history, notifications on terminal events, and a respawn guard for auth/quota errors, recent success, or an active linked PR.[9]

### Inference for Dictus

GitHub Issues can approximate the same durable state machine without adopting Hermes Kanban itself:

```text
needs-triage -> needs-info | ready-for-agent | ready-for-human | blocked
ready-for-agent -> in-progress -> review -> done
review -> changes-requested -> ready-for-agent
blocked -> previous actionable state (only when unblock condition is met)
```

Required durable handoff fields for agent work should be:

- outcome summary;
- files/areas changed;
- tests and exact results;
- unresolved risks;
- next action and owner;
- blocker reason plus unblock condition, when blocked;
- links to parent/child issues or PRs.

Use GitHub issue/PR comments as the durable protocol, not chat history. Agents should never “wait” by keeping a conversation alive; they should record the blocker and stop. A webhook or scheduled sweep can resume work only when a real state change occurs.

Add simple circuit breakers:

- no more than two automated retries for the same failure signature;
- repeated identical blockers route to `ready-for-human` rather than another retry;
- creation automation must use an idempotency key such as `source:event-id` in a hidden marker or external ledger;
- cap concurrent agent implementation tasks so review capacity is not overwhelmed.

## 4. Review and testing gates

### Observed practice

The PR template asks for a linked issue, one declared change type, an explicit change list, reproducible test instructions, passing tests, tests added for behavior changes, platform tested, documentation/config updates, architecture-instruction updates, and cross-platform impact.[5]

Hermes CI first classifies changed paths, then runs only affected lanes: Python tests, OS-specific tests, lint, JS/TS checks, installer tests, Rust tests, docs checks, lockfile checks, supply-chain/OSV scans, and other targeted validation. A final `all-checks-pass` job aggregates required outcomes so branch protection needs one stable check.[13]

Sensitive paths are not approved by green tests alone. Changes to CI-sensitive files, the MCP catalog, or critical supply-chain findings require the manually applied `ci-reviewed` label; the workflow fails until that label is present. Applying the label triggers a rerun of failed checks.[14]

The contribution guide and agent instructions prefer behavior contracts over snapshot/change-detector tests and require end-to-end validation for config propagation, security boundaries, remote backends, and real I/O paths where mocks could hide integration failures.[1][2]

### Inference for Dictus

Use a two-tier merge gate:

**Always required**

- linked issue or documented exception;
- acceptance criteria;
- relevant unit/integration tests;
- build/test result recorded in the PR;
- docs or user-facing strings updated when behavior changes;
- final aggregate CI check.

**Explicit human approval required when touched**

- keyboard extension entitlements, App Group, microphone/open-access configuration;
- privacy manifests, analytics, network behavior, secrets, or data retention;
- model download/deletion and storage migration;
- release workflows, signing, App Store metadata;
- CI/workflow permissions;
- changes that raise extension memory risk or alter transcription insertion semantics.

A single human-approval label can gate all sensitive classes if the bot comment lists the class-specific checklist, mirroring Hermes’s `ci-reviewed` pattern.[14]

Path-based CI is reusable, but Dictus should fail open on classifier uncertainty: if a changed path is unknown, run the broader suite rather than silently skipping coverage. Hermes explicitly treats post-merge/dispatch classification conservatively.[13]

## 5. Scheduled and event-driven automation

### Observed practice

Hermes separates time-triggered work from event-triggered work:

- **Cron** handles one-shot and recurring schedules, persists jobs, creates fresh sessions, supports project workdirs and skills, validates configuration before spending tokens, records each attempt in an execution ledger, prevents duplicate scheduler ticks with a file lock, and nudges humans after repeated failures.[10]
- **Webhooks** accept external events, authenticate them with per-route HMAC secrets, filter and transform payloads before dispatch, impose rate and body-size limits, deduplicate delivery IDs for one hour, and can either run an agent or deliver directly without one.[11]
- **Hooks** expose lifecycle events and policy/observer points. Callback failures are isolated; some hooks are passive observers while others can block or transform execution, with explicit fail-open/fail-closed semantics.[15]

Webhook-triggered agent runs have a constrained default toolset because authenticated senders can still carry untrusted issue titles, PR bodies, or comments. Elevated toolsets require manual configuration; an agent-created subscription cannot self-grant terminal access.[11]

The official blueprints combine these primitives for nightly backlog triage, PR review on pull-request events, docs-drift detection, dependency audits, issue auto-labeling, CI-failure analysis, and deploy verification. Quiet scheduled runs use `[SILENT]` to suppress no-op notifications.[12]

### Inference for Dictus

Use this split:

- **Webhook on issue opened/edited:** validate intake completeness, suggest labels, detect likely duplicates, and request missing device/iOS/version/reproduction details.
- **Webhook on PR opened/synchronized:** run targeted review and post evidence; never grant the event-triggered agent unrestricted secrets or release permissions.
- **Webhook on review submitted or CI completed:** reopen an implementation task only when actionable feedback/failure exists.
- **Nightly cron:** find stale `needs-triage`, `needs-info`, and `blocked` items; prepare a digest rather than mutating many issues silently.
- **Weekly cron:** detect docs/test drift, duplicate clusters, flaky tests, and issues apparently fixed on `main`.
- **Direct delivery:** send deterministic notifications without paying for an LLM when no interpretation is needed.

Every event handler should use GitHub’s delivery ID as an idempotency key, reject unsigned events, constrain payload fields passed into prompts, and separate read-only triage credentials from write/release credentials.[11]

## 6. Proposed minimum viable Dictus governance

### Labels

```text
Priority: P0, P1, P2, P3
Type: type/bug, type/feature, type/docs, type/test, type/refactor
Area: area/keyboard, area/stt, area/models, area/onboarding,
      area/settings, area/privacy, area/release
Workflow: needs-triage, needs-info, ready-for-agent,
          ready-for-human, blocked
Risk: risk/privacy, risk/data-loss, risk/app-store,
      risk/memory, risk/migration
Outcome: duplicate, wontfix
```

Use exactly one priority, one type, at least one area, and one active workflow state.

### Intake contracts

**Bug form required fields**

- description, expected and actual behavior;
- minimal reproduction;
- app version/commit, iOS version, device/simulator;
- affected target (`DictusApp`, `DictusKeyboard`, `DictusCore`);
- model/engine and language when transcription-related;
- logs or screenshots with privacy warning/redaction guidance;
- regression status and last known good version, if known.

**Feature form required fields**

- user problem and success criterion;
- proposed behavior;
- alternatives/workarounds;
- privacy, offline, memory, and keyboard-extension implications;
- acceptance criteria;
- explicit `ready-for-human` default for product judgment.

### Automation authority

Allow agents to:

- suggest/apply deterministic labels;
- request missing structured data;
- reproduce on current `main` when tooling permits;
- create/update durable evidence comments;
- open a draft PR for an issue explicitly marked `ready-for-agent`;
- close only exact duplicates or issues proven fixed on `main`, under a reversible policy.

Require humans to:

- decide roadmap/product scope and UX trade-offs;
- approve privacy, entitlement, signing, release, and migration changes;
- approve destructive or externally visible actions;
- resolve repeated blockers and architecture disagreements;
- merge.

### Definition of ready for agent

An issue is `ready-for-agent` only if it has:

1. a bounded problem statement;
2. testable acceptance criteria;
3. affected area/target;
4. reproduction or implementation context;
5. no unresolved product/privacy decision;
6. known validation commands or simulator/device matrix;
7. explicit constraints (notably keyboard-extension memory and API restrictions).

### Definition of done

A task is not done when code is merely written. It is done when:

- acceptance criteria are demonstrated;
- relevant tests/builds pass;
- manual device/simulator checks are recorded when required;
- documentation/localization/config changes are included;
- residual risks and untested conditions are stated;
- a reviewer, human or explicitly designated review agent, has approved the handoff;
- high-risk changes have human approval.

## 7. What not to copy blindly

1. **Do not copy Hermes’s label volume.** Hermes has a very large product surface. Dictus should reuse the dimensions, not the count.[6]
2. **Do not assume issue forms stay synchronized automatically.** The observed legacy/richer-label mismatch shows why a validation or sync check is needed.[3][4][6]
3. **Do not treat an agent’s confidence as evidence.** Require reproduction, code/doc citations, and test output before automatic disposition.[2][7]
4. **Do not keep retrying human-blocked work.** Persist the reason and unblock condition, then stop until an external event changes state.[9]
5. **Do not expose broad tools to untrusted webhook text.** Authenticate the sender, constrain capabilities, and still treat issue/PR content as untrusted.[11]
6. **Do not make all review automated.** Hermes’s strongest pattern is selective automation plus explicit human gates for judgment and sensitive changes.[2][14]

## Sources

[1] https://github.com/NousResearch/hermes-agent/blob/02c7ae956e42891d5e337a921b45de0a6067146d/CONTRIBUTING.md
[2] https://github.com/NousResearch/hermes-agent/blob/02c7ae956e42891d5e337a921b45de0a6067146d/AGENTS.md
[3] https://github.com/NousResearch/hermes-agent/blob/02c7ae956e42891d5e337a921b45de0a6067146d/.github/ISSUE_TEMPLATE/bug_report.yml
[4] https://github.com/NousResearch/hermes-agent/blob/02c7ae956e42891d5e337a921b45de0a6067146d/.github/ISSUE_TEMPLATE/feature_request.yml
[5] https://github.com/NousResearch/hermes-agent/blob/02c7ae956e42891d5e337a921b45de0a6067146d/.github/PULL_REQUEST_TEMPLATE.md
[6] https://github.com/NousResearch/hermes-agent/labels
[7] https://github.com/NousResearch/hermes-agent/issues/31016
[8] https://github.com/NousResearch/hermes-agent/issues/64182
[9] https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban
[10] https://hermes-agent.nousresearch.com/docs/user-guide/features/cron
[11] https://hermes-agent.nousresearch.com/docs/user-guide/messaging/webhooks
[12] https://hermes-agent.nousresearch.com/docs/guides/automation-blueprints
[13] https://github.com/NousResearch/hermes-agent/blob/02c7ae956e42891d5e337a921b45de0a6067146d/.github/workflows/ci.yaml
[14] https://github.com/NousResearch/hermes-agent/blob/02c7ae956e42891d5e337a921b45de0a6067146d/.github/workflows/review-labels.yml
[15] https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks
[16] https://api.github.com/repos/NousResearch/hermes-agent/milestones?state=all&per_page=100
