// DictusCore/Tests/DictusCoreTests/ProFeatureSwitchesTests.swift
// The one owner of the Pro feature switches (#216): a write publishes to every
// observer and lands in the key the keyboard reads.
import XCTest
import Combine
@testable import DictusCore

@MainActor
final class ProFeatureSwitchesTests: XCTestCase {

    private var suiteNames: [String] = []

    private func makeSuite() -> String {
        let name = "dictus.tests.proFeatureSwitches.\(UUID().uuidString)"
        suiteNames.append(name)
        return name
    }

    private func defaults(_ name: String) -> UserDefaults {
        // swiftlint:disable:next force_unwrapping
        UserDefaults(suiteName: name)!  // A fresh, non-App-Group suite name is always valid.
    }

    override func tearDown() {
        suiteNames.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) }
        suiteNames = []
        super.tearDown()
    }

    func testAnUnwrittenSwitchReadsAsOn() {
        let switches = ProFeatureSwitches(defaults: defaults(makeSuite()))
        for feature in ProFeature.allCases {
            XCTAssertTrue(switches.isOn(feature), "\(feature) should default to on, as the seeding does")
        }
    }

    func testItReadsWhatIsStored() {
        let suite = makeSuite()
        defaults(suite).set(false, forKey: ProFeature.vocabulary.settingsKey)
        let switches = ProFeatureSwitches(defaults: defaults(suite))
        XCTAssertFalse(switches.isOn(.vocabulary))
        XCTAssertTrue(switches.isOn(.smartMode))
    }

    /// The bug #216's device test found: the screen that flips a switch and the hub
    /// row that shows it must redraw together. Both observe this one object, so one
    /// publication reaches both.
    func testASetPublishesToEveryObserver() {
        let switches = ProFeatureSwitches(defaults: defaults(makeSuite()))
        var hubRowRedraws = 0
        var pushedScreenRedraws = 0
        let hubRow = switches.objectWillChange.sink { hubRowRedraws += 1 }
        let pushedScreen = switches.objectWillChange.sink { pushedScreenRedraws += 1 }

        switches.set(.smartMode, isOn: false)

        XCTAssertEqual(hubRowRedraws, 1)
        XCTAssertEqual(pushedScreenRedraws, 1)
        XCTAssertFalse(switches.isOn(.smartMode))
        hubRow.cancel()
        pushedScreen.cancel()
    }

    /// The keyboard extension never builds this object: it reads the key through its
    /// own `UserDefaults` instance (`FeatureGate.isEnabled`). The write has to land there.
    func testASetLandsInTheKeyAnotherInstanceReads() {
        let suite = makeSuite()
        let switches = ProFeatureSwitches(defaults: defaults(suite))

        switches.set(.history, isOn: false)
        XCTAssertEqual(defaults(suite).object(forKey: ProFeature.history.settingsKey) as? Bool, false)

        switches.set(.history, isOn: true)
        XCTAssertEqual(defaults(suite).object(forKey: ProFeature.history.settingsKey) as? Bool, true)
    }

    func testReloadPicksUpAWriteMadeElsewhere() {
        let suite = makeSuite()
        let switches = ProFeatureSwitches(defaults: defaults(suite))
        defaults(suite).set(false, forKey: ProFeature.smartMode.settingsKey)
        switches.reload()
        XCTAssertFalse(switches.isOn(.smartMode))
    }
}

extension ProFeatureSwitchesTests {
    func testOnCountFollowsTheSwitches() {
        let switches = ProFeatureSwitches(defaults: defaults(makeSuite()))
        XCTAssertEqual(switches.onCount, ProFeature.allCases.count)
        switches.set(.vocabulary, isOn: false)
        switches.set(.history, isOn: false)
        XCTAssertEqual(switches.onCount, ProFeature.allCases.count - 2)
    }
}
