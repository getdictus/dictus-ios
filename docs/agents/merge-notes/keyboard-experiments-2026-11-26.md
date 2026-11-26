# Merge notes: keyboard experiments test branch, 2026-11-26

Branch `test/keyboard-experiments-2026-11-26`, built only for Pierre's iPhone test of four open PRs together. Nothing here is merged into `develop`. These notes are meant to be reused when the real PRs merge.

## What was merged

| Step | Ref | Head | Contains |
|---|---|---|---|
| base | `origin/develop` | `aaa7c06d` | |
| 1 | `origin/feature/bilingual-check` (#1020) | `4f661f78` | #1010 `feature/bilingual-detection` `0017c059`, #1066 `fix/experiments-wired` `5f2a9786` |
| 2 | `origin/feature/adaptive-touch` (#1018) | `3b20e02d` | #1066 `5f2a9786` |

Merge commits, no rebase. Before merging, every head was checked against `gh pr view` and was still the one listed above, with both required checks (`SwiftLint`, `iOS (build + DictusCore + App Tests)`) green.

- Step 1 (`d1f7ecf9`) merged cleanly: #1020 is develop plus its own commits.
- Step 2 (`1d233ccf`) conflicted in 9 files. Both sides carry #1066, so its changes (the `refreshExperiments` hook, the delete-swipe switch, `isSpatialAutocorrectEffective`, `SpatialTouchBuffer.decoderInput`) appear identically on both sides and only conflict where one side edited next to them.

The merge base of the two heads is `aaa7c06d` (develop). When the real PRs land on develop one at a time, the same conflicts appear when the second of #1018 and #1020 merges. The resolutions below apply, whichever comes second.

## Conflicts, file by file

### `DictusKeyboard/DictusKeyboardBridge.swift` and `DictusKeyboardBridge+SpatialTouch.swift`

- **#1020** kept the spatial helpers (`noteSpatialTap`, `noteSpatialDeletion(context:)`, `spatialInput(for:)`, `refreshExperiments`) as `fileprivate` in `DictusKeyboardBridge.swift`. It added one line to `refreshExperiments`: `BilingualAutocorrect.refresh(settings)`, read from the same `KeyboardFeatureSettings.forKeyboard()` value as spatial.
- **#1018** moved those helpers into a new file, `DictusKeyboardBridge+SpatialTouch.swift`, without `fileprivate`. It also changed `noteSpatialDeletion` to `(before:after:)`, made `spatialInput` go through `AdaptiveTouchSwitch.runtime.decoderInput`, and added `AdaptiveTouchSwitch.refresh(settings)` plus its log line to `refreshExperiments`.
- **Kept:** #1018's layout. The block is deleted from `DictusKeyboardBridge.swift`, and #1020's `BilingualAutocorrect.refresh(settings)` line, with its comment, goes into `refreshExperiments` in `+SpatialTouch.swift`. All three switches are read from one `settings` value in one call, at the same moments: every new keyboard view (`keyboardView.didSet`, trigger `newView`) and every appearance (`viewWillAppear`). Nothing is read per tap. The order inside the call is spatial, then the tap-buffer clear, then adaptive, then bilingual. The order does not matter: none of the three refreshes reads another's result. `isAdaptiveTouchEffective` already includes `isSpatialAutocorrectEffective`, from the same settings.
- Every call site in `DictusKeyboardBridge.swift` already used #1018's signatures after the auto-merge (`noteSpatialDeletion(before:after:)`).

### Correction path (auto-merged, checked by hand): spatial, adaptive and bilingual

No logic conflict. The three features act at different stages of one call chain:

1. `DictusKeyboardBridge.spatialInput(for:)` (#1011, wired by #1066): the word's taps and keys, or nil when spatial is off.
2. #1018 wraps it in `AdaptiveTouchSwitch.runtime.decoderInput(_:)`. When a profile is in use, the taps are read with the personal centres, and the stock centres become `SpatialCorrection.Input.baseline`. Otherwise the input is unchanged.
3. `SuggestionState.correctionProposal(…, spatial:)` (#1020): when `BilingualAutocorrect.current` exists, the same input goes to `BilingualKeyboard.commit`, which hands it to both engines. Otherwise it goes to the single engine.

So the bilingual check's two decoders read the adapted taps, with the stock-centre baseline. Both languages are typed on one grid (the partner engine loads for the primary's layout), so one set of personal centres is right for both. Adaptive touch learns from how the word ended (`AdaptiveWordEnd`), after the proposal: a word of the other language that the check kept counts as "stood as typed", and a fix the partner made counts as a correction. That is what each PR does on its own.

### `DictusCore/Sources/DictusCore/KeyboardFeatureSettings.swift`

- The conflict was the type's doc comment only. Each side said the other's feature had no keyboard code yet.
- **Kept:** one sentence naming all five things the keyboard reads: swipe typing, spatial, Adaptive touch, the bilingual check with its partner language, and the delete swipe.
- The code auto-merged. #1018's `isAdaptiveTouchEffective` (channel rule, `&& isSpatialAutocorrectEffective`) and #1020's `isBilingualAutocorrectEffective` and `bilingualPair(for:)` sit side by side. `isSpatialAutocorrectEffective`, from #1066, is identical on both sides and present once.

### `TJ SWITCHES` line (no conflict, checked)

- `BilingualAutocorrect.debugSwitches(_:)` (#1020) builds the line from `SpatialAutocorrect.isOn`, `settings.isAdaptiveTouchEffective` and `BilingualAutocorrect.isOn`. `SuggestionState.setLanguage` writes it at every appearance, after `refreshExperiments`.
- After the merge, `isAdaptiveTouchEffective` is #1018's: the rule `AdaptiveTouchRuntime.refresh` applies. So `adaptive=` shows the value in force, not just the stored switch.
- The doc comment there still says Adaptive touch's keyboard code "is #1018's, not on this branch". That sentence is stale once both are in. It was left as is (comment only, no code change on this branch). Fix it in whichever real PR merges second.

### `Dictus.xcodeproj/project.pbxproj`

- **#1020** added `BC1015A1`/`BC1015B1` (`BilingualAutocorrect.swift`) and `BC1015A2`/`BC1015B2` (`TrieLanguageEvidence.swift`).
- **#1018** added `AT1014A1`/`AT1014B1` (`AdaptiveTouchSwitch.swift`) and `AT1014A2`/`AT1014B2` (`DictusKeyboardBridge+SpatialTouch.swift`). The `+SpatialTouch` group and Sources entries had auto-merged.
- **Kept:** the union, in four places: PBXBuildFile, PBXFileReference, the `TextPrediction` group, and the DictusKeyboard Sources phase.
- Checked: 615 object definitions with no duplicate ID, `plutil -lint` OK, and the Debug build (simulator and device) compiles all four files.

### `DictusApp/DictusApp.swift`

- **#1020** replaced `applySpatialAutocorrectArgument()` with a generic `applyKeyboardDebugArgument(_:write:)`, called for `DictusDebugSpatialAutocorrect` and `DictusDebugBilingualAutocorrect`.
- **#1018** kept `applySpatialAutocorrectArgument()` and added `applyAdaptiveTouchArguments()`, for `-DictusDebugAdaptiveTouch` and `-DictusDebugAdaptiveTouchReset`.
- **Kept:** #1020's generic helper and both of its calls, plus #1018's `applyAdaptiveTouchArguments()` call and function. `applySpatialAutocorrectArgument()` no longer exists. The Adaptive touch pair stays a dedicated function because the reset argument is an action, not a Bool write.

### `DictusApp/Views/LicensesView.swift`

- **#1020** moved Hex's notice into `private static let hexNotice` (a multi-line string) and added the bilingual paragraph. It also added a doc paragraph saying that the bilingual check follows Hex's approach rather than porting its code.
- **#1018** edited the inline string concatenation: one paragraph, "Adaptive touch, which learns where you tap each key (#1014), is ported from Hex's AdaptiveTouch.", after the spatial decoder's paragraph. It also added one doc sentence.
- **Kept:** #1020's `hexNotice` structure, with #1018's paragraph inserted at the same place (after the decoder, before swipe typing), and both doc comments. The text the user sees is #1020's notice plus #1018's sentence, word for word.

### `tools/keyboard-bench/main.swift`

- **#1020** added the `Corrector` protocol (`SingleEngine`, and the bilingual correctors in `Bilingual.swift`). `replay()` takes `corrector:`. The `KB_PAIR` block exits before the monolingual loop. `Commit` gained `language`, and `final` became a `var` for `acrossSpace`.
- **#1018** added `adaptive: AdaptiveTouch?` to `replay()`, a seventh `adaptiveNs` column to the row closure, and the global `benchClock`, `adaptiveGate`, `adaptive`, `adaptiveReport` and `adaptiveRows`, declared just before `tapsOut`. The proposal input reads the personal keys and the baseline.
- **Kept:**
  - `replay(…, spatial:, corrector:, adaptive:, tapRow: (… 7 values))`.
  - The proposal goes through `corrector.proposal(for:previous:…)`, with #1018's adapted `input` and `let before`.
  - The next-word prediction uses `corrector.typingEngine`, followed by #1018's `adaptive.finish` call.
  - #1018's globals are placed **before** #1020's `KB_PAIR` block. `replay()` reads `benchClock` and `adaptiveGate`, and the pair replay calls `replay()` and then `exit(0)`, so with the globals after it, the pair replay would read top-level globals that were never initialised.
- **Compile fix outside the conflict markers:** `tools/keyboard-bench/Bilingual.swift`'s pair replay call now passes `adaptive: nil` and a 7-argument row closure. The pair replay never used Adaptive touch, and `run.sh --pair` does not forward `KB_ADAPTIVE`.
- **Known gap, bench only:** with `--bilingual --adaptive`, an elision across the space (`its a` → `it's a`, `Corrector.acrossSpace`) returns before `adaptive.finish`, so the bench learner never sees that word end. The keyboard does report it (`AdaptiveWordEnd(correction:revisesPrevious: true)`). Neither PR measures that pair of flags, and nothing in the tables below depends on it.

### `tools/keyboard-bench/run.sh`

- Usage line, help text, variables, argument parsing: the union of #1020's `--pair`/`--probe`/`--bilingual` and #1018's `--adaptive`/`--adaptive-load`/`--adaptive-save`/`--adaptive-tune`.
- `score.py --keyboard` label: both suffixes, adaptive then bilingual.
- `--pair` still exits before the monolingual spawn and does not forward the adaptive variables, as on #1020.

### `.claude/skills/verify-dictus-ios/features/README.md` and `typing.autocorrect.md`

The union. `typing.adaptive-touch` comes first, then `typing.bilingual-autocorrect`, after `typing.spatial-autocorrect`, in the ID table, the feature list and the simulator recipes. Nothing was reworded.

## Not changed

- No switch, default or key: every experiment stays off by default, and the App Store build still ignores the stored values.
- No code beyond the conflict resolution and the `Bilingual.swift` call above.
- No version or build number.

## Checks (at `1d233ccf`)

- `cd DictusCore && swift test`: 4242 tests, 4 skipped, 0 failures.
- `xcodebuild build` DictusApp Debug for an iOS 26.5 simulator: succeeded.
- `swiftlint lint --strict` (local 0.65.1; CI pins 0.63.2):
  - No violation in the resolved files of the lint scope: `DictusApp.swift`, `LicensesView.swift`, `KeyboardFeatureSettings.swift`, `DictusKeyboardBridge.swift`, `DictusKeyboardBridge+SpatialTouch.swift`.
  - The 11 findings of a full run are all in files neither PR touches (`superfluous_disable_command` and others that 0.63.2 does not have).
  - `tools/` is outside `.swiftlint.yml`'s `included`. Linted by hand anyway, `replay()` already breaks `function_parameter_count` and `cyclomatic_complexity` on both heads, and the merge adds `function_body_length` (154 > 150).

### #954 bench (iPhone 17 grid, 402×216, iOS 26.5 simulator, `SWIFT_DETERMINISTIC_HASHING`)

"develop" is `aaa7c06d` from a `git archive`, on the same simulator.

| Run | This branch | Expected | Source of the expectation |
|---|---|---|---|
| `--langs fr,en,en-typos`, switches off: wrong words / broken | 2, 8, 1 / 0, 0, 0 | 2, 8, 1 | develop; `commits.tsv` and `texts.tsv` **byte-identical** to develop |
| same with `--spatial` | 1, 2, 1 / 0, 0, 0 | 1, 2, 1 | develop; **byte-identical** to develop |
| `--pair fr,en`, `detect`: fr, en@qwerty, en@azerty, mixed, mixed-heldout, mixed-heldout-2 | 3, 6, 6, 10, 11, 10 | 3, 6, 6, 10, 11 | #1010, #1020 (mixed-heldout-2 not in #1010) |
| `--pair fr,en`, `check`, no `--spatial` | 2, 6, 6, 8, 10, 9 | none published | #1020 publishes `check` with `--spatial` only |
| `--pair fr,en --spatial`, `check` | 1, 2, 2, 4, 10, 9 | 1, 2, 2, 4, 10, 9 | #1020 |
| same, broken words fr / en | 0/0, 0/0, 0/0, 0/1, 0/4, 0/2 | identical | #1020 |
| `--pair fr,en --spatial`, `detect` | 3, 6, 6, 10, 11, 10 | as without `--spatial` | `detect` ignores taps (#1020) |
| `--bilingual --langs fr,en,en-typos` | 2, 8, 1 / 0, 0, 0 | | `commits.tsv` byte-identical to the monolingual run |
| `--bilingual --spatial --langs fr,en,en-typos` | 1, 2, 1 / 0, 0, 0 | 1, 2, 1 / 0, 0, 0 | #1020; byte-identical to `--spatial` alone |
| `--spatial --adaptive learn --langs fr,en,en-typos` | 1, 2, 1 / 0, 0, 0 | 1, 2, 1 / 0, 0, 0 | #1018; `commits.tsv` and `texts.tsv` **byte-identical** to #1018's head `3b20e02d` on the same simulator |

**Adaptive touch learning changes one word.** With `--adaptive learn`, en-typos sentence 7 ends `David doesn't have a all`, against `a well` with `--spatial` alone (meant: `will`). Both are wrong, so the count stays at 1. #1018's own head gives the same output, so this is #1018's behaviour, not the merge's.
