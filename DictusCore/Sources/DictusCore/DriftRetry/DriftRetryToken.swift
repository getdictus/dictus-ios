// DictusCore/Sources/DictusCore/DriftRetry/DriftRetryToken.swift
// The token a Parakeet transcript is made of, as the retry reads it (#623).
import Foundation

/// One token of a Parakeet result, field for field what FluidAudio's `TokenTiming` carries.
///
/// WHY a mirror type: DictusCore does not link FluidAudio, and must not. The keyboard
/// extension links DictusCore, and the retry's logic has to be testable with `swift test`
/// on a Mac. DictusApp copies each `TokenTiming` into one of these, and nothing else
/// crosses the boundary.
public struct DriftRetryTokenTiming: Equatable, Sendable {
    public let tokenId: Int

    /// The SentencePiece piece, with its word-boundary marker already turned into a
    /// leading space, as FluidAudio hands it over.
    public let token: String

    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Float

    public init(tokenId: Int, token: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Float) {
        self.tokenId = tokenId
        self.token = token
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

/// A token placed on the encoder-frame grid of the dictation being retried.
struct DriftRetryPiece: Equatable {
    let tokenId: Int
    let token: String

    /// Encoder frame (80 ms) in the time of the whole call.
    let frame: Int

    let confidence: Float

    /// Length in frames, at least 1. Only the detector reads it, for a word's end.
    let durationFrames: Int

    init(tokenId: Int, token: String, frame: Int, confidence: Float, durationFrames: Int) {
        self.tokenId = tokenId
        self.token = token
        self.frame = frame
        self.confidence = confidence
        self.durationFrames = durationFrames
    }

    /// A first-pass token: the frame FluidAudio reports, unchanged.
    init(firstPass timing: DriftRetryTokenTiming) {
        self.init(
            tokenId: timing.tokenId,
            token: timing.token,
            frame: Self.frame(atSeconds: timing.startTime),
            confidence: timing.confidence,
            durationFrames: max(1, Self.frame(atSeconds: timing.endTime - timing.startTime))
        )
    }

    /// A token of a re-decoded clip, moved to the call's time.
    ///
    /// THE +1 IS DELIBERATE. FluidAudio reports every token one frame earlier than the
    /// decoder emitted it (an emission-delay correction, `max(0, frame - 1)`). The measured
    /// bench reached the decoder directly and filtered candidates on the decoder's own
    /// frame; this restores that frame so the 0.32 s tolerance window sits exactly where it
    /// was measured. The one ambiguous case, decoder frame 0 or 1 both reported as 0, never
    /// reaches a filter: the only cutoff inside a clip is at least 2 frames in.
    init(retry timing: DriftRetryTokenTiming, clipStartFrame: Int) {
        self.init(
            tokenId: timing.tokenId,
            token: timing.token,
            frame: Self.frame(atSeconds: timing.startTime) + 1 + clipStartFrame,
            confidence: timing.confidence,
            durationFrames: max(1, Self.frame(atSeconds: timing.endTime - timing.startTime))
        )
    }

    private static func frame(atSeconds seconds: TimeInterval) -> Int {
        Int((seconds / DriftRetryParameters.secondsPerFrame).rounded())
    }

    /// Start of the token, in seconds of call time.
    var time: Double { Double(frame) * DriftRetryParameters.secondsPerFrame }

    /// Nothing but punctuation or symbols once the boundary marker and spaces are gone.
    /// An empty piece counts too: it carries no word.
    var isPunctuation: Bool {
        let core = token.replacingOccurrences(of: "\u{2581}", with: "").trimmingCharacters(in: .whitespaces)
        return core.isEmpty || core.unicodeScalars.allSatisfy {
            CharacterSet.punctuationCharacters.contains($0) || CharacterSet.symbols.contains($0)
        }
    }

    /// Starts a new word: a leading space, or the raw SentencePiece marker.
    var isWordStart: Bool { token.hasPrefix(" ") || token.hasPrefix("\u{2581}") }
}

enum DriftRetryText {

    /// The text of a token stream, built the way FluidAudio builds `ASRResult.text`: the
    /// pieces joined, the boundary marker as a space, the ends trimmed. Its own
    /// `convertTokensToText` is internal; this is the same three steps over the same pieces.
    static func text(of pieces: [DriftRetryPiece]) -> String {
        pieces.map(\.token).joined()
            .replacingOccurrences(of: "\u{2581}", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Mean confidence of the word pieces, punctuation excluded; `nil` when there is none.
    /// The score a candidate is selected on, and the first pass's own span is scored the same.
    static func meanConfidence(of pieces: [DriftRetryPiece]) -> Float? {
        let scores = pieces.filter { !$0.isPunctuation }.map(\.confidence)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Float(scores.count)
    }

    /// Lower-cased words, typographic apostrophe folded, everything but letters, digits and
    /// apostrophes treated as a separator. What seam dedupe compares.
    static func normalizedWords(_ text: String) -> [String] {
        text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }
    }
}
