// DictusCore/Tests/DictusCoreTests/ReleaseNotesTests.swift
// Reading release notes, and the repository's ReleaseNotes folder itself (#974).
import XCTest
@testable import DictusCore

final class ReleaseNotesTests: XCTestCase {

    /// `ReleaseNotes/` at the root of the repository, the folder the app bundles and
    /// `scripts/release-notes.sh` sends to App Store Connect.
    private static let repositoryFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // DictusCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // DictusCore
        .deletingLastPathComponent()   // repository root
        .appendingPathComponent(ReleaseNotes.bundleFolder, isDirectory: true)

    // MARK: - Parsing

    func testTheFirstLineIsTheTitleAndEachBulletIsOneLine() throws {
        let notes = try XCTUnwrap(ReleaseNotes(text: "What's new in 2.0.2\n• One.\n\n•Two.\n"))
        XCTAssertEqual(notes.title, "What's new in 2.0.2")
        XCTAssertEqual(notes.lines, ["One.", "Two."])
    }

    func testATextWithoutAChangeIsNoNotes() {
        XCTAssertNil(ReleaseNotes(text: ""))
        XCTAssertNil(ReleaseNotes(text: "What's new in 2.0.2\n"))
    }

    func testEachLanguageReadsItsFileAndTheRestReadEnglish() {
        XCTAssertEqual(ReleaseNotes.locale(forLanguage: "fr"), "fr")
        XCTAssertEqual(ReleaseNotes.locale(forLanguage: "fr-CA"), "fr")
        XCTAssertEqual(ReleaseNotes.locale(forLanguage: "de"), "de")
        XCTAssertEqual(ReleaseNotes.locale(forLanguage: "es-ES"), "es")
        XCTAssertEqual(ReleaseNotes.locale(forLanguage: "en-GB"), "en")
        XCTAssertEqual(ReleaseNotes.locale(forLanguage: "it"), "en")
        XCTAssertEqual(ReleaseNotes.locale(forLanguage: nil), "en")
    }

    func testAVersionWithoutAFolderHasNoNotes() {
        XCTAssertNil(ReleaseNotes.load(version: "2.0.0", language: "fr", from: Self.repositoryFolder))
    }

    // MARK: - The repository's notes

    func testTwoPointZeroPointTwoReadsInFrench() throws {
        let notes = try XCTUnwrap(ReleaseNotes.load(version: "2.0.2", language: "fr", from: Self.repositoryFolder))
        XCTAssertEqual(notes.title, "Nouveautés de la 2.0.2")
        XCTAssertEqual(notes.lines.count, 6)
    }

    /// Every version folder is complete and fits both places it is shown: four languages,
    /// three to six changes on the in-app screen, App Store Connect's 4,000 characters.
    func testEveryVersionHasFourLanguagesOfThreeToSixLines() throws {
        let versions = try FileManager.default.contentsOfDirectory(atPath: Self.repositoryFolder.path)
            .filter { !$0.hasPrefix(".") }
        XCTAssertFalse(versions.isEmpty)
        for version in versions {
            for locale in ReleaseNotes.locales {
                let file = Self.repositoryFolder.appendingPathComponent("\(version)/\(locale).txt")
                let text = try String(contentsOf: file, encoding: .utf8)
                let notes = try XCTUnwrap(ReleaseNotes(text: text), "\(version)/\(locale)")
                XCTAssertTrue((3...6).contains(notes.lines.count), "\(version)/\(locale): \(notes.lines.count) lines")
                XCTAssertTrue(notes.title.contains(version), "\(version)/\(locale): title names the version")
                XCTAssertLessThanOrEqual(text.count, 4000, "\(version)/\(locale)")
            }
        }
    }
}
