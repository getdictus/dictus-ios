// DictusCore/Tests/DictusCoreTests/ReturnKeyStyleTests.swift
// The return key follows the host field's returnKeyType (#1023): type → glyph, colour,
// label, and the off state of enablesReturnKeyAutomatically.

import XCTest
@testable import DictusCore

final class ReturnKeyStyleTests: XCTestCase {

    // UIReturnKeyType raw values, spelled out so a test failure names the UIKit case.
    private enum UIKitType: Int, CaseIterable {
        case `default` = 0, go, google, join, next, route, search, send, yahoo, done, emergencyCall, `continue`
    }

    private func style(_ type: UIKitType) -> ReturnKeyStyle {
        ReturnKeyStyle(returnKeyTypeRawValue: type.rawValue)
    }

    // MARK: - Type → role

    func testEveryUIKitTypeMapsToItsRole() {
        let expected: [UIKitType: ReturnKeyStyle.Role] = [
            .default: .newline, .go: .go, .google: .search, .join: .join, .next: .next,
            .route: .route, .search: .search, .send: .send, .yahoo: .search, .done: .done,
            .emergencyCall: .emergencyCall, .continue: .continue
        ]
        for type in UIKitType.allCases {
            XCTAssertEqual(style(type).role, expected[type], "\(type)")
        }
    }

    func testMissingOrUnknownTypeIsThePlainReturnKey() {
        XCTAssertEqual(ReturnKeyStyle(returnKeyTypeRawValue: nil), .newline)
        XCTAssertEqual(ReturnKeyStyle(returnKeyTypeRawValue: 12), .newline)
        XCTAssertEqual(ReturnKeyStyle(returnKeyTypeRawValue: -1), .newline)
    }

    // MARK: - Glyph and colour, as Apple's keyboard draws them

    func testGlyphs() {
        XCTAssertEqual(style(.default).symbol, "return")
        XCTAssertEqual(style(.send).symbol, "arrow.up")
        XCTAssertEqual(style(.go).symbol, "arrow.right")
        XCTAssertEqual(style(.join).symbol, "arrow.right")
        XCTAssertEqual(style(.route).symbol, "arrow.right")
        XCTAssertEqual(style(.search).symbol, "magnifyingglass")
        XCTAssertEqual(style(.google).symbol, "magnifyingglass")
        XCTAssertEqual(style(.yahoo).symbol, "magnifyingglass")
        XCTAssertEqual(style(.done).symbol, "checkmark")
        XCTAssertEqual(style(.emergencyCall).symbol, "phone")
        XCTAssertEqual(style(.next).symbol, "chevron.right")
        XCTAssertEqual(style(.continue).symbol, "chevron.right")
    }

    func testOnlyTheActingTypesAreBlue() {
        let blue: Set<UIKitType> = [.send, .go, .join, .route, .search, .google, .yahoo, .done, .emergencyCall]
        for type in UIKitType.allCases {
            XCTAssertEqual(style(type).isAction, blue.contains(type), "\(type)")
        }
    }

    // MARK: - Labels

    func testFrenchLabels() {
        XCTAssertEqual(style(.default).label(in: .french), "retour")
        XCTAssertEqual(style(.send).label(in: .french), "envoyer")
        XCTAssertEqual(style(.go).label(in: .french), "accéder")
        XCTAssertEqual(style(.search).label(in: .french), "rechercher")
        XCTAssertEqual(style(.next).label(in: .french), "suivant")
        XCTAssertEqual(style(.done).label(in: .french), "OK")
        XCTAssertEqual(style(.emergencyCall).label(in: .french), "appel d’urgence")
    }

    func testEnglishLabels() {
        XCTAssertEqual(style(.default).label(in: .english), "return")
        XCTAssertEqual(style(.send).label(in: .english), "send")
        XCTAssertEqual(style(.go).label(in: .english), "go")
        XCTAssertEqual(style(.search).label(in: .english), "search")
        XCTAssertEqual(style(.next).label(in: .english), "next")
        XCTAssertEqual(style(.done).label(in: .english), "done")
        XCTAssertEqual(style(.emergencyCall).label(in: .english), "emergency call")
    }

    func testSpanishAndGermanLabels() {
        XCTAssertEqual(style(.default).label(in: .spanish), "intro")
        XCTAssertEqual(style(.send).label(in: .spanish), "enviar")
        XCTAssertEqual(style(.search).label(in: .spanish), "buscar")
        XCTAssertEqual(style(.default).label(in: .german), "Eingabe")
        XCTAssertEqual(style(.send).label(in: .german), "Senden")
        XCTAssertEqual(style(.search).label(in: .german), "Suchen")
    }

    /// Every role has its own word in every language: none falls back to the plain key's.
    func testEveryRoleHasALabelInEveryLanguage() {
        for language in SupportedLanguage.allCases {
            for role in ReturnKeyStyle.Role.allCases {
                let label = ReturnKeyStyle(role: role).label(in: language)
                XCTAssertFalse(label.isEmpty, "\(language) \(role)")
                if role != .newline {
                    XCTAssertNotEqual(label, language.returnName, "\(language) \(role) fell back")
                }
            }
        }
    }

    // MARK: - Off state (enablesReturnKeyAutomatically)

    func testOffOnlyWhenTheHostAsksAndTheFieldIsEmpty() {
        XCTAssertFalse(ReturnKeyAppearance.isEnabled(automatically: true, hasText: false))
        XCTAssertTrue(ReturnKeyAppearance.isEnabled(automatically: true, hasText: true))
        XCTAssertTrue(ReturnKeyAppearance.isEnabled(automatically: false, hasText: false))
        XCTAssertTrue(ReturnKeyAppearance.isEnabled(automatically: nil, hasText: false))
    }

    func testAppearanceReadsTheThreeTraits() {
        let safariEmpty = ReturnKeyAppearance(
            returnKeyTypeRawValue: UIKitType.go.rawValue,
            enablesReturnKeyAutomatically: true,
            hasText: false
        )
        XCTAssertEqual(safariEmpty, ReturnKeyAppearance(style: ReturnKeyStyle(role: .go), isEnabled: false))

        let notesField = ReturnKeyAppearance(returnKeyTypeRawValue: nil, enablesReturnKeyAutomatically: nil, hasText: false)
        XCTAssertEqual(notesField, .standard)
    }
}
