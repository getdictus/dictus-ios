// DictusCore/Sources/DictusCore/ProtectedDataLaunchWork.swift
import Foundation

/// Runs DictusApp's App Group launch work once, at the first moment the App Group can be
/// read and trusted (#868): protected data available and `AppGroupReadCheck` `.trusted`.
///
/// On an ordinary launch that moment is `App.init`, and the work runs there as it always
/// did. On a launch iOS makes at boot before the first unlock it is later, or never in a
/// process whose view stays stale: the app asks again when `protectedDataDidBecomeAvailable`
/// fires and at every activation, and the first ask that finds the reads trusted runs it.
public final class ProtectedDataLaunchWork {

    private let isReady: () -> Bool
    private let work: () -> Void

    /// Whether the work has run in this process.
    public private(set) var hasRun = false

    public init(isReady: @escaping () -> Bool, work: @escaping () -> Void) {
        self.isReady = isReady
        self.work = work
    }

    /// Run the work if it has not run yet and the App Group reads can be trusted.
    ///
    /// - Returns: true when this call ran it.
    @discardableResult
    public func runIfAvailable() -> Bool {
        guard !hasRun, isReady() else { return false }
        hasRun = true
        work()
        return true
    }
}
