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

    /// What Accept stores for the pair as suggested.
    ///
    /// - Returns: nil when there is nothing to store: a vocabulary pair whose term was
    ///   deleted while the suggestion was on screen, or a pair that makes no entry.
    ///
    /// A new term keeps the learned word as the keyboard stored it, lowercase:
    /// History is not asked for its capitals. The review sheet lets the user fix them.
    public init?(_ pair: VocabularyPair, vocabulary: [VocabularyEntry]) {
        let stored = vocabulary.contains { $0.term.lowercased() == pair.canonical.lowercased() }
        guard stored || pair.source == .learned else { return nil }
        self.init(term: pair.canonical, variant: pair.observed, vocabulary: vocabulary)
    }

    /// What Accept stores once the user has edited the two fields of the review sheet.
    ///
    /// The stored term is looked up first, ignoring case like `VocabularyStore`, so a
    /// term typed with other capitals gains a variant rather than a duplicate entry.
    /// Otherwise the two fields make a new term.
    ///
    /// - Returns: nil when saving would change nothing a dictation goes through: an
    ///   empty or over-long term, an empty variant, a variant equal to the term, or one
    ///   the stored term already has (`VocabularyEntry.init?` cleans those away).
    public init?(term: String, variant: String, vocabulary: [VocabularyEntry]) {
        let needle = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let stored = vocabulary.first(where: { $0.term.lowercased() == needle }) {
            let updated = stored.addingVariants([variant])
            guard updated.variants != stored.variants else { return nil }
            self = .addVariant(updated)
            return
        }
        guard let entry = VocabularyEntry(term: term, variants: [variant]), entry.hasEffect else { return nil }
        self = .newTerm(entry)
    }
}
