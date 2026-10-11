// DictusCore/Sources/DictusCore/IntroAutoAdvance.swift
// When the intro carousel turns its own pages, and how long it stays on each (#676).
import Foundation

/// The rules of the intro carousel's auto-advance (#676, decided 2026-10-09).
///
/// WHY THE CAROUSEL TURNS ITS OWN PAGES: on the first device test the user tapped
/// **Get started** on page 1 and never saw pages 2 and 3. Wispr Flow's opening carousel
/// moves on by itself, and so does this one: 1 → 2 → 3 → 1, until the button is tapped.
/// A page stays on screen for one full pass of its scene (`OnboardingIntroScene.loopSeconds`).
public enum IntroAutoAdvance {

    /// Whether the carousel may turn its pages by itself.
    ///
    /// - VoiceOver: never. Content that moves on its own while a VoiceOver user is reading
    ///   it takes the focus away from them; they swipe through the pages themselves.
    /// - Reduce Motion: never. The user asked the system for less motion, and a carousel
    ///   sliding every few seconds is exactly that.
    public static func isEnabled(voiceOverRunning: Bool, reduceMotion: Bool) -> Bool {
        !voiceOverRunning && !reduceMotion
    }

    /// Whether a page plays its video, rather than showing its still frame.
    ///
    /// With Reduce Motion on, the still frame alone: it tells the scene without moving.
    public static func playsVideo(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}

/// The time spent on one page, which can be paused and resumed.
///
/// WHY PAUSABLE: when the app goes to the background, the scene's player pauses where it
/// is. The page's time pauses with it and resumes on return, so the page still turns after
/// one full pass of the scene, not earlier because of the time spent away.
///
/// A swipe lands on a new page and starts a new `IntroDwellTimer`: the page the user
/// chose gets its full time.
///
/// Times are seconds on any monotonic clock the caller picks; the type never reads one,
/// which keeps it testable.
public struct IntroDwellTimer: Equatable, Sendable {
    /// How long the page stays on screen in total, in seconds.
    public let dwellSeconds: Double
    /// Time spent on the page before the last pause.
    private var accumulated: Double = 0
    /// When the current running stretch started, or nil while paused.
    private var runningSince: Double?

    /// A paused timer for a page that stays `dwellSeconds` on screen.
    public init(dwellSeconds: Double) {
        self.dwellSeconds = dwellSeconds
    }

    /// Whether time is currently counting.
    public var isRunning: Bool { runningSince != nil }

    /// Starts counting at `now`. No effect when already running.
    public mutating func resume(at now: Double) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    /// Stops counting at `now`, keeping the time spent so far. No effect when paused.
    public mutating func pause(at now: Double) {
        guard let start = runningSince else { return }
        accumulated += max(0, now - start)
        runningSince = nil
    }

    /// Time left before the page turns, at `now`. Never negative.
    public func remaining(at now: Double) -> Double {
        let running = runningSince.map { max(0, now - $0) } ?? 0
        return max(0, dwellSeconds - accumulated - running)
    }
}
