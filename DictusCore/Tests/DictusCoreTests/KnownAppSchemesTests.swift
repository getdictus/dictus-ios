// DictusCore/Tests/DictusCoreTests/KnownAppSchemesTests.swift
// Unit tests verifying KnownAppSchemes URL scheme list integrity.
// Required by VALIDATION.md Wave 0 for COLD-08 compliance.
import XCTest
@testable import DictusCore

final class KnownAppSchemesTests: XCTestCase {

    /// Verify the list is not empty and contains exactly 10 entries.
    func testAllSchemesNotEmpty() {
        XCTAssertFalse(KnownAppSchemes.all.isEmpty, "KnownAppSchemes.all should not be empty")
        XCTAssertEqual(KnownAppSchemes.all.count, 10, "KnownAppSchemes.all should have exactly 10 entries")
    }

    /// Verify each scheme string produces a valid URL.
    /// WHY: URL(string:) returns nil for malformed strings. This catches typos like
    /// missing "://" or invalid characters in scheme definitions.
    func testSchemeURLsAreValid() {
        for appScheme in KnownAppSchemes.all {
            let url = URL(string: appScheme.scheme)
            XCTAssertNotNil(url, "\(appScheme.name) scheme '\(appScheme.scheme)' should be a valid URL")
        }
    }

    /// Verify queryScheme matches the scheme portion of the full URL.
    /// E.g., "whatsapp" should match the scheme of "whatsapp://".
    func testQuerySchemesMatchSchemes() {
        for appScheme in KnownAppSchemes.all {
            guard let url = URL(string: appScheme.scheme) else {
                XCTFail("\(appScheme.name) scheme '\(appScheme.scheme)' is not a valid URL")
                continue
            }
            XCTAssertEqual(
                url.scheme,
                appScheme.queryScheme,
                "\(appScheme.name) queryScheme '\(appScheme.queryScheme)' should match URL scheme '\(url.scheme ?? "nil")'"
            )
        }
    }

    /// Verify no duplicate queryScheme values exist in the list.
    func testNoDuplicateSchemes() {
        let querySchemes = KnownAppSchemes.all.map(\.queryScheme)
        let uniqueSchemes = Set(querySchemes)
        XCTAssertEqual(
            querySchemes.count,
            uniqueSchemes.count,
            "KnownAppSchemes should have no duplicate queryScheme values"
        )
    }

    /// Verify no duplicate name values exist in the list.
    func testNoDuplicateNames() {
        let names = KnownAppSchemes.all.map(\.name)
        let uniqueNames = Set(names)
        XCTAssertEqual(
            names.count,
            uniqueNames.count,
            "KnownAppSchemes should have no duplicate name values"
        )
    }
}
