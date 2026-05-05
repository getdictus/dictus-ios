# 0001 — Empty overrides and seed bigrams for non-native language launches

- **Date:** 2026-05-05
- **Status:** Accepted
- **Context:** Issue #110 (language onboarding system), issue #109 (German support, dogfood).

## Decision

When onboarding a new transcription language whose maintainer is **not a native speaker** of that language:

- `LanguageProfile.overrides` ships **empty** on first launch.
- `tools/ngram_builder.py::SEED_BIGRAMS_BY_LANG[code]` ships **empty** on first launch.
- The autocorrect pipeline relies on its three other layers: edit-distance trie, accent expansion, and the encyclopedic n-gram corpus (Wikipedia + OpenSubtitles + Google Books).
- Override map and seed bigrams are populated **post-launch** from real user feedback or native-speaker contributions, tracked on the language's GitHub issue.

This applies to German on its first ship (PR2 of the language onboarding work) and becomes the documented default for future languages onboarded under the same conditions.

## Why

**The override map and seed bigrams require native-speaker judgment.**

`LanguageProfile.overrides` is the *must-correct* map: words where pure edit-distance gets it wrong and we hard-code the answer. French uses it for `ca → ça`, `tres → très`, `deja → déjà`. The list is small (~14 entries) and every entry is a claim that the input is *never* a valid word in the language. Producing a correct list requires knowing which words are unambiguously misspelled vs. which are valid alternatives a non-native maintainer would mistake.

Seed bigrams (`tools/ngram_builder.py`) are the *conversational* word pairs underrepresented in the encyclopedic corpus we mine. French seeds include `("ça", "va")`, `("je", "pense")`, `("pas", "mal")` — pairs that are obvious to a native ear but rare in Wikipedia's tone register. Producing a correct list requires fluent intuition for spoken-form usage.

Issue #109's reporter (`hmwagner`) summarized the failure mode bluntly: "the keyboard makes things worse." A half-curated override map reproduces that exact failure mode in a new shape: false-positive corrections destroy user trust faster than missing corrections do.

Spanish was shipped with an empty override map in PR #ff6a2df (issue #83). The world did not end. That is empirical evidence the trie + accent expansion + n-grams cover the 80% case adequately, and it gives us the precedent.

## Alternatives considered

**Curate the lists manually using online resources (Duden, frequency lists).** Rejected because "conservative selection" depends on knowing the language well enough to tell which words are unambiguous. The failure mode is silent — the user types `schon`, gets `schön`, doesn't immediately notice the autocorrect was wrong. Silent regressions are exactly what #109 already reports.

**Block the language launch on native-speaker review.** Rejected for time-to-ship. Issue #109's reporter has been waiting since 2026-04-13. Asking them to wait additional weeks for override curation when the rest of the pipeline works fine is a poor trade.

**Ship a manifest format where overrides are structurally required.** Rejected as forcing the wrong answer. Empty is honest; partially-wrong is worse than empty.

## Consequences

**Positive.**
- The onboarding process is doable by a maintainer who doesn't speak the target language. Italian, Portuguese, and other future requests are unblocked the same way German is.
- Quality improvements are *user-driven* rather than maintainer-guessed. Real corrections people complain about become real overrides.
- The `docs/agents/language-onboarding.md` checklist is honest about what the process can and cannot deliver on day one.

**Negative.**
- First-launch quality for non-French/English languages is lower than a fully-curated launch would be.
- We rely on user feedback being filed (otherwise overrides never get added). Need an explicit "post-launch playbook" doc to make the feedback loop reliable — tracked as a separate follow-up issue.

**Reversibility.**
Reversible per-language. Any future language launched by a native-speaker maintainer (or with one available for review) can ship with curated overrides and seeds. The policy is the *default* for non-native launches, not a constraint on all launches.

## Implementation notes

- `Languages/German.swift` ships with `overrides = [:]` and the accent map populated (accent map is generative, not curated — populating it doesn't require fluency).
- `tools/ngram_builder.py::SEED_BIGRAMS_BY_LANG` does not gain a `"de"` entry; the build runs without seeds for German.
- The German launch comment on issue #109 explicitly invites the reporter and other German users to suggest overrides via issue comments.
- `docs/agents/language-onboarding.md` documents this policy under "Curated decisions" so future maintainers don't read empty maps as a bug.
