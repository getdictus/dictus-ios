// DictusCore/Sources/DictusCore/Polish/SmartModePick.swift
// The onboarding's "pick your three Smart Modes" step, as rules (#677, #649 decision 16).
import Foundation

/// What the user has picked on the onboarding's Smart Mode step, and what it may offer.
///
/// The keyboard's long-press fan holds `SmartModeCatalogue.maximumPinnedModes` modes and
/// the catalogue has more, so the onboarding asks which ones. The choice **replaces** the
/// seed (`defaultPinnedIdentifiers`) in the pinned list; skipping the step writes nothing,
/// so the seed stays.
///
/// WHY IN DICTUSCORE: the offer (which translation targets), the cap and the write are
/// rules, and the app target has no test bundle. The page in DictusApp only draws this
/// value and forwards taps to it.
public struct SmartModePick: Equatable, Sendable {

    /// The modes offered as one large card each: the structure and register modes, in
    /// catalogue order (Structured, List, Message, Summary).
    ///
    /// Read from `builtIns` rather than listed by identifier, so a mode added to that axis
    /// later appears here by existing. Translation modes are offered separately, as chips
    /// (`translateTargets`).
    public static var cardModes: [SmartMode] {
        SmartModeCatalogue.builtIns.filter { !isTranslate($0.id) }
    }

    /// The translation targets offered: the four `SupportedLanguage` targets the catalogue
    /// ships, minus the language the user said they speak on the language screen.
    ///
    /// WHY THAT ONE GOES (decision 16): translating French into French is not a mode. The
    /// catalogue itself keeps every target, because outside onboarding the spoken
    /// language is not known until the user speaks; here it is, the user just declared it.
    ///
    /// - Parameter spokenLanguage: `SharedKeys.spokenLanguage`, a `SpokenLanguage` code.
    ///   A language Dictus has no keyboard for (Chinese) or nil removes nothing: all four
    ///   targets are a real translation from it.
    public static func translateTargets(spokenLanguage: String?) -> [SupportedLanguage] {
        let spoken = spokenLanguage.flatMap(SupportedLanguage.init(rawValue:))
        return SupportedLanguage.allCases.filter { $0 != spoken }
    }

    /// The most modes the pick can hold: what the fan can draw.
    public static let maximum = SmartModeCatalogue.maximumPinnedModes

    /// The picked identifiers, in the order they were picked.
    ///
    /// WHY THAT ORDER: the fan draws the pinned list in its stored order
    /// (`SmartModeCatalogue.pinnedModes`), nearest the thumb first, and the first mode a
    /// user picks is the one they want most.
    public private(set) var selected: [String]

    /// An empty pick: the step opens with nothing chosen, so the counter starts at 0 and
    /// every mode in the fan is one the user asked for.
    public init(selected: [String] = []) {
        self.selected = Array(selected.prefix(Self.maximum))
    }

    /// Whether `identifier` is picked.
    public func isSelected(_ identifier: String) -> Bool {
        selected.contains(identifier)
    }

    /// Whether the pick is at the cap.
    public var isFull: Bool {
        selected.count >= Self.maximum
    }

    /// Whether tapping `identifier` would change anything: always for a picked mode (it
    /// is removed), and for another one only below the cap.
    ///
    /// WHY A TAP AT THE CAP DOES NOTHING rather than replacing the oldest pick: a mode
    /// that silently leaves the selection is a choice the user did not make. The page dims
    /// what cannot be added, and the user removes one first, like the app's mode list.
    public func canToggle(_ identifier: String) -> Bool {
        isSelected(identifier) || !isFull
    }

    /// Picks `identifier`, or removes it when it is already picked. A pick past the cap
    /// is ignored (`canToggle`).
    public mutating func toggle(_ identifier: String) {
        if let index = selected.firstIndex(of: identifier) {
            selected.remove(at: index)
        } else if !isFull {
            selected.append(identifier)
        }
    }

    /// Whether Continue may write the pick: at least one mode.
    ///
    /// WHY NOT ZERO: an empty stored list is a real choice to `SmartModeStore` (a fan with
    /// Normal alone), and a user who tapped Continue without reading would get exactly
    /// that. The step's Skip is the way past it without choosing, and it keeps the seed.
    public var canContinue: Bool {
        !selected.isEmpty
    }

    /// Writes the pick to the pinned list, replacing the seed or any earlier list.
    /// Nothing is written while `canContinue` is false.
    public func commit() {
        guard canContinue else { return }
        SmartModeStore.setPinned(selected)
    }

    private static func isTranslate(_ identifier: String) -> Bool {
        SupportedLanguage.allCases.contains { SmartModeCatalogue.translateIdentifier(target: $0) == identifier }
    }
}
