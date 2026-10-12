// DictusCore/Sources/DictusCore/VoiceNotesSceneScript.swift
// What the onboarding's voice notes scene shows at each moment of its loop (#680).
import Foundation

/// The script of the voice notes scene (#680, #649 decision 9.2, mock-up
/// `07a-scene-memos-vocaux`): a voice message shared to Dictus, its transcript inserted
/// from the keyboard, then Dictus added to the share sheet's favourites.
///
/// The card's chips above the drawn iPhone name the everyday path once Dictus is set up:
/// Share, Dictus (a favourite, so in the sheet's row), Insert. The loop plays the first
/// time instead, which is how a user meets it, and ends on what makes the next times
/// that short.
///
/// THE STORY, three movements:
/// 1. **Share.** In a conversation, the finger holds a received voice message; the
///    context menu opens; it taps *Share*. The share sheet comes up; Dictus is not in its
///    row of apps, so the finger opens *More* and picks Dictus from the list.
/// 2. **Insert.** The finger taps the message field. The Dictus keyboard opens on its
///    voice note reader (it opens by itself on a note it has not shown yet,
///    `VoiceNoteKeyboardPresentation.onAppearance`), with the duration, the language and
///    the transcript. The finger taps *Insert*: the transcript lands in the field and the
///    reader closes, as `KeyboardVoiceNoteState.insert` does.
/// 3. **Dictus as a favourite.** The share sheet again, for the next note: *More*,
///    *Edit*, the green + beside Dictus, *Done*. Dictus is now in the sheet's row, one
///    tap away from any app. The scene ends there (#680: "the scene ends on adding Dictus
///    to the share sheet's favourites"), because no API does it for the user.
///
/// WHY THE FAVOURITES LAST AND NOT IN THE MIDDLE: the brief asks the scene to end on
/// them, and it is the one step a user has to be shown: sharing and inserting explain
/// themselves once seen, a list behind *More* → *Edit* does not.
///
/// The loop closes on itself: the sheet goes down on the conversation the scene opens
/// on, the field empty.
public enum VoiceNotesSceneScript {

    /// What the drawn finger taps.
    public enum Target: Hashable, Sendable {
        /// The received voice message, held for the context menu.
        case voiceMessage
        /// *Share* in that menu.
        case shareAction
        /// *More* at the end of the share sheet's row of apps.
        case moreApps
        /// Dictus in the list *More* opens.
        case dictusInList
        /// The host's message field, which brings up the keyboard.
        case messageField
        /// The reader's *Insert*.
        case insert
        /// *Edit* at the top of the list.
        case editApps
        /// The green + beside Dictus, in edit mode.
        case addDictus
        /// *Done*, which leaves edit mode and the list.
        case doneEditing
    }

    /// The system sheet over the host.
    public enum Sheet: Equatable, Sendable {
        /// The share sheet: the file, the row of apps, the actions.
        case share
        /// The list of apps behind *More*, in edit mode or not.
        case apps(isEditing: Bool)
    }

    /// What the Dictus keyboard shows, when it is up.
    public enum Keyboard: Equatable, Sendable {
        /// `VoiceNoteReaderView`: header, transcript, *Insert*.
        case reader
        /// The keys under the toolbar, after the insert closed the reader.
        case keys
    }

    /// Everything the scene draws at one moment.
    public struct Frame: Equatable, Sendable {
        /// Whether the voice message's context menu is open.
        public let contextMenuIsOpen: Bool
        /// The system sheet, nil for none.
        public let sheet: Sheet?
        /// Whether Dictus is among the share sheet's favourites.
        public let dictusIsFavourite: Bool
        /// The keyboard, nil while it is down.
        public let keyboard: Keyboard?
        /// Whether the transcript is in the message field.
        public let fieldHasTranscript: Bool
        /// The finger, nil while it is off screen.
        public let finger: SceneTapFinger<Target>?
    }

    /// The beats, in seconds from the start of the loop.
    enum Beat {
        // 1. Share.
        static let holdMessage = SceneTap(Target.voiceMessage, press: 0.7, release: 1.3)
        /// The context menu opens while the finger is still down, as a long press does.
        static let menuOpens: Double = 1.2
        static let tapShare = SceneTap(Target.shareAction, press: 2.0, release: 2.2)
        static let tapMore = SceneTap(Target.moreApps, press: 3.1, release: 3.3)
        static let tapDictus = SceneTap(Target.dictusInList, press: 4.1, release: 4.3)
        // 2. Insert.
        static let tapField = SceneTap(Target.messageField, press: 5.2, release: 5.4)
        static let tapInsert = SceneTap(Target.insert, press: 6.7, release: 6.9)
        /// The keyboard goes down and the share sheet of the next note comes up.
        static let nextShare: Double = 8.6
        // 3. Dictus as a favourite.
        static let tapMoreAgain = SceneTap(Target.moreApps, press: 9.4, release: 9.6)
        static let tapEdit = SceneTap(Target.editApps, press: 10.4, release: 10.6)
        static let tapAdd = SceneTap(Target.addDictus, press: 11.4, release: 11.6)
        static let tapDone = SceneTap(Target.doneEditing, press: 12.6, release: 12.8)
        /// The share sheet with Dictus in its row stays on screen until here, then goes
        /// down on the opening conversation.
        static let sheetCloses: Double = 15.4
    }

    /// Every tap, in order. They never overlap (tested).
    static let taps: [SceneTap<Target>] = [
        Beat.holdMessage, Beat.tapShare, Beat.tapMore, Beat.tapDictus, Beat.tapField, Beat.tapInsert,
        Beat.tapMoreAgain, Beat.tapEdit, Beat.tapAdd, Beat.tapDone
    ]

    /// One pass: 16 s, inside decision 14's 10 to 20.
    public static let loopSeconds: Double = 16

    /// The moment shown with Reduce Motion on: the reader open on the transcript, the
    /// frame mock-up 07a draws. The text *in the keyboard* is what the page's line
    /// promises, so it is the picture that stands for the scene.
    public static let stillSeconds: Double = 6.0

    /// The scene at `time` seconds into the loop.
    public static func frame(at time: Double) -> Frame {
        Frame(
            contextMenuIsOpen: time >= Beat.menuOpens && time < Beat.tapShare.release,
            sheet: sheet(at: time),
            dictusIsFavourite: time >= Beat.tapAdd.release,
            keyboard: keyboard(at: time),
            // Cleared under the next share sheet, once it covers the field, so the loop
            // can start again on an empty one.
            fieldHasTranscript: time >= Beat.tapInsert.release && time < Beat.tapMoreAgain.release,
            finger: taps.finger(at: time)
        )
    }

    private static func sheet(at time: Double) -> Sheet? {
        switch time {
        case Beat.tapShare.release..<Beat.tapMore.release: return .share
        case Beat.tapMore.release..<Beat.tapDictus.release: return .apps(isEditing: false)
        case Beat.nextShare..<Beat.tapMoreAgain.release: return .share
        case Beat.tapMoreAgain.release..<Beat.tapEdit.release: return .apps(isEditing: false)
        case Beat.tapEdit.release..<Beat.tapDone.release: return .apps(isEditing: true)
        case Beat.tapDone.release..<Beat.sheetCloses: return .share
        default: return nil
        }
    }

    private static func keyboard(at time: Double) -> Keyboard? {
        switch time {
        case Beat.tapField.release..<Beat.tapInsert.release: return .reader
        case Beat.tapInsert.release..<Beat.nextShare: return .keys
        default: return nil
        }
    }
}
