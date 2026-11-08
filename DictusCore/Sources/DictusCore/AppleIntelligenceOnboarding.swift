// DictusCore/Sources/DictusCore/AppleIntelligenceOnboarding.swift
// Whether the onboarding shows its Apple Intelligence step (#683, #649 decision 7).
import Foundation

/// The rule behind the onboarding's Apple Intelligence step.
///
/// WHY IN DICTUSCORE: the app target has no test bundle, and "shown only on a capable
/// device where Apple Intelligence is not ready" is a rule, not a layout.
public enum AppleIntelligenceOnboarding {

    /// Whether the step has something to ask on a device in `engineState`.
    ///
    /// - A capable iPhone where Apple Intelligence is not ready: shown. That is
    ///   `appleIntelligenceNotEnabled`, `modelNotReady`, and `.other`, a reason this build
    ///   does not know, which `SmartModeUnavailableReason.isRecoverable` already treats as
    ///   recoverable rather than guess that it is permanent.
    /// - Apple Intelligence available: nothing to ask.
    /// - A device that can never run it (hardware, OS, SDK): nothing to ask, and nothing
    ///   the user could do about it.
    ///
    /// WHY THE REASON IS NOT SPLIT FURTHER: Apple reportedly reports Apple Intelligence
    /// switched off, and a Siri language mismatch, as `modelNotReady` too, so they cannot
    /// be told apart reliably. The step is shown for all of them. The reason only picks
    /// where the step opens: `modelNotReady` on the setting-up screen, which keeps the
    /// Siri language hint (decision of 2026-10-28, #846, `AppleIntelligenceStepState`).
    ///
    /// "Capable" is `SmartModeAvailability.isCapable(engineState:)`, the same table the
    /// trial and the paywall read, so the onboarding cannot disagree with them about
    /// which iPhones can run Smart Modes.
    public static func isStepNeeded(engineState: PolishAvailabilityState) -> Bool {
        engineState != .available && SmartModeAvailability.isCapable(engineState: engineState)
    }

    /// `isStepNeeded` for this device, right now.
    public static var isStepNeeded: Bool {
        isStepNeeded(engineState: PolishAvailability.state)
    }

    // MARK: - Where the Siri language lives

    /// The row of the Settings root that leads to Siri's language.
    ///
    /// Read on devices and simulators on 2026-10-10 (#683): on iOS 26 the root row is
    /// *Apple Intelligence et Siri* / *Apple Intelligence & Siri*, and its page opens on
    /// the Siri language. On iOS 27 the root row is *Siri*, its page has the same language
    /// row, and there is no Apple Intelligence switch any more: matching Siri's language
    /// to the iPhone's is what turns it on.
    public enum SettingsRoute: Equatable, Sendable {
        /// iOS 26: Settings > Apple Intelligence & Siri > Language, plus a switch.
        case appleIntelligenceAndSiri
        /// iOS 27 and later: Settings > Siri > Language.
        case siri

        /// Whether the page also carries an Apple Intelligence switch to turn on.
        public var hasAppleIntelligenceSwitch: Bool {
            self == .appleIntelligenceAndSiri
        }
    }

    /// The route on an iOS of major version `osMajorVersion`.
    ///
    /// WHY THE OS VERSION AND NOT A GUESS: the two layouts were each read on that version,
    /// and an iOS later than 27 is assumed to keep 27's until someone reads otherwise.
    public static func settingsRoute(osMajorVersion: Int) -> SettingsRoute {
        osMajorVersion >= 27 ? .siri : .appleIntelligenceAndSiri
    }

    /// `settingsRoute` for this device.
    public static var settingsRoute: SettingsRoute {
        settingsRoute(osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }

    // MARK: - The language to pick

    /// The language the drawn Siri language list shows checked: the iPhone's language,
    /// named on its own ("English", "Français"), in `displayLocale`.
    ///
    /// WHY THE LANGUAGE ALONE (device test of 2026-10-11): built from the iPhone's
    /// language and region, the row read "English (France)", an entry Siri's list does
    /// not have. Read on iOS 26.5 and 27.0 simulators on 2026-10-11, FR and EN: Siri lists
    /// English and French only by country it supports ("English (United Kingdom)",
    /// "English (United States)", "French (France)", "French (Canada)"…), and nothing ties
    /// that list to the iPhone's region. A language name alone matches every entry of that
    /// language and never names one that does not exist.
    ///
    /// - Parameter preferredLanguage: the iPhone's first preferred language, a BCP 47 tag
    ///   ("en-FR", "fr-FR", "zh-Hans-CN").
    public static func siriLanguageLabel(preferredLanguage: String, displayLocale: Locale) -> String {
        let code = Locale.Language(identifier: preferredLanguage).languageCode?.identifier ?? preferredLanguage
        let name = displayLocale.localizedString(forLanguageCode: code) ?? code
        return name.prefix(1).uppercased(with: displayLocale) + name.dropFirst()
    }
}
