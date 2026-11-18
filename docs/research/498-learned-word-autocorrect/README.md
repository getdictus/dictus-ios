# #498: keyboard bench before and after

In-process replay (`tools/keyboard-bench/run.sh --langs fr,en,fr-learned,en-learned`),
iOS 26.5 simulator (iPhone 17), 2026-11-17, `SWIFT_DETERMINISTIC_HASHING=1`.

- `before.md`, `before-commits.tsv`: commit `3f74a5c0` (the bench change alone, engine as on `develop`).
- `after.md`, `after-commits.tsv`: commit `67fba7cb` (learned words become correction targets).

Two replays of the after commit gave the same commits and texts; engine time p50 and p95
moved by under 0.2 ms between them, the max by tens of ms (one outlier per run).
