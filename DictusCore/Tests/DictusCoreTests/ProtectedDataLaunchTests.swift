// DictusCore/Tests/DictusCoreTests/ProtectedDataLaunchTests.swift
// The decisions #868 changed around a launch before first unlock, one by one. The
// end-to-end reproduction is `ProtectedDataLaunchReproTests`.
import XCTest
@testable import DictusCore

final class ProtectedDataLaunchTests: XCTestCase {

    // MARK: - KeyboardSignalPolicy

    func testAFlagSetIsHonoredInEveryStatus() {
        for status in DictationStatus.allCases {
            XCTAssertEqual(KeyboardSignalPolicy.decide(.stop, flagRequested: true, status: status), .honor)
            XCTAssertEqual(KeyboardSignalPolicy.decide(.cancel, flagRequested: true, status: status), .honor)
        }
    }

    func testAStopWithoutTheFlagIsHonoredOnlyWhileRecording() {
        for status in DictationStatus.allCases {
            let decision = KeyboardSignalPolicy.decide(.stop, flagRequested: false, status: status)
            if status == .recording {
                XCTAssertEqual(decision, .honor)
            } else {
                XCTAssertEqual(decision, .ignore(reason: "flagFalse status=\(status.rawValue)"), "\(status)")
            }
        }
    }

    func testACancelWithoutTheFlagIsHonoredOnlyWhileAudioIsCaptured() {
        for status in DictationStatus.allCases {
            let decision = KeyboardSignalPolicy.decide(.cancel, flagRequested: false, status: status)
            if status == .requested || status == .recording {
                XCTAssertEqual(decision, .honor, "\(status)")
            } else {
                XCTAssertEqual(decision, .ignore(reason: "flagFalse status=\(status.rawValue)"), "\(status)")
            }
        }
    }

    // MARK: - dictate URL routing

    func testPrepareIsRoutedBeforeTheOnboardingRule() {
        for completed in [true, false] {
            for host in [nil, "com.apple.mobilenotes", KeyboardOnboardingGate.dictusHostId] {
                XCTAssertEqual(
                    KeyboardOnboardingGate.dictateURLRoute(intent: .prepare, hostId: host, onboardingCompleted: completed),
                    .prepare
                )
            }
        }
    }

    func testRecordBeforeOnboardingStaysOnOnboardingUnlessTheHostIsDictus() {
        XCTAssertEqual(
            KeyboardOnboardingGate.dictateURLRoute(intent: .record, hostId: "com.apple.mobilenotes", onboardingCompleted: false),
            .stayOnOnboarding
        )
        XCTAssertEqual(
            KeyboardOnboardingGate.dictateURLRoute(intent: .record, hostId: nil, onboardingCompleted: false),
            .stayOnOnboarding
        )
        XCTAssertEqual(
            KeyboardOnboardingGate.dictateURLRoute(
                intent: .record, hostId: KeyboardOnboardingGate.dictusHostId, onboardingCompleted: false
            ),
            .dictate,
            "the onboarding test dictation"
        )
    }

    func testEveryDictateRecordsOnceOnboardingIsDone() {
        XCTAssertEqual(KeyboardOnboardingGate.dictateURLRoute(intent: .record, hostId: nil, onboardingCompleted: true), .dictate)
        XCTAssertEqual(KeyboardOnboardingGate.dictateURLRoute(intent: nil, hostId: nil, onboardingCompleted: true), .dictate)
        XCTAssertEqual(KeyboardOnboardingGate.dictateURLRoute(intent: nil, hostId: nil, onboardingCompleted: false), .stayOnOnboarding)
    }

    // MARK: - ProtectedDataLaunchWork

    func testLaunchWorkWaitsForTrustedReadsAndRunsOnce() {
        var ready = false
        var runs = 0
        let work = ProtectedDataLaunchWork(isReady: { ready }) { runs += 1 }

        XCTAssertFalse(work.runIfAvailable())
        XCTAssertEqual(runs, 0)

        ready = true
        XCTAssertTrue(work.runIfAvailable())
        XCTAssertFalse(work.runIfAvailable(), "an activation after the first must not run it again")
        XCTAssertEqual(runs, 1)
        XCTAssertTrue(work.hasRun)
    }

    // MARK: - AppGroupReadCheck

    private let unlocked = FixedProtectedData(isProtectedDataAvailable: true)

    func testReadStateFromTheFile() {
        let file: [String: Any] = [SharedKeys.hasCompletedOnboarding: true, SharedKeys.language: "en"]

        let locked = LockableAppGroupStore(values: file, isLocked: true)
        XCTAssertEqual(
            AppGroupReadCheck.state(of: locked, protectedData: FixedProtectedData(isProtectedDataAvailable: false), fileValues: file),
            .protected
        )
        XCTAssertEqual(
            AppGroupReadCheck.state(of: locked, protectedData: unlocked, fileValues: file),
            .stale(missingKeys: [SharedKeys.hasCompletedOnboarding, SharedKeys.language])
        )

        let fresh = LockableAppGroupStore(values: file, isLocked: false)
        XCTAssertEqual(AppGroupReadCheck.state(of: fresh, protectedData: unlocked, fileValues: file), .trusted)
        XCTAssertEqual(AppGroupReadCheck.state(of: locked, protectedData: unlocked, fileValues: nil), .trusted, "no file: a new install")
        XCTAssertEqual(
            AppGroupReadCheck.state(of: locked, protectedData: unlocked, fileValues: ["dictus.dictationStatus": "idle"]),
            .trusted,
            "only witness keys decide: runtime keys come and go"
        )
    }

    func testFileValuesReadsAPlistWithoutUserDefaults() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictus_file_values_\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try PropertyListSerialization.data(
            fromPropertyList: [SharedKeys.language: "en", SharedKeys.hasCompletedOnboarding: true],
            format: .binary,
            options: 0
        )
        try data.write(to: url)

        let values = try XCTUnwrap(AppGroupReadCheck.fileValues(at: url))
        XCTAssertEqual(values[SharedKeys.language] as? String, "en")
        XCTAssertEqual(values[SharedKeys.hasCompletedOnboarding] as? Bool, true)
        XCTAssertNil(AppGroupReadCheck.fileValues(at: nil))
    }

    func testSettingsFallbackKeepsSettingsAndLeavesRuntimeState() {
        let fallback = AppGroupReadCheck.settingsFallback(from: [
            SharedKeys.language: "en",
            SharedKeys.liveActivityEnabled: false,
            SharedKeys.stopRequested: true,
            SharedKeys.dictationStatus: "recording"
        ])
        XCTAssertEqual(Set(fallback.keys), [SharedKeys.language, SharedKeys.liveActivityEnabled])
    }

    /// The stale process's fix relies on this: a fallback registered on one instance is
    /// read by another instance of the suite, the way `AppGroup.defaults` builds a new one
    /// per access, and a value written later still wins.
    func testARegisteredFallbackReachesEveryInstanceAndYieldsToAWrite() throws {
        let suiteName = "dictus.tests.protectedDataLaunch.fallback"
        let first = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        first.removePersistentDomain(forName: suiteName)
        defer { first.removePersistentDomain(forName: suiteName) }

        first.register(defaults: ["dictus.tests.fallbackLanguage": "en"])
        let second = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        XCTAssertEqual(second.string(forKey: "dictus.tests.fallbackLanguage"), "en")

        second.set("de", forKey: "dictus.tests.fallbackLanguage")
        XCTAssertEqual(first.string(forKey: "dictus.tests.fallbackLanguage"), "de")
    }

    // MARK: - ProtectedDataProbe

    func testTheProbeTellsAnUnreadableFileFromAReadableOrMissingOne() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictus_probe_\(UUID().uuidString).plist")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: url)
        }
        XCTAssertTrue(ProtectedDataProbe.canOpen(url), "no file yet: a new install")
        XCTAssertTrue(ProtectedDataProbe.canOpen(nil), "no container")

        try Data("x".utf8).write(to: url)
        XCTAssertTrue(ProtectedDataProbe.canOpen(url))

        // Unreadable, the way a protected file is before first unlock.
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        XCTAssertFalse(ProtectedDataProbe.canOpen(url))
    }

    // MARK: - Warmth marker

    func testWarmthSurvivesADownloadThatFindsEveryFileOnDisk() throws {
        let suiteName = "dictus.tests.protectedDataLaunch.warmth"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = "parakeet-tdt-0.6b-v3"
        ModelWarmth.markWarm(model, identity: "install-1", defaults: defaults)

        XCTAssertFalse(ModelWarmth.clearBeforeDownload(model, filesCompleteOnDisk: true, defaults: defaults))
        XCTAssertTrue(ModelWarmth.isWarm(model, identity: "install-1", defaults: defaults))

        XCTAssertTrue(ModelWarmth.clearBeforeDownload(model, filesCompleteOnDisk: false, defaults: defaults))
        XCTAssertFalse(ModelWarmth.isWarm(model, identity: "install-1", defaults: defaults))
    }

    // MARK: - Launch line and export header

    func testAppLaunchedCarriesTheLaunchFacts() {
        XCTAssertEqual(LogEvent.appLaunched(version: "2.0.0").payload().hasSuffix("appLaunched version=2.0.0"), true)
        let payload = LogEvent.appLaunched(
            version: "2.0.0", protectedData: false, activePrewarm: true, appGroup: "deferred"
        ).payload()
        XCTAssertTrue(
            payload.hasSuffix("appLaunched version=2.0.0 protectedData=false activePrewarm=true appGroup=deferred"),
            payload
        )
    }

    func testExportHeaderCarriesTheLaunchLineWhenKnown() {
        let base = PersistentLog.buildExportHeader(
            iosVersion: "27.0.1", appVersion: "2.0.0", buildNumber: "37", deviceModel: "iPhone", activeModel: "parakeet"
        )
        XCTAssertFalse(base.contains("Launch:"))
        let header = PersistentLog.buildExportHeader(
            iosVersion: "27.0.1", appVersion: "2.0.0", buildNumber: "37", deviceModel: "iPhone", activeModel: "parakeet",
            launch: "protectedData=false activePrewarm=true appGroup=deferred"
        )
        XCTAssertTrue(header.contains("Launch: protectedData=false activePrewarm=true appGroup=deferred\n---\n"))
    }
}

/// The lines a refused append used to drop (#868).
final class PendingLogLinesTests: XCTestCase {

    private var directory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictus_unwritable_\(UUID().uuidString)")
        // Both URLs before anything can throw: `tearDown` runs after a failed setUp and
        // unwraps them.
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictus_pending_\(UUID().uuidString).log")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        PersistentLog.resetCollapseStateForTesting()
    }

    override func tearDown() {
        PersistentLog.resetCollapseStateForTesting()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    /// A directory cannot be opened for writing: it stands for the App Group file before
    /// first unlock. The held line reaches the file with the next append that succeeds.
    func testALineTheFileRefusedIsWrittenWithTheNextSuccessfulAppend() {
        PersistentLog.appendCollapsingForTesting(payload: "appLaunched version=2.0.0", timestamp: "t1", to: directory)
        XCTAssertEqual(PersistentLog.pendingLinesForTesting.held, 1)

        PersistentLog.appendCollapsingForTesting(payload: "appDidBecomeActive", timestamp: "t2", to: fileURL)

        XCTAssertEqual(
            PersistentLog.readForTesting(from: fileURL),
            "[t1] appLaunched version=2.0.0\n[t2] appDidBecomeActive\n"
        )
        XCTAssertEqual(PersistentLog.pendingLinesForTesting.held, 0)
    }

    func testOverflowIsCountedAndReported() {
        var pending = PendingLogLines()
        for index in 0..<(PendingLogLines.capacity + 3) {
            pending.hold("[t] line \(index)\n")
        }
        XCTAssertEqual(pending.chunks.count, PendingLogLines.capacity)
        XCTAssertEqual(pending.droppedCount, 3)

        let text = pending.text(timestamp: "t-unlock")
        XCTAssertTrue(text.hasPrefix("[t] line 0\n"))
        XCTAssertTrue(
            text.hasSuffix(
                "action=linesDropped details=count=3 kept=\(PendingLogLines.capacity) reason=fileUnwritable\n"
            ),
            String(text.suffix(200))
        )
        XCTAssertTrue(text.contains("[t-unlock] "), "the counting line carries the time the file came back")

        pending.removeAll()
        XCTAssertTrue(pending.isEmpty)
    }
}
