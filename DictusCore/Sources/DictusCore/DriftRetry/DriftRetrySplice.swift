// DictusCore/Sources/DictusCore/DriftRetry/DriftRetrySplice.swift
// Putting a chosen re-decode back into the first pass (#623).
import Foundation

/// The choice made for one span: the first-pass pieces it covers, and what replaces them.
struct DriftRetryChoice: Equatable {

    /// Half-open range of first-pass piece indices the span owns.
    let range: Range<Int>

    /// The winning candidate's pieces, or the first pass's own when it won.
    let pieces: [DriftRetryPiece]

    /// The first pass won: its pieces go back untouched, never deduped.
    let keepsFirstPass: Bool
}

enum DriftRetrySplice {

    /// The pieces of whole words whose first piece sits in `[fromFrame, toFrame)`.
    ///
    /// Continuation pieces at the front belong to the word before the span and are skipped;
    /// continuation pieces past `toFrame` finish a word that started inside it and are kept.
    /// A word is a word-start piece plus everything up to the next one, punctuation and
    /// apostrophes included (`qu` `'` `elle` is one word, `répondu` `.` too).
    static func wordRange(in pieces: [DriftRetryPiece], fromFrame: Int, toFrame: Int) -> Range<Int> {
        var low = pieces.firstIndex { $0.frame >= fromFrame } ?? pieces.count
        while low < pieces.count && pieces[low].frame < toFrame && !pieces[low].isWordStart { low += 1 }
        var high = low
        while high < pieces.count && pieces[high].frame < toFrame { high += 1 }
        while high < pieces.count && high > low && !pieces[high].isWordStart { high += 1 }
        return low..<high
    }

    /// The first-pass pieces `span` replaces.
    static func firstPassRange(of span: DriftSpan, in pieces: [DriftRetryPiece]) -> Range<Int> {
        let frame = DriftRetryParameters.samplesPerFrame
        return wordRange(in: pieces, fromFrame: span.start / frame, toFrame: (span.end + frame - 1) / frame)
    }

    /// The spliced token stream: each choice's pieces in place of the range it owns, seams
    /// deduped where a re-decode won.
    static func splice(firstPass: [DriftRetryPiece], choices: [DriftRetryChoice]) -> [DriftRetryPiece] {
        let context = DriftRetryParameters.seamContextTokens
        let sorted = choices.sorted { $0.range.lowerBound < $1.range.lowerBound }
        var output: [DriftRetryPiece] = []
        var cursor = 0
        for (index, choice) in sorted.enumerated() {
            if choice.range.lowerBound > cursor { output += firstPass[cursor..<choice.range.lowerBound] }
            // What sits right after the seam: the next span's chosen text when the two spans
            // touch, otherwise the first pass.
            let after: [DriftRetryPiece]
            if index + 1 < sorted.count && sorted[index + 1].range.lowerBound == choice.range.upperBound {
                after = Array(sorted[index + 1].pieces.prefix(context))
            } else {
                let upper = choice.range.upperBound
                after = upper < firstPass.count ? Array(firstPass[upper..<min(firstPass.count, upper + context)]) : []
            }
            output += choice.keepsFirstPass
                ? choice.pieces
                : dedupeSeams(choice.pieces, before: Array(output.suffix(context)), after: after)
            cursor = max(cursor, choice.range.upperBound)
        }
        if cursor < firstPass.count { output += firstPass[cursor...] }
        return output
    }

    /// A re-decode places an edge word a few frames off the first pass's, so the same word
    /// can end up on both sides of a seam. Drops up to three leading words equal to the words
    /// just before, and up to three trailing words equal to the words just after.
    static func dedupeSeams(_ candidate: [DriftRetryPiece], before: [DriftRetryPiece],
                            after: [DriftRetryPiece]) -> [DriftRetryPiece] {
        let candidateWords = wordKeys(candidate), beforeWords = wordKeys(before), afterWords = wordKeys(after)
        let maximum = DriftRetryParameters.maximumSeamDedupeWords
        var dropHead = 0, dropTail = 0
        for count in stride(from: min(maximum, candidateWords.count, beforeWords.count), through: 1, by: -1)
        where candidateWords.prefix(count).map(\.key) == beforeWords.suffix(count).map(\.key) {
            dropHead = count
            break
        }
        for count in stride(from: min(maximum, candidateWords.count - dropHead, afterWords.count), through: 1, by: -1)
        where candidateWords.suffix(count).map(\.key) == afterWords.prefix(count).map(\.key) {
            dropTail = count
            break
        }
        guard dropHead > 0 || dropTail > 0 else { return candidate }
        let low = dropHead > 0 ? candidateWords[dropHead - 1].range.upperBound : 0
        let high = dropTail > 0 ? candidateWords[candidateWords.count - dropTail].range.lowerBound : candidate.count
        var kept = low < high ? Array(candidate[low..<high]) : []
        while let first = kept.first, first.isPunctuation { kept.removeFirst() }
        return kept
    }

    /// Normalised words with the piece range each spans; pieces that normalise to nothing
    /// (punctuation alone) are not words.
    static func wordKeys(_ pieces: [DriftRetryPiece]) -> [(key: String, range: Range<Int>)] {
        var keys: [(key: String, range: Range<Int>)] = []
        var index = 0
        while index < pieces.count {
            var next = index + 1
            while next < pieces.count && !pieces[next].isWordStart { next += 1 }
            let key = DriftRetryText.normalizedWords(pieces[index..<next].map(\.token).joined()).joined(separator: " ")
            if !key.isEmpty { keys.append((key, index..<next)) }
            index = next
        }
        return keys
    }
}
