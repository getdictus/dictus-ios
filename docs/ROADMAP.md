# Roadmap — Dictus

Where we are going, and which issue to work on next. Nothing else.

**Rules for this file**

- One line per item: issue number, title, state. The why and the how live on the issue.
- When an item ships, strike it through. Delete struck lines at each version cut.
- No paragraphs, no measurements, no dates beyond the "Last reviewed" line. If it needs a sentence of justification, write it on the issue and link it.
- Whole file under 60 lines. If an edit pushes it past that, something belongs on an issue instead.

Last reviewed: 2026-09-30.

## Now — 2.0.0, the Pro launch

Take the first line that is not struck through.

1. #587 — Smart Mode prompt campaign: its remaining threads
   - #570 — meaning guardrail (product name replaced, negation dropped). Gates the 2.0.0 cut. Needs a grilling.
   - #598 — language check refuses a correct short line (`es` read as `pt`)
   - #592 — warn instead of refusing on an ungrounded name
2. #573 — rebuild `Liste`'s prompt (Pierre rates it the weakest mode). `needs-triage`
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

## Settled — do not reopen

- #138 wontfix: a keyboard extension cannot extend a key's hit area (measured).
- The Smart Mode set is five modes on one axis; a Typeless-like mode is refused (#523).
- Verbal `point` in French is not a feature: Parakeet already punctuates.
- The bullet mode stays, renamed `Liste`.
- Changing `KeyboardAreaMode` destroys SwiftUI gesture identity (hits #505).

## Someday

Milestone `Someday`. Out of view on purpose; review it at each version cut.

---

Numbering: [VERSIONING.md](VERSIONING.md). What a cycle is and why: [RELEASE-PLAN.md](RELEASE-PLAN.md). The old long-form roadmap is in git history (`git show dba87db:docs/ROADMAP.md`).
