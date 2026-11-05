// DictusCore/Tests/DictusCoreTests/KeyboardPreviewSpaceLabelTests.swift
// The space bar of the Settings keyboard preview, pinned to the catalog and to the
// word the real keyboard writes (#798).

import XCTest
@testable import DictusCore

/// The miniature keyboard under Settings > Default page wrote "espace" on its space
/// bar in every language (#798). It now reads the `space` key of the app's catalog.
/// DictusApp has no test bundle, so this reads the repo, like `SettingsFrenchCopyTests`.
final class KeyboardPreviewSpaceLabelTests: XCTestCase {

    private static let catalog = "DictusApp/Localizable.xcstrings"
    private static let pickerSource = "DictusApp/Views/KeyboardModePicker.swift"

    /// Each shipped language gets the word its real space bar shows, so the preview
    /// and the keyboard never disagree.
    func testCatalogSpaceMatchesTheRealKeyboardInEveryLanguage() throws {
        let data = try Data(contentsOf: repoRoot().appendingPathComponent(Self.catalog))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = json?["strings"] as? [String: Any]
        let entry = try XCTUnwrap(strings?["space"] as? [String: Any], "the catalog has no `space` entry")
        let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
        for language in SupportedLanguage.allCases {
            let unit = (localizations[language.rawValue] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertEqual(unit?["value"] as? String, language.spaceName, "`space` in \(language.rawValue)")
        }
    }

    /// The preview goes through the catalog and no longer hard-codes the French word.
    func testThePreviewLooksTheLabelUp() throws {
        let source = try String(
            contentsOf: repoRoot().appendingPathComponent(Self.pickerSource), encoding: .utf8
        )
        XCTAssertTrue(source.contains("String(localized: \"space\""), "the preview no longer reads `space` from the catalog")
        XCTAssertFalse(source.contains("\"espace\""), "the preview hard-codes the French space bar label again")
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // DictusCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // DictusCore
            .deletingLastPathComponent()  // repo root
    }
}
