// DictusCore/Sources/DictusCore/TextCorrection/AutocorrectRejectionMemory.swift
// Remembers where in the document the user refused an autocorrection (#872).
import Foundation

/// Tells the keyboard when a refused autocorrection must not be applied again,
/// and which word that refusal teaches.
///
/// WHY a position and not a word. Apple's French keyboard, observed on iOS 27:
/// `soleik` → `soleil`, the user erases the correction and types `soleiq`, and
/// `soleiq` is kept. The word the user commits after refusing is often not the
/// word that was corrected, so a set of rejected words cannot recognise it. What
/// stays the same is *where* the user is typing.
///
/// The position key is the text before the word, without trailing whitespace,
/// cut to its last `keyLength` characters:
/// - without trailing whitespace, so erasing the space before the word and typing
///   it again (`la plage` → `la` → `la plagr`) lands on the same key;
/// - the last characters only, because `documentContextBeforeInput` may be a window
///   that ends at the cursor. The window starts further right when the retyped word
///   is longer than the corrected one, but its end, right before the word, is the
///   same.
///
/// Lifetime: RAM only, one document at a time. A new `documentIdentifier` empties
/// it. Nothing here is cleared when the next word starts, which is what made the
/// old `rejectedWords` forget a refusal one keystroke after it was made.
///
/// Learning stays behind the #287 guard: this type only ever asks to learn a word
/// committed at a position whose correction the user refused. Words never
/// corrected still go through `UserDictionary.recordUsage` and its threshold.
public final class AutocorrectRejectionMemory {

    /// Characters of the text before a word that identify its position.
    public static let keyLength = 32

    /// Refused positions kept per document. A document with more refusals than
    /// this forgets the oldest, which costs one correction made again.
    public static let capacity = 64

    /// Applied corrections watched for a backspace into them.
    static let watchedCorrections = 8

    /// What to do with the word being committed.
    public enum Decision: Equatable {
        /// Apply the proposed correction.
        case correct
        /// The user refused a correction here: keep the word and learn it.
        case keepAndLearn
        /// Nothing proposed: keep the word. `countUsage` is false when this exact
        /// word at this exact position was already counted (#872 scenario 13:
        /// erase the space after a word, type `.`, and the word is committed twice).
        case keep(countUsage: Bool)
    }

    private struct Applied {
        let key: String
        let corrected: String
    }

    private var document: String?
    private var applied: [Applied] = []
    private var rejected: [String] = []
    /// Positions restored by Undo, mapped to the restored word. Learned when the
    /// user moves past it unchanged, or replaced by what they commit there instead.
    private var restoredByUndo: [String: String] = [:]
    private var lastCounted: (key: String, word: String)?

    public init() {}

    // MARK: - Positions

    /// The position key of a word whose preceding text is `prefix`.
    public static func positionKey(prefix: Substring) -> String {
        var end = prefix.endIndex
        while end > prefix.startIndex, prefix[prefix.index(before: end)].isWhitespace {
            end = prefix.index(before: end)
        }
        return String(prefix[..<end].suffix(keyLength))
    }

    /// The word the cursor sits at the end of, and the text before it. Nil when
    /// the context does not END with a word, after a space or a comma for example.
    public static func wordAtCursor(context: String?) -> (prefix: Substring, word: String)? {
        guard let context, !context.isEmpty else { return nil }
        var last = ""
        context.enumerateSubstrings(in: context.startIndex..., options: .byWords) { sub, _, _, _ in
            if let sub { last = sub }
        }
        guard !last.isEmpty, context.hasSuffix(last) else { return nil }
        return (context.dropLast(last.count), last)
    }

    // MARK: - Events

    /// Starts over when the keyboard is editing another document.
    public func enter(document id: String?) {
        guard id != document else { return }
        document = id
        applied.removeAll()
        rejected.removeAll()
        restoredByUndo.removeAll()
        lastCounted = nil
    }

    /// Dictus replaced the word after `prefix` with `corrected`.
    public func correctionApplied(prefix: Substring, corrected: String) {
        let key = Self.positionKey(prefix: prefix)
        applied.removeAll { $0.key == key }
        applied.append(Applied(key: key, corrected: corrected))
        if applied.count > Self.watchedCorrections { applied.removeFirst() }
    }

    /// Called after every backspace with the context it left. Returns the
    /// correction it took as refused, if the backspace went into one: the context
    /// now ends with a strict beginning of the corrected word, at its position. A
    /// backspace that only removes the space after the word is not a refusal.
    @discardableResult
    public func textDeleted(context: String) -> String? {
        for (index, correction) in applied.enumerated().reversed() {
            let letters = Array(correction.corrected)
            for kept in 0..<letters.count {
                let fragment = String(letters[0..<kept])
                guard context.hasSuffix(fragment) else { continue }
                let prefix = context.dropLast(fragment.count)
                if Self.positionKey(prefix: prefix) == correction.key {
                    applied.remove(at: index)
                    reject(correction.key)
                    return correction.corrected
                }
            }
        }
        return nil
    }

    /// The user tapped Undo: `original` is back after `prefix`. It is learned only
    /// once the user moves past it unchanged; editing it learns the edit instead.
    public func correctionUndone(prefix: Substring, original: String) {
        let key = Self.positionKey(prefix: prefix)
        applied.removeAll { $0.key == key }
        reject(key)
        restoredByUndo[key] = original
    }

    /// The user tapped the typed word, quoted in slot 0 of the corrections row.
    public func typedWordKept(prefix: Substring) {
        reject(Self.positionKey(prefix: prefix))
    }

    /// Called before a character, a space or a return is inserted. When the cursor
    /// sits after whitespace that follows a word restored by Undo, the user has
    /// moved on and kept that word: it is returned, to be learned.
    public func movingOn(context: String?) -> String? {
        guard let context, let last = context.last, last.isWhitespace else { return nil }
        var trimmed = Substring(context)
        while let character = trimmed.last, character.isWhitespace { trimmed = trimmed.dropLast() }
        guard let (prefix, word) = Self.wordAtCursor(context: String(trimmed)) else { return nil }
        let key = Self.positionKey(prefix: prefix)
        guard let restored = restoredByUndo[key],
              restored.lowercased() == word.lowercased() else { return nil }
        restoredByUndo[key] = nil
        return word
    }

    /// What to do with `word`, committed after `prefix` by a space, a punctuation
    /// mark or a return. `proposedCorrection` is what the corrector would apply,
    /// nil when it keeps the word.
    public func commit(prefix: Substring, word: String, proposedCorrection: String?) -> Decision {
        let key = Self.positionKey(prefix: prefix)
        let proposes = proposedCorrection.map { $0.lowercased() != word.lowercased() } ?? false

        if proposes {
            if rejected.contains(key) {
                restoredByUndo[key] = nil
                return .keepAndLearn
            }
            return .correct
        }

        // The word stands on its own: nothing left to learn from a restore here.
        restoredByUndo[key] = nil
        let lowered = word.lowercased()
        if let last = lastCounted, last.key == key, last.word == lowered {
            return .keep(countUsage: false)
        }
        lastCounted = (key, lowered)
        return .keep(countUsage: true)
    }

    /// Whether a correction refused at the position after `prefix` is remembered.
    public func isRejected(prefix: Substring) -> Bool {
        rejected.contains(Self.positionKey(prefix: prefix))
    }

    // MARK: - Private

    private func reject(_ key: String) {
        rejected.removeAll { $0 == key }
        rejected.append(key)
        if rejected.count > Self.capacity { rejected.removeFirst() }
    }
}
