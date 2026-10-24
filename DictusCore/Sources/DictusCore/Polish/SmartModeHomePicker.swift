// DictusCore/Sources/DictusCore/Polish/SmartModeHomePicker.swift
// The armed Smart Mode on the app's home mic, and the picker that changes it (issue #489).
import Foundation

/// What the home screen's mic says about Smart Modes.
///
/// ### Why the app needs this at all
///
/// The armed mode is sticky (#79) and was settable only from the keyboard's fan, while
/// the app's own dictations honour it. A user who armed `→ EN` last week and tapped the
/// home mic got English out of a French dictation with nothing on screen having said
/// so (#489). This is the read side the home screen was missing.
///
/// ### Why it mirrors the keyboard rather than reading the store directly
///
/// It answers the two questions `KeyboardSmartModeState.refresh(status:)` answers for
/// the mic pill, from the same expressions, so the two mics cannot disagree:
///
/// - **Is the surface offered at all?** `SmartModeSurface.fanEntryPoint` over
///   `SmartModeAvailability.current`. `.hidden` means nothing is on sale and nothing is
///   paid (#460): no badge, no picker, no long press.
/// - **What will the next dictation run?** The armed mode when
///   `SmartModeAvailability.forDictation` would honour it, else nothing. That is the
///   pill's `effectiveMode`, the expression `SmartModeStore.resolveArmedMode()` consults,
///   and the only one an indicator may draw: a badge saying EN over a dictation that
///   returns French is the lie #423 removed from the keyboard.
public struct SmartModeHomeMic: Equatable, Sendable {

    /// Whether the home screen offers the Smart Mode surface: the mode chip, the long
    /// press and the accessibility action. False exactly where the keyboard's long press
    /// opens nothing.
    public let isOffered: Bool

    /// The mode the next dictation started from the app will run, or nil for Normal.
    /// What the badge draws and what VoiceOver says.
    public let effectiveMode: SmartMode?

    public init(isOffered: Bool, effectiveMode: SmartMode?) {
        self.isOffered = isOffered
        self.effectiveMode = effectiveMode
    }

    /// Resolve the indicator from the facts that decide it.
    ///
    /// - Parameter armed: `SmartModeStore.armedMode`, the non-mutating read. Drawing a
    ///   surface must never disarm, which is the store's stated contract.
    /// - Parameter armability: `SmartModeAvailability.current`, what the fan opens on.
    /// - Parameter dictation: `SmartModeAvailability.forDictation`, what a dictation
    ///   starting now resolves against.
    /// - Parameter paywallVisible: `PremiumFlags.paywallVisible`.
    public static func resolve(armed: SmartMode?,
                               armability: SmartModeArmability,
                               dictation: SmartModeArmability,
                               paywallVisible: Bool) -> SmartModeHomeMic {
        let entryPoint = SmartModeSurface.fanEntryPoint(
            reason: armability.reason, paywallVisible: paywallVisible
        )
        return SmartModeHomeMic(
            isOffered: entryPoint != .hidden,
            effectiveMode: dictation.isArmable ? armed : nil
        )
    }

    /// The indicator as the App Group says it is right now.
    public static var current: SmartModeHomeMic {
        resolve(
            armed: SmartModeStore.armedMode,
            armability: SmartModeAvailability.current,
            dictation: SmartModeAvailability.forDictation,
            paywallVisible: PremiumFlags.paywallVisible
        )
    }
}

/// What choosing a row of the home picker did.
public enum SmartModeHomeChoice: Equatable, Sendable {

    /// The mode is now armed, in the store the keyboard reads.
    case armed(SmartMode)

    /// Back to Normal.
    case disarmed

    /// The Dictus Pro row: nothing was written, the caller opens the paywall.
    case openPaywall

    /// A mode row that cannot be armed right now. Nothing was written; the picker's
    /// reason line already says why.
    case refused
}

/// The home mic's mode picker: the keyboard's long-press fan, drawn in the app (#489).
///
/// ### Same rows, same order, same gate
///
/// The rows come from `SmartModeFanLayout.entries`, the function the keyboard's fan is
/// built from, over the same pinned list (`SmartModeCatalogue.pinnedModes`, in the
/// user's order). So the picker offers Normal, then the pinned modes, then the Dictus
/// Pro row for a non-subscriber — whatever the fan offers, because it is the fan's own
/// list. The gate, the reason line, the tags and what a row may do are
/// `KeyboardSmartModeState.open()` and `commit()` read as values; see each property.
///
/// ### The one place it departs from the fan
///
/// With nothing pinned and nothing armed the fan refuses to open and the toolbar says
/// "Pick your Smart Modes in Dictus" — the keyboard has no room for anything else. The
/// app is the place that sentence points to, and the user reached this picker from a
/// visible control asking which mode is running. So it opens on `Normal` alone, ticked,
/// with `nothingPinned` set for the line that says why it is alone.
public struct SmartModeHomePicker: Equatable, Sendable {

    /// The rows, Normal first, in the fan's order.
    public let entries: [SmartModeFanEntry]

    /// Whether a mode row may be armed at all. False in the non-subscriber's picker and
    /// whenever the device or the user's switch rules modes out.
    public let modesAreArmable: Bool

    /// Why modes cannot be armed, for the line under the rows, or nil when there is no
    /// line. Nil in the non-subscriber's picker even though modes are refused there: the
    /// Dictus Pro row is the message (#404), as in the fan.
    public let unavailableReason: SmartModeUnavailableReason?

    /// The stored armed mode, or nil for Normal. Drawn as the `Off` tag when it will not
    /// run (#423).
    public let armedIdentifier: String?

    /// The row a dictation started right now would actually run.
    public let effectiveIdentifier: String

    /// Whether the mode rows carry the reverse trial's `PRO` mark (#593).
    public let marksTrialPro: Bool

    /// Whether the rows are `Normal` alone because nothing is pinned or armed. See the
    /// type's doc comment.
    public let nothingPinned: Bool

    /// Whether this is the non-subscriber's picker, derived from the rows so the tag and
    /// the row cannot disagree — the fan's own rule.
    public var offersProUpgrade: Bool { entries.contains(.pro) }

    /// What `entry` carries beside its name. `SmartModeFanLayout.tag`, the fan's rule.
    public func tag(for entry: SmartModeFanEntry) -> SmartModeFanRowTag? {
        SmartModeFanLayout.tag(
            for: entry,
            armedIdentifier: armedIdentifier,
            effectiveIdentifier: effectiveIdentifier,
            modesRequirePro: offersProUpgrade,
            marksTrialPro: marksTrialPro
        )
    }

    /// Whether choosing `entry` would do anything. `SmartModeFanState.canCommitHighlighted`
    /// for one row: Normal and Dictus Pro always, a mode only when modes are armable.
    public func canChoose(_ entry: SmartModeFanEntry) -> Bool {
        switch entry {
        case .normal, .pro: return true
        case .mode: return modesAreArmable
        }
    }

    // Six parameters, past SwiftLint's five: each is a fact the fan reads separately,
    // and none has a default — the #392 rule about entitlement parameters. A struct
    // bundling them would rename the list, not shorten it.

    /// Resolve the picker, or nil when the surface is hidden.
    ///
    /// The inputs are the ones `KeyboardSmartModeState.open()` reads, passed in so the
    /// rule can be tested without a device, a subscription or Apple Intelligence.
    ///
    /// - Parameter pinned: `SmartModeCatalogue.pinnedModes`.
    /// - Parameter armed: `SmartModeStore.armedMode`.
    /// - Parameter armability: `SmartModeAvailability.current`.
    /// - Parameter dictation: `SmartModeAvailability.forDictation`.
    /// - Parameter paywallVisible: `PremiumFlags.paywallVisible`.
    /// - Parameter marksTrialPro: `ProStatusManager.showsTrialProMarks(now:)`.
    public static func resolve(pinned: [SmartMode], // swiftlint:disable:this function_parameter_count
                               armed: SmartMode?,
                               armability: SmartModeArmability,
                               dictation: SmartModeArmability,
                               paywallVisible: Bool,
                               marksTrialPro: Bool) -> SmartModeHomePicker? {
        let entryPoint = SmartModeSurface.fanEntryPoint(
            reason: armability.reason, paywallVisible: paywallVisible
        )
        guard entryPoint != .hidden else { return nil }
        let offersPro = SmartModeSurface.sellsPro(
            reason: armability.reason, paywallVisible: paywallVisible
        )
        let fanEntries = SmartModeFanLayout.entries(
            pinned: pinned, armed: armed, offersProUpgrade: offersPro
        )
        return SmartModeHomePicker(
            entries: fanEntries.isEmpty ? [.normal] : fanEntries,
            modesAreArmable: armability.isArmable,
            unavailableReason: offersPro ? nil : armability.reason,
            armedIdentifier: armed?.id,
            effectiveIdentifier: dictation.isArmable
                ? (armed?.id ?? SmartModeFanEntry.normal.id)
                : SmartModeFanEntry.normal.id,
            marksTrialPro: marksTrialPro,
            nothingPinned: fanEntries.isEmpty
        )
    }

    /// The picker as the App Group says it is right now, or nil when hidden.
    public static func current(now: Date = Date()) -> SmartModeHomePicker? {
        resolve(
            pinned: SmartModeCatalogue.pinnedModes,
            armed: SmartModeStore.armedMode,
            armability: SmartModeAvailability.current,
            dictation: SmartModeAvailability.forDictation,
            paywallVisible: PremiumFlags.paywallVisible,
            marksTrialPro: ProStatusManager.showsTrialProMarks(now: now)
        )
    }

    /// Apply the user's choice of `entry`.
    ///
    /// Writes through `SmartModeStore.arm` and `disarm`, the two calls the keyboard's fan
    /// makes, so arming here and arming there are the same write to the same App Group
    /// key and each side reads the other's choice (#489 acceptance 4).
    ///
    /// Switched over the case rather than over `entry.smartMode`, for the fan's reason:
    /// nil is both Normal and Dictus Pro, and reading it as "disarm" would have the Pro
    /// row silently clear the user's mode on its way to the paywall.
    @discardableResult
    public func choose(_ entry: SmartModeFanEntry) -> SmartModeHomeChoice {
        guard canChoose(entry) else { return .refused }
        switch entry {
        case .pro:
            return .openPaywall
        case .normal:
            SmartModeStore.disarm()
            return .disarmed
        case .mode(let mode):
            SmartModeStore.arm(mode)
            return .armed(mode)
        }
    }
}
