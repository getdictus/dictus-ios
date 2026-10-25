// DictusCore/Sources/DictusCore/Vocabulary/VocabularyPairAcceptance.swift
// What Accept on a suggested pair stores in the Personal Vocabulary (#512, step 2 UI).
import Foundation

/// The change **Accept** makes, decided before the review sheet shows it, so the sheet
/// says exactly what will be stored and the store writes exactly that.
public enum VocabularyPairAcceptance: Equatable {
    /// The canonical is a stored term: the span joins its variants.
    case addVariant(VocabularyEntry)
    /// The canonical is a word the keyboard learned and no term yet: a new term with
    /// the span as its one variant.
    case newTerm(VocabularyEntry)

    /// The entry to store, whichever the case.
    public var entry: VocabularyEntry {
        switch self {
        case .addVariant(let entry), .newTerm(let entry): return entry
        }
    }

    /// - Returns: nil when there is nothing to store: a vocabulary pair whose term was
    ///   deleted while the suggestion was on screen, or a pair that makes no entry.
    ///
    /// The stored term is looked up first, ignoring case like `VocabularyStore`, so a
    /// learned word the user has since added as a term gains a variant rather than a
    /// duplicate. A new term keeps the learned word as the keyboard stored it,
    /// lowercase: History is not asked for its capitals.
    public init?(_ pair: VocabularyPair, vocabulary: [VocabularyEntry]) {
        let needle = pair.canonical.lowercased()
        if let stored = vocabulary.first(where: { $0.term.lowercased() == needle }) {
            self = .addVariant(stored.addingVariants([pair.observed]))
            return
        }
        guard pair.source == .learned,
              let entry = VocabularyEntry(term: pair.canonical, variants: [pair.observed]) else { return nil }
        self = .newTerm(entry)
    }
}
