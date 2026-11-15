// DictusCore/Sources/DictusCore/PastAudioSegments.swift
// Drops the Whisper segments timed after the end of the audio (#953).
//
// When a dictation stops mid-speech there is no silent tail for TrailingSilence to cut
// (#932), and Whisper's decoder can still emit one more segment, timed in the padding of
// its 30 s window: « – Le... » with lastSegmentEndSec=28.40 for 14.41 s of audio. A
// segment that starts where the audio has already ended cannot come from the audio.
import Foundation

public enum PastAudioSegments {

    public struct Segment: Equatable {
        public let start: Float
        public let end: Float
        public let text: String

        public init(start: Float, end: Float, text: String) {
            self.start = start
            self.end = end
            self.text = text
        }
    }

    /// One WhisperKit `TranscriptionResult`: one per VAD chunk, segment times already
    /// offset to the whole buffer by WhisperKit.
    public struct Result {
        public let text: String
        public let segments: [Segment]

        public init(text: String, segments: [Segment]) {
            self.text = text
            self.segments = segments
        }
    }

    /// A segment starting this close to the end, or later, is dropped.
    public static let tolerance: Float = 0.1

    /// The text of `results` joined as the app always has, without the segments that
    /// start at or after `audioSeconds - tolerance`. A result that loses no segment
    /// keeps WhisperKit's own text, so a dictation with nothing dropped reads exactly as
    /// before.
    public static func text(of results: [Result], audioSeconds: Float) -> (text: String, dropped: [Segment]) {
        var dropped: [Segment] = []
        let texts: [String] = results.compactMap { result in
            let late = result.segments.filter { $0.start >= audioSeconds - tolerance }
            guard !late.isEmpty else { return result.text }
            dropped += late
            let kept = result.segments.filter { $0.start < audioSeconds - tolerance }
            let text = kept.map(\.text).joined().trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : text
        }
        return (texts.joined(separator: " "), dropped)
    }
}
