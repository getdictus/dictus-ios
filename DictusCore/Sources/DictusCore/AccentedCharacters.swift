// DictusCore/Sources/DictusCore/AccentedCharacters.swift
// Long-press accent variants (per language, #1042) and the French-specific adaptive
// accent key (AZERTY row 3) namespace.
import Foundation

/// Accented character variants for keyboard long-press popups, per language (#1042).
///
/// Each language declares its own list in `LanguageProfile.longPressAccents`, in the order
/// Apple's keyboard for it shows them (`LongPressAccents`). This namespace turns that data
/// into what the popup of a given layout offers, and gives the shifted form of a variant.
///
/// WHY the layout matters: the layout is not the language since #272. A language whose
/// Apple layout has a key for a letter (German ä ö ü, Spanish ñ) leaves it out of its held
/// lists, and a layout without that key would then lose the letter entirely. Apple's
/// keyboard holds it right after its base letter there (German on QWERTY: a → ä à á…), so
/// `mappings(for:layout:)` does the same.
///
/// WHY precomposed Unicode characters (e.g., \u{00E9}) instead of combining characters:
/// Combining characters (e.g., "e" + combining acute \u{0301}) can cause string comparison
/// issues and display inconsistencies. Precomposed forms are single code points that render
/// identically everywhere. This is how iOS system keyboards store accented characters.
public enum AccentedCharacters {

    /// What a held letter offers in `language` on `layout`, keyed by lowercase base letter,
    /// variants only (the popup adds the base itself), lowercase.
    ///
    /// The language's own list, plus each of its `lettersWithOwnKey` that `layout` has no
    /// key for, placed first on its base letter.
    public static func mappings(for language: SupportedLanguage, layout: LayoutType) -> [String: [String]] {
        let profile = language.profile
        var mappings = profile.longPressAccents
        let onKeys = lettersOnTheirOwnKeys(layout)
        // Reversed so that, of two letters on the same base, the first listed ends up first.
        for letter in profile.lettersWithOwnKey.reversed() where !onKeys.contains(letter) {
            guard let base = baseLetter(of: letter) else { continue }
            var variants = mappings[base] ?? []
            variants.removeAll { $0 == letter }
            variants.insert(letter, at: 0)
            mappings[base] = variants
        }
        return mappings
    }

    /// The variants a held `key` offers in `language` on `layout`, or nil when it holds
    /// nothing. Lookup is case-insensitive: "E" and "e" return the same lowercase list;
    /// the keyboard capitalizes it on shifted pages with `shifted(_:)`.
    public static func accents(for key: String, language: SupportedLanguage, layout: LayoutType) -> [String]? {
        mappings(for: language, layout: layout)[key.lowercased()]
    }

    /// The form a variant takes on a shifted or caps-lock page: one key in, one key out.
    ///
    /// `KeyCaseTransform` already turns ß into ẞ rather than "SS" (#322). The dotless ı
    /// (English's held i) is the other exception: its Unicode capital is plain I, the key's
    /// own letter, so the popup would show I twice. Apple's shows İ there, and so does this.
    public static func shifted(_ variant: String) -> String {
        if variant == "\u{0131}" { return "\u{0130}" }  // ı → İ
        return KeyCaseTransform.uppercased(variant)
    }

    /// Accented letters `layout` draws on keys of their own, lowercase.
    ///
    /// WHY a switch and not a set kept by hand next to each layout: a new layout then fails
    /// to compile here until someone says which accented keys it has.
    private static func lettersOnTheirOwnKeys(_ layout: LayoutType) -> Set<String> {
        switch layout {
        case .qwertz:
            return Set(QWERTZLayout.lowercasedLettersRows.joined().filter { key in
                !key.unicodeScalars.allSatisfy(\.isASCII)
            })
        case .azerty, .qwerty:
            return []
        }
    }

    /// The unaccented letter an accented one is written on ("ä" → "a"), nil for a letter
    /// that decomposes to nothing else.
    private static func baseLetter(of letter: String) -> String? {
        guard let first = letter.decomposedStringWithCanonicalMapping.unicodeScalars.first else { return nil }
        let base = String(first)
        return base == letter ? nil : base
    }
}

/// French-specific adaptive accent key (AZERTY row 3) behaviour.
///
/// The data and rules in this namespace apply ONLY to French. Other languages
/// reach accents via standard long-press popups (`AccentedCharacters.mappings(for:layout:)`)
/// — they do not get an adaptive key at all. This namespace exists as its own
/// type so future readers cannot mistake the contents for a multilingual API.
///
/// Wired into the keyboard at the AZERTY layout's row 3 single key labelled
/// `"'"` with `alternate: "accent"`. `DictusKeyboardBridge` calls into this
/// namespace on each keystroke to decide what label the key should display
/// and what action it should take when tapped.
///
/// WHY every entry point takes a language (#272):
/// the key used to trigger purely off its physical presence on the AZERTY grid, with no
/// language check at all. That was harmless while AZERTY implied French. Now that the
/// layout is decoupled from the dictionary language, English/Spanish/German on AZERTY are
/// reachable combinations, and French adaptive accents on those keyboards would be wrong —
/// so outside French the key behaves as the plain apostrophe it is labelled with.
/// French on QWERTY is not the mirror problem: that grid has no adaptive key slot at all,
/// and those users reach accents through the standard long-press popups, which already
/// carry the French set.
public enum FrenchAdaptiveKey {

    /// Default accent per vowel (most common in French).
    /// Used by `label(...)` to decide the adaptive key's displayed character
    /// after the user types a vowel.
    public static let defaults: [String: String] = [
        "e": "\u{00E9}",  // e-acute (most common French accent)
        "a": "\u{00E0}",  // a-grave
        "u": "\u{00F9}",  // u-grave
        "i": "\u{00EE}",  // i-circumflex
        "o": "\u{00F4}"  // o-circumflex
    ]

    /// Bigrams where the second character is a vowel but the user almost certainly
    /// wants an apostrophe, not an accent. "qu" is the canonical French example:
    /// qu'il, qu'elle, qu'on, qu'un, qu'est-ce, etc.
    private static let apostropheBigrams: Set<String> = ["qu"]

    /// Returns what the adaptive key should display based on the last typed character.
    /// After a vowel: shows the most common French accent for that vowel.
    /// Otherwise (or after an apostrophe-bigram): shows apostrophe (').
    ///
    /// WHY apostrophe as default:
    /// In French, the apostrophe is the most common non-letter character after space.
    /// It appears in "l'", "d'", "n'", "j'", "c'", "s'" etc. Having it one tap away
    /// on the letters layer eliminates the 3-tap layer switch otherwise needed.
    ///
    /// - Parameter language: the active keyboard language by default; outside French the
    ///   key is a plain apostrophe (#272).
    public static func label(
        afterTyping lastChar: String?,
        precedingChar: String? = nil,
        language: SupportedLanguage = .active
    ) -> String {
        guard language == .french else { return "'" }
        guard let lastChar = lastChar else { return "'" }
        let lowered = lastChar.lowercased()

        // Check if the 2-char context triggers apostrophe override (e.g., "qu")
        if let prev = precedingChar?.lowercased() {
            let bigram = prev + lowered
            if apostropheBigrams.contains(bigram) {
                return "'"
            }
        }

        if let accent = defaults[lowered] {
            // Preserve original case: if user typed "A", return "À" not "à"
            return lastChar == lastChar.uppercased() && lastChar != lastChar.lowercased()
                ? accent.uppercased() : accent
        }
        return "'"
    }

    /// Returns true if the adaptive key should replace the previous character
    /// (i.e., when the key is showing an accent for a vowel, not apostrophe).
    /// Used by the bridge to call `deleteBackward()` before inserting the accent.
    /// Never replaces anything outside French, where the key inserts an apostrophe (#272).
    public static func shouldReplace(
        afterTyping lastChar: String?,
        precedingChar: String? = nil,
        language: SupportedLanguage = .active
    ) -> Bool {
        guard language == .french else { return false }
        guard let lastChar = lastChar?.lowercased() else { return false }
        if let prev = precedingChar?.lowercased() {
            let bigram = prev + lastChar
            if apostropheBigrams.contains(bigram) {
                return false
            }
        }
        return defaults[lastChar] != nil
    }

    /// Returns the base vowel that triggered the adaptive key's accent display.
    /// Used to determine which accent variants to show on long-press.
    /// Returns nil when the adaptive key is showing apostrophe (no long-press popup needed),
    /// which is every keystroke outside French (#272).
    public static func vowel(
        afterTyping lastChar: String?,
        precedingChar: String? = nil,
        language: SupportedLanguage = .active
    ) -> String? {
        guard language == .french else { return nil }
        guard let lastChar = lastChar?.lowercased() else { return nil }
        if let prev = precedingChar?.lowercased() {
            let bigram = prev + lastChar
            if apostropheBigrams.contains(bigram) {
                return nil
            }
        }
        return defaults[lastChar] != nil ? lastChar : nil
    }
}
