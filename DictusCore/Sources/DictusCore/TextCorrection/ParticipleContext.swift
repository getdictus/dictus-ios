// DictusCore/Sources/DictusCore/TextCorrection/ParticipleContext.swift
// Where a language expects an accented past participle, read from the previous word (#994).
import Foundation

/// Where a language expects an accented past participle, so that the accent pass reads
/// `est arrive` as `arrivé` but leaves `il arrive` alone (#994).
///
/// WHY a word list and not the n-gram data: the n-gram file keeps the 16 most frequent
/// words after each word. After `est` those are `un`, `le`, `très`…, and no participle
/// is among them, so the bigram score of `arrivé` after `est` is 0, the same as `arrive`.
public struct ParticipleContext: Sendable {

    /// The previous words, without accents, after which a participle is expected.
    public let triggers: Set<String>

    /// The endings of an accented participle, longest first.
    public let endings: [String]

    public init(triggers: [String], endings: [String]) {
        self.triggers = Set(triggers.map(Self.withoutAccents))
        self.endings = endings.sorted { $0.count > $1.count }
    }

    /// Whether `previousWord` calls for a participle. For a contraction only the part
    /// after the apostrophe counts: `j'ai`, `s'est`. Accents are ignored, so a previous
    /// word typed without its accent (`deja`) still counts.
    public func expectsParticiple(after previousWord: String?) -> Bool {
        guard let previousWord else { return false }
        let lowered = previousWord.lowercased()
        let word = lowered.split(whereSeparator: { $0 == "'" || $0 == "\u{2019}" }).last.map(String.init) ?? lowered
        return triggers.contains(Self.withoutAccents(word))
    }

    /// Whether `spelling` is an accented participle ending of the letters `typed` has
    /// there without the accent: `arrivé` for `arrive`, `couchés` for `couches`.
    public func isParticiple(_ spelling: String, of typed: String) -> Bool {
        guard let ending = endings.first(where: { spelling.hasSuffix($0) }) else { return false }
        return typed.hasSuffix(Self.withoutAccents(ending))
    }

    private static func withoutAccents(_ word: String) -> String {
        word.folding(options: .diacriticInsensitive, locale: nil)
    }
}
