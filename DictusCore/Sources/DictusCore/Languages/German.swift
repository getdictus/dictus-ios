// DictusCore/Sources/DictusCore/Languages/German.swift
// German language profile. First non-French/English/Spanish language onboarded
// via the LanguageProfile system. Override map and seed bigrams ship empty per
// ADR 0001 — the maintainer is non-native, populated post-launch from feedback.
import Foundation

/// German (`de`).
///
/// Layout: QWERTY on launch (QWERTZ deferred to follow-up issue #151).
/// Overrides: empty per ADR 0001 (populated post-launch from native-speaker feedback on issue #109).
/// Contractions: empty — German `geht's`/`gibt's` style elisions are rare and not curated.
public let germanProfile = LanguageProfile(
    code: "de",
    displayName: "Deutsch",
    shortCode: "DE",
    defaultLayout: .qwerty,
    spaceName: "Leertaste",
    returnName: "Eingabe",
    overrides: [:],
    accentMap: [
        "a": ["\u{00E4}"],          // ä  (a-umlaut)
        "o": ["\u{00F6}"],          // ö  (o-umlaut)
        "u": ["\u{00FC}"],          // ü  (u-umlaut)
        // ß is reached via the collapseRules ss→ß below, not single-char
        // substitution — it would require deleting a position, which the
        // single-char accent substitution algorithm doesn't model. Long-press
        // on `s` is still wired via AccentedCharacters.mappings.
    ],
    contractionPrefixes: [],
    collapseRules: [
        // German `ss → ß` collapse. Lets users on QWERTY (no dedicated ß key)
        // get `straße`, `weiß`, `groß`, `Spaß`, `heißen`, `müssen → muss`,
        // etc. Same 5x dominance protection as single-char accent expansion:
        // `muss` (valid 1st/3rd-person verb form) won't be over-corrected to
        // `muß` because both are valid and the dominance check rejects it.
        ("ss", "\u{00DF}"),
    ]
)
