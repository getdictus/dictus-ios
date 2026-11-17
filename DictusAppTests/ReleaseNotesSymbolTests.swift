// DictusAppTests/ReleaseNotesSymbolTests.swift
// Every symbol a bundled release note names exists on this iOS (#974).
import XCTest
import UIKit
import DictusCore

/// WHY a hosted app test and not a DictusCore test: SF Symbols are an iOS asset catalog, and
/// `swift test` runs on the Mac. A misspelt name draws an empty tile on the What's new screen
/// without any error, so it is checked here, on the notes the app actually bundles.
final class ReleaseNotesSymbolTests: XCTestCase {

    func testEveryBundledNoteNamesAnExistingSymbol() throws {
        let folder = try XCTUnwrap(Bundle.main.url(forResource: ReleaseNotes.bundleFolder, withExtension: nil))
        let versions = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertFalse(versions.isEmpty)
        for version in versions {
            for locale in ReleaseNotes.locales {
                let notes = try XCTUnwrap(ReleaseNotes.load(version: version, language: locale, from: folder),
                                          "\(version)/\(locale)")
                for item in notes.items {
                    XCTAssertNotNil(UIImage(systemName: item.symbol), "\(version)/\(locale): \(item.symbol)")
                }
            }
        }
    }
}
