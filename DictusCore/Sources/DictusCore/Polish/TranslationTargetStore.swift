// DictusCore/Sources/DictusCore/Polish/TranslationTargetStore.swift
// The Translate targets the user added through "Other language…" (issue #622).
import Foundation

/// The translation targets beyond the four built-ins that the user chose, in the App
/// Group, most recently chosen first.
///
/// ### One list for two jobs, on purpose
///
/// The list is both **which `translate.<code>` modes exist** for this user and **the
/// picker's recent order**. Option B (#622, approved 2026-11-21) adds a mode per chosen
/// language rather than a target switch, so a language the user chose *is* a row they
/// can pin, and the rows they added are their recent targets. Two lists — recents and
/// added modes — would be able to disagree about a language the user removed, and
/// nothing would be gained from the disagreement.
///
/// ### Why the App Group
///
/// The keyboard's fan resolves pinned identifiers through
/// `SmartModeCatalogue.mode(withIdentifier:)`, in the keyboard's process. That
/// resolution does not need this list (any known target resolves), but the app's mode
/// list, the voice note picker and the onboarding pick read it, and the share
/// extension may one day. Every Smart Mode setting lives here for that reason.
///
/// ### Why DictusCore
///
/// The order rule and the persistence are rules, and the app target has no test
/// bundle. The sheet in DictusApp draws `pickerOrder` and calls `choose` and `remove`.
public enum TranslationTargetStore {

    private static var defaults: UserDefaults { AppGroup.defaults }

    /// The chosen targets, most recently chosen first.
    ///
    /// A code this build does not know is dropped on read, never rewritten: a
    /// downgrade costs the one language it cannot resolve and the next upgrade gets it
    /// back. A built-in code is dropped too: the four are rows of their own already,
    /// and `choose` never writes one.
    public static var chosen: [TranslationTarget] {
        let codes = defaults.stringArray(forKey: SharedKeys.translationTargetsChosen) ?? []
        return codes.compactMap { code in
            TranslationTarget(code: code).flatMap { $0.builtIn == nil ? $0 : nil }
        }
    }

    /// Record that the user chose `target`: it moves to the front, or enters there.
    ///
    /// Choosing a language already in the list does not duplicate it, it only makes it
    /// the most recent — which is what "recently chosen first" means. A built-in target
    /// is ignored: `translate.en` is in the catalogue whatever this list says, so
    /// writing it would only make the list disagree with what the screen shows.
    public static func choose(_ target: TranslationTarget) {
        guard target.builtIn == nil else { return }
        var codes = chosen.map(\.code)
        codes.removeAll { $0 == target.code }
        codes.insert(target.code, at: 0)
        defaults.set(codes, forKey: SharedKeys.translationTargetsChosen)
        defaults.synchronize()
    }

    /// Remove `target`'s mode: out of the list, and out of the keyboard's fan if it was
    /// pinned there, so the fan never holds a row the mode list no longer shows. If it
    /// was the armed mode it is disarmed for the same reason.
    public static func remove(_ target: TranslationTarget) {
        let codes = chosen.map(\.code).filter { $0 != target.code }
        defaults.set(codes, forKey: SharedKeys.translationTargetsChosen)
        let identifier = SmartModeCatalogue.translateIdentifier(target: target)
        let pinned = SmartModeStore.pinnedIdentifiers
        if pinned.contains(identifier) {
            SmartModeStore.setPinned(pinned.filter { $0 != identifier })
        }
        if SmartModeStore.armedIdentifier == identifier {
            SmartModeStore.disarm()
        }
        defaults.synchronize()
    }

    /// What the "Other language…" sheet lists, in its order: the chosen targets, most
    /// recent first, then every other target the user could add, by name in `locale`.
    ///
    /// The four built-ins are absent: they are rows of the mode list already, and
    /// listing them here would offer a choice that changes nothing.
    public static func pickerOrder(locale: Locale = .current) -> (recent: [TranslationTarget], others: [TranslationTarget]) {
        let recent = chosen
        let recentCodes = Set(recent.map(\.code))
        let others = TranslationTarget.additional
            .filter { !recentCodes.contains($0.code) }
            .sorted {
                $0.localizedName(in: locale).localizedStandardCompare($1.localizedName(in: locale)) == .orderedAscending
            }
        return (recent, others)
    }
}
