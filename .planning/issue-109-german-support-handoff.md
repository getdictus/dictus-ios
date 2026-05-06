# Issue #109 + #110 — German support handoff (PR2)

**Branch:** `feature/german-support` (off `develop` at commit `5440231`)
**Status:** Branch created, no work started.
**Plan source:** PR1 handoff (`.planning/issue-110-language-onboarding-handoff.md`) and the 17 locked decisions from `/grill-with-docs` 2026-05-04/05.
**Predecessor:** PR1 (#153) merged into develop on 2026-05-05, shipped to App Store as v1.6.2 (build 15) via PR #154. TestFlight soak underway.

## Why this work exists

PR1 built the **language onboarding system** (LanguageProfile + DictusCore helpers + FrenchAdaptiveKey + dynamic SettingsView picker) but did not add any new language. This PR (PR2) is the **dogfood proof** of the system: ship German end-to-end using the new architecture as the empirical validation that "adding a language is a one-file change."

If PR2 hits friction the system was supposed to remove, the friction itself is data for the doc + script we owe at the end.

## What PR1 already did (so you don't redo it)

Read first: `.planning/issue-110-language-onboarding-handoff.md` — full PR1 plan.

Concretely on `develop` today:
- `DictusCore/Sources/DictusCore/Languages/{French,English,Spanish}.swift` — three pure-data `LanguageProfile` files
- `DictusCore/Sources/DictusCore/Languages/LanguageProfile.swift` — the struct + `SupportedLanguage.profile` switch
- `DictusCore/Sources/DictusCore/TextCorrection/{applyOverride,expandAccents,expandContractions,FrequencyProvider}` — pure-Swift helpers driven by a protocol
- `DictusCore/Sources/DictusCore/AccentedCharacters.swift` — multilingual long-press `mappings` + `FrenchAdaptiveKey` namespace (French-only AZERTY adaptive accent key)
- `DictusKeyboard/TextPrediction/AOSPTrieEngine.swift` — consumes the helpers via `currentProfile`; conforms to `FrequencyProvider` via extension
- `DictusKeyboard/TextPrediction/TextPredictionEngine.swift` — gates `correctApostrophePrefix` on `!profile.contractionPrefixes.isEmpty`
- `DictusApp/Views/SettingsView.swift` — language picker uses `ForEach(SupportedLanguage.allCases)`
- `CONTEXT.md` (repo root) — domain glossary
- `docs/adr/0001-empty-overrides-and-seeds-for-non-native-language-launches.md` — override/seed empty policy for non-native launches

193/193 DictusCore tests pass on this state.

## What PR2 must deliver

### 1. German `LanguageProfile`

Create `DictusCore/Sources/DictusCore/Languages/German.swift` mirroring the existing pattern. Per ADR 0001:

- `code: "de"`, `displayName: "Deutsch"`, `shortCode: "DE"`, `defaultLayout: .qwerty` (QWERTZ deferred to issue #151)
- `spaceName: "Leertaste"`, `returnName: "Eingabe"` (verify these are the conventional German keyboard labels)
- `overrides: [:]` — **empty** on first ship (ADR 0001: maintainer is non-native; populated post-launch from real user feedback)
- `accentMap` — populated (generative, doesn't require fluency):
  ```swift
  [
      "a": ["ä"],
      "o": ["ö"],
      "u": ["ü"],
      "s": ["ß"],
  ]
  ```
- `contractionPrefixes: []` — German `geht's`/`gibt's` style contractions are rare and not curated for first ship

Add `case german = "de"` to `SupportedLanguage` enum (and update the `profile`, `displayName`, `shortCode`, `defaultLayout`, `spaceName`, `returnName` switches).

### 2. Per-language test file

Per locked decision #10: `DictusCore/Tests/DictusCoreTests/Languages/GermanLanguageTests.swift` (new directory). Tests should cover:
- `germanProfile.code == "de"`, `displayName == "Deutsch"`, etc. (snapshot of the data)
- `applyOverride(profile: germanProfile, word: ...)` returns nil for any input (empty overrides per ADR 0001)
- `expandAccents(profile: germanProfile, ...)` with a `MockFrequencyProvider` covering `straße`, `mädchen`, `über`, `schön`
- `expandContractions(profile: germanProfile, ...)` returns nil for any input (empty contractionPrefixes)

Mirror the existing `FrenchLanguageTests.swift` if it exists, otherwise establish the structure.

### 3. Dictionary + n-gram pipeline for German

The Python tooling at `tools/` builds `de_spellcheck.dict` and `de_ngrams.dict` binaries. Investigate:
- `tools/dict_builder.py` (or equivalent) — does it have a `LANG_MAP` entry for `de`?
- `tools/ngram_builder.py::SEED_BIGRAMS_BY_LANG` — per ADR 0001, do **not** add German seeds. The Wikipedia + OpenSubtitles + Google Books corpus should run alone.
- Stopwords list for German.

Run the pipeline. Output binaries land in the keyboard target's bundle resources. Wire them into Xcode (`DictusKeyboard.xcodeproj` build phases) so `de_spellcheck.dict` and `de_ngrams.dict` ship with the app.

### 4. `tools/onboard_language.py` script

Per locked decision #9: phased commands `scaffold`, `build-dicts`, `wire-xcode`, `verify`. Build this script **as you go through the German onboarding** — capture the friction in code so the next language can use the script directly. Don't build it speculatively; build it from the friction.

Phases:
- `scaffold <lang>` — generates `Languages/<Lang>.swift` skeleton + `Tests/Languages/<Lang>LanguageTests.swift` skeleton
- `build-dicts <lang>` — runs the Python dictionary + n-gram pipeline
- `wire-xcode <lang>` — edits `project.pbxproj` to add the .dict binaries to keyboard bundle resources
- `verify <lang>` — runs DictusCoreTests + checks Swift profile data matches the Python pipeline expectations

### 5. `docs/agents/language-onboarding.md`

Per locked decision #15: ~150-200 lines reference + checklist + rationale. Cover:
- The flow (scaffold → curate profile → build-dicts → wire-xcode → verify → smoke test → ship)
- The curated decisions (display name, layout, accent map, override population) with pointers to ADR 0001
- The empty-on-launch policy (overrides + seeds) with rationale
- A worked example pointing at the German onboarding commits

Write this **after** the German onboarding so it reflects what actually happened, not what we hoped would happen.

### 6. Smoke test the German keyboard

Same runbook structure as PR1's 6 cases, but for German:
- Type `straße` (already accented) → no over-correction
- Type `strasse` → if `straße` is the more frequent form in the corpus, `expandAccents` may correct (test on real device behavior)
- Type `madchen`, `uber`, `schon` → expect `mädchen`, `über`, `schön` (or stay as-is if the unaccented form is also in dict; ADR 0001 says we accept this trade-off on launch)
- Switch language to German via Settings, verify keyboard layout stays QWERTY (per locked decision #4)
- Verify no regression on French / English / Spanish autocorrect

If a smoke test surfaces an obvious quality gap, it goes into the post-launch playbook (issue #152), **not** into this PR.

## What's out of scope (don't pull in)

- QWERTZ layout — deferred to follow-up issue #151
- UI string localization (`Localizable.xcstrings`) — German UI translation is separate work, tracked in issue #52
- App onboarding flow translation (`GlobeKeyTutorialPage` etc.) — also separate
- Apple Intelligence post-correction (#141)
- App Store metadata / screenshots for German market

## 17 locked decisions (do NOT re-grill these)

See `.planning/issue-110-language-onboarding-handoff.md` for the full list. Most relevant for PR2:
- #1 — PR2 ships German as the dogfood (this PR)
- #4 — QWERTY layout only on launch (QWERTZ → #151)
- #6 — German `LanguageProfile.overrides` ships **empty** (ADR 0001)
- #7 — German `SEED_BIGRAMS_BY_LANG` ships **empty** (ADR 0001)
- #9 — Onboarding script API: `scaffold`, `build-dicts`, `wire-xcode`, `verify`
- #10 — Test split: per-language tests in `Tests/Languages/<Lang>LanguageTests.swift`
- #15 — Doc scope: `docs/agents/language-onboarding.md` ~150-200 lines

## Branch / PR strategy

- **Branch:** `feature/german-support` (already created, off `develop` at `5440231`)
- **PR target:** `develop` → after merge, follow the standard release flow: `release/v1.6.3` → `main` (then sync main → develop, sync main → feature/premium per the v1.6.2 playbook)
- **Tag the German user (`hmwagner` on issue #109)** when the build hits TestFlight, per locked decision #6 — invite override contributions from real usage
- **Always merge commits, never squash** (per `feedback_no_squash_merge.md`)

## Workflow guidance

- Pierre is non-native German speaker. ADR 0001 covers the policy: empty overrides + empty seeds = honest first ship. Don't try to curate German overrides from Duden lookups — that's the silent-regression failure mode the ADR explicitly rejects.
- The `tools/onboard_language.py` script should be built **incrementally as friction surfaces**, not designed up front. If `scaffold` is the only command needed for German, that's fine — `wire-xcode` etc. can be added when the next language hits the friction.
- Don't ask Pierre to re-validate the 17 locked decisions. If the work hits a question that contradicts a locked decision, **flag it explicitly** and ask before deviating.
- Validate on TestFlight before claiming German works. Simulator smoke test is necessary but not sufficient — the autocorrect quality is a function of corpus stats that only surface in real typing.

## Files to read first (in order)

1. **`.planning/issue-109-german-support-handoff.md`** — this file
2. **`.planning/issue-110-language-onboarding-handoff.md`** — PR1 plan + locked decisions
3. **`CONTEXT.md`** — domain glossary
4. **`docs/adr/0001-empty-overrides-and-seeds-for-non-native-language-launches.md`** — override/seed policy
5. **`DictusCore/Sources/DictusCore/Languages/{French,English,Spanish}.swift`** — templates by example
6. **`DictusCore/Sources/DictusCore/SupportedLanguage.swift`** — the enum to extend
7. **`tools/`** directory — Python pipeline. Identify the entry points before assuming structure.
8. **`git log --oneline 8efda46..HEAD`** on develop — see exactly what PR1 changed

## When this file becomes obsolete

Once PR2 merges, German ships, and `docs/agents/language-onboarding.md` exists as the canonical doc. Then both this file and `.planning/issue-110-language-onboarding-handoff.md` can be deleted — the decisions are captured in the doc, ADR 0001, and CONTEXT.md.
