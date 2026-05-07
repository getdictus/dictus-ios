// DictusCore/Sources/DictusCore/ModelLoadState.swift
import Foundation

/// Tri-state lifecycle for the active transcription model.
/// Written to App Group UserDefaults under `SharedKeys.modelLoadState` so the
/// keyboard extension can refuse mic taps while the app is busy loading the
/// model into RAM (issue #144 — fixes the cascade of `Swift.CancellationError`
/// when a user taps the mic during a turbo model swap).
public enum ModelLoadState: String, Codable {
    /// No load in flight. `modelReady` reflects whether a model is on disk.
    case idle
    /// WhisperKit/Parakeet is being loaded into RAM (or compiling/downloading).
    /// Mic taps from the keyboard MUST be refused while in this state.
    case loading
    /// Active model is loaded in RAM and ready to transcribe.
    case ready
}
