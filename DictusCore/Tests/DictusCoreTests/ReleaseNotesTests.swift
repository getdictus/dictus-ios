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

    func testTheFirstBlockIsTheTitleAndEachOtherBlockIsOneChange() throws {
        let text = "What's new in 2.0.2\n\nat\nAddresses\nNo more autocorrect.\n\n\nmic.fill\nMicrophone\nIt tells you.\n"
        let notes = try XCTUnwrap(ReleaseNotes(text: text))
        XCTAssertEqual(notes.title, "What's new in 2.0.2")
        XCTAssertEqual(notes.items, [
            .init(symbol: "at", title: "Addresses", text: "No more autocorrect."),
            .init(symbol: "mic.fill", title: "Microphone", text: "It tells you.")
        ])
    }

    func testAMalformedFileIsNoNotes() {
        XCTAssertNil(ReleaseNotes(text: ""))
        // No change.
        XCTAssertNil(ReleaseNotes(text: "What's new in 2.0.2\n"))
        // A change without its symbol.
        XCTAssertNil(ReleaseNotes(text: "What's new in 2.0.2\n\nAddresses\nNo more autocorrect.\n"))
        // The title and the first change run together.
        XCTAssertNil(ReleaseNotes(text: "What's new in 2.0.2\nat\nAddresses\nNo more autocorrect.\n"))
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
        XCTAssertEqual(notes.items.count, 6)
        XCTAssertEqual(notes.items.first?.title, "Écrivez-nous depuis l'app")
    }

    /// Every version folder is complete and fits both places it is shown: four languages, three
    /// to six changes with the same symbols in the same order, and App Store Connect's 4,000
    /// characters (the store text, `scripts/release-notes.sh`, is shorter than the file).
    func testEveryVersionHasFourMatchingLanguagesOfThreeToSixChanges() throws {
        let versions = try FileManager.default.contentsOfDirectory(atPath: Self.repositoryFolder.path)
            .filter { !$0.hasPrefix(".") }
        XCTAssertFalse(versions.isEmpty)
        for version in versions {
            var symbols: [String]?
            for locale in ReleaseNotes.locales {
                let file = Self.repositoryFolder.appendingPathComponent("\(version)/\(locale).txt")
                let text = try String(contentsOf: file, encoding: .utf8)
                let notes = try XCTUnwrap(ReleaseNotes(text: text), "\(version)/\(locale)")
                XCTAssertTrue((3...6).contains(notes.items.count), "\(version)/\(locale): \(notes.items.count) changes")
                XCTAssertTrue(notes.title.contains(version), "\(version)/\(locale): title names the version")
                XCTAssertLessThanOrEqual(text.count, 4000, "\(version)/\(locale)")
                let theseSymbols = notes.items.map(\.symbol)
                XCTAssertEqual(theseSymbols, symbols ?? theseSymbols, "\(version)/\(locale): symbols differ from fr")
                symbols = symbols ?? theseSymbols
            }
        }
    }
}
