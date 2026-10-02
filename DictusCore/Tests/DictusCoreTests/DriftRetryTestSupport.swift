// DictusCore/Tests/DictusCoreTests/DriftRetryTestSupport.swift
// Synthetic audio and token streams for the #623 drift retry tests.
import Foundation
@testable import DictusCore

/// Audio built from stretches of "speech" and "pause".
///
/// Speech is a 220 Hz tone at 0.1 amplitude; a pause is the same tone at 0.001, quiet but
/// above the audible floor. Real recordings never hold digital silence between words, and
/// the levels are percentile-based, so a pause has to be quiet relative to the speech, not
/// absent.
enum SyntheticAudio {

    enum Part {
        case speech(Double)
        case pause(Double)
        case silence(Double)
    }

    static let sampleRate = 16_000

    static func samples(_ parts: [Part]) -> [Float] {
        var samples: [Float] = []
        for part in parts {
            let (seconds, amplitude): (Double, Float)
            switch part {
            case .speech(let length): (seconds, amplitude) = (length, 0.1)
            case .pause(let length): (seconds, amplitude) = (length, 0.001)
            case .silence(let length): (seconds, amplitude) = (length, 0)
            }
            let count = Int(seconds * Double(sampleRate))
            let offset = samples.count
            samples += (0..<count).map { index in
                amplitude * Float(sin(2 * Double.pi * 220 * Double(offset + index) / Double(sampleRate)))
            }
        }
        return samples
    }

    /// One-second speech stretches separated by 0.3 s pauses: a stretch starts every 1.3 s.
    static func regularSpeech(stretches: Int) -> [Float] {
        var parts: [Part] = []
        for index in 0..<stretches {
            parts.append(.speech(1.0))
            if index < stretches - 1 { parts.append(.pause(0.3)) }
        }
        return samples(parts)
    }
}

/// Token streams, written as words.
enum SyntheticTokens {

    /// One single-piece word per entry, starting at `start` seconds, 0.4 s long.
    static func timings(_ words: [(text: String, start: Double, confidence: Float)]) -> [DriftRetryTokenTiming] {
        words.enumerated().map { index, word in
            DriftRetryTokenTiming(tokenId: index, token: " " + word.text, startTime: word.start,
                                  endTime: word.start + 0.4, confidence: word.confidence)
        }
    }

    /// The text FluidAudio would return for `timings`.
    static func text(of timings: [DriftRetryTokenTiming]) -> String {
        timings.map(\.token).joined().trimmingCharacters(in: .whitespaces)
    }

    /// A piece on the call's frame grid.
    static func piece(_ token: String, frame: Int, confidence: Float = 0.99, duration: Int = 2) -> DriftRetryPiece {
        DriftRetryPiece(tokenId: 0, token: token, frame: frame, confidence: confidence, durationFrames: duration)
    }
}
