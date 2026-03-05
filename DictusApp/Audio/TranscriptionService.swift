// DictusApp/Audio/TranscriptionService.swift
// Encapsulates WhisperKit transcription with French language settings.
import Foundation
import WhisperKit

/// Errors that can occur during transcription.
enum TranscriptionError: Error, LocalizedError {
    case notReady
    case emptyAudio
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notReady:
            return "TranscriptionService is not ready — WhisperKit not initialized"
        case .emptyAudio:
            return "No audio samples to transcribe"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}

/// Handles WhisperKit transcription with French language configuration.
///
/// WHY this is a separate class from AudioRecorder:
/// Single Responsibility — AudioRecorder handles recording, TranscriptionService handles
/// transcription. This also makes it easy to swap or test each independently.
class TranscriptionService {
    private var whisperKit: WhisperKit?

    /// Inject or re-use a WhisperKit instance.
    func prepare(whisperKit: WhisperKit) {
        self.whisperKit = whisperKit
    }

    /// Transcribe audio samples to text using WhisperKit.
    ///
    /// - Parameter audioSamples: Array of Float32 audio samples at 16 kHz mono
    ///   (as returned by `AudioRecorder.stopRecording()`).
    /// - Returns: Transcribed text with punctuation (Whisper provides this natively).
    ///
    /// WHY these DecodingOptions:
    /// - `language: "fr"` — Forces French transcription (no language detection overhead)
    /// - `temperature: 0.0` — Greedy decoding = fastest and most deterministic output
    /// - `usePrefillPrompt: true` — Enables language-specific prompt prefill for better accuracy
    /// - `usePrefillCache: true` — Caches prefill results between transcriptions for speed
    /// - `skipSpecialTokens: true` — Removes Whisper's special tokens from output
    ///
    /// NOTE: No filler word filtering is applied here — that comes in Plan 2.2.
    /// This method returns raw Whisper output.
    func transcribe(audioSamples: [Float]) async throws -> String {
        guard let whisperKit else {
            throw TranscriptionError.notReady
        }

        guard !audioSamples.isEmpty else {
            throw TranscriptionError.emptyAudio
        }

        let options = DecodingOptions(
            task: .transcribe,
            language: "fr",
            temperature: 0.0,
            usePrefillPrompt: true,
            usePrefillCache: true,
            skipSpecialTokens: true
        )

        do {
            let results: [TranscriptionResult] = try await whisperKit.transcribe(
                audioArray: audioSamples,
                decodeOptions: options
            )

            // Join all segment texts into a single string.
            // Whisper may produce multiple segments for longer audio.
            let text = results.map { $0.text }.joined(separator: " ")

            // Trim whitespace — Whisper sometimes adds leading/trailing spaces
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmed.isEmpty else {
                throw TranscriptionError.transcriptionFailed("Empty transcription result")
            }

            return trimmed
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }
}
