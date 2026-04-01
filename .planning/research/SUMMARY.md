# Project Research Summary

**Project:** Dictus v1.4
**Domain:** iOS Keyboard Extension — Prediction Engine Upgrade + Stability
**Researched:** 2026-04-01
**Confidence:** MEDIUM-HIGH

## Executive Summary

Dictus v1.4 is a focused incremental improvement to an existing production iOS keyboard extension. The core work is replacing the current UITextChecker-based spell correction with SymSpell (probabilistic, frequency-ranked), adding n-gram next-word prediction (a capability the current engine lacks entirely), fixing a known autocorrect state corruption bug (#67), and resolving open license compliance items (#63). The existing architecture — two-process model with DictusApp handling speech recognition and DictusKeyboard handling text input — is sound and requires no structural changes. All v1.4 work is additive within the existing keyboard extension.

The recommended implementation approach is strictly sequential by risk and dependency: fix the autocorrect bug first (independent, zero risk, validates the test harness), then integrate SymSpell (medium risk, must profile on device before proceeding), then build the n-gram data pipeline and predictor (medium risk, depends on corpus sourcing and binary format design), and finally wire next-word prediction into the suggestion bar UI. Cold start auto-return (#23) is explicitly deferred — Apple DTS confirmed in January 2026 that no public API exists for this, and the existing swipe-back overlay already works for 100% of apps.

The primary risk across all v1.4 work is memory pressure in the 50MB keyboard extension limit. SymSpell pre-computes deletion variants (potentially 15-30MB if not tuned), and n-gram binary data adds another 5-10MB. Both components must be profiled on a physical iPhone SE or iPhone 12 (the tightest-memory supported devices) before any feature work is considered complete. The mitigation strategy is clear: 30K-word SymSpell dictionary with prefix length 7 and adaptive edit distance, and a memory-mapped flat binary trie for n-grams (not a Swift Dictionary, which would balloon to 40-50MB). Staying within these bounds leaves ~20-25MB headroom.

## Key Findings

### Recommended Stack

The stack changes for v1.4 are minimal by design. One new SPM dependency is added: **SymSpellSwift** (github.com/gdetari/SymSpellSwift, v0.1.4, MIT). The n-gram component uses no external library — it is a custom pure-Swift binary trie with offline data preparation scripts. KenLM was evaluated and rejected: it is a C++ library with no Swift binding, requires CMake/Boost, and produces 50-500MB model files that are impossible in a 50MB keyboard extension. The existing stack (Swift 5.9+, SwiftUI, WhisperKit, FluidAudio, giellakbd-ios, DeviceKit, DictusCore) is unchanged.

Two new bundled data files are required: a French frequency dictionary for SymSpell (~2-3MB TSV) sourced from Lexique 3.83 or OpenSubtitles, and a French trigram binary file (~5-10MB) built from French Wikipedia/OpenSubtitles with an offline Python/Swift CLI tool. English variants of both files are needed as well. These are not dependencies — they are build-time artifacts bundled in the DictusKeyboard target.

**Core technologies:**
- **SymSpellSwift 0.1.4** (SPM, recommend vendoring): spell correction via symmetric delete algorithm — replaces UITextChecker for corrections, frequency-ranked output, O(1) lookup, pure Swift, MIT license; vendor source (~500 lines) to enable direct bug fixes for French Unicode edge cases
- **Custom NgramTrie** (no library): flat sorted binary array with binary search, memory-mapped at runtime — 16 bytes/entry vs ~80 bytes/entry for a Swift Dictionary; 500K trigrams = ~8MB flat vs ~40MB nested
- **UITextChecker** (system, kept): word completions during partial typing — retained because it handles French morphology at zero memory cost; SymSpell is for spell correction only, not prefix completion
- **Lexique 3.83 / OpenSubtitles French corpus** (data, offline build): gold-standard French word frequency source for SymSpell dictionary curation
- **fr_symspell.txt + fr_trigram.bin** (bundled data files): runtime data added to DictusKeyboard target

### Expected Features

**Must have (table stakes):**
- Word completion while typing — upgrade from UITextChecker (alphabetical) to SymSpell (frequency-ranked); "helo" corrects to "hello" not "helons"
- Spell correction on space — UITextChecker.guesses() is alphabetical; SymSpell provides frequency-ranked corrections matching user intent
- Undo autocorrect on backspace — iOS standard since iOS 6; currently broken (bug #67); must be fixed before any prediction engine changes
- Accent correction (e.g. "cafe" → "café") — already works; SymSpell must preserve this via the frequency dictionary

**Should have (differentiators):**
- Next-word prediction — predicts what user types AFTER completing a word; requires n-gram model; biggest visible upgrade in v1.4
- Offline-only prediction — all data on-device, no cloud; already the architecture, reinforced by bundled data files

**Defer to v2+:**
- Cold start auto-return — no public iOS API exists; Apple DTS confirmed January 2026; Wispr Flow's apparent auto-return is UX-guided (system back arrow), not programmatic
- Swipe typing — massive effort, patent risks
- User dictionary learning — storage, privacy, sync complexity
- Personalized n-gram retraining — training pipeline complexity; pre-built corpus model is sufficient for v1.4

### Architecture Approach

The v1.4 architecture is an additive extension of the existing TextPrediction layer within DictusKeyboard. The two-process model and App Group communication are unchanged. Three new components are added inside DictusKeyboard/TextPrediction/: `SymSpellEngine` (wraps SymSpellSwift, handles spell correction), `NgramPredictor` (orchestrates trigram/bigram/unigram backoff), and `NgramTrie` (memory-mapped flat binary data structure). The existing `TextPredictionEngine` is modified as orchestrator to route between SymSpell (corrections) and UITextChecker (completions, kept). `SuggestionState` gains a new `.nextWord` mode for post-space predictions. The single-language loading pattern from FrequencyDictionary is extended to SymSpell and n-gram — load only one language at a time, swap on language change.

**Major components:**
1. **SymSpellEngine** — wraps SymSpellSwift, loads `{lang}_symspell.txt`, exposes `correct(_:)` with adaptive edit distance (1 for short words, 2 for longer)
2. **NgramPredictor** — orchestrates trigram/bigram backoff, wraps NgramTrie, exposes `predict(context:max:)`
3. **NgramTrie** — memory-mapped flat sorted array (16 bytes/entry), binary search for trigram/bigram lookup, loaded from `{lang}_trigram.bin`
4. **TextPredictionEngine (modified)** — UITextChecker for completions (kept), SymSpell for corrections (new), NgramPredictor for next-word (new), fallback to UITextChecker during async SymSpell load
5. **SuggestionState (modified)** — adds `.nextWord` mode, context extraction (last 1-2 words after space), clears `lastAutocorrect` synchronously on main thread in key handler (fixes #67)
6. **Offline build tool** — macOS CLI or Python script to generate `{lang}_trigram.bin` from corpus; runs at development time only

### Critical Pitfalls

1. **SymSpell dictionary pre-computation exceeds memory budget** — a 100K-word dictionary with edit distance 2 can consume 15-30MB during pre-computation, killing the extension silently. Fix: cap at 30K words, adaptive edit distance (1 default), prefix length 7, load async with UITextChecker fallback. Profile with Instruments on iPhone SE or iPhone 12 after every dictionary size change.

2. **N-gram stored as Swift Dictionary instead of flat binary trie** — Swift Dictionary overhead is ~80 bytes/entry; 500K trigrams = ~40MB. Flat sorted array at 16 bytes/entry = ~8MB. Use memory-mapped binary from the start. Never use `[String: [String: [String: Int]]]`.

3. **Cold start auto-return is impossible via public iOS API** — Apple DTS explicitly confirmed (January 2026), `_hostBundleID` is private and broken in iOS 26.4 beta, LSApplicationWorkspace causes App Store rejection. Do not re-research. Timebox any investigation to 2 hours maximum.

4. **Autocorrect state race condition** — `lastAutocorrect` must be cleared synchronously on the main thread in `DictusKeyboardBridge.handleInputKey()`, not inside the async suggestion callback. A fast typist can trigger the autocorrect async callback AFTER the main-thread clear, re-setting the corrupt state. Fix bug #67 in isolation before touching the prediction engine.

5. **SymSpellSwift library quality** — 16 commits, single author, no test suite, potential Unicode issues with French combining diacritical marks (NFC vs NFD). Vendor the source into DictusKeyboard/TextPrediction/SymSpell/ and write French-specific integration tests (e/é/è/ê, l'homme, aujourd'hui, peut-être).

## Implications for Roadmap

Based on research, the build order is dependency-driven with clear risk gates between phases.

### Phase 1: Autocorrect Bug Fix + License Updates (#67, #63)

**Rationale:** Bug #67 must be fixed in isolation. With the current prediction engine as baseline, the fix is verifiable (type after autocorrect → backspace should delete, not undo correction). If fixed after SymSpell is introduced, the async race becomes harder to isolate. License updates (#63) are trivial text changes — ship them together.

**Delivers:** Working autocorrect undo behavior matching iOS standard; correct license attributions in SettingsView (Parakeet/NVIDIA + SymSpellSwift MIT attribution)

**Addresses features:** Undo autocorrect on backspace (table stakes), license compliance (#63)

**Avoids:** Pitfall 4 (async race in autocorrect state), Pitfall 13 (accent flow interaction with autocorrect undo)

**Research flag:** No research phase needed — root cause is identified, fix location is known.

### Phase 2: SymSpell Dictionary Preparation + Integration (#68 part 1)

**Rationale:** SymSpell replaces UITextChecker for spell correction — the biggest quality improvement for the most common keyboard interaction. Must come before n-gram because the SymSpell frequency dictionary becomes the vocabulary source for n-gram pruning. Dictionary curation (30K words from Lexique 3.83) must be validated against real French text before coding SymSpellEngine — garbage-in-garbage-out risk is high.

**Delivers:** SymSpellEngine integrated into TextPredictionEngine; spell correction quality upgrade ("helo" → "hello"); UITextChecker kept as fallback during async load

**Uses:** SymSpellSwift (vendored source), Lexique 3.83, fr_symspell.txt + en_symspell.txt

**Implements:** SymSpellEngine, modified TextPredictionEngine.spellCheck()

**Avoids:** Pitfall 1 (memory — 30K words, edit distance adaptive, prefix=7, async load), Pitfall 6 (dictionary quality — Lexique 3.83 curation), Pitfall 10 (library quality — vendor source), Pitfall 9 (double memory — release UITextChecker after SymSpell loads)

**Research flag:** May need targeted research on Lexique 3.83 format and filtering methodology. Memory profiling on physical device is mandatory before proceeding to Phase 3.

### Phase 3: N-gram Binary Data Pipeline + Trie Data Structure (#68 part 2)

**Rationale:** The binary format and offline build tool must exist and be validated before any predictor code is written. Building the data structure first allows testing trie load, binary search correctness, and memory footprint in isolation. If corpus sourcing or memory usage is unacceptable, the approach can be adjusted before Phase 4 wires it into the live keyboard.

**Delivers:** NgramTrie Swift data structure; offline build tool (CLI or Python script); validated fr_trigram.bin and en_trigram.bin bundled in DictusKeyboard target

**Uses:** French Wikipedia/OpenSubtitles corpus; custom binary format (flat sorted array, 16 bytes/trigram entry, mmap)

**Implements:** NgramTrie, offline corpus processing tool

**Avoids:** Pitfall 2 (n-gram too large — flat binary trie, not Swift Dictionary), Pitfall 7 (French morphology — custom French tokenizer for elisions), Pitfall 12 (English bleed — monolingual corpus filtering), Pitfall 11 (apostrophe handling — custom tokenizer, not .byWords enumeration)

**Research flag:** Needs a brief spike on French corpus sourcing and tokenization strategy. French NLP tokenization for elisions is a known domain — bounded research, not open-ended.

### Phase 4: NgramPredictor Integration + Next-Word UI (#68 part 3)

**Rationale:** NgramPredictor is a thin wrapper around NgramTrie (Phase 3). Once the trie is validated, wiring the predictor into TextPredictionEngine and adding `.nextWord` SuggestionState mode is straightforward. Chained prediction (tap word → new predictions) completes the feature.

**Delivers:** Full next-word prediction — after completing a word (space typed), suggestion bar shows 3 predicted next words; tapping a word inserts it and refreshes predictions; chained prediction works end-to-end ("Je" → "suis" → "un")

**Implements:** NgramPredictor, modified TextPredictionEngine.nextWordPredictions(), SuggestionState .nextWord mode + context extraction, SuggestionBarView next-word rendering, KeyboardRootView tap handler

**Avoids:** Pitfall 5 (no n-gram queries on partial words — only after word boundary), Pitfall 8 (timing regression — single async dispatch for SymSpell + n-gram), Pitfall 3 (no C++ bridging — pure Swift)

**Research flag:** Standard iOS SwiftUI patterns — no research phase needed. SuggestionBarView mode extension follows established patterns from .completions and .accents modes.

### Phase 5: Cold Start UX Polish + sourceApplication Investigation (#23)

**Rationale:** Cold start auto-return is explicitly deferred from phases 1-4. A bounded investigation (2-hour timebox) of the `sourceApplication` approach is worthwhile: if `application(_:open:options:)[.sourceApplication]` returns the host app's bundle ID when opened via URL scheme, the overlay text can be personalized ("Swipe back to WhatsApp"). This is a UX improvement, not auto-return. A 5-minute on-device test determines the entire strategy.

**Delivers:** More informative swipe-back overlay if sourceApplication is viable; otherwise, confirmed closure of #23

**Avoids:** Pitfall 4 (do not attempt private APIs, do not exceed 2-hour timebox)

**Research flag:** 5-minute on-device test, no coding until test result is known.

### Phase Ordering Rationale

- **Bug fix first** — autocorrect state bug is harder to diagnose with two correction engines running (UITextChecker during SymSpell load + SymSpell after load). Requires a clean, known-good baseline.
- **Data before code for n-gram** — corpus sourcing and binary format must precede predictor implementation to avoid discovering format incompatibilities during integration.
- **SymSpell before n-gram** — the SymSpell vocabulary becomes the pruning filter for n-gram entries; only words in the SymSpell dictionary appear as n-gram predictions.
- **Cold start last** — highest risk, lowest success probability. Do not let it block the milestone.
- **Memory gate between phases** — Phase 2 (SymSpell) and Phase 3 (n-gram binary) each require device profiling before the next phase begins. No exceptions.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (SymSpell dictionary):** French corpus sourcing and filtering — Lexique 3.83 format, combining with OpenSubtitles frequencies, lemmatization strategy. Bounded to known sources, not open-ended.
- **Phase 3 (N-gram pipeline):** French tokenization for elisions (l'homme, aujourd'hui, peut-être) and iOS version inconsistencies in `.byWords` enumeration.

Phases with standard patterns (skip research phase):
- **Phase 1 (Bug fix + licenses):** Root cause identified, fix location known. No unknowns.
- **Phase 4 (NgramPredictor + UI):** Follows established SymSpellEngine pattern and existing SuggestionState mode structure. No new APIs.
- **Phase 5 (Cold start UX):** A single 5-minute device test determines the strategy.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | SymSpellSwift is verified but young (9 months, 16 commits). Custom n-gram is well-understood algorithmically but untested at this memory budget on iOS. KenLM rejection is HIGH confidence. |
| Features | HIGH | Feature scope is tightly defined by existing GitHub issues (#63, #67, #68, #23). Table stakes are clear from current codebase. Anti-features are clearly justified. |
| Architecture | HIGH | Based on direct codebase analysis of TextPredictionEngine, SuggestionState, DictusKeyboardBridge. Integration points are clear. Memory budget analysis based on algorithm documentation — needs empirical device validation. |
| Pitfalls | HIGH | Grounded in Apple DTS responses, codebase audits, SymSpell documentation, and documented issue analysis. Cold start impossibility confirmed by Apple DTS January 2026. Memory pressure pitfalls are well-documented in iOS extension community. |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **SymSpell memory on physical device:** Estimates (3-5MB for 30K-word dict, prefix=7, edit distance 2) are based on algorithm analysis. Must be closed with Instruments profiling on iPhone SE or iPhone 12 in Phase 2 before Phase 3 begins.
- **sourceApplication feasibility:** No confirmation that `options[.sourceApplication]` returns the keyboard host app bundle ID. A 5-minute on-device test at the start of Phase 5 resolves this completely.
- **French tokenization across iOS versions:** `.byWords` string enumeration handles apostrophes inconsistently between iOS 17 and 18+. Custom French tokenizer is recommended but needs test confirmation of specific failure cases.
- **SymSpellSwift Unicode correctness:** No test suite exists. French-specific edge cases (combining diacritical marks, NFC vs NFD normalization) need integration tests written in Phase 2 before shipping.

## Sources

### Primary (HIGH confidence)
- Dictus codebase: TextPredictionEngine.swift, SuggestionState.swift, DictusKeyboardBridge.swift, FrequencyDictionary.swift, KnownAppSchemes.swift — direct code analysis
- [SymSpell algorithm (wolfgarbe)](https://github.com/wolfgarbe/SymSpell) — symmetric delete documentation, memory optimization, prefix length optimization
- [SymSpellSwift (gdetari)](https://github.com/gdetari/SymSpellSwift) — Swift port v0.1.4, MIT license, source audited
- [Apple DTS response on keyboard auto-return (January 2026)](https://developer.apple.com/forums/thread/118709) — "No API exists" confirmation
- `assets/reference/issue-23-report.md` — comprehensive cold start research documenting 3 failed approaches
- GitHub issues #23, #67, #68 — root cause analyses and proposed solutions
- [Lexique 3.83](http://www.lexique.org/) — French psycholinguistic database, gold standard for French word frequencies
- [Apple Custom Keyboard programming guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) — extension memory limits and API restrictions

### Secondary (MEDIUM confidence)
- [SymSpellSwift on Swift Package Index](https://swiftpackageindex.com/gdetari/SymSpellSwift) — version and compatibility metadata
- [KenLM](https://github.com/kpu/kenlm) — evaluated and rejected; C++, LGPL, 50-500MB models
- [KeyboardKit iOS 26.4 hostApplicationBundleId bug](https://keyboardkit.com/blog/2026/03/02/ios-26-4-host-application-bundle-id-bug) — confirms `_hostBundleID` private API broken in iOS 26.4 beta
- [HeliBoard / AOSP dictionaries](https://codeberg.org/Helium314/aosp-dictionaries) — reference for pre-trained language models and linguistic quality
- [iOS keyboard extension memory limits](https://developer.apple.com/forums/thread/85478) — 30-50MB experimentally determined
- [Wiktionary French frequency lists](https://en.wiktionary.org/wiki/Wiktionary:Frequency_lists/French) — alternative corpus source

### Tertiary (LOW confidence)
- [Swift Forums: auto-return techniques](https://forums.swift.org/t/how-do-voice-dictation-keyboard-apps-like-wispr-flow-return-users-to-the-previous-app-automatically/83988) — no public API solution; Wispr Flow mechanism undocumented
- [N-gram language model overview (Stanford)](https://web.stanford.edu/~jurafsky/slp3/3.pdf) — textbook reference for backoff and pruning strategies
- [SymSpell memory optimization issue #16](https://github.com/wolfgarbe/SymSpell/issues/16) — prefix length optimization discussion

---
*Research completed: 2026-04-01*
*Ready for roadmap: yes*
