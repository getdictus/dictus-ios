# Roadmap — Dictus

Where we are going. Which issue to work on next is not in this file: it is the order of the GitHub project.

## What to work on next

The organisation project [« Dictus 2.1 »](https://github.com/orgs/getdictus/projects/3) is the source of truth for order.

```bash
gh project item-list 3 --owner getdictus --limit 200 --format json \
  --jq '.items[] | "\(.status)\t#\(.content.number)\t\(.content.title)"'
```

The `Status` columns run `À faire` → `En cours` → `En review` → `Fait`. Take the first `À faire` item, in the order the command prints (the project's own order). Anything `En cours` or `En review` is already taken.

## Milestones

- **2.1** — the big bugs, the keyboard, statistics.
- **2.2** — Smart Modes and vocabulary.
- **Later** — everything else.

## Settled — do not reopen

- #138 wontfix: a keyboard extension receives no touch below its own window, so the bottom row's hit area cannot extend downward (measured). Resizing key targets inside the keyboard is possible (#949).
- The Smart Mode set is five modes on one axis; a Typeless-like mode is refused (#523).
- Verbal `point` in French is not a feature: Parakeet already punctuates.
- The bullet mode stays, renamed `Liste`, re-centred on 2026-09-30 as a summary in bullets (#573).
- Changing `KeyboardAreaMode` destroys SwiftUI gesture identity (hits #505).

---

Numbering: [VERSIONING.md](VERSIONING.md). What a cycle is and why: [RELEASE-PLAN.md](RELEASE-PLAN.md). The old long-form roadmap is in git history (`git show dba87db:docs/ROADMAP.md`).
