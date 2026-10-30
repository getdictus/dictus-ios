// DictusCore/Sources/DictusCore/ProtectedDataAvailability.swift
// The two seams a launch before first unlock goes through (#868).
//
// WHY THIS EXISTS: iOS can start DictusApp at boot, before the user has unlocked the
// iPhone once (app prewarming). Until that first unlock the App Group is protected data:
// its `UserDefaults` reads come back empty and its files cannot be opened. A process that
// trusts what it reads in that window shows onboarding to a user who finished it long ago,
// misses the stop the keyboard asked for, and writes launch defaults over real settings.
// Neither seam can be exercised on a simulator, which never launches before first unlock,
// so the decisions that depend on them take both as parameters and are tested here.
import Foundation

/// Whether the device has been unlocked since boot, so protected data can be read.
///
/// The app passes `UIApplication.shared.isProtectedDataAvailable`; tests pass a constant.
public protocol ProtectedDataAvailability {
    var isProtectedDataAvailable: Bool { get }
}

/// The slice of the App Group `UserDefaults` the launch and the keyboard-signal
/// decisions read and write. `UserDefaults` conforms as is.
public protocol AppGroupStore: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func string(forKey defaultName: String) -> String?
    func bool(forKey defaultName: String) -> Bool
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: AppGroupStore {}

/// Whether a file protected until first unlock can be opened yet (#868).
///
/// WHY A FILE AND NOT ONLY `UIApplication.isProtectedDataAvailable`: in `App.init` that
/// property reads false on every launch, because the application has not finished
/// launching (measured on the iOS 26.5 simulator on 2026-10-29: `protectedData=false` on
/// a launch from the home screen). The App Group's preferences file is protected until
/// first unlock like every file in the container, and opening it tells the two launches
/// apart from the first line of `init`.
public enum ProtectedDataProbe {

    /// The App Group's `UserDefaults` file.
    public static var appGroupPreferencesURL: URL? {
        AppGroup.containerURL?
            .appendingPathComponent("Library/Preferences/\(AppGroup.identifier).plist")
    }

    /// Whether the file at `url` can be opened for reading.
    ///
    /// True when there is no such file: a new install has nothing protected to misread.
    /// Its existence can be checked before first unlock, only its content is protected.
    public static func canOpen(_ url: URL?) -> Bool {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return true }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        try? handle.close()
        return true
    }
}
