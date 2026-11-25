// DictusCore/Sources/DictusCore/KeyboardFeatureSettings.swift
// The on/off of every keyboard feature, its default, and the rules that combine them.
import Foundation

/// The keyboard features the app's "Clavier" and "Expériences" screens switch on and off,
/// read by the keyboard extension through the App Group.
///
/// WHY one type in DictusCore rather than a default in each place that reads a key:
/// the app's screen and the keyboard are two processes reading the same key, and a key
/// whose default is written twice ends up with two defaults — the screen shows a switch
/// on while the keyboard behaves as if it were off. Here the default is written once;
/// the screen's `@AppStorage` takes it from `Defaults` instead of a literal:
///
/// ```swift
/// @AppStorage(SharedKeys.keyboardDeleteWordSwipe, store: AppGroup.defaults)
/// private var deleteWordSwipe = KeyboardFeatureSettings.Defaults.deleteWordSwipe
/// ```
///
/// WHY a missing key reads as the default instead of being registered with
/// `UserDefaults.register(defaults:)`: registration lives in one process's memory, so the
/// app and the keyboard would each have to remember to do it before the first read.
/// Reading "absent means default" needs nobody to remember anything, and changing a
/// default later reaches every install that never touched the switch.
///
/// The keyboard reads swipe typing, spatial autocorrect and the delete swipe from here.
/// Adaptive touch and the bilingual check have no keyboard code reading a switch yet.
public struct KeyboardFeatureSettings {

    /// The value of each switch on an install that never touched it. The single source of
    /// truth: neither the app's screen nor the keyboard writes a default of its own.
    public enum Defaults {
        public static let spatialAutocorrect = false
        public static let adaptiveTouch = false
        public static let bilingualAutocorrect = false
        /// On: Pierre's decision, 2026-11-24 (#609).
        public static let deleteWordSwipe = true
        public static let swipeTyping = false
        /// On: the trail only shows while swipe typing, which is off by default.
        public static let swipeTrail = true
    }

    private let store: UserDefaults
    private let channel: BuildChannel

    /// - Parameters:
    ///   - store: where the switches live; the App Group in both targets, a scratch suite
    ///     in tests.
    ///   - channel: the build the binary comes from, which decides whether the
    ///     Experiments page exists. Injectable so tests can play each channel.
    public init(store: UserDefaults = AppGroup.defaults, channel: BuildChannel = .current) {
        self.store = store
        self.channel = channel
    }

    // MARK: - Switches
    //
    // `nonmutating set`: the struct holds no value of its own, only a reference to the
    // store, so writing a switch does not change the struct and works on a `let`.

    public var spatialAutocorrect: Bool {
        get { bool(SharedKeys.keyboardSpatialAutocorrect, default: Defaults.spatialAutocorrect) }
        nonmutating set { store.set(newValue, forKey: SharedKeys.keyboardSpatialAutocorrect) }
    }

    /// The user's choice only. Whether it has an effect is `isAdaptiveTouchEffective`.
    public var adaptiveTouch: Bool {
        get { bool(SharedKeys.keyboardAdaptiveTouch, default: Defaults.adaptiveTouch) }
        nonmutating set { store.set(newValue, forKey: SharedKeys.keyboardAdaptiveTouch) }
    }

    public var bilingualAutocorrect: Bool {
        get { bool(SharedKeys.keyboardBilingualAutocorrect, default: Defaults.bilingualAutocorrect) }
        nonmutating set { store.set(newValue, forKey: SharedKeys.keyboardBilingualAutocorrect) }
    }

    public var deleteWordSwipe: Bool {
        get { bool(SharedKeys.keyboardDeleteWordSwipe, default: Defaults.deleteWordSwipe) }
        nonmutating set { store.set(newValue, forKey: SharedKeys.keyboardDeleteWordSwipe) }
    }

    public var swipeTyping: Bool {
        get { bool(SharedKeys.keyboardSwipeTyping, default: Defaults.swipeTyping) }
        nonmutating set { store.set(newValue, forKey: SharedKeys.keyboardSwipeTyping) }
    }

    public var swipeTrail: Bool {
        get { bool(SharedKeys.keyboardSwipeTrail, default: Defaults.swipeTrail) }
        nonmutating set { store.set(newValue, forKey: SharedKeys.keyboardSwipeTrail) }
    }

    // MARK: - Rules

    /// Whether Adaptive touch changes anything: it moves the key centres the spatial
    /// decoder reads, so without the decoder it has nothing to act on.
    public var isAdaptiveTouchEffective: Bool {
        Self.isAdaptiveTouchEffective(adaptiveTouch: adaptiveTouch, spatialAutocorrect: spatialAutocorrect)
    }

    /// The same rule on values the caller already holds — the screen's `@AppStorage`
    /// bindings, which redraw on change where a read of the store would not.
    public static func isAdaptiveTouchEffective(adaptiveTouch: Bool, spatialAutocorrect: Bool) -> Bool {
        adaptiveTouch && spatialAutocorrect
    }

    /// Whether the app shows its Experiments page: on a test build (Debug, TestFlight),
    /// never in the App Store build (Pierre, 2026-11-24).
    public var isExperimentsPageVisible: Bool { Self.isExperimentsPageVisible(on: channel) }

    /// The rule behind `isExperimentsPageVisible`.
    ///
    /// WHY `BuildChannel` and not a detection of its own: it already tells a test build
    /// from the App Store one (#861), and every doubt it has resolves to `.appStore` —
    /// here the side that shows nothing. Two detections could disagree on the same
    /// binary; one cannot. Its limits are in `BuildChannel.current`; the one that matters
    /// here is that it is reliable in the app, which is where the page is.
    public static func isExperimentsPageVisible(on channel: BuildChannel) -> Bool {
        switch channel {
        case .testBuild: return true
        case .appStore: return false
        }
    }

    // MARK: - Experiments as the keyboard applies them

    /// The settings as the keyboard extension reads them: the channel is the one the app
    /// wrote (`AppDistribution.recordedChannel`), since the extension cannot read its own.
    public static func forKeyboard(store: UserDefaults = AppGroup.defaults) -> KeyboardFeatureSettings {
        KeyboardFeatureSettings(store: store, channel: AppDistribution.recordedChannel(in: store))
    }

    /// Swipe typing as it acts: the stored switch on a test build, its default in the App
    /// Store build, where the Experiments page that set it does not exist (Pierre,
    /// 2026-11-24). A tester who switched it on in TestFlight and then installs the App
    /// Store build gets the App Store's behaviour.
    public var isSwipeTypingEffective: Bool {
        Self.experiment(swipeTyping, default: Defaults.swipeTyping, on: channel)
    }

    /// Spatial autocorrect as it acts, by the same rule: the Experiments switch on a test
    /// build (Debug, TestFlight), its default (off) in the App Store build, whatever the
    /// store holds there. The keyboard reads it at each appearance (`SpatialAutocorrect`).
    public var isSpatialAutocorrectEffective: Bool {
        Self.experiment(spatialAutocorrect, default: Defaults.spatialAutocorrect, on: channel)
    }

    /// The trail, by the same rule. Meaningful only while `isSwipeTypingEffective`.
    public var isSwipeTrailEffective: Bool {
        Self.experiment(swipeTrail, default: Defaults.swipeTrail, on: channel)
    }

    /// An Experiments switch as it acts: `stored` where the page exists, `fallback` where it
    /// does not.
    public static func experiment(_ stored: Bool, default fallback: Bool, on channel: BuildChannel) -> Bool {
        isExperimentsPageVisible(on: channel) ? stored : fallback
    }

    // MARK: - Partner language

    /// The second language the bilingual check types alongside `keyboard`: the user's
    /// choice when there is one, otherwise `defaultPartnerLanguage(for:)`.
    ///
    /// A stored partner equal to `keyboard` reads as the default: the key is one global
    /// value, so a user who picked English for their French keyboard and then switched the
    /// keyboard to English would otherwise be paired with English itself.
    public func partnerLanguage(for keyboard: SupportedLanguage) -> SupportedLanguage {
        if let raw = store.string(forKey: SharedKeys.keyboardPartnerLanguage),
           let chosen = SupportedLanguage(rawValue: raw),
           chosen != keyboard {
            return chosen
        }
        return Self.defaultPartnerLanguage(for: keyboard)
    }

    public func setPartnerLanguage(_ language: SupportedLanguage) {
        store.set(language.rawValue, forKey: SharedKeys.keyboardPartnerLanguage)
    }

    /// The partner of each keyboard language before the user picks one.
    ///
    /// English for every non-English keyboard: it is the language French, Spanish and
    /// German typists mix in (tech words, brands, messages). French for the English
    /// keyboard, Dictus's first language and the other half of the only pair the
    /// bilingual engine builds today (fr + en, #1015): a Spanish or German partner is
    /// stored and returned, but has no engine yet.
    ///
    /// A `switch` with no `default:` on purpose: adding a language to `SupportedLanguage`
    /// stops the build here until someone decides its partner.
    public static func defaultPartnerLanguage(for keyboard: SupportedLanguage) -> SupportedLanguage {
        switch keyboard {
        case .french, .spanish, .german: return .english
        case .english: return .french
        }
    }

    // MARK: - Store

    /// The stored Bool, or `fallback` when the key is absent. `UserDefaults.bool(forKey:)`
    /// alone cannot say "absent", it answers false, which is wrong for a default of true.
    private func bool(_ key: String, default fallback: Bool) -> Bool {
        store.object(forKey: key) as? Bool ?? fallback
    }
}
