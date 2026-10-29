// DictusCore/Sources/DictusCore/ProtectedDataLaunchWork.swift
import Foundation

/// Runs DictusApp's App Group launch work once, at the first moment protected data is
/// available (#868).
///
/// On an ordinary launch that moment is `App.init`, and the work runs there as it always
/// did. On a launch iOS makes at boot before the first unlock it is later: the app asks
/// again when `protectedDataDidBecomeAvailable` fires and at every activation, and the
/// first ask that finds the data readable runs the work.
public final class ProtectedDataLaunchWork {

    private let availability: ProtectedDataAvailability
    private let work: () -> Void

    /// Whether the work has run in this process.
    public private(set) var hasRun = false

    public init(availability: ProtectedDataAvailability, work: @escaping () -> Void) {
        self.availability = availability
        self.work = work
    }

    /// Run the work if it has not run yet and protected data is available.
    ///
    /// - Returns: true when this call ran it.
    @discardableResult
    public func runIfAvailable() -> Bool {
        guard !hasRun, availability.isProtectedDataAvailable else { return false }
        hasRun = true
        work()
        return true
    }
}
