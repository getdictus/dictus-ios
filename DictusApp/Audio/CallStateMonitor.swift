// DictusApp/Audio/CallStateMonitor.swift
// Detects active phone calls via CXCallObserver to prevent SIGABRT crash (#71).
import Foundation
import CallKit
import DictusCore
import os

/// Monitors telephony call state using CallKit's CXCallObserver.
///
/// WHY this exists: Starting AVAudioEngine.installTapOnBus while a phone call
/// is active triggers an Objective-C NSException (SIGABRT) that Swift's do/catch
/// cannot intercept. The only safe approach is to check call state BEFORE
/// attempting to start recording, and block with a user-visible error.
///
/// WHY CXCallObserver (not CTCallCenter): CTCallCenter is deprecated since iOS 10.
/// CXCallObserver is the modern replacement and works on all supported iOS versions (17+).
@MainActor
class CallStateMonitor: NSObject, ObservableObject, CXCallObserverDelegate {

    /// Whether a phone call is currently active (ringing, dialing, or connected).
    @Published private(set) var isCallActive = false

    private let callObserver = CXCallObserver()

    override init() {
        super.init()
        callObserver.setDelegate(self, queue: .main)
        updateCallState()
    }

    // MARK: - CXCallObserverDelegate

    /// Called by CallKit whenever a call's state changes (incoming, connected, ended).
    /// WHY nonisolated: CXCallObserverDelegate requires this method to be non-isolated
    /// because CallKit may invoke it from any thread. We dispatch to main for @Published.
    nonisolated func callObserver(_ observer: CXCallObserver, callChanged call: CXCall) {
        DispatchQueue.main.async { [weak self] in
            self?.updateCallState()
        }
    }

    // MARK: - Private

    private func updateCallState() {
        let wasActive = isCallActive
        isCallActive = callObserver.calls.contains { !$0.hasEnded }
        if wasActive != isCallActive {
            DictusLogger.app.info("Call state changed: active=\(self.isCallActive)")
        }
    }
}
