# Evidence for #1098 (refs #1089)

A pending key belongs to the finger that pressed it.

Simulator: iPhone 17, iOS 26.5, French UI, status bar 09:41, Dictus French AZERTY, Settings
search field. AXe 2.2.0 (official release binary). Branch build `ce4c03ad`.

- `fast-typing.mp4`: « Bonjour je teste le clavier », 27 AXe taps 120 ms apart in one
  `axe batch`: every letter typed. One finger at a time: AXe holds one contact per simulator
  (a second selected-input `touch --down` is refused), and its two-finger gestures land and
  lift both fingers together, so the two-thumb overlap this fixes cannot be driven here.
- `bench-develop.txt` (`eb129bbb`, same touch code as `6d57b268`), `bench-branch.txt`: the
  single-finger bench of #1097 (`docs/agents/evidence/1097/scripts/` on `study/evidence-1097`).
- `keyboard-bench-954-develop.md` (`6d57b268`), `keyboard-bench-954-branch.md`:
  `tools/keyboard-bench/run.sh --langs fr,en,en-typos`. `texts.tsv` and `commits.tsv` were
  byte-identical; only the engine timings differ.
