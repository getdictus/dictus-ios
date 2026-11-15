// DictusCore/Sources/DictusCore/ModelDownloadCancellations.swift
// Which in-flight download attempts the user has cancelled since they started (issue #493).
import Foundation

/// Tells a download attempt whether the user cancelled it after it started.
///
/// WHY A COUNTER AND NOT A FLAG (issue #493). An attempt is long: a repository listing,
/// a transfer, a hop back to the main actor. A cancel can land at any point of it, and
/// the user can tap Download again before the cancelled attempt has noticed. A flag set
/// by the cancel and cleared by the new download would be cleared before the old attempt
/// reads it, and the old attempt would go on to compile a model the user said no to. A
/// count bumped only by a cancel has no such window: the old attempt captured the count
/// from before the cancel, the new one the count from after, and only the old one sees a
/// difference.
public struct ModelDownloadCancellations: Sendable {

    private var counts: [String: Int] = [:]

    public init() {}

    /// The token an attempt captures when it starts, and hands back to `isCancelled`.
    public func token(for model: String) -> Int {
        counts[model, default: 0]
    }

    /// Records that the user cancelled every attempt at this model started so far.
    public mutating func cancel(_ model: String) {
        counts[model, default: 0] += 1
    }

    /// Whether the user cancelled this model since the attempt holding `token` started.
    public func isCancelled(_ model: String, since token: Int) -> Bool {
        counts[model, default: 0] != token
    }
}
