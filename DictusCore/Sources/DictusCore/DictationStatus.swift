// DictusCore/Sources/DictusCore/DictationStatus.swift
import Foundation

/// Represents the current state of a dictation round-trip.
/// Written to App Group UserDefaults so both processes can track progress.
public enum DictationStatus: String, Codable {
    case idle         // No dictation in progress
    case requested    // Keyboard triggered dictus://dictate
    case recording    // Main app is recording audio
    case transcribing // Main app is running transcription
    case ready        // Transcription result available in shared storage
    case failed       // Something went wrong
}
