# Roadmap — Dictus

Where we are going, and which issue to work on next. Nothing else.

**Rules for this file**

- One line per item: issue number, title, state. The why and the how live on the issue.
- When an item ships, strike it through. Delete struck lines at each version cut.
- No paragraphs, no measurements, no dates beyond the "Last reviewed" line. If it needs a sentence of justification, write it on the issue and link it.
- Whole file under 60 lines. If an edit pushes it past that, something belongs on an issue instead.
- The [Project board](https://github.com/orgs/getdictus/projects/2) moves by itself on a branch push, a PR and a merge. Two moves are by hand: an issue added to **Now** is added to the board in the same edit (`gh project item-add 2 --owner getdictus --url <issue-url>`), and work with no branch (a grilling, a measurement) is set to In progress when it starts.

Last reviewed: 2026-10-07.

## Now — 2.0.0, the Pro launch

Take the first line that is not struck through. Status (who is on what): [Project board](https://github.com/orgs/getdictus/projects/2).

1. ~~#587 — Smart Mode prompt campaign~~ — last thread #592 (warn on an ungrounded name) parked in 2.1, near-spelling tolerance covers its case
2. ~~#627 — run a voice note's Smart Mode in the background~~ — merged in PR #689 (probe 19/19, no `rateLimited`); next #628, notes over ~4 min, in 2.0.0 only if reliable and short
3. ~~#637 — voice-note transcripts in the keyboard~~ — merged in PR #638; #639 (tap ☰ for notes, keep them 15 min) merged in PR #641; then #640 (research: quote a passage)
4. ~~#573 — rebuild `Liste` as a summary in bullets~~ — merged in PR #629; open until Pierre's verdict in real use
5. ~~#593 — reverse trial: Pro free for a fixed period, then the paywall~~ — merged in PR #595; two device checks left (iPad, EN strings)
6. #649 — onboarding rebuild: PR A merged in PR #654 (#653 in PR #655); mock-ups done 2026-10-07; split into sub-issues #675-#686 (start with #675, then #676-#678, #682, #683 in parallel); intro videos #667 merged in PR #670 (2026-10-09)
7. #216 — the Pro hub, one screen for free / trial / paid users. `ready-for-agent`. Must land before #279.
8. ~~#621 — search the history: the paywall already sells it~~ — merged in PR #652
9. ~~#643 — App Store listing for 2.0.0~~ — merged in PR #645 (en, fr, de, es; ASC upload at submission). Remaining French UI follow-ups: ~~#664~~ (merged in PR #668), ~~#665~~ (merged in PR #671)
10. ~~#673 — download screen: drop the two phrases that promise the end ("Almost there" at 1 %)~~ — merged in PR #674
11. ~~#533 — countdown under the model preparation (compile / load), not a second bar~~ — merged in PR #687
12. #279 — flip `PremiumFlags.paywallVisible` and walk all four entry points
13. Cut chore: remove the bundled `JointDecisionv3.mlmodelc` from DictusApp

Done in this lane: #530, #414, #490, #518, #80, #536, #523 `Structuré`, #572 `Message`, #571 `Résumé`, #575, #215, #620 voice notes.

## Next — the keyboard session

Milestone `Keyboard session` (`gh issue list --milestone "Keyboard session"`). Start with #114: #499 and #500 depend on it.

## Later — 2.1

Milestone `2.1 — after the Pro launch`, plus the unmilestoned open issues. Pick from there only after 2.0.0 ships.

- #619 — measure which paragraphs of the Smart Mode prompts do work
- #570 — meaning guardrail for the rewriting Smart Modes. Moved out of the 2.0.0 gate on Pierre's real-use verdict.
- #512 — analyze the history to suggest vocabulary
- #622 — translation targets from Apple FM's languages, not the keyboard's
- #269 — custom Smart Modes

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
