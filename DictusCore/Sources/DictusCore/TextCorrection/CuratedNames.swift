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
        return decision(for: word, casing: casing)
    }

    /// `word`, a curated name as typed, against `casing`, the way it is written.
    /// Apart from the list so a name written all lowercase can be tested: none is yet.
    static func decision(for word: String, casing: String) -> SupplementaryLexicon.Decision {
        let key = casing.lowercased()
        let autocapitalized = key.prefix(1).uppercased() + key.dropFirst()
        // A name written all lowercase keeps a sentence-start capital, as any word does.
        let recasable = word == key || (word == autocapitalized && casing != key)
        return word != casing && recasable ? .replace(with: casing) : .keep
    }

    /// `correction` with each of its words that is a curated name in that name's
    /// casing: the trie's `whatsapp` for a typed `whatsap` is "WhatsApp" (Titus,
    /// 2026-11-24). `decision(for:)` only ever saw the typed word.
    ///
    /// WHY by word: a split correction (`thewhatsap` -> "the whatsapp") holds the
    /// name next to another word. The casing rules are the typed word's: lowercase
    /// and sentence-start forms take the name's casing, all caps stays all caps,
    /// and a name that is also a word ("telegram") stays as the corrector wrote it.
    public static func casing(of correction: String) -> String {
        correction
            .split(separator: " ", omittingEmptySubsequences: false)
            .map { word -> String in
                let word = String(word)
                guard case .replace(let casing)? = decision(for: word) else { return word }
                return casing
            }
            .joined(separator: " ")
    }
}

extension CorrectionProposal {
    /// The same proposal with every curated name in it written in its casing
    /// (`CuratedNames.casing(of:)`). The keyboard applies it to what the dictionary
    /// proposes, never to the lexicon's answer: a user's text replacement is kept as
    /// the user wrote it.
    public var inCuratedCasing: CorrectionProposal {
        mapWords(CuratedNames.casing(of:))
    }
}
