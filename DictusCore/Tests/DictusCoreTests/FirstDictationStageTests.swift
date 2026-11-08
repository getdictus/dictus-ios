import XCTest
@testable import DictusCore

final class FirstDictationStageTests: XCTestCase {

    // MARK: - The states (#678, #845)

    func testAnUnfocusedFieldHasNoKeyboard() {
        XCTAssertEqual(FirstDictationStage(isFieldFocused: false, isDictusKeyboard: false, isAwaitingAutoFocus: false), .beforeTap)
        // The input mode an unfocused text view reports is the last one it had, not one on
        // screen: it must not light the Dictus banner.
        XCTAssertEqual(FirstDictationStage(isFieldFocused: false, isDictusKeyboard: true, isAwaitingAutoFocus: false), .beforeTap)
    }

    func testWhileTheAutoFocusIsPendingTheKeyboardIsOpening() {
        XCTAssertEqual(FirstDictationStage(isFieldFocused: false, isDictusKeyboard: false, isAwaitingAutoFocus: true), .opening)
        XCTAssertEqual(FirstDictationStage(isFieldFocused: false, isDictusKeyboard: true, isAwaitingAutoFocus: true), .opening)
    }

    func testAFocusedFieldShowsTheKeyboardThatIsUp() {
        for awaiting in [false, true] {
            XCTAssertEqual(FirstDictationStage(isFieldFocused: true, isDictusKeyboard: false, isAwaitingAutoFocus: awaiting), .otherKeyboard)
            XCTAssertEqual(FirstDictationStage(isFieldFocused: true, isDictusKeyboard: true, isAwaitingAutoFocus: awaiting), .dictusKeyboard)
        }
    }

    // MARK: - Auto-focus fallback, 1 s (#845)

    func testTheAutoFocusIsStillAwaitedBeforeOneSecond() {
        XCTAssertFalse(FirstDictationStage.autoFocusHasFailed(secondsSinceRequest: 0, isFieldFocused: false))
        XCTAssertFalse(FirstDictationStage.autoFocusHasFailed(secondsSinceRequest: 0.99, isFieldFocused: false))
    }

    func testTheAutoFocusHasFailedAtAndAfterOneSecond() {
        XCTAssertTrue(FirstDictationStage.autoFocusHasFailed(secondsSinceRequest: 1, isFieldFocused: false))
        XCTAssertTrue(FirstDictationStage.autoFocusHasFailed(secondsSinceRequest: 5, isFieldFocused: false))
    }

    func testAFocusedFieldNeverFailsItsAutoFocus() {
        XCTAssertFalse(FirstDictationStage.autoFocusHasFailed(secondsSinceRequest: 1, isFieldFocused: true))
        XCTAssertFalse(FirstDictationStage.autoFocusHasFailed(secondsSinceRequest: 60, isFieldFocused: true))
    }

    // MARK: - Continue, 15 s (#845)

    func testContinueIsHiddenBeforeFifteenSeconds() {
        XCTAssertFalse(FirstDictationStage.showsContinue(secondsSinceOtherKeyboard: 0, hasSeenDictusKeyboard: false))
        XCTAssertFalse(FirstDictationStage.showsContinue(secondsSinceOtherKeyboard: 14.9, hasSeenDictusKeyboard: false))
    }

    func testContinueShowsAtAndAfterFifteenSeconds() {
        XCTAssertTrue(FirstDictationStage.showsContinue(secondsSinceOtherKeyboard: 15, hasSeenDictusKeyboard: false))
        XCTAssertTrue(FirstDictationStage.showsContinue(secondsSinceOtherKeyboard: 120, hasSeenDictusKeyboard: false))
    }

    func testContinueNeedsAnotherKeyboardToHaveBeenUp() {
        XCTAssertFalse(FirstDictationStage.showsContinue(secondsSinceOtherKeyboard: nil, hasSeenDictusKeyboard: false))
    }

    func testContinueIsHiddenOnceDictusHasBeenDetected() {
        XCTAssertFalse(FirstDictationStage.showsContinue(secondsSinceOtherKeyboard: 15, hasSeenDictusKeyboard: true))
        XCTAssertFalse(FirstDictationStage.showsContinue(secondsSinceOtherKeyboard: 120, hasSeenDictusKeyboard: true))
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

    // MARK: - Typed text (#845)

    /// The rule takes no chip: typing with the Dictus keyboard completes the step on an
    /// A14 or later (where the page asks for a dictation) as on an older chip (where it
    /// asks for typing, #635). Both pages feed the same call, so one input covers both.
    func testTypedTextCompletesOnceDictusHasBeenUpOnEveryChip() {
        XCTAssertTrue(FirstDictationStage.completes(text: "abc", hasSeenDictusKeyboard: true))
        XCTAssertTrue(FirstDictationStage.completes(text: "Je tape au clavier", hasSeenDictusKeyboard: true))
    }

    func testTypedTextWithoutDictusSeenDoesNotComplete() {
        XCTAssertFalse(FirstDictationStage.completes(text: "abc", hasSeenDictusKeyboard: false))
        XCTAssertFalse(FirstDictationStage.completes(text: "Je tape au clavier", hasSeenDictusKeyboard: false))
    }
}
