// DictusCore/Sources/DictusCore/OnboardingStep.swift
// The onboarding steps, in order, and where an install mid-onboarding resumes (#649, #675).
import Foundation

/// One step of the first-run onboarding, persisted by name in `SharedKeys.onboardingStep`.
///
/// WHY persisted at all: when the user enables "Allow Full Access" during keyboard setup,
/// iOS kills the app (the TCC permission changes under it). The step has to survive that
/// so the user comes back where they were, not to the welcome screen.
///
/// WHY by name and not by index (#649): the flow used to store a page index, and every
/// page added or removed moved the meaning of every index after it — the old switch
/// carried a `case 3` that meant two different pages depending on the device. A raw
/// string means the same step for as long as the step exists, and a name this build does
/// not know (written by a later build, then rolled back) falls back to the start instead
/// of to whichever page happens to hold that number.
///
/// WHY in DictusCore: the order, the skips and the migrations are rules, and the app
/// target has no test bundle.
///
/// THE ORDER (#675, #649 decisions 1 and 17): intro, language, keyboard in Settings, the
/// wait for the model, the microphone, the first dictation, the completion screen. The
/// microphone sits right before the first dictation because it is the first step that
/// uses it, and its pre-permission screen keeps the system popup out of the recording.
/// Steps the later #649 sub-issues add (Apple Intelligence, the feature scenes, the Smart
/// Mode pick, the Dynamic Island tutorial) slot in as new cases with new raw values; the
/// existing raw values keep their meaning.
public enum OnboardingStep: String, CaseIterable, Sendable {
    /// The intro. Today the static welcome page; #676 replaces its content.
    case welcome
    /// Spoken language, keyboard language and layout. Confirming it starts the model
    /// download.
    case language
    /// Adding the keyboard and Full Access in iOS Settings. The step iOS kills the app on.
    case keyboardSetup
    /// Shown only while the model is still downloading or compiling; skipped otherwise.
    case modelPreparation
    /// The pre-permission screen, then the system microphone prompt.
    ///
    /// WHY NOT "microphone" (#675): that raw value was written by the flow before #675,
    /// where the microphone came BEFORE the keyboard. A stored "microphone" therefore
    /// means "keyboard not set up yet", and reading it as this step would skip the
    /// keyboard for whoever updates mid-onboarding. A new name keeps the two apart;
    /// `current()` sends the old one to `keyboardSetup`.
    case microphone = "microphonePrompt"
    /// The first dictation through the globe key.
    case firstDictation
    /// The "you're all set" screen. Its button ends the onboarding.
    case completion

    /// The step after this one, or nil for the last.
    public var next: OnboardingStep? {
        next(skipping: [])
    }

    /// The step after this one, passing over every step in `satisfied`, or nil for the
    /// last.
    ///
    /// WHY THE CALLER SAYS WHAT IS SATISFIED: whether the model is ready or the microphone
    /// already granted is read from `ModelManager` and `AVAudioSession`, which DictusCore
    /// does not see. Which steps CAN be passed over is a rule, and lives here
    /// (`isSkippedWhenSatisfied`): a step outside that list is shown even if the caller
    /// puts it in `satisfied`.
    public func next(skipping satisfied: Set<OnboardingStep>) -> OnboardingStep? {
        let all = Self.allCases
        guard var index = all.firstIndex(of: self) else { return nil }
        while index + 1 < all.count {
            index += 1
            let candidate = all[index]
            if candidate.isSkippedWhenSatisfied, satisfied.contains(candidate) { continue }
            return candidate
        }
        return nil
    }

    /// Whether this step is passed over when what it asks for is already done.
    ///
    /// - `modelPreparation`: there is nothing to wait for once the model is ready (#649
    ///   decision 1.6). A download that finished while the user was in Settings goes
    ///   straight on.
    /// - `microphone`: a microphone already granted (a second run of the onboarding, or an
    ///   install that went through the old order, where the microphone came first) has
    ///   nothing to ask. A denied one is still shown: the page says where to turn it on.
    public var isSkippedWhenSatisfied: Bool {
        switch self {
        case .modelPreparation, .microphone:
            return true
        case .welcome, .language, .keyboardSetup, .firstDictation, .completion:
            return false
        }
    }

    /// Position in the flow.
    public var position: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    // MARK: - Shell

    /// Whether the step shows the segmented progress bar (#675).
    ///
    /// The intro and the completion screen are drawn without it in the mock-ups: the
    /// first is before the work starts, the second after it ends.
    public var showsProgress: Bool {
        switch self {
        case .welcome, .completion:
            return false
        case .language, .keyboardSetup, .modelPreparation, .microphone, .firstDictation:
            return true
        }
    }

    /// The steps that own a segment of the progress bar, in order.
    ///
    /// WHY a skipped step keeps its segment: the bar would otherwise change length
    /// depending on how fast the download was. A passed-over step reads as done, like the
    /// old dots did.
    public static var progressSteps: [OnboardingStep] {
        allCases.filter(\.showsProgress)
    }

    /// This step's segment in `progressSteps`, or nil for a step without the bar.
    public var progressIndex: Int? {
        Self.progressSteps.firstIndex(of: self)
    }

    /// Whether the shell offers the discreet Skip in the top-right slot.
    ///
    /// Only the first dictation today: everything before it sets up something the
    /// keyboard needs, and the completion screen is its own way out.
    public var isSkippable: Bool {
        self == .firstDictation
    }

    // MARK: - Migration from the page index (before #649)

    /// Where an install that was mid-onboarding on the old page numbering resumes.
    ///
    /// The old flow was Welcome (0), Mic (1), Keyboard (2), Polish or, on a device without
    /// polish, Model (3), Model (4), Globe (5). The language screen did not exist, so every
    /// install between the welcome and the model has not seen it, and it is the screen
    /// that decides the keyboard and the model. They resume there; the keyboard and
    /// microphone steps that follow detect what is already granted.
    ///
    /// Index 5 had already installed a model on the old device-only rule, so it resumes at
    /// the first dictation: sending it back to the language screen would download a second
    /// model to someone one step from done. Anything else (a negative or unknown index)
    /// starts over, which is what the old switch's `default` did.
    public static func migrated(fromLegacyPageIndex index: Int) -> OnboardingStep {
        switch index {
        case 1...4: return .language
        case 5: return .firstDictation
        default: return .welcome
        }
    }

    // MARK: - Migration from the #649 order (before #675)

    /// The raw value the microphone step had while it came second, right after the
    /// language screen (#649 PR A).
    public static let legacyMicrophoneRawValue = "microphone"

    /// Where a step name written by an earlier build resumes, or nil for a name this build
    /// does not know.
    ///
    /// Every current raw value resumes at its own step: the five that existed before #675
    /// mean the same thing in the new order (what was done before them is still done
    /// before them, the microphone apart, and the microphone step is shown later). The one
    /// exception is the old microphone name: the user had confirmed the language and not
    /// yet added the keyboard, so they resume at the keyboard.
    public static func resumed(fromStoredRawValue raw: String) -> OnboardingStep? {
        if raw == legacyMicrophoneRawValue { return .keyboardSetup }
        return OnboardingStep(rawValue: raw)
    }

    // MARK: - Persistence

    /// The step to show, read from the App Group, migrating the legacy values once.
    ///
    /// The legacy index key is removed as soon as it has been read, and a legacy step name
    /// is rewritten under its new meaning, so neither migration can run twice and a later
    /// reset of the onboarding is not dragged back to the old position.
    public static func current(defaults: UserDefaults = AppGroup.defaults) -> OnboardingStep {
        if let raw = defaults.string(forKey: SharedKeys.onboardingStep) {
            guard let step = resumed(fromStoredRawValue: raw) else { return .welcome }
            if step.rawValue != raw {
                defaults.set(step.rawValue, forKey: SharedKeys.onboardingStep)
            }
            return step
        }
        guard defaults.object(forKey: SharedKeys.onboardingCurrentPage) != nil else {
            return .welcome
        }
        let migrated = migrated(fromLegacyPageIndex: defaults.integer(forKey: SharedKeys.onboardingCurrentPage))
        defaults.set(migrated.rawValue, forKey: SharedKeys.onboardingStep)
        defaults.removeObject(forKey: SharedKeys.onboardingCurrentPage)
        return migrated
    }

    /// Records `step` as the one to resume at.
    public static func save(_ step: OnboardingStep, defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(step.rawValue, forKey: SharedKeys.onboardingStep)
    }
}
