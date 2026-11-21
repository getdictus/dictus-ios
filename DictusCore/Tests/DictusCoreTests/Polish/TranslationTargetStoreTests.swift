// DictusCore/Tests/DictusCoreTests/Polish/TranslationTargetStoreTests.swift
// "Other language…": recents, persistence, and the modes it adds (issue #622).
//
// These tests mutate the real App Group suite, so setUp/tearDown remove every key they
// touch, as `SmartModeStoreTests` does.
import XCTest
@testable import DictusCore

final class TranslationTargetStoreTests: XCTestCase {

    private var defaults: UserDefaults { AppGroup.defaults }

    private let keys = [
        SharedKeys.translationTargetsChosen, SharedKeys.smartModePinned, SharedKeys.smartModeArmed,
        SharedKeys.smartModeSkipAnnounced, SharedKeys.voiceNoteMode, SharedKeys.voiceNoteLanguage
    ]

    override func setUp() {
        super.setUp()
        keys.forEach { defaults.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { defaults.removeObject(forKey: $0) }
        super.tearDown()
    }

    private func target(_ code: String) throws -> TranslationTarget {
        try XCTUnwrap(TranslationTarget(code: code))
    }

    // MARK: - Recents

    func testNothingIsChosenByDefault() {
        XCTAssertTrue(TranslationTargetStore.chosen.isEmpty)
        XCTAssertTrue(SmartModeCatalogue.addedTranslateModes.isEmpty)
        XCTAssertEqual(SmartModeCatalogue.all.map(\.id), SmartModeCatalogue.builtIns.map(\.id))
    }

    /// The brief's "recently chosen ones first": the last choice leads, and choosing a
    /// language again moves it to the front rather than adding it twice.
    func testTheMostRecentlyChosenTargetComesFirst() throws {
        TranslationTargetStore.choose(try target("pt"))
        TranslationTargetStore.choose(try target("zh-Hans"))
        XCTAssertEqual(TranslationTargetStore.chosen.map(\.code), ["zh-Hans", "pt"])

        TranslationTargetStore.choose(try target("ja"))
        XCTAssertEqual(TranslationTargetStore.chosen.map(\.code), ["ja", "zh-Hans", "pt"])

        TranslationTargetStore.choose(try target("pt"))
        XCTAssertEqual(TranslationTargetStore.chosen.map(\.code), ["pt", "ja", "zh-Hans"])
    }

    func testTheSheetListsRecentsFirstThenEveryOtherNewTargetByName() throws {
        TranslationTargetStore.choose(try target("pt"))
        TranslationTargetStore.choose(try target("ru"))
        let french = Locale(identifier: "fr")
        let order = TranslationTargetStore.pickerOrder(locale: french)

        XCTAssertEqual(order.recent.map(\.code), ["ru", "pt"])
        XCTAssertEqual(order.others.count, 20)
        XCTAssertFalse(order.others.contains { ["ru", "pt"].contains($0.code) }, "a recent is listed twice")
        XCTAssertFalse((order.recent + order.others).contains { $0.builtIn != nil },
                       "a built-in is offered although it is already a row")
        let names = order.others.map { $0.localizedName(in: french) }
        XCTAssertEqual(names, names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        XCTAssertEqual(order.others.first?.code, "ar", "arabe sorts first in French")
    }

    /// The four are rows already. Writing one would only make the list disagree with
    /// the screen.
    func testABuiltInTargetIsNeverRecorded() {
        TranslationTargetStore.choose(.english)
        XCTAssertTrue(TranslationTargetStore.chosen.isEmpty)
        XCTAssertNil(defaults.stringArray(forKey: SharedKeys.translationTargetsChosen))
    }

    // MARK: - Persistence

    /// What the keyboard, the app after a relaunch and the share extension read is the
    /// App Group value, not anything held in memory: the store has no state of its own.
    func testTheChoiceLivesInTheAppGroupUnderItsKey() throws {
        TranslationTargetStore.choose(try target("pt"))
        TranslationTargetStore.choose(try target("zh-Hant"))
        XCTAssertEqual(defaults.stringArray(forKey: SharedKeys.translationTargetsChosen), ["zh-Hant", "pt"])
        XCTAssertEqual(SharedKeys.translationTargetsChosen, "dictus.translationTargetsChosen",
                       "a renamed key loses every user's languages on update")

        // A value written by another process (the app, before a relaunch) is what a
        // fresh read finds.
        defaults.set(["it", "pt"], forKey: SharedKeys.translationTargetsChosen)
        XCTAssertEqual(TranslationTargetStore.chosen.map(\.code), ["it", "pt"])
        XCTAssertEqual(SmartModeCatalogue.addedTranslateModes.map(\.id), ["translate.it", "translate.pt"])
    }

    /// A downgrade or a corrupted value costs that one entry, and is not rewritten.
    func testAnUnknownOrBuiltInCodeOnDiskIsSkippedNotRewritten() {
        defaults.set(["klingon", "pt", "en", "zh"], forKey: SharedKeys.translationTargetsChosen)
        XCTAssertEqual(TranslationTargetStore.chosen.map(\.code), ["pt"])
        XCTAssertEqual(defaults.stringArray(forKey: SharedKeys.translationTargetsChosen), ["klingon", "pt", "en", "zh"])
    }

    // MARK: - The modes it adds

    func testAChosenTargetIsAModeAfterTheBuiltInsThatPinsAndArms() throws {
        TranslationTargetStore.choose(try target("pt"))
        XCTAssertEqual(SmartModeCatalogue.all.map(\.id), SmartModeCatalogue.builtIns.map(\.id) + ["translate.pt"])

        SmartModeStore.setPinned(["translate.pt", "notes"])
        XCTAssertEqual(SmartModeCatalogue.pinnedModes.map(\.id), ["translate.pt", "notes"],
                       "the keyboard fan reads this list")
        XCTAssertEqual(SmartModeCatalogue.mode(withIdentifier: "translate.pt")?.isPinned, true)

        SmartModeStore.arm(try XCTUnwrap(SmartModeCatalogue.mode(withIdentifier: "translate.pt")))
        XCTAssertEqual(SmartModeStore.armedMode?.id, "translate.pt")
        XCTAssertEqual(SmartModeStore.armedMode?.badge, .text("PT"))
    }

    /// A pinned or armed `translate.<code>` is read in the keyboard's process; it must
    /// resolve there even in the second after the app removed the language.
    func testAnyKnownTargetResolvesEvenWhenItIsNotInTheList() {
        XCTAssertEqual(SmartModeCatalogue.mode(withIdentifier: "translate.th")?.id, "translate.th")
        XCTAssertNil(SmartModeCatalogue.mode(withIdentifier: "translate.klingon"))
    }

    func testRemovingATargetUnpinsAndDisarmsItsMode() throws {
        let portuguese = try target("pt")
        TranslationTargetStore.choose(portuguese)
        TranslationTargetStore.choose(try target("ru"))
        SmartModeStore.setPinned(["notes", "translate.pt"])
        SmartModeStore.arm(SmartModeCatalogue.translate(to: portuguese))

        TranslationTargetStore.remove(portuguese)

        XCTAssertEqual(TranslationTargetStore.chosen.map(\.code), ["ru"])
        XCTAssertEqual(SmartModeStore.pinnedIdentifiers, ["notes"])
        XCTAssertNil(SmartModeStore.armedIdentifier)
    }

    /// Removing a language the user never pinned leaves an untouched seed untouched:
    /// no stored pinned list appears out of nowhere.
    func testRemovingAnUnpinnedTargetDoesNotWriteThePinnedList() throws {
        let portuguese = try target("pt")
        TranslationTargetStore.choose(portuguese)
        TranslationTargetStore.remove(portuguese)
        XCTAssertNil(SmartModeStore.storedPinnedIdentifiers)
    }

    // MARK: - Voice notes

    func testTheVoiceNotePickerOffersTheAddedModesAfterTheBuiltIns() throws {
        TranslationTargetStore.choose(try target("pt"))
        XCTAssertEqual(VoiceNoteSettings.availableModes().map(\.id),
                       SmartModeCatalogue.builtIns.map(\.id) + ["translate.pt"])
    }

    func testAVoiceNoteSetToANewTargetResolvesAndKeepsItsRowAfterRemoval() throws {
        let portuguese = try target("pt")
        TranslationTargetStore.choose(portuguese)
        VoiceNoteSettings(mode: .smartMode("translate.pt")).save()
        let loaded = VoiceNoteSettings.load()
        XCTAssertEqual(loaded.mode.smartMode?.id, "translate.pt")

        TranslationTargetStore.remove(portuguese)
        XCTAssertTrue(VoiceNoteSettings.availableModes(keeping: loaded.mode).contains { $0.id == "translate.pt" },
                      "the picker would show a selection with no row")
        XCTAssertFalse(VoiceNoteSettings.availableModes().contains { $0.id == "translate.pt" })
    }

    // MARK: - Onboarding

    /// The onboarding pick stays on the four: its scene and its chips are written for them.
    func testTheOnboardingPickOffersTheFourBuiltInsOnly() throws {
        TranslationTargetStore.choose(try target("pt"))
        XCTAssertEqual(SmartModePick.translateTargets(spokenLanguage: "fr"), [.english, .spanish, .german])
        XCTAssertFalse(SmartModePick.cardModes.contains { $0.id.hasPrefix("translate.") })
    }
}
