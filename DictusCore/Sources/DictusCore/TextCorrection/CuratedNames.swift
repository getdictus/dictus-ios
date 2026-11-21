// DictusCore/Sources/DictusCore/TextCorrection/CuratedNames.swift
// App and brand names autocorrect never touches, with the casing they are
// written in. Reported on device: "Dictus" became "Rictus", and "iphone" became
// "Iphone", the casing of a contact.
//
// WHY here and not in the spellcheck dictionaries: `tools/dict_builder.py`
// lowercases every word, so a trie entry cannot say "iPhone". And not in
// `LanguageProfile.overrides`: those are per-language must-correct claims that
// ADR 0001 reserves for native-speaker judgment, and `applyOverride` recases
// with `.capitalized`, which writes "Whatsapp". `SupplementaryLexicon` already
// keeps a word and gives it a casing, so it consults this list.

import Foundation

public enum CuratedNames {

    /// Names whose lowercase form is no word in any Dictus language. Typed
    /// lowercase, or with only the first letter capitalized, they take this casing.
    static let recased = [
        "Dictus",
        "WhatsApp", "Gmail", "Instagram", "Facebook", "Snapchat", "TikTok",
        "LinkedIn", "YouTube", "Spotify", "Netflix", "ChatGPT",
        "iPhone", "iPad", "iCloud", "AirPods", "MacBook"
    ]

    /// Names that are also ordinary words ("a telegram", "discord between them"):
    /// never corrected, but kept as typed.
    static let keptAsTyped = ["Discord", "Telegram"]

    private static let recasedByKey = Dictionary(
        recased.map { ($0.lowercased(), $0) }, uniquingKeysWith: { first, _ in first }
    )
    private static let keptKeys = Set(keptAsTyped.map { $0.lowercased() })

    /// What autocorrect does with `word`, or nil when it is no curated name.
    public static func decision(for word: String) -> SupplementaryLexicon.Decision? {
        let key = word.lowercased()
        if keptKeys.contains(key) { return .keep }
        guard let casing = recasedByKey[key] else { return nil }
        let autocapitalized = key.prefix(1).uppercased() + key.dropFirst()
        if word != casing, word == key || word == autocapitalized {
            return .replace(with: casing)
        }
        return .keep
    }
}
