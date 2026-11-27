// DictusCore/Sources/DictusCore/PendingKey.swift
// A key waiting to be typed belongs to the finger that pressed it (#1089).
import Foundation

/// The key a finger is pressing, typed when that finger lifts.
///
/// A letter is typed on touch-up, so between touch-down and touch-up the keyboard holds
/// one pending key. Until #1089 it did not remember whose it was: any finger that moved
/// moved it onto the key under that finger, and any finger that lifted typed it. With two
/// thumbs overlapping, the second thumb's key became the pending one; a 1 pt tremor of the
/// first thumb, still on its own key, moved the pending key back under it, and the first
/// thumb's lift typed that key again: « ee » for « er ».
///
/// Now the pending key keeps the finger that owns it. Only that finger moves it or types
/// it; another finger's move or lift leaves it alone. A finger landing still types the
/// key pending before it, whoever's, as before.
///
/// Generic over the finger (`UITouch` in the keyboard, plain values in the tests) and the
/// key, so the rule runs on the Mac.
public struct PendingKey<Finger: Equatable, Key> {
    /// The key under the finger now.
    public let key: Key
    /// The finger that pressed it.
    public let finger: Finger

    public init(key: Key, finger: Finger) {
        self.key = key
        self.finger = finger
    }

    /// The pending key after `finger` moved onto `key` (nil: onto no key, which drops it,
    /// as before). Only its own finger moves it; another finger's move changes nothing.
    public func moved(_ finger: Finger, onto key: Key?) -> PendingKey? {
        guard finger == self.finger else { return self }
        return key.map { PendingKey(key: $0, finger: finger) }
    }

    /// Whether lifting `fingers` types the pending key: only when its own finger is one
    /// of them. Another finger lifting leaves it pending.
    public func isTyped<Fingers: Sequence>(byLifting fingers: Fingers) -> Bool where Fingers.Element == Finger {
        fingers.contains(finger)
    }

    /// The one finger among `fingers` that may move the pending key, if it is there.
    public func ownFinger<Fingers: Sequence>(among fingers: Fingers) -> Finger? where Fingers.Element == Finger {
        fingers.first { $0 == finger }
    }
}
