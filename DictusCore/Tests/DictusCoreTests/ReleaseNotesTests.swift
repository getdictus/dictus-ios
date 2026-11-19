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

    private static func file(highlights: [String], changes: [String]) -> String {
        (["What's new in 2.0.2", "## Highlights"] + highlights + ["## All changes"] + changes)
            .joined(separator: "\n\n") + "\n"
    }

    func testTheHighlightsAndTheFullListAreReadApart() throws {
        let text = Self.file(highlights: ["Feedback\nSend it from Settings."],
                             changes: ["Feedback\nSend it from Settings, log attached.", "Addresses\nKept as typed."])
        let notes = try XCTUnwrap(ReleaseNotes(text: text))
        XCTAssertEqual(notes.title, "What's new in 2.0.2")
        XCTAssertEqual(notes.highlights, [.init(title: "Feedback", text: "Send it from Settings.")])
        XCTAssertEqual(notes.changes, [
            .init(title: "Feedback", text: "Send it from Settings, log attached."),
            .init(title: "Addresses", text: "Kept as typed.")
        ])
    }

    func testAMalformedFileIsNoNotes() {
        let change = "Addresses\nKept as typed."
        XCTAssertNil(ReleaseNotes(text: ""))
        // No highlight, or more than three.
        XCTAssertNil(ReleaseNotes(text: Self.file(highlights: [], changes: [change])))
        XCTAssertNil(ReleaseNotes(text: Self.file(highlights: Array(repeating: change, count: 4), changes: [change])))
        // No change for App Store Connect.
        XCTAssertNil(ReleaseNotes(text: Self.file(highlights: [change], changes: [])))
        // A change without its sentence, or with a third line (the old symbol format).
        XCTAssertNil(ReleaseNotes(text: Self.file(highlights: ["Addresses"], changes: [change])))
        XCTAssertNil(ReleaseNotes(text: Self.file(highlights: [change], changes: ["at\n" + change])))
        // No section headings.
        XCTAssertNil(ReleaseNotes(text: "What's new in 2.0.2\n\n" + change + "\n"))
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
        XCTAssertEqual(notes.highlights.map(\.title),
                       ["Écrivez-nous depuis l'app", "Adresses et liens intacts", "Fini les fins inventées"])
        XCTAssertEqual(notes.changes.count, 6)
    }

    /// Every version folder is complete and fits both places it is shown: four languages with
    /// the same number of highlights (at most three, the sheet) and of changes, and App Store
    /// Connect's 4,000 characters (the store text, `scripts/release-notes.sh`, is shorter than
    /// the file).
    func testEveryVersionHasFourMatchingLanguages() throws {
        let versions = try FileManager.default.contentsOfDirectory(atPath: Self.repositoryFolder.path)
            .filter { !$0.hasPrefix(".") }
        XCTAssertFalse(versions.isEmpty)
        for version in versions {
            var counts: [Int]?
            for locale in ReleaseNotes.locales {
                let file = Self.repositoryFolder.appendingPathComponent("\(version)/\(locale).txt")
                let text = try String(contentsOf: file, encoding: .utf8)
                let notes = try XCTUnwrap(ReleaseNotes(text: text), "\(version)/\(locale)")
                XCTAssertTrue(notes.title.contains(version), "\(version)/\(locale): title names the version")
                XCTAssertLessThanOrEqual(text.count, 4000, "\(version)/\(locale)")
                let theseCounts = [notes.highlights.count, notes.changes.count]
                XCTAssertEqual(theseCounts, counts ?? theseCounts, "\(version)/\(locale): counts differ from fr")
                counts = counts ?? theseCounts
            }
        }
    }
}
