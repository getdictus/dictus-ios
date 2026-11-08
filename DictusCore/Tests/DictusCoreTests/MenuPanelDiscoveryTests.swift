// DictusCore/Tests/DictusCoreTests/MenuPanelDiscoveryTests.swift
// When the toolbar teaches the long press on ☰ that opens the keyboard panel (#639).
//
// These tests mutate the real App Group suite, so setUp/tearDown remove the keys.
import XCTest
@testable import DictusCore

final class MenuPanelDiscoveryTests: XCTestCase {

    private var defaults: UserDefaults { AppGroup.defaults }

    override func setUp() {
        super.setUp()
        clear()
    }

    override func tearDown() {
        clear()
        super.tearDown()
    }

    private func clear() {
        defaults.removeObject(forKey: SharedKeys.voiceNoteReaderOpenedByTap)
        defaults.removeObject(forKey: SharedKeys.menuLongPressUsed)
    }

    /// Nobody has met the new tap yet: nothing to explain.
    func testNoHintBeforeTheReaderWasEverOpenedByATap() {
        XCTAssertFalse(MenuPanelDiscovery.offersHint(readerOpenedByTap: false, longPressUsed: false))
    }

    func testTheHintIsOfferedOnceTheReaderWasOpenedByATap() {
        XCTAssertTrue(MenuPanelDiscovery.offersHint(readerOpenedByTap: true, longPressUsed: false))
    }

    func testTheHintRetiresAtTheFirstLongPress() {
        XCTAssertFalse(MenuPanelDiscovery.offersHint(readerOpenedByTap: true, longPressUsed: true))
        // A long press before any tap retires it in advance too.
        XCTAssertFalse(MenuPanelDiscovery.offersHint(readerOpenedByTap: false, longPressUsed: true))
    }

    /// Both flags persist in the App Group, set once and never cleared.
    func testBothFlagsAreRememberedAndIdempotent() {
        XCTAssertFalse(MenuPanelDiscovery.hasOpenedReaderByTap)
        XCTAssertFalse(MenuPanelDiscovery.hasUsedLongPress)
        MenuPanelDiscovery.noteReaderOpenedByTap()
        MenuPanelDiscovery.noteReaderOpenedByTap()
        XCTAssertTrue(MenuPanelDiscovery.hasOpenedReaderByTap)
        XCTAssertFalse(MenuPanelDiscovery.hasUsedLongPress)
        MenuPanelDiscovery.noteLongPressUsed()
        MenuPanelDiscovery.noteLongPressUsed()
        XCTAssertTrue(defaults.bool(forKey: SharedKeys.menuLongPressUsed))
        XCTAssertTrue(defaults.bool(forKey: SharedKeys.voiceNoteReaderOpenedByTap))
    }
}
