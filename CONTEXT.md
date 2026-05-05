# Dictus — Domain Context

Living glossary of the terms that domain conversations rely on. When a term in conversation conflicts with what's defined here, raise it: the glossary or the conversation needs to change.

## Languages and onboarding

### Language onboarding
The process of adding a new transcription language to Dictus. **Distinct from user onboarding** (the first-run tutorial pages in `DictusApp/Onboarding/`). Language onboarding is a maintainer-facing workflow defined by `tools/onboard_language.py` + `docs/agents/language-onboarding.md`.

### Supported language
A language registered in `DictusCore/SupportedLanguage.swift` as an enum case. Registration unlocks: settings picker entry, keyboard toolbar cycle slot, autocorrect/predict pipeline, transcription language hint to Whisper. **Adding a `SupportedLanguage` case is the act of "registering" the language** — the script and checklist exist to make every other touch point a mechanical follow-on.

### Language profile (`LanguageProfile`)
The per-language data struct in `DictusCore/Languages/LanguageProfile.swift`. Pure data — no logic. One file per language (`French.swift`, `English.swift`, `Spanish.swift`, `German.swift`). Holds: code, displayName, shortCode, defaultLayout, spaceName, returnName, longPressAccents, overrides, accentMap, contractionPrefixes. Algorithms in `AOSPTrieEngine` and elsewhere read the profile; they don't switch on language code.

### Override map (`LanguageProfile.overrides`)
Per-language **must-correct** map: input → forced correction, applied before edit-distance lookup. Used for cases the trie can't infer (e.g., French `ca → ça`: "ca" is itself never a valid French word). **Distinct from accent map** (which is generative — try adding accents and check the dict) and from **edit-distance correction** (which is statistical). Policy: empty for new languages on first ship; populated from real user feedback. See ADR 0001.

### Accent map (`LanguageProfile.accentMap`)
Per-language map from base letter to accented variants used by `accentExpansion()` to attempt accent insertions when a typed word isn't in the dictionary. Generative, not curated — you list which accents *could* apply to which letters, then the algorithm tries them and picks the highest-frequency hit.

### Adaptive accent key
A French-specific feature of the AZERTY layout: the apostrophe/accent key on row 3 changes its label based on context (shows `é` after `e`, apostrophe after `qu`, etc.). **Not generalized to other languages.** Lives in `DictusCore/Languages/French.swift`. Other languages reach accents via standard long-press popups.

### Seed bigrams
Hand-curated word pairs injected into the n-gram corpus by `tools/ngram_builder.py` to compensate for underrepresentation in encyclopedic sources (Wikipedia, Google Books). Required for splitting compound input like `pasmal → pas mal`. Per-language list in `SEED_BIGRAMS_BY_LANG`. Policy: empty for new languages onboarded by non-native maintainers; populated post-launch from native-speaker contributions. See ADR 0001.

### Onboarding script (`tools/onboard_language.py`)
Phased command-line tool that handles the deterministic parts of language onboarding: `scaffold` (create `Languages/<Lang>.swift`, register stubs), `build-dicts` (run dictionary pipeline), `wire-xcode` (edit `project.pbxproj`), `verify` (run regression + per-language tests). Curated decisions (display name, layout, accent map, override population) stay manual and live in `docs/agents/language-onboarding.md`.

## Speech-to-text

### Transcription language
The language hint passed to the active STT engine. Read from App Group via `SharedKeys.language`. Whisper uses it as a forced-decode hint; Parakeet auto-detects and ignores it. Set by user via the settings picker or the keyboard toolbar cycle.

### STT engine
A speech-to-text backend conforming to `SpeechModelProtocol`. Two exist today: `WhisperKitEngine` (local Whisper variants) and `ParakeetEngine` (FluidAudio Parakeet v3, auto-detects language). New engines plug in via the protocol; language registration is engine-agnostic.

## Keyboard

### Layout type
The physical key arrangement: `LayoutType.azerty` (French) or `LayoutType.qwerty` (English, Spanish, German). Each `SupportedLanguage` declares its `defaultLayout`. Layout is global today (one active at a time), not per-language; per-language layout selection is tracked in issue #52.

### Long-press accents (`AccentedCharacters.mappings`)
Pop-up accent variants shown when a key is long-pressed. Currently merged across languages (French + Spanish ñ + acute variants), keyed by base letter. To be migrated into `LanguageProfile.longPressAccents` so each language declares its own popups.
