// DictusCore/Sources/DictusCore/Vocabulary/VocabularyEntry.swift
// One term the user taught Dictus, and the shapes the engine produces instead (#80).
import Foundation

/// A canonical spelling plus zero or more variants the engine writes in its place.
///
/// ### What an entry does (#80 decision 4, amended by #536)
///
/// **Each variant triggers a replacement** to `term` on the raw transcript. That
/// works for every user, every engine and every language, because it is text and not
/// acoustics — see `VocabularyReplacer`. It is the whole of what an entry does, and
/// it is what keeps the paywall sentence honest.
///
/// It used to be half. #80 decision 7 also put `term` in the polish prompt, which is
/// what let an entry with no variants claim to protect a spelling; #536 measured that
/// claim false on device and withdrew the decision. The prompt no longer carries a
/// term list at all, so **an entry with no variants changes nothing** — see
/// `hasEffect`, which the add sheet uses to refuse one.
///
/// ### Why `variants` can still be empty
///
/// Entries stored before #536 have none, and the file is the user's data. `init?` and
/// `isValid` deliberately keep accepting them, so nothing already on disk is dropped
/// at load; the requirement lives at the point of entry instead.
///
/// ### Why there is no language tag (#80 decision 9)
///
/// A term is a spelling, not a sentence: `Kubernetes` is `Kubernetes` in French and
/// in English, and asking the user which language their company's name belongs to is
/// a question with no good answer. The accepted consequence is written on the issue:
/// if #288 ever forces tagging, it is a migration on data that survives a reinstall.
///
/// ### Why `id`
///
/// The brief names four fields. The fifth is SwiftUI's: a `List` needs stable
/// identity per row, and `term` cannot supply it while the user is mid-edit on a
/// duplicate. `TranscriptionRecord` carries one for the same reason.
public struct VocabularyEntry: Codable, Identifiable, Equatable, Sendable {

    /// Longest accepted `term`, and longest accepted variant (#80 decision 10).
    ///
    /// A hundred characters is far beyond any real technical term; the limit exists
    /// so a paste accident cannot put a paragraph into the matcher, where it would
    /// cost a scan of the whole transcript per character and match nothing.
    public static let maxFieldLength = 100

    public let id: UUID

    /// The canonical spelling. What replacements emit.
    public let term: String

    /// What the engine produces instead. May be empty, and an entry whose variants
    /// are empty does nothing — see `hasEffect`.
    public let variants: [String]

    /// The per-entry switch (#80 decision 8). The replacement is silent, so this and
    /// the global toggle are the only two places a user can stop one.
    public let isEnabled: Bool

    public let dateAdded: Date

    /// Build an entry from user input, or refuse.
    ///
    /// Refuses only on the term, because the term is the entry: an empty or
    /// over-long canonical spelling has nothing to store. Variants are cleaned
    /// rather than refused — an over-long or duplicated one is dropped and the rest
    /// of the entry survives, which is what a user who pasted a stray line expects.
    ///
    /// A variant **byte-identical** to its term is dropped, and so is a variant that
    /// merely repeats another with different case.
    ///
    /// A variant that differs from its term only by case is **kept**, deliberately.
    /// `ampli` for `Ampli` is not a no-op: an engine writing a proper noun in
    /// lowercase is the commonest mangling there is, and it is the one thing a
    /// case-insensitive matcher can fix on its own. `VocabularyReplacer` treats that
    /// rule as a fixed point rather than as a cycle.
    public init?(term: String,
                 variants: [String] = [],
                 isEnabled: Bool = true,
                 id: UUID = UUID(),
                 dateAdded: Date = Date()) {
        let cleanTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTerm.isEmpty, cleanTerm.count <= Self.maxFieldLength else { return nil }

        var seen = Set<String>()
        var cleanVariants: [String] = []
        for variant in variants {
            let clean = variant.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, clean.count <= Self.maxFieldLength else { continue }
            guard clean != cleanTerm else { continue }
            guard seen.insert(clean.lowercased()).inserted else { continue }
            cleanVariants.append(clean)
        }

        self.id = id
        self.term = cleanTerm
        self.variants = cleanVariants
        self.isEnabled = isEnabled
        self.dateAdded = dateAdded
    }

    /// Whether an entry that came off disk still satisfies what `init?` enforces.
    ///
    /// `Codable` synthesises its own initialiser and cannot be routed through the
    /// failable one, so the file is the one place an invalid entry can enter — and
    /// that file lives in a container anyone with the device can edit. The store
    /// filters on this at load; nothing else has to remember to.
    ///
    /// **Rebuilt and compared rather than re-checked.** A second list of conditions
    /// beside `init?` is a list that drifts from it, and it already had: a term of
    /// three spaces passed, so did an empty variant, a duplicate differing only in
    /// case, and a variant byte-identical to its own term. Routing through the real
    /// initialiser makes the two impossible to disagree — whatever `init?` cleans or
    /// refuses, this refuses.
    public var isValid: Bool {
        let rebuilt = VocabularyEntry(
            term: term, variants: variants, isEnabled: isEnabled, id: id, dateAdded: dateAdded
        )
        return rebuilt == self
    }

    /// Whether this entry can change a transcript at all (#536).
    ///
    /// Separate from `isValid` on purpose, and the separation is the whole design:
    /// `isValid` decides what may be **stored**, and the store filters on it at load,
    /// so folding this rule into it would silently delete every variant-less entry
    /// written before #536. This decides what is **worth storing**, and only the add
    /// sheet asks — a stored entry that answers `false` is kept, listed, and flagged
    /// on screen with the one action that fixes it.
    public var hasEffect: Bool {
        !variants.isEmpty
    }

    /// The same entry with its switch flipped. Used by the list's per-row toggle.
    public func enabled(_ newValue: Bool) -> VocabularyEntry {
        VocabularyEntry(
            term: term, variants: variants, isEnabled: newValue, id: id, dateAdded: dateAdded
        ) ?? self
    }

    /// The variants as the add sheet writes them: one comma-separated line.
    public var variantsLine: String {
        variants.joined(separator: ", ")
    }

    /// Split a comma-separated line into candidate variants.
    ///
    /// Static and on the model rather than in the view, so the harness and the tests
    /// parse a user's line exactly the way the sheet does.
    public static func variants(fromLine line: String) -> [String] {
        line.split(separator: ",").map { String($0) }
    }
}
