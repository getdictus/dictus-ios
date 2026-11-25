// DictusKeyboard/TextPrediction/SpatialAutocorrect.swift
//
// Spatial autocorrect (#1011): Hex's noisy-channel decoder (github.com/anomalyco/hex,
// MIT, Copyright (c) 2026 Christopher Langton), ported in DictusCore/SpatialDecoder.
// This file is the keyboard's side of it: the switch as it acts, and the models in the bundle.
import DictusCore
import Foundation

/// Whether the space bar reads the taps, and the decoder for each language.
enum SpatialAutocorrect {
    /// Whether the space bar consults the decoder: the Experiments page's "Spatial
    /// autocorrect" switch (`SharedKeys.keyboardSpatialAutocorrect`) as it acts,
    /// `KeyboardFeatureSettings.isSpatialAutocorrectEffective` — the switch on a test build
    /// (Debug, TestFlight), off in the App Store build whatever the store holds.
    ///
    /// WHY a value set at each appearance (`refresh`) rather than a read of the store on
    /// every tap: the switch lives in the app, where the keyboard is not on screen, so an
    /// appearance is the first moment a change can be seen — the moment swipe typing is
    /// configured too. Read per tap it would cost an App Group read and a channel read on
    /// every keystroke for an answer that cannot have changed since the keyboard appeared.
    ///
    /// The Debug app's launch argument `-DictusDebugSpatialAutocorrect YES` (or `NO`) writes
    /// the same switch (`DictusApp`, `applySpatialAutocorrectArgument`), then make the
    /// keyboard reappear.
    ///
    /// Main thread only: set by the bridge's refresh, read by its keystroke handlers.
    private(set) static var isOn = KeyboardFeatureSettings.Defaults.spatialAutocorrect

    /// Reads the switch from `settings`, the keyboard's view of the App Group
    /// (`KeyboardFeatureSettings.forKeyboard()`). Returns the value now in force.
    @discardableResult
    static func refresh(_ settings: KeyboardFeatureSettings) -> Bool {
        isOn = settings.isSpatialAutocorrectEffective
        return isOn
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
