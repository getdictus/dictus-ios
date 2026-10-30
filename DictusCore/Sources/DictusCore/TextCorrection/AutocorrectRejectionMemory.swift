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
/// old `rejectedWords` forget a refusal one keystroke after it was made. A position
/// is forgotten when a backspace erases the text before it: the field emptied and a
/// new message started with the same `Le` is another place, and a key alone would
/// not tell them apart.
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
    /// Length of the text before each remembered position, whitespace trimmed. A
    /// backspace that leaves less text than that has erased the position.
    private var offsets: [String: Int] = [:]

    public init() {}

    // MARK: - Positions

    /// The position key of a word whose preceding text is `prefix`.
    public static func positionKey(prefix: Substring) -> String {
        String(trimmed(prefix).suffix(keyLength))
    }

    private static func trimmed(_ text: Substring) -> Substring {
        var end = text.endIndex
        while end > text.startIndex, text[text.index(before: end)].isWhitespace {
            end = text.index(before: end)
        }
        return text[..<end]
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

    /// False in a host that gives no document identifier: nothing is remembered
    /// from one event to the next there.
    public var remembersRefusals: Bool { document != nil }

    // MARK: - Events

    /// Starts over when the keyboard is editing another document.
    ///
    /// A nil identifier starts over every time (review of #874). Nothing the
    /// extension sees tells two such fields apart, and sharing refusals between
    /// them keeps and learns typos. Those hosts get no refusal memory at all: a
    /// refused correction is made again, as before #872.
    public func enter(document id: String?) {
        guard id == nil || id != document else { return }
        document = id
        applied.removeAll()
        rejected.removeAll()
        restoredByUndo.removeAll()
        lastCounted = nil
        offsets.removeAll()
    }

    /// Dictus replaced the word after `prefix` with `corrected`.
    public func correctionApplied(prefix: Substring, corrected: String) {
        let key = remember(prefix)
        applied.removeAll { $0.key == key }
        applied.append(Applied(key: key, corrected: corrected))
        if applied.count > Self.watchedCorrections { applied.removeFirst() }
    }

    /// Called after every backspace with the context before and after it. Returns
    /// the correction it took as refused, if the backspace erased at least one
    /// letter of it, at its position. Erasing the space after the word, or the
    /// space before it with the caret moved back, is not a refusal. A nil context
    /// reads as empty.
    @discardableResult
    public func textDeleted(before: String?, after: String?) -> String? {
        let context = after ?? ""
        forgetPositions(beyond: Self.trimmed(Substring(context)).count)
        for (index, correction) in applied.enumerated().reversed() {
            guard let had = Self.lettersAtCaret(of: correction, in: before ?? ""), had > 0,
                  let left = Self.lettersAtCaret(of: correction, in: context), left < had
            else { continue }
            applied.remove(at: index)
            reject(correction.key)
            return correction.corrected
        }
        return nil
    }

    /// The user tapped Undo: `original` is back after `prefix`. It is learned only
    /// once the user moves past it unchanged; editing it learns the edit instead.
    public func correctionUndone(prefix: Substring, original: String) {
        let key = remember(prefix)
        applied.removeAll { $0.key == key }
        reject(key)
        restoredByUndo[key] = original
    }

    /// The user tapped the typed word, quoted in slot 0 of the corrections row.
    /// `word` is the word at the caret and `rowWord` the one the row was built
    /// for. Returns whether the tap is taken as a refusal, the word to be learned.
    @discardableResult
    public func typedWordKept(prefix: Substring, word: String, rowWord: String) -> Bool {
        // A caret move does not refresh the row: a row built for another word
        // would refuse, and teach, whatever word the caret now ends (review of #874).
        guard word.lowercased() == rowWord.lowercased() else { return false }
        reject(remember(prefix))
        return true
    }

    /// Called before anything is inserted. When a word restored by Undo is still
    /// in place, unchanged, and the caret has left it (a space, a punctuation
    /// mark, a prediction tap's word), the user kept it: it is returned, to be
    /// learned. The word the caret ends on is still being typed and is skipped.
    public func movingOn(context: String?) -> String? {
        guard let context, !restoredByUndo.isEmpty else { return nil }
        var kept: String?
        context.enumerateSubstrings(in: context.startIndex..., options: .byWords) { sub, range, _, stop in
            guard let word = sub, range.upperBound < context.endIndex else { return }
            let key = Self.positionKey(prefix: context[..<range.lowerBound])
            guard let restored = self.restoredByUndo[key],
                  restored.lowercased() == word.lowercased() else { return }
            self.restoredByUndo[key] = nil
            kept = word
            stop = true
        }
        return kept
    }

    /// What to do with `word`, committed after `prefix` by a space, a punctuation
    /// mark or a return. `proposedCorrection` is what the corrector would apply,
    /// nil when it keeps the word. `countable` is false when the caller will not
    /// count the word whatever is decided (autocorrect off, mirror suspect): it is
    /// then not marked as counted, so a later countable commit still counts.
    public func commit(
        prefix: Substring, word: String, proposedCorrection: String?, countable: Bool = true
    ) -> Decision {
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
        if countable { lastCounted = (remember(prefix), lowered) }
        return .keep(countUsage: true)
    }

    /// Whether the suggestion bar may preview a correction for the word at the
    /// caret: not at a refused position, where space will not make it either.
    /// Decided by position, like the space bar, never by spelling (review of #874).
    public func previewsCorrection(context: String?) -> Bool {
        guard let (prefix, _) = Self.wordAtCursor(context: context) else { return true }
        return !isRejected(prefix: prefix)
    }

    /// Whether a correction refused at the position after `prefix` is remembered.
    public func isRejected(prefix: Substring) -> Bool {
        rejected.contains(Self.positionKey(prefix: prefix))
    }

    // MARK: - Private

    /// How many letters of the corrected word sit right before the caret, at its
    /// position (trailing whitespace ignored). Nil when the caret is elsewhere.
    private static func lettersAtCaret(of correction: Applied, in context: String) -> Int? {
        let text = trimmed(Substring(context))
        let letters = Array(correction.corrected)
        for kept in stride(from: letters.count, through: 0, by: -1) {
            let fragment = String(letters[0..<kept])
            guard text.hasSuffix(fragment) else { continue }
            if positionKey(prefix: text.dropLast(fragment.count)) == correction.key { return kept }
        }
        return nil
    }

    /// The key of the position after `prefix`, with its offset noted for erasure.
    private func remember(_ prefix: Substring) -> String {
        let key = Self.positionKey(prefix: prefix)
        offsets[key] = Self.trimmed(prefix).count
        // Every counted word notes an offset; keep only the ones still referenced.
        if offsets.count > Self.capacity + Self.watchedCorrections + 1 {
            let referenced = Set(rejected + applied.map(\.key) + restoredByUndo.keys + [key])
            offsets = offsets.filter { referenced.contains($0.key) }
        }
        return key
    }

    private func forgetPositions(beyond reach: Int) {
        let erased = Set(offsets.filter { $0.value > reach }.keys)
        guard !erased.isEmpty else { return }
        applied.removeAll { erased.contains($0.key) }
        rejected.removeAll { erased.contains($0) }
        for key in erased {
            restoredByUndo[key] = nil
            offsets[key] = nil
        }
        if let last = lastCounted, erased.contains(last.key) { lastCounted = nil }
    }

    private func reject(_ key: String) {
        rejected.removeAll { $0 == key }
        rejected.append(key)
        // Every restored word sits at a refused position, so evicting the oldest
        // refusal with its restore keeps both within `capacity`.
        if rejected.count > Self.capacity { restoredByUndo[rejected.removeFirst()] = nil }
    }
}
