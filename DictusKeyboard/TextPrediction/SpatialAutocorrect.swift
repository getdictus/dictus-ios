// DictusKeyboard/TextPrediction/SpatialAutocorrect.swift
//
// Spatial autocorrect (#1011): Hex's noisy-channel decoder (github.com/anomalyco/hex,
// MIT, Copyright (c) 2026 Christopher Langton), ported in DictusCore/SpatialDecoder.
// This file is the keyboard's side of it: the switch, and the models in the bundle.
import DictusCore
import Foundation

/// Whether the space bar reads the taps, and the decoder for each language.
enum SpatialAutocorrect {
    /// App Group key of the switch. Debug builds only: a Release build never reads it,
    /// so the decoder cannot run there whatever the store holds.
    ///
    /// WHY here and not in `SharedKeys`: the switch is an experiment of the keyboard's
    /// and nothing else reads it. It moves to `SharedKeys`, with a row in the app's Debug
    /// settings, once the decoder is measured on a device and earns a setting.
    ///
    /// Set it on a simulator with:
    /// `xcrun simctl spawn <udid> defaults write group.solutions.pivi.dictus debug.spatialAutocorrect -bool YES`
    static let switchKey = "debug.spatialAutocorrect"

    static var isOn: Bool {
        #if DEBUG
        return AppGroup.defaults.bool(forKey: switchKey)
        #else
        return false
        #endif
    }

    /// A change to Hex's parameters, for the bench's sweeps; nil in the keyboard.
    static var tuning: ((inout SpatialDecoder.Parameters) -> Void)?

    private static let lock = NSLock()
    private static var decoders: [String: SpatialDecoder?] = [:]

    /// The decoder for `language`, its model mapped on first use; nil when the bundle has
    /// no model for it (only `fr.hextm` and `en.hextm` ship).
    static func decoder(for language: String) -> SpatialDecoder? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = decoders[language] { return cached }
        let decoder = Bundle.main.path(forResource: language, ofType: "hextm")
            .flatMap { SpatialDecoderModel(path: $0) }
            .map { model -> SpatialDecoder in
                var parameters = SpatialDecoder.Parameters.tuned(for: model.language)
                tuning?(&parameters)
                return SpatialDecoder(model: model, parameters: parameters)
            }
        decoders[language] = decoder
        return decoder
    }
}
