// DictusCore/Tests/DictusCoreTests/Polish/SmartModeHomePickerTests.swift
// The armed Smart Mode on the app's home mic, and the picker that changes it (issue #489).
//
// The `choose` tests mutate the real App Group suite, so setUp/tearDown remove the keys,
// as `SmartModeStoreTests` does.
import XCTest
@testable import DictusCore

final class SmartModeHomePickerTests: XCTestCase {

    private var defaults: UserDefaults { AppGroup.defaults }

    private let keys = [
        SharedKeys.smartModeArmed, SharedKeys.smartModePinned, SharedKeys.smartModeSkipAnnounced
    ]

    override func setUp() {
        super.setUp()
        keys.forEach { defaults.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { defaults.removeObject(forKey: $0) }
        super.tearDown()
    }

    // MARK: - Fixtures

    private func mode(_ identifier: String) throws -> SmartMode {
        try XCTUnwrap(SmartModeCatalogue.mode(withIdentifier: identifier))
    }

    private var english: String { SmartModeCatalogue.translateIdentifier(target: .english) }
    private var german: String { SmartModeCatalogue.translateIdentifier(target: .german) }

    private func picker(pinned: [SmartMode],
                        armed: SmartMode? = nil,
                        armability: SmartModeArmability = .armable,
                        dictation: SmartModeArmability? = nil,
                        paywallVisible: Bool = true,
                        marksTrialPro: Bool = false) -> SmartModeHomePicker? {
        SmartModeHomePicker.resolve(
            pinned: pinned,
            armed: armed,
            armability: armability,
            dictation: dictation ?? armability,
            paywallVisible: paywallVisible,
            marksTrialPro: marksTrialPro
        )
    }

    // MARK: - Same rows, same order as the keyboard fan

    /// The acceptance the issue is built on: the picker is the fan, in the app. Same
    /// function, same inputs, same rows in the user's pinned order.
    func testASubscriberGetsTheFanRowsInThePinnedOrder() throws {
        let pinned = [try mode(german), try mode(SmartModeCatalogue.notesIdentifier)]
        let result = try XCTUnwrap(picker(pinned: pinned))

        XCTAssertEqual(result.entries, SmartModeFanLayout.entries(pinned: pinned, armed: nil))
        XCTAssertEqual(result.entries.map(\.id), ["normal", german, SmartModeCatalogue.notesIdentifier])
        XCTAssertTrue(result.modesAreArmable)
        XCTAssertNil(result.unavailableReason)
        XCTAssertFalse(result.offersProUpgrade)
    }

    func testTheArmedModeIsTheTickedRow() throws {
        let translate = try mode(english)
        let result = try XCTUnwrap(picker(pinned: [translate], armed: translate))

        XCTAssertEqual(result.tag(for: .mode(translate)), .effective)
        XCTAssertNil(result.tag(for: .normal))
    }

    func testNormalIsTickedWhenNothingIsArmed() throws {
        let result = try XCTUnwrap(picker(pinned: [try mode(english)]))
        XCTAssertEqual(result.tag(for: .normal), .effective)
    }

    // MARK: - The Pro gate, as the keyboard applies it

    /// The non-subscriber's fan (#404): Normal, the default modes greyed, Dictus Pro last,
    /// and no reason line because the Pro row is the message.
    func testANonSubscriberGetsTheUpgradeFan() throws {
        let result = try XCTUnwrap(picker(
            pinned: [try mode(german)], armability: .unavailable(.notSubscribed)
        ))

        XCTAssertEqual(
            result.entries,
            SmartModeFanLayout.entries(pinned: [try mode(german)], armed: nil, offersProUpgrade: true)
        )
        XCTAssertEqual(result.entries.last, .pro)
        XCTAssertTrue(result.offersProUpgrade)
        XCTAssertFalse(result.modesAreArmable)
        XCTAssertNil(result.unavailableReason)
        XCTAssertEqual(result.tag(for: .normal), .effective)
    }

    /// While nothing is on sale the surface is absent, not locked (#460): no picker, no
    /// chip, no badge, exactly where the keyboard's long press opens nothing.
    func testNothingIsOfferedWhileNothingIsOnSale() throws {
        let translate = try mode(english)
        XCTAssertNil(picker(
            pinned: [translate], armed: translate,
            armability: .unavailable(.notSubscribed), paywallVisible: false
        ))

        let mic = SmartModeHomeMic.resolve(
            armed: translate,
            armability: .unavailable(.notSubscribed),
            dictation: .unavailable(.notSubscribed),
            paywallVisible: false
        )
        XCTAssertFalse(mic.isOffered)
        XCTAssertNil(mic.effectiveMode)
    }

    /// A subscriber who switched Smart Modes off is not sold anything (#423): the picker
    /// opens, says why, and marks the armed mode `Off` rather than ticking it.
    func testASwitchedOffSubscriberSeesTheReasonAndTheOffTag() throws {
        let translate = try mode(english)
        let result = try XCTUnwrap(picker(
            pinned: [translate], armed: translate, armability: .unavailable(.switchedOff)
        ))

        XCTAssertFalse(result.offersProUpgrade)
        XCTAssertFalse(result.modesAreArmable)
        XCTAssertEqual(result.unavailableReason, .switchedOff)
        XCTAssertEqual(result.tag(for: .mode(translate)), .inactive)
        XCTAssertEqual(result.tag(for: .normal), .effective)
    }

    /// During the reverse trial the mode rows carry `PRO`, and the ticked row keeps its
    /// tick: the fan's precedence (#593).
    func testTheTrialMarksModeRowsButNotTheTickedOne() throws {
        let notes = try mode(SmartModeCatalogue.notesIdentifier)
        let translate = try mode(english)
        let result = try XCTUnwrap(picker(pinned: [notes, translate], armed: notes, marksTrialPro: true))

        XCTAssertEqual(result.tag(for: .mode(notes)), .effective)
        XCTAssertEqual(result.tag(for: .mode(translate)), .pro)
        XCTAssertNil(result.tag(for: .normal))
    }

    // MARK: - The indicator says what will run

    func testTheIndicatorShowsTheArmedModeWhenItWillRun() throws {
        let translate = try mode(english)
        let mic = SmartModeHomeMic.resolve(
            armed: translate, armability: .armable, dictation: .armable, paywallVisible: true
        )
        XCTAssertTrue(mic.isOffered)
        XCTAssertEqual(mic.effectiveMode, translate)
        // The badge is the keyboard pill's: the target's code, not a globe.
        XCTAssertEqual(mic.effectiveMode?.badge, .text("EN"))
    }

    /// The badge is an assertion about the next dictation (#423). A mode that will not
    /// run is not drawn, even though it is still armed.
    func testTheIndicatorShowsNormalWhenTheArmedModeWillNotRun() throws {
        let translate = try mode(english)
        let mic = SmartModeHomeMic.resolve(
            armed: translate,
            armability: .unavailable(.appleIntelligenceNotEnabled),
            dictation: .unavailable(.appleIntelligenceNotEnabled),
            paywallVisible: true
        )
        XCTAssertTrue(mic.isOffered)
        XCTAssertNil(mic.effectiveMode)
    }

    // MARK: - Nothing pinned

    func testNothingPinnedAndNothingArmedOpensOnNormalAlone() throws {
        let result = try XCTUnwrap(picker(pinned: []))
        XCTAssertEqual(result.entries, [.normal])
        XCTAssertTrue(result.nothingPinned)
        XCTAssertEqual(result.tag(for: .normal), .effective)
    }

    /// With a mode armed, Normal is the row that clears it (#402), and that is the fan's
    /// own answer, not the "nothing pinned" one.
    func testNothingPinnedButAModeArmedIsTheFansOwnNormalRow() throws {
        let translate = try mode(english)
        let result = try XCTUnwrap(picker(pinned: [], armed: translate))
        XCTAssertEqual(result.entries, [.normal])
        XCTAssertFalse(result.nothingPinned)
    }

    // MARK: - Choosing writes the state the keyboard reads

    func testChoosingAModeArmsItInTheSharedStore() throws {
        let translate = try mode(english)
        let result = try XCTUnwrap(picker(pinned: [translate]))

        XCTAssertEqual(result.choose(.mode(translate)), .armed(translate))
        XCTAssertEqual(defaults.string(forKey: SharedKeys.smartModeArmed), english)
        XCTAssertEqual(SmartModeStore.armedMode, translate)
    }

    func testChoosingNormalDisarms() throws {
        let translate = try mode(english)
        SmartModeStore.arm(translate)
        let result = try XCTUnwrap(picker(pinned: [translate], armed: translate))

        XCTAssertEqual(result.choose(.normal), .disarmed)
        XCTAssertNil(SmartModeStore.armedIdentifier)
    }

    /// The reverse direction of acceptance 4: a mode armed the way the keyboard arms it
    /// is what the app's indicator and picker read.
    func testAModeArmedByTheKeyboardIsWhatTheAppReads() throws {
        let translate = try mode(english)
        SmartModeStore.arm(translate)

        let result = try XCTUnwrap(SmartModeHomePicker.resolve(
            pinned: [translate],
            armed: SmartModeStore.armedMode,
            armability: .armable,
            dictation: .armable,
            paywallVisible: true,
            marksTrialPro: false
        ))
        XCTAssertEqual(result.armedIdentifier, english)
        XCTAssertEqual(result.tag(for: .mode(translate)), .effective)
    }

    func testARefusedModeWritesNothing() throws {
        let translate = try mode(english)
        let result = try XCTUnwrap(picker(pinned: [translate], armability: .unavailable(.modelNotReady)))

        XCTAssertEqual(result.choose(.mode(translate)), .refused)
        XCTAssertNil(SmartModeStore.armedIdentifier)
    }

    /// The Pro row must not clear the user's mode on its way to the paywall.
    func testTheProRowLeavesTheArmedModeAlone() throws {
        let translate = try mode(english)
        SmartModeStore.arm(translate)
        let result = try XCTUnwrap(picker(
            pinned: [translate], armed: translate, armability: .unavailable(.notSubscribed)
        ))

        XCTAssertEqual(result.choose(.pro), .openPaywall)
        XCTAssertEqual(SmartModeStore.armedIdentifier, english)
    }

    func testNormalIsAlwaysChoosable() throws {
        let result = try XCTUnwrap(picker(
            pinned: [try mode(english)], armability: .unavailable(.deviceNotEligible)
        ))
        XCTAssertTrue(result.canChoose(.normal))
        XCTAssertFalse(result.canChoose(.mode(try mode(english))))
    }
}
