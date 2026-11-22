// DictusCore/Tests/DictusCoreTests/KnownMisspellingsTests.swift
// The misspelling maps match the committed record of removals, and the shipped
// word lists hold every target and none of the misspellings (#995).
import XCTest
@testable import DictusCore

final class KnownMisspellingsTests: XCTestCase {

    private let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // DictusCoreTests/
        .deletingLastPathComponent()   // Tests/
        .deletingLastPathComponent()   // DictusCore/
        .deletingLastPathComponent()   // repo root

    private func removals(_ language: String) throws -> [String: String] {
        let url = repoRoot.appendingPathComponent("tools/misspellings/removed-\(language).tsv")
        let rows = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").dropFirst()
        return Dictionary(uniqueKeysWithValues: rows.map { row in
            let fields = row.split(separator: "\t", omittingEmptySubsequences: false)
            return (String(fields[0]), String(fields[1]))
        })
    }

    private func wordList(_ language: String) throws -> [String: Int] {
        let url = repoRoot.appendingPathComponent("DictusKeyboard/Resources/\(language)_frequency.json")
        return try JSONDecoder().decode([String: Int].self, from: Data(contentsOf: url))
    }

    func testProfilesCarryTheCommittedRemovals() throws {
        XCTAssertEqual(englishProfile.misspellings, try removals("en"))
        XCTAssertEqual(spanishProfile.misspellings, try removals("es"))
        XCTAssertTrue(frenchProfile.misspellings.isEmpty)
        XCTAssertTrue(germanProfile.misspellings.isEmpty)
    }

    func testWordListsHoldTheTargetsAndNotTheMisspellings() throws {
        for (language, profile) in [("en", englishProfile), ("es", spanishProfile)] {
            let words = try wordList(language)
            for (misspelling, target) in profile.misspellings {
                XCTAssertNil(words[misspelling], "\(language): \(misspelling) is still a word")
                XCTAssertNotNil(words[target], "\(language): target \(target) of \(misspelling) is missing")
            }
        }
    }

    func testNoMisspellingShadowsAnOverride() {
        for profile in [englishProfile, spanishProfile] {
            XCTAssertTrue(Set(profile.misspellings.keys).isDisjoint(with: profile.overrides.keys), profile.code)
        }
    }
}
