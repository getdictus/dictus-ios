// DictusKeyboard/TextPrediction/AdaptiveTouchSwitch.swift
//
// Adaptive touch (#1014): Hex's personal key centres (github.com/anomalyco/hex, MIT,
// Copyright (c) 2026 Christopher Langton), ported in DictusCore/AdaptiveTouch. This file
// is the keyboard's side of it: the one runtime this process uses, on the App Group file.
import DictusCore
import Foundation

/// Whether the keyboard learns where this user lands on each key and the spatial decoder
/// reads the taps with those centres: the Experiments page's "Adaptive touch" switch
/// (`SharedKeys.keyboardAdaptiveTouch`) as it acts,
/// `KeyboardFeatureSettings.isAdaptiveTouchEffective` — on a test build (Debug,
/// TestFlight) only, and only with spatial autocorrect acting too. Read at each keyboard
/// appearance with spatial autocorrect (`DictusKeyboardBridge.refreshExperiments`), never
/// per tap.
///
/// The Debug app's launch argument `-DictusDebugAdaptiveTouch YES` (or `NO`) writes the same
/// switch; `-DictusDebugAdaptiveTouchReset YES` and the Experiments page's reset forget what
/// was learned (`AdaptiveTouchStore.requestReset`).
enum AdaptiveTouchSwitch {
    /// Main thread only: refreshed by the bridge, read by its keystroke handlers.
    static let runtime = AdaptiveTouchRuntime {
        // The App Group file (Full Access); without one, memory until the keyboard closes.
        let storage = AdaptiveTouchStore.defaultURL.map(AdaptiveTouch.Storage.file) ?? .memory
        return AdaptiveTouch(storage: storage, defaults: AppGroup.defaults)
    }

    static var isOn: Bool { runtime.isOn }

    /// The process's learner while the switch acts; nil while it does not.
    static var current: AdaptiveTouch? { runtime.current }

    /// Reads the switch from `settings`, the keyboard's view of the App Group. Returns the
    /// value now in force.
    @discardableResult
    static func refresh(_ settings: KeyboardFeatureSettings) -> Bool {
        runtime.refresh(settings)
    }

    /// Writes what was learned, when the keyboard goes away.
    static func save() {
        runtime.save()
    }
}
