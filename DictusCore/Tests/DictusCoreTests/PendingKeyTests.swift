// DictusCore/Tests/DictusCoreTests/PendingKeyTests.swift
// The pending key belongs to the finger that pressed it (#1089).
import XCTest
@testable import DictusCore

final class PendingKeyTests: XCTestCase {

    /// The keyboard's touch handling around `PendingKey`, as `GiellaKeyboardView` runs it:
    /// a finger landing types the key pending before it and presses its own; a move goes
    /// through `moved`; a lift types the key when `isTyped(byLifting:)` says so.
    private struct Typist {
        var pending: PendingKey<Int, Character>?
        var text = ""

        mutating func down(_ finger: Int, on key: Character) {
            if let pending { text.append(pending.key) }
            pending = PendingKey(key: key, finger: finger)
        }

        mutating func move(_ finger: Int, onto key: Character?) {
            pending = pending?.moved(finger, onto: key)
        }

        mutating func up(_ finger: Int) {
            guard let pending, pending.isTyped(byLifting: [finger]) else { return }
            text.append(pending.key)
            self.pending = nil
        }
    }

    // MARK: - Two thumbs

    /// The #1089 case: the right thumb lands on r while the left is still on e, and the left
    /// thumb trembles 1 pt, still on e, before it lifts. It used to type « ee ».
    func testATremorOfTheFirstThumbDoesNotTypeItsLetterAgain() {
        var typist = Typist()
        typist.down(1, on: "e")
        typist.down(2, on: "r")
        typist.move(1, onto: "e")
        typist.up(1)
        typist.up(2)
        XCTAssertEqual(typist.text, "er")
    }

    func testOverlappingRollsTypeEachLetterOnce() {
        for (first, second) in [("e", "r"), ("r", "e"), ("t", "e")] as [(Character, Character)] {
            var typist = Typist()
            typist.down(1, on: first)
            typist.down(2, on: second)
            typist.move(1, onto: first)
            typist.move(1, onto: first)
            typist.up(1)
            typist.move(2, onto: second)
            typist.up(2)
            XCTAssertEqual(typist.text, String([first, second]))
        }
    }

    /// The first thumb sliding onto another key while the second is pressed changes nothing:
    /// its own key was typed when the second landed.
    func testAnotherFingerMovingNeverRetargetsThePendingKey() {
        var typist = Typist()
        typist.down(1, on: "e")
        typist.down(2, on: "r")
        typist.move(1, onto: "t")
        typist.move(1, onto: nil)
        typist.up(1)
        typist.up(2)
        XCTAssertEqual(typist.text, "er")
    }

    /// The first thumb lifting leaves the second's key pending, and the second's lift types it.
    func testAnotherFingerLiftingLeavesThePendingKey() {
        var typist = Typist()
        typist.down(1, on: "e")
        typist.down(2, on: "r")
        typist.up(1)
        XCTAssertEqual(typist.text, "e")
        XCTAssertEqual(typist.pending?.key, "r")
        typist.up(2)
        XCTAssertEqual(typist.text, "er")
    }

    func testThreeOverlappingFingersTypeInOrder() {
        var typist = Typist()
        typist.down(1, on: "t")
        typist.down(2, on: "r")
        typist.move(1, onto: "t")
        typist.down(3, on: "e")
        typist.move(2, onto: "r")
        typist.up(1)
        typist.up(2)
        typist.up(3)
        XCTAssertEqual(typist.text, "tre")
    }

    // MARK: - One finger, as before

    /// A finger that slides across keys types the key it lifts on.
    func testASingleFingerSlideTypesTheKeyItLiftsOn() {
        var typist = Typist()
        typist.down(1, on: "e")
        typist.move(1, onto: "r")
        typist.move(1, onto: "t")
        typist.up(1)
        XCTAssertEqual(typist.text, "t")
    }

    /// Slid off every key, the touch types nothing, even back on a key: the pending key
    /// is dropped, as before.
    func testASingleFingerSlidOffTheKeysTypesNothing() {
        var typist = Typist()
        typist.down(1, on: "e")
        typist.move(1, onto: nil)
        typist.move(1, onto: "r")
        typist.up(1)
        XCTAssertEqual(typist.text, "")
    }

    func testTapsOneAfterAnotherTypeEachKey() {
        var typist = Typist()
        for (finger, key) in zip(1..., "bonjour") {
            typist.down(finger, on: key)
            typist.move(finger, onto: key)
            typist.up(finger)
        }
        XCTAssertEqual(typist.text, "bonjour")
    }

    // MARK: - The rule itself

    func testOwnFingerIsFoundOnlyAmongTheFingersGiven() {
        let pending = PendingKey(key: "e", finger: 7)
        XCTAssertEqual(pending.ownFinger(among: [3, 7]), 7)
        XCTAssertNil(pending.ownFinger(among: [3, 4]))
        XCTAssertTrue(pending.isTyped(byLifting: [7]))
        XCTAssertFalse(pending.isTyped(byLifting: [3]))
    }
}
