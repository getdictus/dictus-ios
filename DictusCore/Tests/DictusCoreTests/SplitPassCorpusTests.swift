// DictusCore/Tests/DictusCoreTests/SplitPassCorpusTests.swift
import XCTest

/// Guards the glued-word corpus the split-pass bench measures (#499).
///
/// WHY a test for a data file: the bench (`tools/split-pass-bench`) needs an
/// iOS Simulator and never runs in CI, so nothing else would notice a corpus row
/// whose expected split does not match what was typed. A bad row measures
/// nothing and silently moves the hit rate.
final class SplitPassCorpusTests: XCTestCase {

    private struct Row {
        let line: Int
        let id: String
        let lang: String
        let category: String
        let typed: String
        let expected: String
        let source: String
    }

    private static let header = ["id", "lang", "category", "typed", "expected", "source"]
    private static let glued: Set<String> = ["missed-space", "neighbour-key", "observed"]
    private static let legitimate: Set<String> = ["legit-compound", "legit-rare"]

    /// The spacebar neighbours `TextPredictionEngine.trySplitWithSignal` reads,
    /// without the AZERTY comma: the comma key commits the word before it (#872),
    /// so a comma glue never reaches the split pass as one word.
    private static let neighbours: [String: Set<Character>] = [
        "fr": ["n", "b"], "en": ["n", "b", "m"], "de": ["n", "b", "m"], "es": ["n", "b", "m"]
    ]

    private func rows() throws -> [Row] {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "split-pass-corpus", withExtension: "tsv", subdirectory: "Fixtures"),
            "split-pass-corpus.tsv missing from the test bundle"
        )
        let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
        var sawHeader = false
        var result: [Row] = []
        for (index, line) in lines.enumerated() where !line.isEmpty && !line.hasPrefix("#") {
            let fields = line.components(separatedBy: "\t")
            if !sawHeader {
                XCTAssertEqual(fields, Self.header, "first non-comment line must be the header")
                sawHeader = true
                continue
            }
            guard fields.count == Self.header.count else {
                XCTFail("line \(index + 1): \(fields.count) fields, expected \(Self.header.count)")
                continue
            }
            result.append(Row(
                line: index + 1, id: fields[0], lang: fields[1], category: fields[2],
                typed: fields[3], expected: fields[4], source: fields[5]
            ))
        }
        XCTAssertTrue(sawHeader, "no header line")
        return result
    }

    func test_everyRowIsWellFormed() throws {
        for row in try rows() {
            let at = "line \(row.line) (\(row.id))"
            XCTAssertNotNil(Self.neighbours[row.lang], "\(at): unknown language \(row.lang)")
            XCTAssertTrue(
                Self.glued.contains(row.category) || Self.legitimate.contains(row.category),
                "\(at): unknown category \(row.category)"
            )
            XCTAssertFalse(row.typed.isEmpty, "\(at): empty typed")
            XCTAssertEqual(row.typed, row.typed.lowercased(), "\(at): typed must be lowercase")
            XCTAssertFalse(row.typed.contains(where: \.isWhitespace), "\(at): typed holds a space")
            XCTAssertTrue(row.id.hasPrefix("\(row.lang)-\(row.category)-"), "\(at): id does not match its row")
            XCTAssertFalse(row.source.isEmpty, "\(at): no source")
        }
    }

    func test_idsAndTypedWordsAreUnique() throws {
        var ids = Set<String>()
        var typed = Set<String>()
        for row in try rows() {
            XCTAssertTrue(ids.insert(row.id).inserted, "duplicate id \(row.id)")
            XCTAssertTrue(typed.insert("\(row.lang):\(row.typed)").inserted, "duplicate case \(row.lang) \(row.typed)")
        }
    }

    func test_everyGluedCaseHasItsExpectedSplit() throws {
        for row in try rows() where Self.glued.contains(row.category) {
            let at = "line \(row.line) (\(row.id)) \(row.typed) → \(row.expected)"
            let parts = row.expected.components(separatedBy: " ")
            XCTAssertEqual(parts.count, 2, "\(at): expected must be two words")
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { continue }
            let neighbours = Self.neighbours[row.lang] ?? []
            let missedSpace = row.typed == parts[0] + parts[1]
            let neighbourKey = neighbours.contains { row.typed == parts[0] + String($0) + parts[1] }
            switch row.category {
            case "missed-space":
                XCTAssertTrue(missedSpace, "\(at): typed is not the two words joined")
            case "neighbour-key":
                XCTAssertTrue(neighbourKey, "\(at): typed is not the two words joined by a spacebar neighbour")
            default:
                // Observed glues keep what the typist meant, which can hold an
                // accent or an apostrophe the keyboard never received.
                XCTAssertTrue(
                    missedSpace || neighbourKey || Self.folded(row.expected) == row.typed,
                    "\(at): typed is not the expected text without its space"
                )
            }
        }
    }

    func test_legitimateWordsAreKeptWhole() throws {
        for row in try rows() where Self.legitimate.contains(row.category) {
            XCTAssertEqual(row.expected, row.typed, "line \(row.line) (\(row.id)): a legitimate word expects itself")
        }
    }

    func test_everyLanguageHasEveryMeasuredCategory() throws {
        let present = Set(try rows().map { "\($0.lang) \($0.category)" })
        for lang in Self.neighbours.keys {
            for category in ["missed-space", "neighbour-key", "legit-compound", "legit-rare"] {
                XCTAssertTrue(present.contains("\(lang) \(category)"), "no \(category) case for \(lang)")
            }
        }
    }

    /// Lowercase, no diacritics, no space or apostrophe: what the keys produced.
    private static func folded(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .filter { $0 != " " && $0 != "'" }
    }
}
