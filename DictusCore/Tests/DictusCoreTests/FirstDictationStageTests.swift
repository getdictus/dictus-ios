import XCTest
@testable import DictusCore

final class FirstDictationStageTests: XCTestCase {

    // MARK: - The three states (#678)

    func testAnUnfocusedFieldHasNoKeyboard() {
        XCTAssertEqual(FirstDictationStage(isFieldFocused: false, isDictusKeyboard: false), .beforeTap)
        // The input mode an unfocused text view reports is the last one it had, not one on
        // screen: it must not light the Dictus banner.
        XCTAssertEqual(FirstDictationStage(isFieldFocused: false, isDictusKeyboard: true), .beforeTap)
    }

    func testAFocusedFieldShowsTheKeyboardThatIsUp() {
        XCTAssertEqual(FirstDictationStage(isFieldFocused: true, isDictusKeyboard: false), .otherKeyboard)
        XCTAssertEqual(FirstDictationStage(isFieldFocused: true, isDictusKeyboard: true), .dictusKeyboard)
    }

    // MARK: - Which input mode is Dictus

    func testTheKeyboardExtensionIsDictus() {
        XCTAssertTrue(FirstDictationStage.isDictusInputMode(identifier: "com.pivi.dictus.keyboard"))
    }

    func testAppleKeyboardsAreNotDictus() {
        XCTAssertFalse(FirstDictationStage.isDictusInputMode(identifier: "fr_FR@sw=AZERTY-French;hw=Automatic"))
        XCTAssertFalse(FirstDictationStage.isDictusInputMode(identifier: "en_US@sw=QWERTY;hw=Automatic"))
        XCTAssertFalse(FirstDictationStage.isDictusInputMode(identifier: "emoji@sw=Emoji"))
        XCTAssertFalse(FirstDictationStage.isDictusInputMode(identifier: "com.apple.dictation"))
    }

    func testAnIdentifierThatOnlyContainsThePrefixIsNotDictus() {
        XCTAssertFalse(FirstDictationStage.isDictusInputMode(identifier: "com.example.com.pivi.dictus.keyboard"))
        XCTAssertFalse(FirstDictationStage.isDictusInputMode(identifier: "com.pivi.dictusplus.keyboard"))
    }

    func testAnUnreadableIdentifierIsNotDictus() {
        XCTAssertFalse(FirstDictationStage.isDictusInputMode(identifier: nil))
        XCTAssertFalse(FirstDictationStage.isDictusInputMode(identifier: ""))
    }

    // MARK: - Completion, as before #678

    func testTextBeforeTheDictusKeyboardDoesNotComplete() {
        XCTAssertFalse(FirstDictationStage.completes(text: "Bonjour à tous", hasSeenDictusKeyboard: false))
    }

    func testThreeCharactersCompleteOnceDictusHasBeenUp() {
        XCTAssertTrue(FirstDictationStage.completes(text: "oui", hasSeenDictusKeyboard: true))
        XCTAssertTrue(FirstDictationStage.completes(text: "Bonjour à tous", hasSeenDictusKeyboard: true))
    }

    func testFewerThanThreeCharactersDoNotComplete() {
        XCTAssertFalse(FirstDictationStage.completes(text: "", hasSeenDictusKeyboard: true))
        XCTAssertFalse(FirstDictationStage.completes(text: "ok", hasSeenDictusKeyboard: true))
        // Whitespace does not count: a stray space and return are not a dictation.
        XCTAssertFalse(FirstDictationStage.completes(text: "  a \n ", hasSeenDictusKeyboard: true))
    }
}
