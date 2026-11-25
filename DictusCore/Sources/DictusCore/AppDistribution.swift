// DictusCore/Sources/DictusCore/AppDistribution.swift
// Where the app was installed from, as the app reads it, handed to the keyboard (#948).
import Foundation

/// Where the running app came from: a Debug build, TestFlight or the App Store.
///
/// WHY the app tells the keyboard instead of the keyboard asking its own receipt:
/// `BuildChannel.current` reads `Bundle.main.appStoreReceiptURL`, and in an app extension
/// `Bundle.main` is the extension's bundle, whose receipt URL Apple does not document. A
/// keyboard reading `.appStore` from a TestFlight install would silently ignore every
/// experiment a tester switched on. The app's own reading is the documented one, so the app
/// writes it into the App Group (`record`) and the keyboard reads it there (`recorded`).
///
/// Every doubt still resolves to the App Store: a keyboard that finds no value (the app
/// never opened since the install), or one it does not know, reads `.appStore`.
public enum AppDistribution: String, Equatable, Sendable, CaseIterable {
    case debug
    case testFlight
    case appStore

    /// The running binary's distribution, by `BuildChannel.current`'s rule: Debug by
    /// construction, then the receipt's file name. Reliable in the app, not in an extension.
    public static let current: AppDistribution = detect(isDebug: BuildChannel.isDebugBuild,
                                                        receiptURL: Bundle.main.appStoreReceiptURL)

    /// The rule behind `current`, with its inputs passed in so tests can drive it. The same
    /// one `BuildChannel.detect` applies, with Debug and TestFlight told apart.
    static func detect(isDebug: Bool, receiptURL: URL?) -> AppDistribution {
        if isDebug { return .debug }
        return receiptURL?.lastPathComponent == "sandboxReceipt" ? .testFlight : .appStore
    }

    /// What the log and the Experiments rules need: a Debug or TestFlight build is a test build.
    public var channel: BuildChannel {
        switch self {
        case .debug, .testFlight: return .testBuild
        case .appStore: return .appStore
        }
    }

    /// The app's side: stores `distribution` for the keyboard. A write of a constant, safe
    /// to repeat at every activation.
    public static func record(_ distribution: AppDistribution = .current, in store: UserDefaults = AppGroup.defaults) {
        guard store.string(forKey: SharedKeys.appDistribution) != distribution.rawValue else { return }
        store.set(distribution.rawValue, forKey: SharedKeys.appDistribution)
    }

    /// The keyboard's side: what the app stored, or nil when it stored nothing the keyboard
    /// knows.
    public static func recorded(in store: UserDefaults = AppGroup.defaults) -> AppDistribution? {
        store.string(forKey: SharedKeys.appDistribution).flatMap(AppDistribution.init(rawValue:))
    }

    /// The channel the keyboard acts on: the app's reading, the App Store without one.
    public static func recordedChannel(in store: UserDefaults = AppGroup.defaults) -> BuildChannel {
        recorded(in: store)?.channel ?? .appStore
    }
}
