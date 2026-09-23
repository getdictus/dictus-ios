# Triage Labels

The skills speak in terms of canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker. The full lifecycle, scheduling gate and validation classes are defined in [`docs/ISSUE-GOVERNANCE.md`](../ISSUE-GOVERNANCE.md).

## State labels

Every open issue must carry exactly one state label after the governance rollout.

| Role | Label in our tracker | Meaning |
| --- | --- | --- |
| `needs-triage` | `needs-triage` | Maintainer needs to evaluate this issue |
| `needs-info` | `needs-info` | Waiting on factual evidence from the reporter or another external source |
| Dictus extension | `needs-decision` | Waiting on a product, UX, scope, release or risk decision from Pierre |
| `ready-for-agent` | `ready-for-agent` | Fully specified and executable by an agent, but not necessarily scheduled |
| `ready-for-human` | `ready-for-human` | Fully specified, but the work itself requires human access or action |
| `wontfix` | `wontfix` | Will not be actioned |

`needs-decision` is the state for unfinished grilling. Do not use `ready-for-human` merely because Pierre has questions to answer.

## Scheduling is not a label

`ready-for-agent` says an issue is specified, never that it is next. The schedule lives in [`docs/ROADMAP.md`](../ROADMAP.md): an issue is next when it is the first unfinished item of the active lane. Do not read the label as permission to start, and do not add a label to express that permission.

Until `needs-decision` has been created in GitHub as part of the governance rollout, do not invent it through comments or silently substitute another state. Record the recommended transition and leave the issue in `needs-triage`.

When a skill mentions a canonical role, use the corresponding label string from this table. When the local operating model is stricter than the generic skill, the local model wins.
