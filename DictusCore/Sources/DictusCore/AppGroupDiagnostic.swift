// DictusCore/Sources/DictusCore/AppGroupDiagnostic.swift
import Foundation
import os.log

public struct DiagnosticResult {
    public let canWrite: Bool
    public let canRead: Bool
    public let appGroupID: String
    public let containerExists: Bool
    public let timestamp: Date

    public var isHealthy: Bool {
        canWrite && canRead && containerExists
    }
}

public enum AppGroupDiagnostic {
    /// Run a full diagnostic check on the App Group shared container.
    /// Call from both DictusApp.init() and KeyboardViewController.viewDidLoad().
    public static func run() -> DiagnosticResult {
        let defaults = AppGroup.defaults
        let testKey = "diagnostic.test"
        let testValue = "ok-\(Date().timeIntervalSince1970)"

        // Write test
        defaults.set(testValue, forKey: testKey)
        defaults.synchronize()

        // Read test
        let readBack = defaults.string(forKey: testKey)
        let canWrite = readBack == testValue
        let canRead = readBack != nil

        // Container test
        let containerExists = AppGroup.containerURL != nil

        let result = DiagnosticResult(
            canWrite: canWrite,
            canRead: canRead,
            appGroupID: AppGroup.identifier,
            containerExists: containerExists,
            timestamp: Date()
        )

        // Log using os_log for broad platform compatibility (iOS 10+, macOS 10.12+)
        os_log(
            "AppGroup diagnostic: canWrite=%{public}@ canRead=%{public}@ container=%{public}@",
            log: OSLog(subsystem: "com.pivi.dictus", category: "diagnostic"),
            type: .info,
            canWrite ? "true" : "false",
            canRead ? "true" : "false",
            containerExists ? "true" : "false"
        )

        // Clean up test key
        defaults.removeObject(forKey: testKey)

        return result
    }
}
