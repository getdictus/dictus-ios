// DictusCore/Tests/DictusCoreTests/DictationSessionClaimTests.swift
// Tests for DictationSessionClaim — one owner per keyboard dictation session, even when
// DictusApp answers just after the keyboard's 500 ms window (spike).
import XCTest
@testable import DictusCore

final class DictationSessionClaimTests: XCTestCase {

    private var directory = URL(fileURLWithPath: "/nonexistent")
    private let suiteName = "dictus.tests.dictationSessionClaim"
    private var defaults = UserDefaults.standard

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictus-claims-\(UUID().uuidString)")
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// The measured race: the keyboard's window ends at 500 ms with the app silent, the
    /// keyboard takes the session and records; the app's answer lands at 525 ms. The app
    /// must not record.
    func testLateAppAnswerDoesNotRecordASessionTheKeyboardTook() {
        defaults.set("A1B2C3D4", forKey: SharedKeys.dictationSessionRequest)
        var recorders: [DictationSessionClaim.Owner] = []

        // t = 500 ms: the keyboard decides to dictate itself.
        if DictationSessionClaim.claim("A1B2C3D4", as: .keyboard, in: directory) == .keyboard {
            recorders.append(.keyboard)
        }
        // t = 525 ms: the app's Darwin handler runs.
        if DictationSessionClaim.appMayStart(defaults: defaults, directory: directory) {
            recorders.append(.app)
        }

        XCTAssertEqual(recorders, [.keyboard])
        XCTAssertEqual(DictationSessionClaim.current("A1B2C3D4", in: directory), .keyboard)
    }

    /// The warm path: the app answers inside the window and records; when the window
    /// ends, the keyboard reads the app's claim and stays out.
    func testAppThatAnswersFirstKeepsTheSession() {
        defaults.set("S1", forKey: SharedKeys.dictationSessionRequest)
        XCTAssertTrue(DictationSessionClaim.appMayStart(defaults: defaults, directory: directory))
        XCTAssertEqual(DictationSessionClaim.claim("S1", as: .keyboard, in: directory), .app)
    }

    /// Both processes racing at the same instant, many times over: exactly one winner per
    /// session, and both sides agree on who it is.
    func testSimultaneousClaimsHaveExactlyOneWinner() {
        let sessions = (0..<200).map { "race-\($0)" }
        var keyboardSaw = [DictationSessionClaim.Owner?](repeating: nil, count: sessions.count)
        var appSaw = [DictationSessionClaim.Owner?](repeating: nil, count: sessions.count)
        let lock = NSLock()
        let directory = self.directory
        DispatchQueue.concurrentPerform(iterations: sessions.count * 2) { index in
            let session = index / 2
            let owner: DictationSessionClaim.Owner = index.isMultiple(of: 2) ? .keyboard : .app
            let winner = DictationSessionClaim.claim(sessions[session], as: owner, in: directory)
            lock.lock()
            if owner == .keyboard { keyboardSaw[session] = winner } else { appSaw[session] = winner }
            lock.unlock()
        }
        for index in sessions.indices {
            XCTAssertNotNil(keyboardSaw[index])
            XCTAssertEqual(keyboardSaw[index], appSaw[index], "both sides must see the same owner")
        }
    }

    /// A keyboard from before this change writes no session id: the app records as today.
    func testNoSessionIDFailsOpen() {
        XCTAssertTrue(DictationSessionClaim.appMayStart(defaults: defaults, directory: directory))
        XCTAssertTrue(DictationSessionClaim.appMayStart(defaults: defaults, directory: nil))
    }

    func testSessionIDsThatCouldEscapeTheDirectoryAreRefused() {
        XCTAssertNil(DictationSessionClaim.claim("../x", as: .app, in: directory))
        XCTAssertNil(DictationSessionClaim.claim("", as: .app, in: directory))
        XCTAssertNil(DictationSessionClaim.claim("a/b", as: .app, in: directory))
    }

    func testPruneRemovesOnlyOldClaims() throws {
        DictationSessionClaim.claim("old", as: .app, in: directory)
        DictationSessionClaim.claim("new", as: .app, in: directory)
        let oldURL = directory.appendingPathComponent("old")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -7200)], ofItemAtPath: oldURL.path)
        DictationSessionClaim.prune(in: directory)
        XCTAssertNil(DictationSessionClaim.current("old", in: directory))
        XCTAssertEqual(DictationSessionClaim.current("new", in: directory), .app)
    }
}
