// DictusCore/Sources/DictusCore/VoiceNotesSceneScript.swift
// What the onboarding's voice notes scene shows at each moment of its loop (#680).
import Foundation

/// The script of the voice notes scene (#680, #649 decision 9.2, mock-up
/// `07a-scene-memos-vocaux`): Dictus added to the share sheet's favourites once, then a
/// voice message shared to Dictus and its transcript waiting in the keyboard.
///
/// TWO CHAPTERS, SEPARATED ON SCREEN (decided by Pierre after the device test of
/// 2026-10-12): the first version chained "share through *More*, insert" and "add to
/// the favourites" in one movement, and even knowing the feature he could not tell where
/// one ended and the other began. Each chapter now has its own caption and its own step
/// chips above the drawn iPhone, and the scene fades between them.
/// 1. **Just once** (`Chapter.setUp`). The share sheet comes up; Dictus is not in its row
///    of apps. The finger opens *More*, taps *Edit*, the green + beside Dictus, *Done*.
///    Dictus now leads the row, and stays there long enough to be seen. No API does this
///    for the user, which is why the scene shows it.
/// 2. **Then, for every voice note** (`Chapter.everyNote`). The finger holds a received
///    voice message; the context menu opens; *Share*. Dictus is already in the row: one
///    tap. The finger taps the message field; the Dictus keyboard opens on its voice note
///    reader (it opens by itself on a note it has not shown yet,
///    `VoiceNoteKeyboardPresentation.onAppearance`), with the duration, the language and
///    the transcript. The scene ends there, and holds it.
///
/// WHY IT ENDS ON THE READER AND NOT ON *INSERT* (Pierre, second device test,
/// 2026-10-12): the feature's strength is the transcript already sitting in the keyboard.
/// *Insert* explains itself; tapping it only took the picture away. The reader stays on
/// screen about three seconds, longer than any other beat, before the loop fades out.
public enum VoiceNotesSceneScript {

    /// What the drawn finger taps.
    public enum Target: Hashable, Sendable {
        /// *More* at the end of the share sheet's row of apps.
        case moreApps
        /// *Edit* at the top of the list *More* opens.
        case editApps
        /// The green + beside Dictus, in edit mode.
        case addDictus
        /// *Done*, which leaves edit mode and the list.
        case doneEditing
        /// The received voice message, held for the context menu.
        case voiceMessage
        /// *Share* in that menu.
        case shareAction
        /// Dictus in the share sheet's row of apps, once it is a favourite.
        case dictusInRow
        /// The host's message field, which brings up the keyboard.
        case messageField
    }

    /// The scene's two chapters, each with its caption and its step chips.
    public enum Chapter: Equatable, Sendable {
        /// Adding Dictus to the share sheet's favourites, done once.
        case setUp
        /// Sharing a voice note to Dictus and inserting it, every time.
        case everyNote
    }

    /// The system sheet over the host.
    public enum Sheet: Equatable, Sendable {
        /// The share sheet: the file, the row of apps, the actions.
        case share
        /// The list of apps behind *More*, in edit mode or not.
        case apps(isEditing: Bool)
    }

    /// Everything the scene draws at one moment.
    public struct Frame: Equatable, Sendable {
        /// The chapter on screen, which picks the caption and the chips.
        public let chapter: Chapter
        /// How visible the drawn screen is: 1 inside a chapter, down to 0 at the fades
        /// between the chapters and at the loop's end.
        public let screenOpacity: Double
        /// Whether the voice message's context menu is open.
        public let contextMenuIsOpen: Bool
        /// The system sheet, nil for none.
        public let sheet: Sheet?
        /// Whether Dictus is among the share sheet's favourites.
        public let dictusIsFavourite: Bool
        /// Whether the Dictus keyboard is up, open on its voice note reader
        /// (`VoiceNoteReaderView`: header, transcript, *Insert*).
        public let readerIsOpen: Bool
        /// The finger, nil while it is off screen.
        public let finger: SceneTapFinger<Target>?
    }

    /// The beats, in seconds from the start of the loop.
    ///
    /// WHY THE SCREEN STAYS DARK A MOMENT AT EACH CHAPTER'S START: what the previous
    /// chapter left on screen (the share sheet, the keyboard) leaves while nothing is
    /// visible, so the new chapter fades in on a clean conversation instead of on a sheet
    /// sliding away.
    enum Beat {
        // 1. Just once.
        /// The screen fades in from here.
        static let setUpFadeIn: Double = 0.4
        /// The share sheet comes up on its own: the chapter is about what is behind *More*.
        static let shareSheetUp: Double = 0.9
        static let tapMore = SceneTap(Target.moreApps, press: 1.8, release: 2.0)
        static let tapEdit = SceneTap(Target.editApps, press: 2.8, release: 3.0)
        static let tapAdd = SceneTap(Target.addDictus, press: 3.8, release: 4.0)
        static let tapDone = SceneTap(Target.doneEditing, press: 4.9, release: 5.1)
        /// The share sheet with Dictus leading the row holds until here (1.6 s), then the
        /// screen fades out.
        static let setUpFadeOut: Double = 6.7
        /// The second chapter starts and the screen fades back in: the caption and the
        /// chips change here, after the sheet left in the dark.
        static let everyNoteStarts: Double = 7.4
        // 2. Every voice note.
        static let holdMessage = SceneTap(Target.voiceMessage, press: 8.4, release: 9.0)
        /// The context menu opens while the finger is still down, as a long press does.
        static let menuOpens: Double = 8.9
        static let tapShare = SceneTap(Target.shareAction, press: 9.7, release: 9.9)
        static let tapDictus = SceneTap(Target.dictusInRow, press: 10.8, release: 11.0)
        static let tapField = SceneTap(Target.messageField, press: 11.8, release: 12.0)
        /// The reader holds the transcript until here (3 s), then the screen fades out
        /// and the loop starts again.
        static let loopFadeOut: Double = 15.0
    }

    /// How long a fade takes, each way.
    static let fade: Double = 0.3

    /// Every tap, in order. They never overlap (tested).
    static let taps: [SceneTap<Target>] = [
        Beat.tapMore, Beat.tapEdit, Beat.tapAdd, Beat.tapDone,
        Beat.holdMessage, Beat.tapShare, Beat.tapDictus, Beat.tapField
    ]

    /// One pass: 15.3 s, inside decision 14's 10 to 20.
    public static let loopSeconds: Double = Beat.loopFadeOut + fade

    /// The moment shown with Reduce Motion on: the reader open on the transcript, the
    /// frame mock-up 07a draws and the one the scene ends on.
    public static let stillSeconds: Double = 13.5

    /// The scene at `time` seconds into the loop.
    public static func frame(at time: Double) -> Frame {
        let chapter: Chapter = time < Beat.everyNoteStarts ? .setUp : .everyNote
        return Frame(
            chapter: chapter,
            screenOpacity: screenOpacity(at: time),
            contextMenuIsOpen: time >= Beat.menuOpens && time < Beat.tapShare.release,
            sheet: sheet(at: time),
            // Added in the first chapter and kept through the second, which is the point:
            // the second never goes through *More*.
            dictusIsFavourite: time >= Beat.tapAdd.release,
            // Up from the tap on the field to the end of the loop, which fades out on it.
            readerIsOpen: time >= Beat.tapField.release,
            finger: taps.finger(at: time)
        )
    }

    private static func screenOpacity(at time: Double) -> Double {
        for start in [Beat.setUpFadeIn, Beat.everyNoteStarts] where time >= start && time < start + fade {
            return (time - start) / fade
        }
        for start in [Beat.setUpFadeOut, Beat.loopFadeOut] where time >= start && time < start + fade {
            return 1 - (time - start) / fade
        }
        let isDark = time < Beat.setUpFadeIn
            || (time >= Beat.setUpFadeOut + fade && time < Beat.everyNoteStarts)
            || time >= Beat.loopFadeOut + fade
        return isDark ? 0 : 1
    }

    private static func sheet(at time: Double) -> Sheet? {
        switch time {
        case Beat.shareSheetUp..<Beat.tapMore.release: return .share
        case Beat.tapMore.release..<Beat.tapEdit.release: return .apps(isEditing: false)
        case Beat.tapEdit.release..<Beat.tapDone.release: return .apps(isEditing: true)
        // Held through the fade out: the chapter ends on the row with Dictus in it.
        case Beat.tapDone.release..<(Beat.setUpFadeOut + fade): return .share
        case Beat.tapShare.release..<Beat.tapDictus.release: return .share
        default: return nil
        }
    }
}
