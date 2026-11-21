// DictusKeyboard/TextPrediction/AdaptiveTouchSwitch.swift
//
// Adaptive touch (#1014): Hex's personal key centres (github.com/anomalyco/hex, MIT,
// Copyright (c) 2026 Christopher Langton), ported in DictusCore/AdaptiveTouch. This file
// is the keyboard's side of it: the switch, and the one learner this process uses.
import DictusCore
import Foundation

/// Whether the keyboard learns where this user lands on each key and the spatial decoder
/// reads the taps with those centres.
enum AdaptiveTouchSwitch {
    /// App Group key of the switch, beside `SpatialAutocorrect.switchKey`. Debug builds
    /// only: a Release build never reads it.
    ///
    /// WHY here and not in `SharedKeys`: as for the decoder's switch, nothing but the
    /// keyboard reads it until a device test earns it a row in the app's settings.
    ///
    /// Turn it on with the Debug app's launch argument, which writes it (`DictusApp`):
    /// `xcrun devicectl device process launch --device <id> com.pivi.dictus -DictusDebugAdaptiveTouch YES`.
    /// `-DictusDebugAdaptiveTouchReset YES` forgets what was learned.
    static let switchKey = "debug.adaptiveTouch"

    /// On only with the decoder on: the decoder is the only reader of the centres, and the
    /// taps it keeps are the ones Adaptive touch learns from.
    static var isOn: Bool {
        #if DEBUG
        // LOCAL BATCH BUILD ONLY (never pushed): on unless the key was written NO.
        return SpatialAutocorrect.isOn && (AppGroup.defaults.object(forKey: switchKey) as? Bool ?? true)
        #else
        return false
        #endif
    }

    private static var shared: AdaptiveTouch?

    /// The process's learner while the switch is on; nil while it is off (what it learned
    /// is saved first). Main thread: the keyboard calls it as it types.
    static var current: AdaptiveTouch? {
        guard isOn else {
            shared?.save()
            shared = nil
            return nil
        }
        if let shared { return shared }
        // The App Group file (Full Access); without one, memory until the keyboard closes.
        let storage = AdaptiveTouchStore.defaultURL.map(AdaptiveTouch.Storage.file) ?? .memory
        let touch = AdaptiveTouch(storage: storage, defaults: AppGroup.defaults)
        shared = touch
        return touch
    }

    /// Writes what was learned, when the keyboard goes away.
    static func save() {
        shared?.save()
    }
}
