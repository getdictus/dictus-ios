# Issue #110 + #109 — Language onboarding refactor handoff

**Branch:** `feature/language-profile-refactor` (off `develop`)
**Status:** Phase 1 done (commit `8efda46`). Phase 2 next.
**Plan source:** /grill-with-docs session 2026-05-04/05 — 17 decisions locked.

## Why this work exists

- **#110** — make adding a new language fast and safe (recurring requests: Spanish #83, German #109, more coming).
- **#109** — German language support; blocked on #110.
- This branch ships **both** together (PR2 will use the system to onboard German as the dogfood proof).

## Branch / PR strategy

- **PR1** = `feature/language-profile-refactor` → `develop` → TestFlight → 24-48h soak on fr/en/es. Behavior-preserving refactor only.
- **PR2** = `feature/german-support` (off updated `develop`) → `develop` → TestFlight → tag `hmwagner` for testing.
- Two separate ships so the refactor's "no-op for fr/en/es" claim is empirically validated before German is layered on.
- Always merge commits, never squash.

## Phase status

- ✅ **Phase 0** (commit `d60bdf2`): `CONTEXT.md` + ADR 0001 (override/seed policy)
- ✅ **Phase 1** (commit `8efda46`): `LanguageProfile` struct + algorithm helpers + `FrequencyProvider` protocol + 57 new tests + 5 stale-test fixes. **193/193 DictusCore tests pass.**
- ⬜ **Phase 2** (next): refactor `AOSPTrieEngine` to consume the helpers
- ⬜ **Phase 3**: gate adaptive accent key as French-only + derive `SettingsView` picker from `SupportedLanguage.allCases`
- ⬜ **PR1 ready**: smoke test 6 cases, push, open PR

After PR1 merges + 24-48h soak, PR2 begins.

## 17 locked decisions (do NOT re-grill these)

1. **Scope of branch**: deliver #110 + #109 together. German is the dogfood.
2. **Artifact shape**: hybrid — `tools/onboard_language.py` + `docs/agents/language-onboarding.md` checklist.
3. **Refactor depth**: aggressive, one file per language. Guardrails: regression tests first, refactor before German, profile = pure data, separate commits.
4. **Layout for German**: QWERTY only on launch; QWERTZ → follow-up issue #151.
5. **Adaptive accent key**: stays French-only, explicitly gated/renamed in Phase 3.
6. **German `LanguageProfile.overrides`**: empty on first ship (ADR 0001). Pierre pings `hmwagner` post-launch for contributions.
7. **German seed bigrams**: also empty on first ship (ADR 0001). Wikipedia + OpenSubtitles + Google Books pipeline runs alone.
8. **Settings picker UX**: leave as-is; cycle includes German automatically. Improvement tracked in #52.
9. **Onboarding script API**: phased commands — `scaffold`, `build-dicts`, `wire-xcode`, `verify`.
10. **Test split**: regression in `DictusCoreTests`; per-language in `Tests/Languages/<Lang>LanguageTests.swift` (one file per language). Onboard script scaffolds both.
11. **Branches**: PR1 + PR2 (see above).
12. **TestFlight cadence**: ship after each PR merge with 24-48h soak between.
13. **`LanguageProfile` shape**: minimal Swift-side. Python tooling stays standalone with its own `LANG_MAP` / seeds / stopwords. Code consistency verified by `onboard_language.py verify`.
14. **`LanguageProfile` location**: `DictusCore/Sources/DictusCore/Languages/<Lang>.swift`, free-standing constants, `SupportedLanguage.profile` is a switch (compile-time exhaustive).
15. **Doc scope**: `docs/agents/language-onboarding.md` = reference + checklist + rationale (~150-200 lines). Post-launch quality playbook = separate issue #152.
16. **Follow-up issues**: #151 (QWERTZ) and #152 (post-launch playbook) filed before starting work.
17. **Test approach** (overriding the original "byte-for-byte tests on AOSPTrieEngine" plan): refactor algorithms into pure-Swift DictusCore helpers driven by a `FrequencyProvider` protocol. Algorithm tests in `DictusCoreTests` use `MockFrequencyProvider`. Bridge integration covered by manual smoke test, not by a new Xcode test target.

## Out of scope (do NOT pull in)

- UI string localization (`Localizable.xcstrings`)
- App onboarding flow translation (`GlobeKeyTutorialPage` etc.)
- App Store metadata / screenshots
- Apple Intelligence post-correction (#141)
- QWERTZ layout (deferred to #151)

## Phase 2 work (concrete)

**Touch points:**
- `DictusKeyboard/TextPrediction/AOSPTrieEngine.swift`: replace internal `languageOverrides` dict, accent map switch, and contraction prefix list with calls to `applyOverride(profile:word:)`, `expandAccents(profile:word:provider:)`, `expandContractions(profile:word:provider:)` from DictusCore.
- Make `AOSPTrieEngine` conform to `FrequencyProvider` (or wrap the bridge in an adapter). Methods needed: `isReady`, `frequency(of:)`, `wordExists(_:)`. Already exist on the bridge — adapt the names.
- Public API of `AOSPTrieEngine` (`spellCheck`, `accentExpansion`, `contractionExpansion`, `languageOverride`) stays the same — internal delegation only.
- `DictusKeyboard/TextPrediction/TextPredictionEngine.swift`: replace `if language == "fr"` checks with `profile.contractionPrefixes.isEmpty` reads (or equivalent semantic).

**Validation:**
- 193/193 DictusCore tests still pass.
- Full Xcode build (DictusApp + DictusKeyboard + DictusWidgets) clean.
- Smoke test 6 cases (below) on simulator before commit.

**Commit shape:** one commit, `feat(#110): AOSPTrieEngine consumes DictusCore helpers`. No behavior change for fr/en/es.

## Phase 3 work (concrete)

- Gate the adaptive accent key as French-only: rename `AccentedCharacters.defaultAccents` / `apostropheOverrides` / `adaptiveKeyLabel` etc. to make the French-only nature explicit in code. Could move into `Languages/French.swift`. Document in checklist (PR2).
- `SettingsView` picker: derive from `SupportedLanguage.allCases` instead of hardcoded `Text("…").tag("…")`.

## Smoke test runbook (use after Phase 2 build is on simulator)

iPhone 17 Pro simulator. Branch: `feature/language-profile-refactor`.

1. **French (AZERTY)**: type `cest une bonne idee` → expect `c'est une bonne idée`
2. **French**: type `tres bien` → expect `très bien`
3. **French**: type `lhomme apres ca` → expect `l'homme après ça`
4. **French**: type `je publie un livre` → expect `publie` to STAY `publie` (5x dominance rejects)
5. **English (QWERTY)**: switch to EN, type `i dont know` → expect `I don't know`
6. **Spanish (QWERTY)**: switch to ES, type `espanol` → expect `español`

Any failure on these 6 = refactor regression. Don't merge PR1 without all 6 passing.

## Files Pierre may forget exist

- `CONTEXT.md` (repo root) — domain glossary, written 2026-05-04 (commit `d60bdf2`)
- `docs/adr/0001-empty-overrides-and-seeds-for-non-native-language-launches.md` — override/seed policy (commit `d60bdf2`)
- This file — phase plan (committed alongside it)
- Memory file `project_language_onboarding_phase_plan.md` (mirror of this content, in Claude memory)

## Stash

`Localizable.xcstrings` modification stashed at session start (unrelated, pre-existing build experiment). `git stash list` shows it.

## When this file becomes obsolete

Once PR2 merges (German shipped) and `docs/agents/language-onboarding.md` exists as the canonical onboarding doc, this planning file can be deleted. The decisions are captured in commit messages, ADR 0001, the doc, and CONTEXT.md.
