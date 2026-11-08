// DictusCore/Sources/DictusCore/Subscription/ProFeatureSwitches.swift
// The one owner of the three Pro feature switches in the app (#216).
import Foundation
import Combine

/// The per-feature Pro switches, as one observable object every screen of the app
/// reads and writes (#216).
///
/// ### Why it exists
///
/// The switches used to be `@AppStorage` properties, one per view that needed them:
/// the Dictus Pro hub's rows read the value, the feature screens pushed from it wrote
/// it. Each `@AppStorage(…, store: UserDefaults(suiteName:))` builds its **own**
/// `UserDefaults` instance and only redraws on changes it observes on that instance,
/// so a write made through the pushed screen's instance never redrew the hub: switch
/// Smart Modes off, go back, and the row still read "On" until the hub was reopened
/// (measured on the simulator, 2026-09-30). The stored value was right; nothing told
/// the other view.
///
/// One object, one `@Published` value per feature, is the one source of truth both
/// sides observe. A refresh-on-appear would have hidden the symptom on this path and
/// left the next pair of views with the same bug.
///
/// ### What it does not change
///
/// The storage. Every write goes to `feature.settingsKey` in the App Group, where
/// `FeatureGate` and the keyboard extension read it (#401); the extension never
/// instantiates this class and needs nothing from it.
@MainActor
public final class ProFeatureSwitches: ObservableObject {

    /// The app's instance, on the App Group.
    public static let shared = ProFeatureSwitches(defaults: AppGroup.defaults)

    @Published public private(set) var values: [ProFeature: Bool]

    private let defaults: UserDefaults

    /// - Parameter defaults: the App Group in the app; a test suite in the tests.
    public init(defaults: UserDefaults) {
        self.defaults = defaults
        self.values = Self.read(from: defaults)
    }

    /// Whether the feature's switch is on. Reads the published copy, so a view that
    /// calls this redraws when it changes.
    ///
    /// An unwritten key reads as on, matching `ProStatusManager.seedFeatureTogglesIfNeeded`,
    /// which writes `true` at first launch.
    public func isOn(_ feature: ProFeature) -> Bool {
        values[feature] ?? true
    }

    /// How many Pro features are switched on: the Home Pro card's subtitle (#216).
    public var onCount: Int {
        ProFeature.allCases.filter(isOn).count
    }

    /// Flips the switch: writes the App Group key, then publishes.
    public func set(_ feature: ProFeature, isOn: Bool) {
        defaults.set(isOn, forKey: feature.settingsKey)
        // The reader is another process, the same reason `ProStatusManager.setProActive`
        // synchronises.
        defaults.synchronize()
        values[feature] = isOn
    }

    /// Re-reads the three keys. For a write that did not come through `set`, which no
    /// code path makes today; kept public so one never needs a second owner.
    public func reload() {
        values = Self.read(from: defaults)
    }

    private static func read(from defaults: UserDefaults) -> [ProFeature: Bool] {
        Dictionary(uniqueKeysWithValues: ProFeature.allCases.map { feature in
            (feature, defaults.object(forKey: feature.settingsKey) as? Bool ?? true)
        })
    }
}
