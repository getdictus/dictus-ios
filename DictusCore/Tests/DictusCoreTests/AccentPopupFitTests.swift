// DictusCore/Tests/DictusCoreTests/AccentPopupFitTests.swift
// One row of long-press options always fits the keyboard (#1042).
import XCTest
@testable import DictusCore

final class AccentPopupFitTests: XCTestCase {

    /// iPhone 17 portrait: 402 pt wide less the bubble's 12 pt corner radius on each side,
    /// ten keys a row (40.2 pt), the popup's 3 pt margin.
    private let width = 402.0 - 24, key = 40.2, margin = 3.0

    func testAShortListKeepsKeyWideOptions() {
        XCTAssertEqual(AccentPopupFit.optionWidth(keyWidth: key, availableWidth: width, margin: margin, count: 5), key)
    }

    /// French o and a: ten options with the key's own. At one key wide the row was 405 pt in a
    /// 378 pt bubble and the tenth (º, ª) was cut off.
    func testTenOptionsNarrowJustEnoughToFit() {
        let option = AccentPopupFit.optionWidth(keyWidth: key, availableWidth: width, margin: margin, count: 10)
        XCTAssertLessThan(option, key)
        XCTAssertEqual(option * 10 + margin, width, accuracy: 0.0001)
    }

    /// Every popup Dictus can show fits one row, down to the narrowest iPhone iOS 17 runs on
    /// (375 pt, iPhone SE), and no option gets narrower than a finger can pick.
    func testEveryListFitsOneRowOnTheNarrowestIPhone() {
        let narrow = 375.0 - 24
        for language in SupportedLanguage.allCases {
            for layout in LayoutType.allCases {
                let keyWidth = 375.0 / (layout == .qwertz ? 11 : 10)
                for (base, variants) in AccentedCharacters.mappings(for: language, layout: layout) {
                    let count = variants.count + 1  // the popup adds the key's own
                    let option = AccentPopupFit.optionWidth(
                        keyWidth: keyWidth, availableWidth: narrow, margin: margin, count: count)
                    XCTAssertLessThanOrEqual(option * Double(count) + margin, narrow + 0.0001, "\(language) \(base)")
                    XCTAssertGreaterThanOrEqual(option, 28, "\(language) \(layout) \(base): \(count) options")
                }
            }
        }
    }
}
