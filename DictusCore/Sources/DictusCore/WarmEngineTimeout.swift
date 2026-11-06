// DictusCore/Sources/DictusCore/WarmEngineTimeout.swift
// The user's choice of how long the warm audio engine waits after a dictation (#380).

import Foundation

/// The presets of the inactivity timeout setting (#380 decision 1).
///
/// WHY a closed set rather than a free number of seconds: the picker shows exactly
/// these, and a stored value that is not one of them — a typo, a value from a
/// future build — must fall back to the default rather than arm an arbitrary timer.
/// The raw values are what the App Group stores, so they are part of the format:
/// renaming a case orphans what users picked.
public enum WarmEngineTimeoutOption: String, CaseIterable, Sendable {
    case immediately
    case oneMinute
    case fiveMinutes
    case tenMinutes
    case thirtyMinutes
    case oneHour
    case unlimited

    /// 10 minutes, the value #106 Phase B shipped, so an upgrade changes nothing (decision 5).
    public static let defaultOption: WarmEngineTimeoutOption = .tenMinutes

    /// How long the engine may sit warm and idle. `nil` is Unlimited: no window at all.
    ///
    /// WHY `0` for Immediately rather than a case the caller must special-case: it is
    /// what the setting means, a window that closes as soon as the dictation is over.
    /// What it cannot mean is "release when the samples are collected", because the
    /// dictation is not over then — see `idleTimerInterval`.
    public var interval: TimeInterval? {
        switch self {
        case .immediately: return 0
        case .oneMinute: return 60
        case .fiveMinutes: return 5 * 60
        case .tenMinutes: return 10 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .unlimited: return nil
        }
    }

    /// The timer the engine arms when it goes warm-idle. `nil` arms nothing.
    ///
    /// Immediately arms the default window, as a backstop and not as its behaviour.
    /// The engine goes warm-idle when a recording's samples are collected, and the
    /// transcription, the Smart Mode and the keyboard hand-off all run after that
    /// moment. From the keyboard, Dictus is in the background then, and the warm
    /// engine (`UIBackgroundModes: audio`) is the only thing keeping the process
    /// alive: releasing it there would let iOS suspend Dictus mid-transcription.
    /// So the release itself comes from the dictation's end, and this timer only
    /// bounds a warm state whose end was never reported.
    public var idleTimerInterval: TimeInterval? {
        self == .immediately ? Self.defaultOption.interval : interval
    }
}

/// The warm engine's idle window, from one place (#620 decision 4).
///
/// The engine releases itself after this long without a dictation, which ends the
/// standby pill. Read here, and only here, so it stays independent of the voice note
/// island, whose ready state has its own 5-minute lifetime (`VoiceNoteIsland.readyLifetime`).
///
/// WHY App Group defaults (#380 decision 6): the setting is written by DictusApp's
/// Settings and read by the engine in the same process today, but the keyboard
/// extension reads the same suite, and one stored value is what keeps the two from
/// ever disagreeing about it.
public enum WarmEngineTimeout {
    /// The stored option. Missing or unknown values fall back to `defaultOption`.
    public static func option(in defaults: UserDefaults = AppGroup.defaults) -> WarmEngineTimeoutOption {
        defaults.string(forKey: SharedKeys.warmEngineTimeout)
            .flatMap(WarmEngineTimeoutOption.init(rawValue:))
            ?? .defaultOption
    }
}
