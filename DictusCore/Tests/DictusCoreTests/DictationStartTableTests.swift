// DictusCore/Tests/DictusCoreTests/DictationStartTableTests.swift
// One test per start case of a keyboard mic tap (#992, device round 2, 2026-11-23),
// the two device failures of log 200 replayed, and the safety net's deadline.
import XCTest
@testable import DictusCore

final class DictationStartTableTests: XCTestCase {

    // MARK: - Fixtures

    /// A tap the keyboard could take: setting on, iOS 27, French installed, Full Access,
    /// microphone granted, Dictus model warm. Each test changes what its row is about.
    private func inputs(appAnswer: DictationStartTable.AppAnswer = .silent,
                        owner: DictationSessionClaim.Owner? = nil,
                        appMovedPastRequested: Bool = false,
                        settingEnabled: Bool = true,
                        languageCode: String? = "fr",
                        localeInstalled: Bool? = true,
                        hasFullAccess: Bool = true,
                        microphone: InKeyboardDictationRoute.MicrophonePermission = .granted,
                        needsPreparation: Bool = false) -> DictationStartTable.Inputs {
        DictationStartTable.Inputs(settingEnabled: settingEnabled, systemMajorVersion: 27, languageCode: languageCode,
                                   localeInstalled: localeInstalled, hasFullAccess: hasFullAccess, microphone: microphone,
                                   appAnswer: appAnswer, sessionOwner: owner, appMovedPastRequested: appMovedPastRequested,
                                   dictusModelNeedsPreparation: needsPreparation)
    }

    private func appAnswer(active: Bool = false, engineRunning: Bool = true, status: DictationStatus = .idle,
                           modelDownloaded: Bool = true, loadState: ModelLoadState = .ready,
                           warm: Bool = true) -> AppKeyboardStartAnswer {
        AppKeyboardStartAnswer.decide(.init(appIsActive: active, engineRunning: engineRunning, dictationStatus: status,
                                            onboardingCompleted: true, isModelDownloaded: modelDownloaded,
                                            loadState: loadState, isModelWarm: warm))
    }

    private func claimsDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("start-table-\(UUID().uuidString)")
    }

    // MARK: - The table, one row per case

    /// Row 1. App not running: no pong, no claim. The keyboard records.
    func testRow01AppNotRunningKeyboardRecords() {
        let decision = DictationStartTable.decide(inputs(appAnswer: .silent))
        XCTAssertEqual(decision.outcome, .keyboardRecords)
        XCTAssertEqual(decision.why, "app-silent")
        XCTAssertTrue(InKeyboardEarlyCapture.shouldStartCapture(mayTakeColdTap: true, appAnsweredTapPing: false, sessionOwner: nil))
    }

    /// Row 2. App running, engine warm, model ready: it answers "record", claims, records.
    /// The keyboard keeps its microphone closed and does nothing else.
    func testRow02WarmAppRecords() throws {
        let answer = appAnswer()
        XCTAssertEqual(answer, .record)
        let directory = claimsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "start-table-\(UUID().uuidString)"))
        defaults.set("S2", forKey: SharedKeys.dictationSessionRequest)
        XCTAssertTrue(DictationSessionClaim.appMayStart(defaults: defaults, directory: directory, answer: answer))
        XCTAssertFalse(InKeyboardEarlyCapture.shouldStartCapture(mayTakeColdTap: true, appAnsweredTapPing: answer.willRecord,
                                                                 sessionOwner: .app))
        let decision = DictationStartTable.decide(inputs(appAnswer: .willRecord, owner: DictationSessionClaim.current("S2", in: directory)))
        XCTAssertEqual(decision.outcome, .appRecords)
    }

    /// Row 3. App running in the background, engine stopped: it declines without
    /// claiming, and the keyboard records — or, when it cannot, opens the app to record.
    func testRow03EngineStoppedAppDeclinesKeyboardRecords() {
        XCTAssertEqual(appAnswer(engineRunning: false), .decline(.engineNotRunning))
        XCTAssertEqual(DictationStartTable.decide(inputs(appAnswer: .declined)).outcome, .keyboardRecords)
        XCTAssertEqual(DictationStartTable.decide(inputs(appAnswer: .declined, settingEnabled: false)).outcome, .openAppToRecord)
        // In front, the app can start its engine: it records.
        XCTAssertEqual(appAnswer(active: true, engineRunning: false), .record)
    }

    /// Row 4. App running, model loading or its Core ML cache cold: it declines, the
    /// keyboard records with Apple's model and no word waits on a compile. When the
    /// keyboard cannot, the app opens on its preparation screen, as before #992.
    func testRow04ModelNotReadyAppDeclinesKeyboardRecordsElsePreparation() {
        XCTAssertEqual(appAnswer(loadState: .loading), .decline(.modelNotReady))
        XCTAssertEqual(appAnswer(loadState: .ready, warm: false), .decline(.modelNotReady))
        XCTAssertEqual(DictationStartTable.decide(inputs(appAnswer: .declined, needsPreparation: true)).outcome, .keyboardRecords)
        let cannot = DictationStartTable.decide(inputs(appAnswer: .declined, languageCode: nil, needsPreparation: true))
        XCTAssertEqual(cannot.outcome, .openAppToPrepare)
        XCTAssertEqual(cannot.why, "auto-detect")
    }

    /// Row 5. App suspended in the background: the Darwin post reaches it late, if at
    /// all. Silent at the tap, so the keyboard records; when the app wakes it finds the
    /// session taken and does not record a second time (device, 13:38:45).
    func testRow05SuspendedAppKeyboardRecordsAndTheLateAppDoesNotRecordTwice() throws {
        let directory = claimsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertEqual(DictationStartTable.decide(inputs(appAnswer: .silent)).outcome, .keyboardRecords)
        XCTAssertEqual(DictationSessionClaim.claim("S5", as: .keyboard, in: directory), .keyboard)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "start-table-\(UUID().uuidString)"))
        defaults.set("S5", forKey: SharedKeys.dictationSessionRequest)
        XCTAssertFalse(DictationSessionClaim.appMayStart(defaults: defaults, directory: directory, answer: .record))
    }

    /// Row 6. App killed after the keyboard appeared: the pong from the appearance is
    /// older than the tap and does not count. The keyboard records; if its capture dies
    /// before a single sample, the safety net opens the app (`testDeviceB…`).
    func testRow06AppKilledAfterTheKeyboardAppearedKeyboardRecords() {
        let tap = Date(timeIntervalSince1970: 1_000_000)
        let answered = InKeyboardEarlyCapture.appAnsweredTapPing(pingSentAt: tap, lastPong: tap.addingTimeInterval(-9))
        XCTAssertFalse(answered)
        XCTAssertEqual(DictationStartTable.decide(inputs(appAnswer: .silent)).outcome, .keyboardRecords)
    }

    /// Row 7. Setting off: today's path. A warm app records; a cold one opens by URL,
    /// or on its preparation screen when the Dictus model is cold.
    func testRow07SettingOffKeepsTodaysPath() {
        XCTAssertEqual(DictationStartTable.decide(inputs(owner: .app, settingEnabled: false)).outcome, .appRecords)
        XCTAssertEqual(DictationStartTable.decide(inputs(settingEnabled: false)).outcome, .openAppToRecord)
        XCTAssertEqual(DictationStartTable.decide(inputs(settingEnabled: false, needsPreparation: true)).outcome, .openAppToPrepare)
        XCTAssertEqual(DictationStartTable.decide(inputs(settingEnabled: false)).why, "setting-off")
    }

    /// Row 8. Language not covered: automatic detection, or Apple's model for the
    /// chosen language not installed. Same as "setting off".
    func testRow08LanguageNotCoveredKeepsTodaysPath() {
        let auto = DictationStartTable.decide(inputs(languageCode: nil))
        XCTAssertEqual(auto.outcome, .openAppToRecord)
        XCTAssertEqual(auto.why, "auto-detect")
        let missing = DictationStartTable.decide(inputs(localeInstalled: false))
        XCTAssertEqual(missing.outcome, .openAppToRecord)
        XCTAssertEqual(missing.why, "locale-not-installed")
        XCTAssertEqual(DictationStartTable.decide(inputs(localeInstalled: nil)).why, "locale-not-installed")
    }

    /// Row 9. Microphone refused for Dictus: neither side can record. One line says so;
    /// nothing opens. Never asked: the app is the only one that can ask.
    func testRow09MicrophoneRefusedSaysSo() {
        XCTAssertEqual(DictationStartTable.decide(inputs(microphone: .denied)).outcome, .microphoneRefused)
        let undetermined = DictationStartTable.decide(inputs(microphone: .undetermined))
        XCTAssertEqual(undetermined.outcome, .openAppToRecord)
        XCTAssertEqual(undetermined.why, "microphone-undetermined")
    }

    /// Row 10. Full Access off: today's path (the toolbar shows the Full Access bar
    /// rather than the mic, so this is defensive).
    func testRow10FullAccessOffKeepsTodaysPath() {
        let decision = DictationStartTable.decide(inputs(hasFullAccess: false))
        XCTAssertEqual(decision.outcome, .openAppToRecord)
        XCTAssertEqual(decision.why, "full-access-off")
    }

    /// A pong delivered after the tap but answered before it (a keyboard iOS had
    /// suspended, simulator 14:08:11) is not this tap's answer: only the app's stamp counts.
    func testPingAnswerCountsOnlyWhenTheAppAnsweredAtOrAfterTheTap() {
        let tap = Date(timeIntervalSince1970: 2_000_000)
        let before = DictationStartTable.PingAnswerStamp(answer: .declined, answeredAt: tap.addingTimeInterval(-2)).storedValue
        let after = DictationStartTable.PingAnswerStamp(answer: .willRecord, answeredAt: tap.addingTimeInterval(0.007)).storedValue
        XCTAssertEqual(DictationStartTable.PingAnswerStamp.answer(to: tap, stored: before), .silent)
        XCTAssertEqual(DictationStartTable.PingAnswerStamp.answer(to: tap, stored: after), .willRecord)
        XCTAssertEqual(DictationStartTable.PingAnswerStamp.answer(to: tap, stored: nil), .silent)
        XCTAssertEqual(DictationStartTable.PingAnswerStamp.answer(to: tap, stored: "garbage"), .silent)
        XCTAssertEqual(DictationStartTable.PingAnswerStamp.answer(to: nil, stored: after), .silent)
    }

    // MARK: - The two device failures of log 200

    /// Device A, 2026-11-23 13:38:56. App alive in the background, model compiling
    /// (313 s), engine stopped; it claimed the session, then `dictationDeferred reason=no
    /// engine running`; the keyboard routed `appIsRecording` and skipped its URL. Nobody
    /// recorded. Now the app declines without claiming, its ping answer is "declined",
    /// the keyboard opens its microphone at 120 ms and records the tap.
    func testDeviceAAppAliveNotReadyNoLongerOwnsTheTap() throws {
        let answer = appAnswer(engineRunning: false, loadState: .loading, warm: false)
        XCTAssertEqual(answer, .decline(.engineNotRunning))
        let directory = claimsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "start-table-\(UUID().uuidString)"))
        defaults.set("D11D0E95", forKey: SharedKeys.dictationSessionRequest)
        XCTAssertFalse(DictationSessionClaim.appMayStart(defaults: defaults, directory: directory, answer: answer))
        let owner = DictationSessionClaim.current("D11D0E95", in: directory)
        XCTAssertNil(owner, "a declining app must leave the session free")
        XCTAssertTrue(InKeyboardEarlyCapture.shouldStartCapture(mayTakeColdTap: true, appAnsweredTapPing: answer.willRecord,
                                                                sessionOwner: owner))
        let decision = DictationStartTable.decide(inputs(appAnswer: .declined, owner: owner, needsPreparation: true))
        XCTAssertEqual(decision.outcome, .keyboardRecords)
        XCTAssertEqual(decision.why, "app-declined")
    }

    /// Device A, the keyboard unable to take it (say, automatic detection): the app
    /// opens on its preparation screen, as it did before #992.
    func testDeviceAWhenTheKeyboardCannotTheAppOpensOnPreparation() {
        let decision = DictationStartTable.decide(inputs(appAnswer: .declined, languageCode: nil, needsPreparation: true))
        XCTAssertEqual(decision.outcome, .openAppToPrepare)
    }

    /// Device B, 2026-11-23 13:39:21 (and 13:39:24, 13:39:26). Dictus was not running
    /// (no line from it until a fresh `appLaunched` at 13:39:39, no claim at 524 ms); the
    /// keyboard routed `inKeyboard`, its capture started at 660 ms and was interrupted
    /// at once (`context-interrupted`, `seconds=0.0 action=discard`): back to idle,
    /// nothing recorded, nothing opened. Now a capture that ends before half a second of
    /// audio hands the tap to the safety net, which opens the app by URL at once.
    func testDeviceBCaptureEndedWithoutAudioOpensTheApp() {
        XCTAssertEqual(DictationStartTable.decide(inputs(appAnswer: .silent)).outcome, .keyboardRecords)
        XCTAssertEqual(InKeyboardInterruptionPolicy.action(for: .captureEnded, recordedSeconds: 0), .openApp)
        let verdict = DictationStartSafetyNet.evaluate(.init(elapsed: 0.66, keyboardHasAudio: false, appIsRecording: false,
                                                             tapEnded: false, captureEndedWithoutAudio: true))
        XCTAssertEqual(verdict, .fire("capture-ended-without-audio"))
    }

    /// A capture cut after a few samples (0.3 s) ended before the dictation began: the
    /// net fires even though the keyboard "has audio", or the overlay stays on nothing.
    func testSafetyNetFiresForACaptureCutBeforeTheDictationBegan() {
        XCTAssertEqual(InKeyboardInterruptionPolicy.action(for: .captureEnded, recordedSeconds: 0.3), .openApp)
        XCTAssertEqual(DictationStartSafetyNet.evaluate(.init(elapsed: 0.9, keyboardHasAudio: true, appIsRecording: false,
                                                              tapEnded: false, captureEndedWithoutAudio: true)),
                       .fire("capture-ended-without-audio"))
    }

    // MARK: - The safety net

    func testSafetyNetFiresAtTheDeadlineWhenNothingWasCaptured() {
        XCTAssertEqual(DictationStartSafetyNet.deadline, 1.5)
        func reading(_ elapsed: TimeInterval) -> DictationStartSafetyNet.Reading {
            .init(elapsed: elapsed, keyboardHasAudio: false, appIsRecording: false, tapEnded: false, captureEndedWithoutAudio: false)
        }
        XCTAssertEqual(DictationStartSafetyNet.evaluate(reading(1.49)), .keepWaiting)
        XCTAssertEqual(DictationStartSafetyNet.evaluate(reading(1.5)), .fire("no-audio-by-deadline"))
    }

    /// The deadline sits above every start measured on the device (tap to first sample
    /// 374–1240 ms over 30 starts, logs 190–200), so a working start is never cut.
    func testSafetyNetDeadlineClearsTheSlowestMeasuredStart() {
        let slowestMeasuredFirstSample: TimeInterval = 1.240
        XCTAssertGreaterThan(DictationStartSafetyNet.deadline, slowestMeasuredFirstSample)
    }

    func testSafetyNetStandsDownOnceAudioIsCapturedOrTheTapLeftTheKeyboard() {
        XCTAssertEqual(DictationStartSafetyNet.evaluate(.init(elapsed: 3, keyboardHasAudio: true, appIsRecording: false,
                                                              tapEnded: false, captureEndedWithoutAudio: false)),
                       .standDown("keyboard-audio"))
        XCTAssertEqual(DictationStartSafetyNet.evaluate(.init(elapsed: 3, keyboardHasAudio: false, appIsRecording: true,
                                                              tapEnded: false, captureEndedWithoutAudio: false)),
                       .standDown("app-recording"))
        XCTAssertEqual(DictationStartSafetyNet.evaluate(.init(elapsed: 3, keyboardHasAudio: false, appIsRecording: false,
                                                              tapEnded: true, captureEndedWithoutAudio: false)),
                       .standDown("tap-ended"))
    }

    /// Device, 2026-11-24 17:47 (iOS 27.0.1, build 39f6bdbc), 4 taps out of 4: the
    /// keyboard's capture was still starting (no `captureStarted`, no failure) when the
    /// net fired at 1579 ms, abandoned it and opened the app. Reproduced on the simulator
    /// with the web content process slowed during `getUserMedia`: `stoppedBeforeStart
    /// lastStep=requested`, then `gum-resolved` after the net. A capture still starting
    /// gets until `startingDeadline`; its own 3 s start timeout fails it before that if it
    /// hangs, and the net then fires at once.
    func testSafetyNetWaitsForAKeyboardCaptureStillStarting() {
        func reading(_ elapsed: TimeInterval, starting: Bool) -> DictationStartSafetyNet.Reading {
            .init(elapsed: elapsed, keyboardHasAudio: false, appIsRecording: false, tapEnded: false,
                  captureEndedWithoutAudio: false, keyboardCaptureStarting: starting)
        }
        XCTAssertEqual(DictationStartSafetyNet.evaluate(reading(1.579, starting: true)), .keepWaiting)
        XCTAssertEqual(DictationStartSafetyNet.evaluate(reading(3.5, starting: true)), .fire("capture-start-too-slow"))
        XCTAssertEqual(DictationStartSafetyNet.evaluate(reading(1.579, starting: false)), .fire("no-audio-by-deadline"))
        XCTAssertGreaterThan(DictationStartSafetyNet.startingDeadline, 3.0, "after the capture's own 3 s start timeout")
    }

    /// Device A as it was (the app claims, then never records): the net fires at 1.5 s
    /// and opens the app, instead of the 5 s watchdog and nothing.
    func testSafetyNetCatchesAnAppThatClaimedAndNeverRecorded() {
        let decision = DictationStartTable.decide(inputs(appAnswer: .willRecord, owner: .app))
        XCTAssertEqual(decision.outcome, .appRecords)
        XCTAssertEqual(DictationStartSafetyNet.evaluate(.init(elapsed: 1.5, keyboardHasAudio: false, appIsRecording: false,
                                                              tapEnded: false, captureEndedWithoutAudio: false)),
                       .fire("no-audio-by-deadline"))
    }
}
