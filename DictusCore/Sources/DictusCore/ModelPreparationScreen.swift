// DictusCore/Sources/DictusCore/ModelPreparationScreen.swift
// What the model preparation screen draws for each phase: the ring, the two step rows,
// and the language named in the onboarding subtitle. Issue #708.
import Foundation

/// The phase the preparation screen is showing.
///
/// WHY IT IS HERE AND NOT PRIVATE TO THE VIEW (#708): the screen used to keep this enum to
/// itself, and the rule that decides the very first frame lived next to it, untested. That
/// rule is the whole of the "download that did not happen" defect: a screen opened for a
/// model already on disk drew the download phase at 0 % until the model manager caught up.
/// The rule has a right and a wrong answer, so it is held still by a test here, like the
/// countdown (`ModelPreparationCountdown`).
public enum ModelPreparationPhase: Equatable, Sendable {
    case downloading
    case compiling
    case loading
    case ready

    /// The phase to draw, given the phase the model's state maps to.
    ///
    /// WHY A MASK AT ALL: the parent raises the screen synchronously, and the work that
    /// moves the model out of its resting state starts on the next turn of the run loop
    /// (`ModelDownloadPage.startDownload` raises the screen, then starts a `Task`). Until
    /// a work phase has been seen, a resting `.ready` is "about to start", not "done",
    /// and drawing it as done would flash the completion state (commit f5ba7ab follow-up).
    ///
    /// WHY THE MASK DEPENDS ON THE DISK (#708, defect 1): it used to be `.downloading`
    /// whatever the disk held. For a model whose files are all present, the download phase
    /// is a lie even for one frame: no byte will move, and what comes next is the Core ML
    /// compile. The validated mock-up opens that case directly on the optimization frame
    /// (`B-optimisation`), so that is what the mask answers.
    ///
    /// - Parameters:
    ///   - raw: the phase the model's state maps to right now.
    ///   - hasSeenWorkPhase: whether the screen has observed real work yet.
    ///   - filesOnDisk: whether every file the model needs was on disk when the screen
    ///     opened.
    public static func displayed(raw: Self, hasSeenWorkPhase: Bool, filesOnDisk: Bool) -> Self {
        guard !hasSeenWorkPhase, raw == .ready else { return raw }
        return filesOnDisk ? .compiling : .downloading
    }
}

/// The state of one row of the screen's two-step card (#708).
public enum ModelPreparationStepState: Equatable, Sendable {
    /// Empty circle, tertiary label.
    case pending
    /// Spinner in the accent colour, semibold primary label.
    case running
    /// Green check, secondary label.
    case done
}

/// What the second row of the card says. The first row always names the download.
public enum ModelPreparationSecondStep: Equatable, Sendable {
    /// "Optimizing for this iPhone": the Core ML compile, or the wait before it.
    case optimizing
    /// "Loading the model": the load into RAM.
    case loading
    /// "Optimized for this iPhone": done.
    case optimized
}

/// The card's two rows for a phase (#708).
///
/// WHY ALWAYS TWO ROWS: the card is a fixed-height block, so a phase change only swaps the
/// rows' content and never moves what sits under it. And the two stages of the wait are
/// what the user needs to see: a download they can measure, then a preparation they
/// cannot, which is why the second one shows no percentage.
public struct ModelPreparationSteps: Equatable, Sendable {
    public let download: ModelPreparationStepState
    public let second: ModelPreparationStepState
    public let secondLabel: ModelPreparationSecondStep

    public init(phase: ModelPreparationPhase) {
        switch phase {
        case .downloading:
            download = .running
            second = .pending
            secondLabel = .optimizing
        case .compiling:
            download = .done
            second = .running
            secondLabel = .optimizing
        case .loading:
            download = .done
            second = .running
            secondLabel = .loading
        case .ready:
            download = .done
            second = .done
            secondLabel = .optimized
        }
    }
}

/// What the ring around the logo draws for a phase (#708).
public enum ModelPreparationRing: Equatable, Sendable {
    /// The real download fraction, from 12 o'clock, clockwise.
    case fraction(Double)
    /// A short arc turning continuously. Core ML reports no progress for a compile, so
    /// the ring says "working" and claims nothing about how far (#432, #533).
    case spinning
    /// The full circle, drawn in the success colour.
    case closed

    /// Shortest arc drawn for a download, so a ring at 0 % still reads as started. Same
    /// sliver as the onboarding's download pill.
    public static let minimumFraction = 0.02

    /// Length of the spinning arc, as a fraction of the circle (about 95°, per the brief).
    public static let spinningArcFraction = 95.0 / 360.0

    /// - Parameter downloadFraction: the download's progress, nil before the first tick.
    public init(phase: ModelPreparationPhase, downloadFraction: Double?) {
        switch phase {
        case .downloading:
            let fraction = downloadFraction ?? 0
            self = .fraction(min(1, max(Self.minimumFraction, fraction)))
        case .compiling, .loading:
            self = .spinning
        case .ready:
            self = .closed
        }
    }

    /// Where the arc ends, as a fraction of the circle. The view animates between these.
    public var arcEnd: Double {
        switch self {
        case .fraction(let fraction): return fraction
        case .spinning: return Self.spinningArcFraction
        case .closed: return 1
        }
    }
}

/// The spoken language as the onboarding subtitle names it: "picked for French", "choisi
/// pour le français" (#708, #649 decision 4).
///
/// WHY A PHRASE AND NOT A NAME: French puts an article in front of a language name and
/// elides it before a vowel ("le français", "l'anglais"). A sentence that took the bare
/// name would read "choisi pour français", and a fixed "le" would read "le anglais".
///
/// WHY SOME LANGUAGES GET NO PHRASE: the brief's fallback is "chosen for your language",
/// for wherever the named form is awkward. In French that is every name starting with h:
/// whether the h is mute ("l'hébreu") or aspirated ("le hongrois") is a fact about each
/// word, and getting it wrong in a sentence the user reads on their first launch is worse
/// than not naming the language. Any interface language other than French and English gets
/// the fallback too: those are the only two the app is translated into, and the rule for a
/// third is not one to guess.
public enum ModelPreparationLanguagePhrase {

    /// - Parameters:
    ///   - languageName: the spoken language's name in the interface language, as
    ///     `Locale.localizedString(forLanguageCode:)` returns it.
    ///   - interfaceLanguage: the interface's language code ("fr", "en").
    /// - Returns: the phrase to slot into the sentence, or nil for the fallback sentence.
    public static func phrase(languageName: String?, interfaceLanguage: String) -> String? {
        guard let languageName, !languageName.isEmpty else { return nil }
        switch interfaceLanguage {
        case "en":
            return languageName
        case "fr":
            let name = languageName.lowercased(with: Locale(identifier: "fr"))
            // Folded so "é", "î" and the rest count as the vowels they are.
            guard let first = name.folding(options: .diacriticInsensitive, locale: nil).first else {
                return nil
            }
            if first == "h" { return nil }
            // No y: it starts a consonant sound in "le yiddish", "le yoruba".
            return "aeiou".contains(first) ? "l'\(name)" : "le \(name)"
        default:
            return nil
        }
    }
}
