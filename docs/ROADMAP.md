# Roadmap — Dictus

Where we are going, and which issue to work on next. Nothing else.

**Rules for this file**

- One line per item: issue number, title, state. The why and the how live on the issue.
- When an item ships, strike it through. Delete struck lines at each version cut.
- No paragraphs, no measurements, no dates beyond the "Last reviewed" line. If it needs a sentence of justification, write it on the issue and link it.
- Whole file under 60 lines. If an edit pushes it past that, something belongs on an issue instead.
- The [Project board](https://github.com/orgs/getdictus/projects/2) moves by itself on a branch push, a PR and a merge. Two moves are by hand: an issue added to **Now** is added to the board in the same edit (`gh project item-add 2 --owner getdictus --url <issue-url>`), and work with no branch (a grilling, a measurement) is set to In progress when it starts.

Last reviewed: 2026-09-30.

## Now — 2.0.0, the Pro launch

Take the first line that is not struck through. Status (who is on what): [Project board](https://github.com/orgs/getdictus/projects/2).

1. #587 — Smart Mode prompt campaign: its remaining threads
   - #598 — language check refuses a correct short line (`es` read as `pt`)
   - #592 — warn instead of refusing on an ungrounded name
2. #573 — rebuild `Liste` as a summary in bullets (title, then every point). `ready-for-agent`
3. #593 — reverse trial: Pro free for a fixed period, then the paywall. `ready-for-agent`
4. #494 — onboarding that starts the trial and teaches the Smart Modes. `ready-for-agent`
5. #216 — the Pro hub, one screen for free / trial / paid users. `ready-for-agent`. Must land before #279.
6. #279 — flip `PremiumFlags.paywallVisible` and walk all four entry points
7. Cut chore: remove the bundled `JointDecisionv3.mlmodelc` from DictusApp

Done in this lane: #530, #414, #490, #518, #80, #536, #523 `Structuré`, #572 `Message`, #571 `Résumé`, #575, #215.

## Next — the keyboard session

Milestone `Keyboard session` (`gh issue list --milestone "Keyboard session"`). Start with #114: #499 and #500 depend on it.

## Later — 2.1

Milestone `2.1 — after the Pro launch`, plus the unmilestoned open issues. Pick from there only after 2.0.0 ships.

- #619 — measure which paragraphs of the Smart Mode prompts do work
- #570 — meaning guardrail for the rewriting Smart Modes. Moved out of the 2.0.0 gate on Pierre's real-use verdict.

## Settled — do not reopen

- #138 wontfix: a keyboard extension cannot extend a key's hit area (measured).
- The Smart Mode set is five modes on one axis; a Typeless-like mode is refused (#523).
- Verbal `point` in French is not a feature: Parakeet already punctuates.
- The bullet mode stays, renamed `Liste`, re-centred on 2026-09-30 as a summary in bullets (#573).
- Changing `KeyboardAreaMode` destroys SwiftUI gesture identity (hits #505).

## Someday

Milestone `Someday`. Out of view on purpose; review it at each version cut.

---

Numbering: [VERSIONING.md](VERSIONING.md). What a cycle is and why: [RELEASE-PLAN.md](RELEASE-PLAN.md). The old long-form roadmap is in git history (`git show dba87db:docs/ROADMAP.md`).
