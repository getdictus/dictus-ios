// DictusCore/Sources/DictusCore/TypingJournal/DebugSwitches.swift
// The state of the keyboard's experiments (spatial, adaptive, bilingual), as one journal line.
//
// Debug builds only, like the journal: a Release build has no such switches.
#if DEBUG
import Foundation

/// Which of the keyboard's experimental switches are on: the spatial decoder (#1011),
/// Adaptive touch (#1014) and the bilingual check (#1015).
///
/// WHY a line of its own: a device log says which code path decided each word (`branch=`),
/// not whether a path was even available. On Pierre's session of 2026-11-23 the three
/// switches had to be inferred from the branches seen. The keyboard now writes
/// `TJ SWITCHES spatial=on adaptive=on bilingual=on source=appGroup` when it appears, and
/// again whenever the state differs from the last line it wrote.
public struct DebugSwitches: Equatable, Sendable {
    /// Where the values come from: `appGroup` when at least one switch was written to the
    /// App Group (by the Experiments page or the Debug app's launch arguments), `default`
    /// when none was and every switch reads its default, off.
    public enum Source: String, Sendable {
        case `default`
        case appGroup
    }

    public var spatial: Bool
    public var adaptive: Bool
    public var bilingual: Bool
    public var source: Source

    public init(spatial: Bool, adaptive: Bool, bilingual: Bool, source: Source) {
        self.spatial = spatial
        self.adaptive = adaptive
        self.bilingual = bilingual
        self.source = source
    }

    /// The App Group keys of the three switches, the Experiments page's
    /// (`KeyboardFeatureSettings`).
    public static let keys = [
        SharedKeys.keyboardSpatialAutocorrect, SharedKeys.keyboardAdaptiveTouch, SharedKeys.keyboardBilingualAutocorrect
    ]

    /// `appGroup` when `defaults` holds any of `keys`, else `default`.
    public static func source(of keys: [String], in defaults: UserDefaults) -> Source {
        keys.contains { defaults.object(forKey: $0) != nil } ? .appGroup : .default
    }

    /// The journal line's body.
    public var line: String {
        func onOff(_ value: Bool) -> String { value ? "on" : "off" }
        return "TJ SWITCHES spatial=\(onOff(spatial)) adaptive=\(onOff(adaptive)) "
            + "bilingual=\(onOff(bilingual)) source=\(source.rawValue)"
    }

    private static let lock = NSLock()
    private static var lastLogged: DebugSwitches?

    /// Whether `switches` is a line to write: the first of the process, or a state that
    /// differs from the last one written. A keyboard appears many times per process, and
    /// the switches change only between appearances (the app writes them, the keyboard
    /// reappears), so this is one line per start and one per change.
    public static func shouldLog(_ switches: DebugSwitches) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard switches != lastLogged else { return false }
        lastLogged = switches
        return true
    }

    /// Forgets the last line written. For tests.
    static func resetLogged() {
        lock.lock()
        lastLogged = nil
        lock.unlock()
    }
}
#endif
