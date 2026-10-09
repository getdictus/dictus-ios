// DictusCore/Sources/DictusCore/Polish/TranslationChunking.swift
// Cutting a long transcript into pieces the Translation framework translates one at a time (#648).
import Foundation

/// Splits a transcript into translation chunks: every `<<NL>>` line on its own, and
/// within a line, whole sentences grouped up to a character budget.
///
/// WHY chunk at all. A voice note can run four minutes and 4,000 characters, and one
/// framework call over all of it is one wait the caller cannot see the end of: the
/// device test (#648, 2026-10-08) lost a 4,198-character note to a deadline sized for a
/// keyboard dictation. Chunks give a per-chunk deadline that means something, a place
/// to notice cancellation between calls, and a log of where the time went.
///
/// WHY sentences. The framework translates meaning, and a cut inside a sentence hands
/// it two halves of one. A single sentence longer than the budget stays whole: a long
/// sentence is still one sentence.
///
/// `<<NL>>` markers are kept as separators, never translated, so a dictated line break
/// survives — the framework turns a newline into a blank line.
public enum TranslationChunking {

    /// One chunk and what joins it to the next: `<<NL>>`, a space, or nothing for the last.
    public struct Piece: Equatable, Sendable {
        public let text: String
        public let separatorAfter: String
    }

    public static func pieces(_ raw: String, maxCharacters: Int) -> [Piece] {
        let lines = raw.components(separatedBy: PolishPostpass.newlineMarker)
        var pieces: [Piece] = []
        for (lineIndex, line) in lines.enumerated() {
            let isLastLine = lineIndex == lines.count - 1
            let lineSeparator = isLastLine ? "" : PolishPostpass.newlineMarker
            let chunks = sentenceGroups(line, maxCharacters: maxCharacters)
            guard !chunks.isEmpty else {
                // An empty line still carries its break, so the marker count holds.
                pieces.append(Piece(text: "", separatorAfter: lineSeparator))
                continue
            }
            for (index, chunk) in chunks.enumerated() {
                let isLastChunk = index == chunks.count - 1
                pieces.append(Piece(text: chunk, separatorAfter: isLastChunk ? lineSeparator : " "))
            }
        }
        return pieces
    }

    /// The chunk texts alone, empty ones dropped.
    public static func chunks(_ raw: String, maxCharacters: Int) -> [String] {
        pieces(raw, maxCharacters: maxCharacters).map(\.text).filter { !$0.isEmpty }
    }

    /// Put translated chunks back together, in order, with the original separators.
    public static func join(_ pieces: [Piece], translated: [String]) -> String {
        zip(pieces, translated).map { $0.1 + $0.0.separatorAfter }.joined()
    }

    private static func sentenceGroups(_ line: String, maxCharacters: Int) -> [String] {
        var groups: [String] = []
        var current = ""
        for sentence in PolishSegmentation.sentences(of: line) {
            if current.isEmpty {
                current = sentence
            } else if current.count + 1 + sentence.count <= maxCharacters {
                current += " " + sentence
            } else {
                groups.append(current)
                current = sentence
            }
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }
}
