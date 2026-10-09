// DictusCore/Sources/DictusCore/Polish/TranslationTimeBudget.swift
// How long Translate may wait on Apple's Translation framework, per process (#648).
import Foundation

/// How long Translate may wait on the Translation framework, and what a timeout means.
///
/// ### Two budgets, because two processes wait for two different reasons
///
/// **The keyboard** has a watchdog: `PolishTimeBudget` gives a generation at least 15 s
/// before the overlay comes down. Translate there gets a flat 8 s, and on expiry falls
/// back to Apple FM, which on a keyboard-length dictation still fits inside the rest.
/// The device test (#648, 2026-10-08) saw keyboard translations take 0.8 to 3.3 s.
///
/// **DictusApp** runs Translate for voice notes and in-app dictations, and a voice note
/// can run four minutes. A flat 8 s there lost a 226 s, 4,198-character note: the
/// deadline fired at 8.4 s, Apple FM took over and ran 16.8 s more. So the app's budget
/// grows with the input: 20 ms per character, between 30 s and 5 minutes. On the Mac a
/// 4,443-character French text took 12.4 to 13.0 s in 800-character chunks (16.9 s
/// in one call), so 89 s for that text is about seven times what was measured, which
/// leaves room for a slower phone without waiting forever on a stuck one.
///
/// ### A timeout in the app is a failure, not a fallback
///
/// Apple FM is slower than the framework on a long text and may not fit it in its
/// context window at all, so handing it a text the framework merely needed more time
/// for is the worst trade on offer (#648 problem 1b). In the app a timeout fails the
/// mode, which the voice note card reports with a retry. In the keyboard it falls back,
/// as before.
public struct TranslationTimeBudget: Equatable, Sendable {
    /// The largest chunk handed to the framework in one call (`TranslationChunking`).
    public let chunkCharacters: Int
    /// The longest one chunk may take.
    public let perChunkSeconds: Int
    /// The overall budget's floor, rate and ceiling.
    let overallFloorSeconds: Int
    let overallSecondsPerCharacter: Double
    let overallCeilingSeconds: Int
    /// Whether a timeout hands the text to Apple FM (keyboard) or fails the mode (app).
    public let fallsBackOnTimeout: Bool

    /// The keyboard extension: 8 s overall, Apple FM on expiry.
    public static let keyboard = TranslationTimeBudget(
        chunkCharacters: 800, perChunkSeconds: 8,
        overallFloorSeconds: 8, overallSecondsPerCharacter: 0, overallCeilingSeconds: 8,
        fallsBackOnTimeout: true
    )

    /// DictusApp (voice notes, in-app dictations): scaled to the input, fails on expiry.
    public static let app = TranslationTimeBudget(
        chunkCharacters: 800, perChunkSeconds: 30,
        overallFloorSeconds: 30, overallSecondsPerCharacter: 0.02, overallCeilingSeconds: 300,
        fallsBackOnTimeout: false
    )

    /// The whole attempt's budget for an input of `characters`.
    public func overallSeconds(forCharacters characters: Int) -> Int {
        let scaled = Int((Double(max(0, characters)) * overallSecondsPerCharacter).rounded(.up))
        return min(overallCeilingSeconds, max(overallFloorSeconds, scaled))
    }
}
