// DictusCore/Sources/DictusCore/WhisperKitLoadStage.swift
// Reads WhisperKit's own load messages into the sub-model it is compiling (issue #897).

import Foundation

/// Which part of a WhisperKit model load a log message announces.
///
/// WHY: when a Turbo preparation hits its 300 s budget, the debug log says only that the
/// whole `WhisperKit(config)` call did not return. WhisperKit compiles four Core ML
/// sub-models in a fixed order (mel spectrogram, decoder prefill, text decoder, audio
/// encoder), once for the prewarm pass and again for the load pass, and announces each in
/// a debug message. The last stage started and never done is the sub-model Core ML is
/// stuck on.
///
/// Only these messages are kept. Everything else WhisperKit logs is dropped, including the
/// folder line (it carries the container path) and decoding output (the user's words).
public enum WhisperKitLoadStage: String, Sendable, Equatable {
    case prewarmPassStarted
    case loadPassStarted
    case melSpectrogramStarted
    case melSpectrogramDone
    case prefillStarted
    case prefillDone
    case textDecoderStarted
    case textDecoderDone
    case audioEncoderStarted
    case audioEncoderDone

    /// Message prefixes from WhisperKit 0.18.0 `WhisperKit.init` and `loadModels`. The
    /// prefill entries precede the text decoder ones because they share a prefix.
    private static let prefixes: [(String, WhisperKitLoadStage)] = [
        ("Prewarming models...", .prewarmPassStarted),
        ("Loading models...", .loadPassStarted),
        ("Loading feature extractor", .melSpectrogramStarted),
        ("Loaded feature extractor", .melSpectrogramDone),
        ("Loading text decoder prefill", .prefillStarted),
        ("Loaded text decoder prefill", .prefillDone),
        ("Loading text decoder", .textDecoderStarted),
        ("Loaded text decoder", .textDecoderDone),
        ("Loading audio encoder", .audioEncoderStarted),
        ("Loaded audio encoder", .audioEncoderDone)
    ]

    /// WhisperKit's `Logging.debug` hands its callback the description of its variadic
    /// array, so a message arrives as `["Loading audio encoder"]`. Both forms are read.
    public init?(logMessage: String) {
        var text = Substring(logMessage)
        if text.hasPrefix("[\"") { text = text.dropFirst(2) }
        guard let match = Self.prefixes.first(where: { text.hasPrefix($0.0) }) else { return nil }
        self = match.1
    }
}
