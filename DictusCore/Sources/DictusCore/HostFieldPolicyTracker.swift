// DictusCore/Sources/DictusCore/HostFieldPolicyTracker.swift
// Decides the host field policy (#200) across the readings of one field (#1004).
//
// WHY a tracker and not a fresh `HostFieldPolicy.evaluate` on every reading:
// WhatsApp switches its text view to `autocorrectionType = .no` while the text
// holds an @ mention, and back once the field is empty. Re-reading the traits on
// every text change turned autocorrect off for the rest of the message. Apple's
// keyboard keeps autocorrecting there (checked on device, 2026-11-20), so Dictus
// keeps the policy the field had before the mention.

import Foundation

public struct HostFieldPolicyTracker {

    /// The `documentIdentifier` the readings belong to.
    private var document: String?
    /// The last reading the tracker honoured in this document; the focus reading
    /// until the field changes its traits for a reason other than a mention.
    private var baseline: HostFieldTraits?
    /// A mention made the host turn autocorrection off, and the tracker ignores it
    /// until the host turns it back on or the document changes. Held so the policy
    /// survives the mention scrolling out of the proxy's context window.
    private var heldForMention = false

    public init() {}

    /// The keyboard appeared: the next reading is the field's focus reading.
    public mutating func fieldFocused() {
        baseline = nil
        heldForMention = false
    }

    /// The policy for one reading of the field.
    ///
    /// - Parameters:
    ///   - document: the proxy's `documentIdentifier`, nil when the host gives none.
    ///   - text: what the proxy shows around the caret, before and after it. Read
    ///     only when the reading could be a mention's, not on every keystroke.
    public mutating func policy(
        for traits: HostFieldTraits,
        document: String?,
        text: @autoclosure () -> String
    ) -> HostFieldPolicy {
        if document != self.document {
            self.document = document
            fieldFocused()
        }
        guard let baseline else {
            self.baseline = traits
            return HostFieldPolicy.evaluate(traits)
        }
        if Self.isMentionDowngrade(from: baseline, to: traits),
           heldForMention || HostMention.isPresent(in: text()) {
            heldForMention = true
            let kept = HostFieldPolicy.evaluate(baseline)
            return HostFieldPolicy(
                autocorrectAllowed: kept.autocorrectAllowed,
                suggestionsAllowed: kept.suggestionsAllowed,
                reason: "\(kept.reason) (autocorrectionType.no after a mention, ignored)"
            )
        }
        heldForMention = false
        self.baseline = traits
        return HostFieldPolicy.evaluate(traits)
    }

    /// The field turned autocorrection off mid-field and changed nothing that
    /// marks it as a token or secure field. Spell checking may switch off with it:
    /// the device log only shows the first rule that matched.
    static func isMentionDowngrade(from baseline: HostFieldTraits, to reading: HostFieldTraits) -> Bool {
        guard !baseline.autocorrectionDisabled, reading.autocorrectionDisabled else { return false }
        guard !reading.isSecureEntry else { return false }
        return reading.keyboard == baseline.keyboard && reading.content == baseline.content
    }
}

/// An @ mention as messaging apps insert it: WhatsApp writes `@⁨Kevin LAGE⁩`, the
/// name wrapped in FIRST STRONG ISOLATE (U+2068) and POP DIRECTIONAL ISOLATE
/// (U+2069). The isolate is accepted on either side of the `@`.
enum HostMention {
    private static let isolateStart: Unicode.Scalar = "\u{2068}"
    private static let isolateEnd: Unicode.Scalar = "\u{2069}"
    private static let at: Unicode.Scalar = "@"

    static func isPresent(in text: String) -> Bool {
        let scalars = Array(text.unicodeScalars)
        for (index, scalar) in scalars.enumerated() where scalar == isolateStart {
            let atBefore = index > 0 && scalars[index - 1] == at
            let atAfter = index + 1 < scalars.count && scalars[index + 1] == at
            guard atBefore || atAfter else { continue }
            let nameStart = index + (atAfter ? 2 : 1)
            guard nameStart < scalars.count,
                  let end = scalars[nameStart...].firstIndex(of: isolateEnd),
                  end > nameStart
            else { continue }
            return true
        }
        return false
    }
}
