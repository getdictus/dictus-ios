// DictusCore/Tests/DictusCoreTests/VoiceNoteRouteTests.swift
// Tests for VoiceNoteRoute and the share extension's hand-over to DictusApp (#992).
import XCTest
@testable import DictusCore

final class VoiceNoteRouteTests: XCTestCase {

    /// Every combination: only a note nobody took, on iOS 26+, with the setting on and
    /// the locale installed, is transcribed by the extension.
    func testEveryCombination() {
        for appTookIt in [false, true] {
            for setting in [false, true] {
                for version in [17, 25, 26, 27] {
                    for locale in [nil, false, true] as [Bool?] {
                        let route = VoiceNoteRoute.decide(appTookIt: appTookIt, settingEnabled: setting,
                                                          systemMajorVersion: version, localeInstalled: locale)
                        let expected: VoiceNoteRoute
                        if appTookIt {
                            expected = .appTookIt
                        } else if setting, version >= 26, locale == true {
                            expected = .shareExtension
                        } else {
                            expected = .openApp
                        }
                        XCTAssertEqual(route, expected, "took=\(appTookIt) setting=\(setting) iOS=\(version) locale=\(String(describing: locale))")
                    }
                }
            }
        }
    }

    func testWarmAppKeepsItsPathWhateverElseHolds() {
        XCTAssertEqual(VoiceNoteRoute.decide(appTookIt: true, settingEnabled: true, systemMajorVersion: 26, localeInstalled: true), .appTookIt)
    }

    func testMissingLocaleOrOldOSOpensTheAppAsBefore() {
        XCTAssertEqual(VoiceNoteRoute.decide(appTookIt: false, settingEnabled: true, systemMajorVersion: 26, localeInstalled: false), .openApp)
        XCTAssertEqual(VoiceNoteRoute.decide(appTookIt: false, settingEnabled: true, systemMajorVersion: 18, localeInstalled: true), .openApp)
    }

    /// The app launches while the extension transcribes: one of them owns the note.
    func testNoteOwnedByTheExtensionIsNotTranscribedByTheApp() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vn-claims-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = UUID().uuidString
        XCTAssertEqual(DictationSessionClaim.claim(note, as: .shareExtension, in: directory), .shareExtension)
        XCTAssertEqual(DictationSessionClaim.claim(note, as: .app, in: directory), .shareExtension)
    }

    /// The keyboard's start claim: only the app's own claim lets it record.
    func testAppMayStartOnlyWhenItOwnsTheSession() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vn-claims-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "dictus.tests.voiceNoteRoute"))
        defer { defaults.removePersistentDomain(forName: "dictus.tests.voiceNoteRoute") }
        defaults.set("S7", forKey: SharedKeys.dictationSessionRequest)
        DictationSessionClaim.claim("S7", as: .shareExtension, in: directory)
        XCTAssertFalse(DictationSessionClaim.appMayStart(defaults: defaults, directory: directory))
    }

    func testExtensionResultRoundTrip() throws {
        let storage = VoiceNoteStorage(root: FileManager.default.temporaryDirectory.appendingPathComponent("vn-\(UUID().uuidString)"))
        defer { try? FileManager.default.removeItem(at: storage.root) }
        let result = VoiceNoteExtensionResult(id: UUID(), transcript: "Bonjour", language: "fr", durationSeconds: 61,
                                              savedToHistory: true, engine: "apple-speechtranscriber",
                                              transcribedAt: Date(timeIntervalSince1970: 1_000))
        try result.write(to: storage)
        XCTAssertEqual(VoiceNoteExtensionResult.read(result.id, from: storage), result)
        VoiceNoteExtensionResult.remove(result.id, from: storage)
        XCTAssertNil(VoiceNoteExtensionResult.read(result.id, from: storage))
    }
}
