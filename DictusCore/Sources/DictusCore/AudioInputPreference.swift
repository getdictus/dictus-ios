import Foundation

/// The input used by the next recording. Missing values preserve the built-in mic.
public enum AudioInputPreference: String, CaseIterable, Sendable {
    case automatic
    case builtIn

    public init(storedValue: String?) {
        self = storedValue.flatMap(Self.init(rawValue:)) ?? .builtIn
    }

    public static var current: Self {
        Self(storedValue: AppGroup.defaults.string(forKey: SharedKeys.audioInputDevice))
    }
}
