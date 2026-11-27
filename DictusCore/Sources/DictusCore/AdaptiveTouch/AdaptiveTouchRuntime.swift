// DictusCore/Sources/DictusCore/AdaptiveTouch/AdaptiveTouchRuntime.swift
//
// Adaptive touch (#1014) as one keyboard process runs it: whether it is on, and the one
// learner it uses while it is.
import Foundation

/// Adaptive touch's on/off and learner for one keyboard process.
///
/// WHY a value set at each appearance (`refresh`) rather than a read of the store on every
/// tap: the switches live in the app's Experiments page, where the keyboard is not on
/// screen, so an appearance is the first moment a change can be seen. It is read at the
/// same moment as spatial autocorrect's (`SpatialAutocorrect.refresh`), from the same
/// settings, so the two never disagree inside one appearance.
///
/// Off, there is no learner: no tap is labelled, nothing is written, and the decoder gets
/// its stock centres (`decoderInput`). Not thread-safe: the keyboard calls it on the main
/// thread.
public final class AdaptiveTouchRuntime {
    public private(set) var isOn = false
    private var learner: AdaptiveTouch?
    private let makeLearner: () -> AdaptiveTouch

    /// `makeLearner` builds the learner the first time it is needed while on (the App Group
    /// file in the keyboard, a scratch file in tests).
    public init(makeLearner: @escaping () -> AdaptiveTouch) {
        self.makeLearner = makeLearner
    }

    /// Reads `settings.isAdaptiveTouchEffective`. Turning off writes what was learned while
    /// it was on (never over a newer reset, `AdaptiveTouch.save`) and drops the learner.
    /// Returns the value now in force.
    @discardableResult
    public func refresh(_ settings: KeyboardFeatureSettings) -> Bool {
        isOn = settings.isAdaptiveTouchEffective
        if !isOn {
            learner?.save()
            learner = nil
        }
        return isOn
    }

    /// The learner while on, nil while off.
    public var current: AdaptiveTouch? {
        guard isOn else { return nil }
        if let learner { return learner }
        let made = makeLearner()
        learner = made
        return made
    }

    /// The `adaptiveTouchStatus` line for this appearance (#1081), read from the learner in
    /// memory while on. Off, from the App Group file at `url` when there is one (about 24 KB,
    /// once per appearance, never per tap), so a switch turned off still says what is stored.
    /// `defaults` holds the reset generation.
    public func statusEvent(file url: URL?, defaults: UserDefaults?) -> LogEvent {
        let resetAt = AdaptiveTouchStore.resetAt(defaults)
        if let learner = current {
            let letters = learner.geometry.map { [$0.key: $0.letters] } ?? [:]
            let status = AdaptiveTouchStatus(model: learner.model, geometry: learner.geometry?.key, letters: letters,
                                             resetAt: resetAt)
            return .adaptiveTouchStatus(on: true, stored: .notRead, status: status)
        }
        // Turning off just queued the dropped learner's save (`refresh`): read the file once it
        // landed, or this line reports the file before it. Nothing queued, nothing to wait for.
        AdaptiveTouch.waitForWrites()
        let data = url.flatMap { FileManager.default.fileExists(atPath: $0.path) ? try? Data(contentsOf: $0) : nil }
        let (stored, status) = AdaptiveTouchStatus.stored(data: data, resetAt: resetAt)
        return .adaptiveTouchStatus(on: false, stored: stored, status: status)
    }

    /// Writes what was learned (the keyboard going away).
    public func save() {
        learner?.save()
    }

    /// The spatial decoder's input with this user's centres when a profile is in use, the
    /// stock ones kept as the baseline no correction may go past. `input` unchanged while
    /// off or without a profile.
    public func decoderInput(_ input: SpatialCorrection.Input?) -> SpatialCorrection.Input? {
        guard let input else { return nil }
        guard let personal = current?.personalKeys(for: input.keys) else { return input }
        return SpatialCorrection.Input(taps: input.taps, keys: personal, baseline: input.keys)
    }
}
