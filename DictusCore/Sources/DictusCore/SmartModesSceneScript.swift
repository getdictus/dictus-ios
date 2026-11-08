// DictusCore/Sources/DictusCore/SmartModesSceneScript.swift
// What the onboarding's Smart Modes scene shows at each moment of its loop (#679).
import CoreGraphics
import Foundation

/// The script of the Smart Modes scene (#679, #649 decisions 9 and 14, mock-up
/// `05-scene-smart-modes`): the keyboard's long-press fan and the dictation it starts,
/// performed by a drawn finger.
///
/// WHY THE WHOLE CYCLE (scope change on #679 after the device test of 2026-10-12):
/// releasing on a fan row arms the mode **and** starts recording
/// (`KeyboardSmartModeFan.commit()` calls `startRecording()`). A scene that stopped at
/// the release would teach half a gesture.
///
/// THE STORY, two legs of the same gesture, so the loop closes on itself:
/// 1. **Normal.** The finger taps the toolbar's Undo, which removes the previous leg's
///    text. It holds the mic; after the fan's real long-press delay the rows replace the
///    keys. It moves along the toolbar to the rows' column, then straight down to
///    `Normal`, and lets go: the keyboard records (waveform, timer, ✕ and ✓). The finger
///    taps ✓; the keyboard transcribes; a sentence lands in the host's field, in the
///    user's language.
/// 2. **Translation.** The same, down to `→ EN` (`→ FR` for an English speaker): the mic
///    pill wears the badge, the recording shows the armed mode, the transcription is
///    followed by the Smart Mode's processing, and **the same sentence** lands
///    translated. The loop ends on that payoff, which is also where it starts.
///
/// WHY IN DICTUSCORE: the app target has no test bundle. What makes this a drawing of the
/// real keyboard rather than of an imagined one is tested here: the row under the finger
/// is the row the keyboard would light (`SmartModeFanLayout`), the order of the states is
/// the keyboard's (`DictationStatus`), and the waveform's processing motion is
/// `ProcessingWaveform`'s.
public enum SmartModesSceneScript {

    /// The Normal leg: undo, gesture, record, transcribe, show.
    public static let normalLegSeconds: Double = 9.5

    /// The translation leg: one second longer, for the Smart Mode's processing stage and
    /// a longer look at the result.
    public static let translationLegSeconds: Double = 10.5

    /// The whole loop: 20 s (decision 14 asks for 10 to 20; Pierre asked for 18 to 20).
    public static let loopSeconds: Double = normalLegSeconds + translationLegSeconds

    /// How long the finger holds before the fan opens: the `minimumDuration` of the
    /// keyboard's `LongPressGesture` (`ToolbarView.fanGesture`), so the scene teaches the
    /// real wait. Written here because the keyboard target cannot be imported.
    public static let longPressSeconds: Double = 0.35

    /// Where the loop starts when the scene first appears: the field just cleared, the
    /// translation still armed from the end of the loop. Starting at 0 would open on the
    /// result of a dictation the viewer never saw.
    public static let openingSeconds: Double = Beat.undoRelease

    /// The moment shown with Reduce Motion on: the end state, the translated sentence in
    /// the field and the mode's badge on the mic (#679 scope change).
    public static let stillSeconds: Double = loopSeconds - 0.5

    /// The beats of one leg, in seconds from its start.
    enum Beat {
        /// The finger taps the toolbar's Undo: the previous leg's text goes.
        /// A beat after the leg starts, so the loop's first and last frames are the same
        /// picture with no finger on it.
        static let undoFingerIn: Double = 0.05
        static let undoPress: Double = 0.4
        static let undoRelease: Double = 0.65
        /// It comes back on the mic and holds.
        static let fingerIn: Double = 1.1
        static let press: Double = 1.4
        static let fanOpens: Double = press + longPressSeconds
        /// The first leg of the slide: along the toolbar, from the mic to the rows'
        /// column. The finger stays level with the mic, above the rows, so no row lights.
        static let slideStart: Double = 2.05
        static let columnReached: Double = 2.55
        /// The second leg: straight down the column to the target row.
        static let descentStart: Double = 2.65
        static let slideEnd: Double = 3.55
        /// Letting go on the row: the mode is armed and the recording starts.
        static let release: Double = 4.05
        /// The finger comes back to tap ✓, which sits exactly where the mic pill was.
        static let stopFingerIn: Double = 6.3
        static let stopPress: Double = 6.6
        static let stopRelease: Double = 6.85
        /// Transcription. Normal inserts at its end; a Smart Mode processes first.
        static let transcriptionEnd: Double = 7.85
        static let smartModeTranscriptionEnd: Double = 7.45
        static let smartModeProcessingEnd: Double = 8.45
        /// How long the finger takes to appear and to go.
        static let fade: Double = 0.3
    }

    /// What the keyboard area shows: the real keyboard's states, in their real order.
    public enum KeyboardPhase: Equatable, Sendable {
        /// The keys, under the toolbar.
        case keys
        /// The fan's rows, under the toolbar.
        case fan
        /// `RecordingOverlay` in `.recording`: ✕ and ✓, the live waveform, the timer.
        /// `elapsed` is seconds since the recording started.
        case recording(elapsed: Double)
        /// `RecordingOverlay` in `.transcribing`: the waveform's sweep, no buttons.
        case transcribing(elapsed: Double)
        /// `RecordingOverlay` in `.processing`: the travelling peak of a Smart Mode.
        case processing(elapsed: Double)

        /// Whether the recording overlay covers the toolbar and the keys.
        public var isOverlay: Bool {
            switch self {
            case .keys, .fan: return false
            case .recording, .transcribing, .processing: return true
            }
        }
    }

    /// The sentence in the host's field.
    public enum FieldText: Equatable, Sendable {
        /// As dictated, in the user's language (the Normal leg).
        case original
        /// The same sentence translated (the translation leg).
        case translated
    }

    /// Where the drawn finger is.
    public enum FingerPlace: Equatable, Sendable {
        /// On the keyboard: the mic pill or ✓ (they share a centre), the toolbar, or a
        /// fan row, at `Finger.y` and `Finger.columnTravel`.
        case keyboard
        /// On the toolbar's Undo, at its leading end.
        case undoButton
    }

    /// The drawn finger.
    public struct Finger: Equatable, Sendable {
        public let place: FingerPlace
        /// Vertical position in the fan's coordinates: 0 is the top of the first row,
        /// negative is up on the toolbar, where the mic is.
        public let y: CGFloat
        /// How far along the toolbar it is: 0 over the mic, 1 in the rows' column. The view
        /// turns it into the horizontal position.
        ///
        /// WHY TWO LEGS AND NOT ONE DIAGONAL (device feedback on PR #705, 2026-10-11): a
        /// finger cutting across the rows reads as choosing among them sideways. It first
        /// reaches the column, still level with the mic, then goes straight down the fan,
        /// so the only movement over the rows is the vertical one that chooses.
        public let columnTravel: Double
        /// Whether it is touching the screen.
        public let isPressed: Bool
        /// 0 to 1, for its fade in and out.
        public let opacity: Double
    }

    /// Everything the scene draws at one moment.
    public struct Frame: Equatable, Sendable {
        public let keyboard: KeyboardPhase
        /// The row under the finger, nil when the fan is closed or the finger is on none.
        public let highlightedIndex: Int?
        /// The row of the armed mode, nil for none (Normal).
        public let armedIndex: Int?
        /// The sentence in the field, nil for an empty field.
        public let fieldText: FieldText?
        /// Whether the toolbar offers Undo, as the keyboard does for 8 s after it inserts
        /// a dictation (`KeyboardState.dictationUndoTimeout`).
        public let offersUndo: Bool
        /// The finger, nil while it is off screen.
        public let finger: Finger?

        /// Whether the rows have replaced the keys.
        public var isFanOpen: Bool { keyboard == .fan }
    }

    /// The fan the scene draws: `Normal`, `Message`, `Liste`, `→ EN` (#679, mock-up 05).
    ///
    /// WHY NOT THE USER'S PINNED LIST: the user has not picked yet (the pick comes right
    /// after this scene), and the seed would show three modes that all transform the
    /// text the same way. These four show the two axes the catalogue moves text along,
    /// a register (Message), a structure (List), and a language.
    ///
    /// WHY THE TRANSLATION TARGET DEPENDS ON THE USER: `→ EN` to an English speaker is a
    /// mode they will never use, and the pick that follows does not even offer it. The
    /// scene takes the first target the pick offers (`SmartModePick.translateTargets`),
    /// which is `→ EN` for everyone but English speakers.
    ///
    /// - Parameter spokenLanguage: `SharedKeys.spokenLanguage`, as the pick reads it.
    public static func entries(spokenLanguage: String?) -> [SmartModeFanEntry] {
        let modes = [SmartModeCatalogue.messageIdentifier, SmartModeCatalogue.notesIdentifier]
            .compactMap { identifier in SmartModeCatalogue.builtIns.first { $0.id == identifier } }
        return [.normal]
            + modes.map(SmartModeFanEntry.mode)
            + [.mode(SmartModeCatalogue.translate(to: translationTarget(spokenLanguage: spokenLanguage)))]
    }

    /// The translation the scene arms: the first target the pick offers.
    public static func translationTarget(spokenLanguage: String?) -> SupportedLanguage {
        SmartModePick.translateTargets(spokenLanguage: spokenLanguage).first ?? .english
    }

    /// The languages the two sentences are written in: what the user dictates, and what
    /// the translation turns it into.
    ///
    /// The sentence exists in the app's two languages, French and English. The dictated
    /// one is in the language the user speaks when that is one of them, otherwise in the
    /// interface's. The translated one is in the fan's target when that is one of them;
    /// when it is not, or when it would repeat the dictated language, it is the other of
    /// the two, so the translation always visibly changes the sentence.
    ///
    /// - Parameters:
    ///   - spokenLanguage: `SharedKeys.spokenLanguage`.
    ///   - interfaceLanguage: the language the app's text is shown in.
    /// - Returns: two different codes among `sentenceLanguages`.
    public static func sentenceLanguages(spokenLanguage: String?,
                                         interfaceLanguage: String?) -> (original: String, translated: String) {
        let available = sentenceLanguages
        let fallback = available[1]
        let original = [spokenLanguage, interfaceLanguage]
            .compactMap { $0 }
            .first(where: available.contains) ?? fallback
        let target = translationTarget(spokenLanguage: spokenLanguage).rawValue
        let other = available.first { $0 != original } ?? fallback
        let translated = (available.contains(target) && target != original) ? target : other
        return (original, translated)
    }

    /// The languages the scene's sentence is written in (`Localizable.xcstrings`).
    public static let sentenceLanguages = ["fr", "en"]

    // MARK: - Frames

    /// The frame at `time` seconds into the loop.
    ///
    /// - Parameters:
    ///   - entryCount: the fan's rows, Normal included. The first leg chooses the first
    ///     row (Normal), the second the last (the translation).
    ///   - fanAreaHeight: the height the rows divide (`SmartModeFanLayout.rowHeight`).
    ///   - micY: the centre of the mic pill in the fan's coordinates, so negative.
    public static func frame(at time: Double,
                             entryCount: Int,
                             fanAreaHeight: CGFloat,
                             micY: CGFloat) -> Frame {
        let looped = loopSeconds > 0 ? time.truncatingRemainder(dividingBy: loopSeconds) : 0
        let wrapped = looped < 0 ? looped + loopSeconds : looped
        let isTranslationLeg = wrapped >= normalLegSeconds
        let local = isTranslationLeg ? wrapped - normalLegSeconds : wrapped

        let lastIndex = max(0, entryCount - 1)
        let target = isTranslationLeg ? lastIndex : 0
        // What the leg starts with and what its release leaves armed. Normal is "nothing
        // armed", so it is nil, as `SmartModeFanEntry.smartMode` is for it.
        let armedBefore: Int? = isTranslationLeg ? nil : lastIndex
        let armedAfter: Int? = isTranslationLeg ? lastIndex : nil
        let armedIndex = local < Beat.release ? armedBefore : armedAfter

        let keyboard = keyboardPhase(at: local, isTranslationLeg: isTranslationLeg)
        let insertion = isTranslationLeg ? Beat.smartModeProcessingEnd : Beat.transcriptionEnd

        // The field: the previous leg's sentence until Undo removes it, this leg's once
        // the keyboard inserts it.
        let fieldText: FieldText?
        if local < Beat.undoRelease {
            fieldText = isTranslationLeg ? .original : .translated
        } else if local >= insertion {
            fieldText = isTranslationLeg ? .translated : .original
        } else {
            fieldText = nil
        }

        let finger = finger(at: local, target: target, entryCount: entryCount,
                            fanAreaHeight: fanAreaHeight, micY: micY)

        var highlighted: Int?
        if keyboard == .fan, let finger, finger.place == .keyboard {
            highlighted = SmartModeFanLayout.entryIndex(
                atY: finger.y,
                availableHeight: fanAreaHeight,
                entryCount: entryCount,
                showsReason: false
            )
        }

        return Frame(
            keyboard: keyboard,
            highlightedIndex: highlighted,
            armedIndex: entryCount > 0 ? armedIndex : nil,
            fieldText: fieldText,
            offersUndo: fieldText != nil && keyboard == .keys,
            finger: finger
        )
    }

    /// The recording's waveform at `elapsed` seconds: 30 levels in 0...1, as
    /// `KeyboardWaveformDriver.displayLevels` holds them.
    ///
    /// The live levels come from the microphone; a drawing has none, so these are a
    /// deterministic voice: syllables (fast) inside words (slower), with short gaps,
    /// scrolling from right to left as the real buffer does. Values under the driver's
    /// 0.05 threshold are 0, as there.
    public static func recordingLevels(elapsed: Double) -> [Float] {
        let barCount = ProcessingWaveform.barCount
        // The first fraction of a second rises from silence, as a recording does.
        let onset = Float(min(1, max(0, elapsed / 0.4)))
        return (0..<barCount).map { index in
            // The newest sample is on the right; each bar to the left is 50 ms older.
            let age = Double(barCount - 1 - index) * 0.05
            let moment = elapsed - age
            guard moment > 0 else { return 0 }
            let syllables = abs(sin(moment * 11.0))
            let words = 0.55 + 0.45 * sin(moment * 2.7 + 0.8)
            let gap = sin(moment * 1.3 + 2.0) > 0.85 ? 0.15 : 1.0
            let value = Float(0.12 + 0.78 * syllables * words * gap) * onset
            return value < 0.05 ? 0 : min(1, value)
        }
    }

    // MARK: - Private

    private static func keyboardPhase(at local: Double, isTranslationLeg: Bool) -> KeyboardPhase {
        if local < Beat.fanOpens { return .keys }
        if local < Beat.release { return .fan }
        if local < Beat.stopRelease { return .recording(elapsed: local - Beat.release) }
        if isTranslationLeg {
            if local < Beat.smartModeTranscriptionEnd { return .transcribing(elapsed: local - Beat.stopRelease) }
            if local < Beat.smartModeProcessingEnd {
                return .processing(elapsed: local - Beat.smartModeTranscriptionEnd)
            }
            return .keys
        }
        if local < Beat.transcriptionEnd { return .transcribing(elapsed: local - Beat.stopRelease) }
        return .keys
    }

    private static func finger(at local: Double,
                               target: Int,
                               entryCount: Int,
                               fanAreaHeight: CGFloat,
                               micY: CGFloat) -> Finger? {
        // The tap on Undo.
        if let tap = tap(at: local, start: Beat.undoFingerIn, press: Beat.undoPress, release: Beat.undoRelease) {
            return Finger(place: .undoButton, y: micY, columnTravel: 0, isPressed: tap.isPressed, opacity: tap.opacity)
        }
        // The tap on ✓, where the mic pill was.
        if let tap = tap(at: local, start: Beat.stopFingerIn, press: Beat.stopPress, release: Beat.stopRelease) {
            return Finger(place: .keyboard, y: micY, columnTravel: 0, isPressed: tap.isPressed, opacity: tap.opacity)
        }
        // The long press, the slide and the release on a row.
        guard let hold = tap(at: local, start: Beat.fingerIn, press: Beat.press, release: Beat.release) else {
            return nil
        }
        let columnTravel = smoothStep(from: Beat.slideStart, to: Beat.columnReached, at: local)
        let descent = smoothStep(from: Beat.descentStart, to: Beat.slideEnd, at: local)
        let rowHeight = SmartModeFanLayout.rowHeight(
            availableHeight: fanAreaHeight, entryCount: entryCount, showsReason: false
        )
        // The middle of the target row: where a thumb choosing it rests.
        let targetY = rowHeight * (CGFloat(target) + 0.5)
        let y = micY + (targetY - micY) * CGFloat(descent)
        return Finger(place: .keyboard, y: y, columnTravel: columnTravel,
                      isPressed: hold.isPressed, opacity: hold.opacity)
    }

    /// A finger that fades in at `start`, touches from `press` to `release`, then fades
    /// out; nil outside that span.
    private static func tap(at local: Double,
                            start: Double,
                            press: Double,
                            release: Double) -> (isPressed: Bool, opacity: Double)? {
        guard local >= start, local < release + Beat.fade else { return nil }
        let opacity: Double
        if local < start + Beat.fade {
            opacity = (local - start) / Beat.fade
        } else if local >= release {
            opacity = 1 - (local - release) / Beat.fade
        } else {
            opacity = 1
        }
        return (local >= press && local < release, min(1, max(0, opacity)))
    }

    /// 0 before `start`, 1 after `end`, an ease in and out between: a thumb accelerates
    /// and settles, it does not slide at constant speed.
    private static func smoothStep(from start: Double, to end: Double, at time: Double) -> Double {
        guard end > start else { return time >= end ? 1 : 0 }
        let linear = min(1, max(0, (time - start) / (end - start)))
        return linear * linear * (3 - 2 * linear)
    }
}
