// DictusCore/Tests/DictusCoreTests/Polish/SmartModePickTests.swift
// The onboarding's Smart Mode pick: what it offers, the cap, and what it writes (#677).
//
// The write tests mutate the real App Group suite, so setUp/tearDown remove the pinned key.
import XCTest
@testable import DictusCore

final class SmartModePickTests: XCTestCase {

    private var defaults: UserDefaults { AppGroup.defaults }

    override func setUp() {
        super.setUp()
        defaults.removeObject(forKey: SharedKeys.smartModePinned)
    }

    override func tearDown() {
        defaults.removeObject(forKey: SharedKeys.smartModePinned)
        super.tearDown()
    }

    // MARK: - The offer

    func testCardsAreTheFourNonTranslateModesInCatalogueOrder() {
        XCTAssertEqual(SmartModePick.cardModes.map(\.id), [
            SmartModeCatalogue.structuredIdentifier,
            SmartModeCatalogue.notesIdentifier,
            SmartModeCatalogue.messageIdentifier,
            SmartModeCatalogue.summaryIdentifier
        ])
    }

    func testCardsCarryTheCatalogueIcons() {
        // The page draws `icon`, so the cards show what the app's mode list shows.
        XCTAssertEqual(
            SmartModePick.cardModes.map(\.icon),
            ["text.alignleft", "list.bullet", "bubble.left", "text.quote"]
        )
    }

    func testTranslateOffersTheFourTargetsMinusTheSpokenLanguage() {
        XCTAssertEqual(SmartModePick.translateTargets(spokenLanguage: "fr"), [.english, .spanish, .german])
        XCTAssertEqual(SmartModePick.translateTargets(spokenLanguage: "en"), [.french, .spanish, .german])
        XCTAssertEqual(SmartModePick.translateTargets(spokenLanguage: "es"), [.french, .english, .german])
        XCTAssertEqual(SmartModePick.translateTargets(spokenLanguage: "de"), [.french, .english, .spanish])
    }

    func testASpokenLanguageWithoutADictusKeyboardRemovesNoTarget() {
        XCTAssertEqual(SmartModePick.translateTargets(spokenLanguage: "zh"), SupportedLanguage.allCases)
        XCTAssertEqual(SmartModePick.translateTargets(spokenLanguage: nil), SupportedLanguage.allCases)
    }

    func testEveryOfferedTargetIsACatalogueMode() {
        for target in SmartModePick.translateTargets(spokenLanguage: nil) {
            XCTAssertNotNil(
                SmartModeCatalogue.mode(withIdentifier: SmartModeCatalogue.translateIdentifier(target: target))
            )
        }
    }

    // MARK: - The cap

    func testTheCapIsWhatTheFanHolds() {
        XCTAssertEqual(SmartModePick.maximum, SmartModeCatalogue.maximumPinnedModes)
        XCTAssertEqual(SmartModePick.maximum, 3)
    }

    func testSelectionIsCappedAtThree() {
        var pick = SmartModePick()
        for identifier in ["structured", "notes", "message", "summary"] {
            pick.toggle(identifier)
        }
        XCTAssertEqual(pick.selected, ["structured", "notes", "message"])
        XCTAssertTrue(pick.isFull)
        XCTAssertFalse(pick.canToggle("summary"))
        XCTAssertTrue(pick.canToggle("notes"), "a picked mode can always be removed")
    }

    func testRemovingAtTheCapFreesASlot() {
        var pick = SmartModePick(selected: ["structured", "notes", "translate.en"])
        pick.toggle("notes")
        XCTAssertEqual(pick.selected, ["structured", "translate.en"])
        pick.toggle("summary")
        XCTAssertEqual(pick.selected, ["structured", "translate.en", "summary"])
    }

    func testTheOrderIsThePickOrder() {
        var pick = SmartModePick()
        pick.toggle("translate.de")
        pick.toggle("message")
        XCTAssertEqual(pick.selected, ["translate.de", "message"])
    }

    func testAnInitialListLongerThanTheCapIsTrimmed() {
        XCTAssertEqual(SmartModePick(selected: ["a", "b", "c", "d"]).selected, ["a", "b", "c"])
    }

    func testTheStepOpensEmptyAndContinueNeedsOneMode() {
        var pick = SmartModePick()
        XCTAssertTrue(pick.selected.isEmpty)
        XCTAssertFalse(pick.canContinue)
        pick.toggle("message")
        XCTAssertTrue(pick.canContinue)
    }

    // MARK: - The write

    func testContinueWritesThePickedModesInPlaceOfTheSeed() {
        XCTAssertEqual(SmartModeStore.pinnedIdentifiers, SmartModeCatalogue.defaultPinnedIdentifiers)

        var pick = SmartModePick()
        pick.toggle("message")
        pick.toggle("summary")
        pick.toggle("translate.de")
        pick.commit()

        XCTAssertEqual(SmartModeStore.pinnedIdentifiers, ["message", "summary", "translate.de"])
        // What the keyboard's fan draws, in that order.
        XCTAssertEqual(SmartModeCatalogue.pinnedModes.map(\.id), ["message", "summary", "translate.de"])
    }

    func testFewerThanThreeIsWrittenAsIs() {
        var pick = SmartModePick()
        pick.toggle("structured")
        pick.commit()
        XCTAssertEqual(SmartModeStore.pinnedIdentifiers, ["structured"])
    }

    func testAnEmptyPickWritesNothingAndKeepsTheSeed() {
        SmartModePick().commit()
        XCTAssertNil(defaults.stringArray(forKey: SharedKeys.smartModePinned))
        XCTAssertEqual(SmartModeStore.pinnedIdentifiers, SmartModeCatalogue.defaultPinnedIdentifiers)
    }

    /// Skip is the step writing nothing at all: the seed is what the fan reads.
    func testSkippingKeepsTheSeed() {
        _ = SmartModePick() // the page builds one and Skip never commits it
        XCTAssertNil(defaults.stringArray(forKey: SharedKeys.smartModePinned))
        XCTAssertEqual(SmartModeCatalogue.pinnedModes.map(\.id), SmartModeCatalogue.defaultPinnedIdentifiers)
    }
}
