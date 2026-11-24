// DictusCore/Sources/DictusCore/BuildChannel.swift
// Whether the running binary is a test build or the App Store one (#861).
import Foundation

/// Where the running binary came from, as far as what it may write to the debug log.
///
/// Only two answers, because only one question depends on it: may a log line carry
/// transcript text. A test build (Debug, simulator, TestFlight) may; the App Store build may not.
/// **Every doubt resolves to `.appStore`**, the side that writes less.
public enum BuildChannel: Equatable, Sendable {
    case testBuild
    case appStore

    /// The running binary's channel, read once.
    ///
    /// A Debug build is a test build by construction, and so is any simulator build: the
    /// App Store never installs on a simulator. That second rule is measured, not
    /// cosmetic: a Release build installed on an iOS 26.5 simulator reports a receipt named
    /// `receipt`, the App Store's name, and read `.appStore` before it (2026-11-24).
    ///
    /// Otherwise the App Store receipt's file name tells the two apart: StoreKit names it
    /// `sandboxReceipt` in a TestFlight (or development-signed) install and `receipt` in
    /// an App Store one. The URL is where the receipt *would* be, so the file need not
    /// exist yet.
    ///
    /// Limits: `appStoreReceiptURL` is deprecated since iOS 18 in favour of the async
    /// `AppTransaction`; if it ever returns nil, this answers `.appStore`. In an app
    /// extension `Bundle.main` is the extension's bundle, whose receipt URL Apple does
    /// not document, so an extension may read `.appStore` from a TestFlight install.
    /// Both failures land on the side that writes no text.
    public static let current: BuildChannel = {
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        return detect(isDebug: isDebug, isSimulator: isSimulator, receiptURL: Bundle.main.appStoreReceiptURL)
    }()

    /// The rule behind `current`, with its inputs passed in so tests can drive it.
    static func detect(isDebug: Bool, isSimulator: Bool = false, receiptURL: URL?) -> BuildChannel {
        if isDebug || isSimulator { return .testBuild }
        return receiptURL?.lastPathComponent == "sandboxReceipt" ? .testBuild : .appStore
    }
}
