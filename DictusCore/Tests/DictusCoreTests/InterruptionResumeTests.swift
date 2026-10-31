import XCTest
@testable import DictusCore

/// Behavior of an audio interruption on the warm engine (#353), run against a fake
/// engine and Live Activity: `UnifiedAudioEngine` owns a live `AVAudioEngine` in the
/// DictusApp target and cannot run here.
@MainActor
final class InterruptionResumeTests: XCTestCase {

    private let tenMinutes: TimeInterval = 10 * 60
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private var clock: Date!
    private var logged: [LogEvent]!
    private var engine: FakeEngine!
    private var recovery: AudioInterruptionRecovery!

    override func setUp() async throws {
        clock = start
        logged = []
        engine = FakeEngine()
        recovery = AudioInterruptionRecovery(
            now: { [unowned self] in self.clock },
            log: { [unowned self] in self.logged.append($0) }
        )
    }

    /// Standby armed at `start`; the call comes two minutes later and lasts `callSeconds`.
    private func standbyInterruptedByCall(lasting callSeconds: TimeInterval) {
        engine.enterStandby(idleSince: start, interval: tenMinutes)
        clock = start.addingTimeInterval(120)
        recovery.began(target: engine)
        clock = clock.addingTimeInterval(callSeconds)
    }

    private func lines(named name: String) -> [String] {
        logged.filter { $0.name == name }.map(\.message)
    }

    // MARK: 1. began while in standby

    func testBeganInStandbyStopsTheEngineAndEndsTheLiveActivity() {
        engine.enterStandby(idleSince: start, interval: tenMinutes)

        recovery.began(target: engine)

        XCTAssertFalse(engine.isEngineRunning)
        XCTAssertFalse(engine.idleReleaseArmed)
        XCTAssertFalse(engine.liveActivityShown)
        // Read before the teardown erased the anchor.
        XCTAssertEqual(recovery.interrupted, .standby(idleSince: start, interval: tenMinutes))
    }

    // MARK: 2. ended with shouldResume, standby was active

    func testEndedWithShouldResumeRestoresStandbyAtRest() {
        standbyInterruptedByCall(lasting: 10)

        let restored = recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        XCTAssertTrue(restored)
        XCTAssertEqual(engine.calls, ["tearDown", "reactivateSession", "startEngineAtRest",
                                      "armIdleRelease", "restartStandbyLiveActivity"])
        XCTAssertTrue(engine.isEngineRunning)
        XCTAssertTrue(engine.inputMuted)
        XCTAssertTrue(engine.liveActivityShown)
        XCTAssertEqual(lines(named: "audioInterruptionEnded"), ["shouldResume=true restored=true"])
        XCTAssertEqual(lines(named: "warmStateRestored"), [
            "context=interruptionResume engineRestarted=true inputMuted=true liveActivity=created "
                + "remainingSeconds=470 appState=2"
        ])
    }

    func testResumeKeepsTheDeadlineTheInterruptedWindowHad() {
        standbyInterruptedByCall(lasting: 10)

        recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        // Re-armed on the original window, not a fresh ten minutes from the resume.
        XCTAssertEqual(engine.armedIdleSince, start)
        XCTAssertEqual(engine.armedInterval, tenMinutes)
        XCTAssertEqual(IdleReleasePolicy.isIdleWindowElapsed(
            idleSince: engine.armedIdleSince, now: start.addingTimeInterval(tenMinutes), interval: tenMinutes
        ), true)
    }

    func testResumeInTheForegroundLeavesTheLiveActivityToTheBackgroundTransition() {
        standbyInterruptedByCall(lasting: 10)

        let restored = recovery.ended(shouldResume: true, appIsActive: true, appState: "0", target: engine)

        XCTAssertTrue(restored)
        XCTAssertTrue(engine.isEngineRunning)
        XCTAssertFalse(engine.calls.contains("restartStandbyLiveActivity"))
        XCTAssertTrue(lines(named: "warmStateRestored").first?.contains("liveActivity=skippedForeground") ?? false)
    }

    /// The device case of 2026-10-25: a dictation left the engine in #430 standby (running,
    /// input muted, release armed), and the call's I/O stop reached `isRunning` before
    /// `.began` reached the handler. The first version read that as cold.
    func testMutedStandbyWhoseIOTheCallStoppedFirstIsResumedMuted() {
        engine.enterStandby(idleSince: start, interval: tenMinutes)
        XCTAssertTrue(engine.inputMuted)
        clock = start.addingTimeInterval(60)
        engine.running = false

        recovery.began(target: engine)
        XCTAssertEqual(recovery.interrupted, .standby(idleSince: start, interval: tenMinutes))
        clock = clock.addingTimeInterval(15)
        let restored = recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        XCTAssertTrue(restored)
        XCTAssertTrue(engine.isEngineRunning)
        XCTAssertTrue(engine.inputMuted)
        XCTAssertTrue(engine.liveActivityShown)
        XCTAssertEqual(engine.armedIdleSince, start)
        XCTAssertEqual(engine.armedInterval, tenMinutes)
        XCTAssertEqual(lines(named: "engineWarmUpSkipped"), [])
        XCTAssertEqual(lines(named: "audioInterruptionEnded"), ["shouldResume=true restored=true"])
    }

    // MARK: 3. ended without shouldResume

    func testEndedWithoutShouldResumeRestartsNothing() {
        standbyInterruptedByCall(lasting: 10)

        let restored = recovery.ended(shouldResume: false, appIsActive: false, appState: "2", target: engine)

        XCTAssertFalse(restored)
        XCTAssertEqual(engine.calls, ["tearDown"])
        XCTAssertFalse(engine.isEngineRunning)
        XCTAssertFalse(engine.liveActivityShown)
        XCTAssertEqual(lines(named: "audioInterruptionEnded"), ["shouldResume=false restored=false"])
        XCTAssertEqual(lines(named: "engineWarmUpSkipped"), ["context=interruptionResume reason=noShouldResume"])
    }

    // MARK: 4. ended with shouldResume, restart throws

    func testRefusedEngineStartIsLoggedAndLeavesTheEngineCold() {
        standbyInterruptedByCall(lasting: 10)
        engine.startError = NSError(domain: "com.apple.coreaudio.avfaudio", code: 2_003_329_396)

        let restored = recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        XCTAssertFalse(restored)
        XCTAssertEqual(engine.calls, ["tearDown", "reactivateSession", "startEngineAtRest", "abandonResume"])
        XCTAssertFalse(engine.isEngineRunning)
        XCTAssertFalse(engine.idleReleaseArmed)
        XCTAssertFalse(engine.sessionActive)
        XCTAssertFalse(engine.liveActivityShown)
        let failure = lines(named: "engineWarmUpFailed")
        XCTAssertEqual(failure.count, 1)
        XCTAssertTrue(failure[0].hasPrefix("context=interruptionResume-startEngine"))
        XCTAssertTrue(failure[0].contains("2003329396"))
        XCTAssertTrue(failure[0].hasSuffix("appState=2"))
        XCTAssertEqual(lines(named: "audioInterruptionEnded"), ["shouldResume=true restored=false"])
    }

    func testRefusedActivationIsLoggedAndNeverStartsTheEngine() {
        standbyInterruptedByCall(lasting: 10)
        engine.activationError = NSError(domain: NSOSStatusErrorDomain, code: 560_557_684)

        let restored = recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        XCTAssertFalse(restored)
        XCTAssertEqual(engine.calls, ["tearDown", "reactivateSession", "abandonResume"])
        XCTAssertTrue(lines(named: "engineWarmUpFailed").first?.hasPrefix("context=interruptionResume-reactivateSession") ?? false)
    }

    func testAnInputThatWillNotMuteIsAFailedResume() {
        standbyInterruptedByCall(lasting: 10)
        engine.muteSucceeds = false

        let restored = recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        XCTAssertFalse(restored)
        XCTAssertFalse(engine.isEngineRunning)
        XCTAssertFalse(engine.liveActivityShown)
        XCTAssertTrue(lines(named: "engineWarmUpFailed").first?.hasPrefix("context=interruptionResume-muteInput") ?? false)
    }

    func testAFailedResumeIsNotRetriedByTheNextEnded() {
        standbyInterruptedByCall(lasting: 10)
        engine.startError = NSError(domain: "com.apple.coreaudio.avfaudio", code: 2_003_329_396)
        recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)
        engine.startError = nil

        let restored = recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        XCTAssertFalse(restored)
        XCTAssertEqual(engine.calls.filter { $0 == "startEngineAtRest" }.count, 1)
        XCTAssertEqual(lines(named: "engineWarmUpSkipped").last, "context=interruptionResume reason=wasCold")
    }

    // MARK: 5. standby expired or not active

    func testStandbyThatExpiredDuringTheCallIsNotRestored() {
        // Armed at `start`, interrupted at +2 min, the call lasts nine minutes: the
        // window closed at +10 min, during the call.
        standbyInterruptedByCall(lasting: 9 * 60)

        let restored = recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        XCTAssertFalse(restored)
        XCTAssertEqual(engine.calls, ["tearDown"])
        XCTAssertEqual(lines(named: "engineWarmUpSkipped"), ["context=interruptionResume reason=standbyExpired"])
    }

    func testColdEngineIsNotStartedByAnInterruption() {
        recovery.began(target: engine)

        let restored = recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        XCTAssertFalse(restored)
        XCTAssertFalse(engine.isEngineRunning)
        XCTAssertEqual(lines(named: "engineWarmUpSkipped"), ["context=interruptionResume reason=wasCold"])
    }

    func testRecordingInterruptedByACallIsNotResumed() {
        engine.enterStandby(idleSince: start, interval: tenMinutes)
        engine.recording = true
        recovery.began(target: engine)

        let restored = recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        XCTAssertFalse(restored)
        XCTAssertFalse(engine.isEngineRunning)
        XCTAssertEqual(lines(named: "engineWarmUpSkipped"), ["context=interruptionResume reason=wasRecording"])
    }

    func testEngineReleasedBeforeTheCallStaysCold() {
        engine.enterStandby(idleSince: start, interval: tenMinutes)
        engine.releaseWarmState()
        recovery.began(target: engine)

        let restored = recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        XCTAssertFalse(restored)
        XCTAssertFalse(engine.isEngineRunning)
        XCTAssertEqual(lines(named: "engineWarmUpSkipped"), ["context=interruptionResume reason=wasCold"])
    }

    func testEndedWithoutABeganIsTreatedAsCold() {
        let restored = recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        XCTAssertFalse(restored)
        XCTAssertEqual(engine.calls, [])
    }

    func testWarmStateReleasedDuringTheCallIsNotBroughtBack() {
        standbyInterruptedByCall(lasting: 10)
        recovery.forget()

        let restored = recovery.ended(shouldResume: true, appIsActive: false, appState: "2", target: engine)

        XCTAssertFalse(restored)
        XCTAssertEqual(engine.calls, ["tearDown"])
    }

    func testEngineWarmedByTheAppDuringTheCallIsLeftAlone() {
        standbyInterruptedByCall(lasting: 10)
        engine.running = true

        let restored = recovery.ended(shouldResume: true, appIsActive: true, appState: "0", target: engine)

        XCTAssertFalse(restored)
        XCTAssertEqual(engine.calls, ["tearDown"])
        XCTAssertEqual(lines(named: "engineWarmUpSkipped"), ["context=interruptionResume reason=alreadyRunning"])
    }
}

/// An engine, session and Live Activity reduced to the state a resume reads and writes.
@MainActor
private final class FakeEngine: InterruptionResumeTarget {
    var running = false
    var recording = false
    var inputMuted = false
    var sessionActive = false
    var liveActivityShown = false
    var armedIdleSince: Date?
    var armedInterval: TimeInterval?
    var idleReleaseArmed: Bool { armedIdleSince != nil }

    var activationError: Error?
    var startError: Error?
    var muteSucceeds = true
    private(set) var calls: [String] = []

    /// The idle release ran: engine stopped by us, nothing armed.
    func releaseWarmState() {
        running = false
        inputMuted = false
        sessionActive = false
        liveActivityShown = false
        armedIdleSince = nil
        armedInterval = nil
    }

    func enterStandby(idleSince: Date, interval: TimeInterval) {
        running = true
        inputMuted = true
        sessionActive = true
        liveActivityShown = true
        armedIdleSince = idleSince
        armedInterval = interval
    }

    /// Same rule as `UnifiedAudioEngine`: our flags, not `running`, which iOS may have
    /// cleared before `.began` arrives.
    var engineStateForInterruption: InterruptedEngineState {
        if recording { return .recording }
        guard let armedIdleSince, let armedInterval else { return .cold }
        return .standby(idleSince: armedIdleSince, interval: armedInterval)
    }

    var isEngineRunning: Bool { running }

    func tearDownForInterruption() {
        calls.append("tearDown")
        running = false
        recording = false
        armedIdleSince = nil
        armedInterval = nil
        // iOS takes the session; the Live Activity observer ends the pill.
        sessionActive = false
        liveActivityShown = false
    }

    func reactivateSession() throws {
        calls.append("reactivateSession")
        if let activationError { throw activationError }
        sessionActive = true
    }

    func startEngineAtRest() throws -> Bool {
        calls.append("startEngineAtRest")
        if let startError { throw startError }
        running = true
        inputMuted = muteSucceeds
        return inputMuted
    }

    func abandonResume() {
        calls.append("abandonResume")
        running = false
        inputMuted = false
        sessionActive = false
    }

    func armIdleRelease(idleSince: Date, interval: TimeInterval) {
        calls.append("armIdleRelease")
        armedIdleSince = idleSince
        armedInterval = interval
    }

    func restartStandbyLiveActivity() -> String {
        calls.append("restartStandbyLiveActivity")
        liveActivityShown = true
        return "created"
    }
}
