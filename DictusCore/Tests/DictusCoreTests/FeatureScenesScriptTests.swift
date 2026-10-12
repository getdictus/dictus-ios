// DictusCore/Tests/DictusCoreTests/FeatureScenesScriptTests.swift
// The onboarding's voice notes, vocabulary and history scenes: their taps and their loops (#680).
import XCTest
@testable import DictusCore

final class FeatureScenesScriptTests: XCTestCase {

    /// Every moment of a loop, 10 ms apart.
    private func times(_ loopSeconds: Double) -> [Double] {
        Array(stride(from: 0.0, to: loopSeconds, by: 0.01))
    }

    // MARK: - The tap

    func testATapShowsTheFingerAroundItsPressOnly() {
        let tap = SceneTap("button", press: 1.0, release: 1.2)
        XCTAssertNil(tap.finger(at: 0.69))
        XCTAssertEqual(tap.finger(at: 0.85)?.isPressed, false)
        XCTAssertEqual(tap.finger(at: 0.85)?.opacity ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(tap.finger(at: 1.1), SceneTapFinger(target: "button", isPressed: true, opacity: 1))
        XCTAssertEqual(tap.finger(at: 1.2)?.isPressed, false, "it lifts at the release")
        XCTAssertNil(tap.finger(at: 1.5))
    }

    func testTypingIsEvenAndLandsOnTheWholeText() {
        XCTAssertEqual(SceneTyping.typed("abcd", from: 1, to: 2, at: 0.9), "")
        XCTAssertEqual(SceneTyping.typed("abcd", from: 1, to: 2, at: 1.5), "ab")
        XCTAssertEqual(SceneTyping.typed("abcd", from: 1, to: 2, at: 2), "abcd")
        XCTAssertEqual(SceneTyping.typed("abcd", from: 1, to: 2, at: 9), "abcd")
    }

    /// No two taps of a scene show a finger at the same time, and they come in order.
    private func assertTapsAreSequential<T>(_ taps: [SceneTap<T>], loopSeconds: Double,
                                            file: StaticString = #filePath, line: UInt = #line) {
        for (earlier, later) in zip(taps, taps.dropFirst()) {
            XCTAssertLessThanOrEqual(earlier.fingerOut, later.fingerIn, "\(earlier.target) → \(later.target)",
                                     file: file, line: line)
        }
        XCTAssertGreaterThanOrEqual(taps.first?.fingerIn ?? -1, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(taps.last?.fingerOut ?? .infinity, loopSeconds, file: file, line: line)
    }

    // MARK: - Voice notes

    private typealias VoiceNotes = VoiceNotesSceneScript

    func testVoiceNoteTapsDoNotOverlap() {
        assertTapsAreSequential(VoiceNotes.taps, loopSeconds: VoiceNotes.loopSeconds)
    }

    func testVoiceNotesLoopsWithinDecisionFourteen() {
        XCTAssertGreaterThanOrEqual(VoiceNotes.loopSeconds, 10)
        XCTAssertLessThanOrEqual(VoiceNotes.loopSeconds, 20)
    }

    func testVoiceNotesSharesThenInsertsThenAddsTheFavourite() {
        // The order of the taps is the story: share, insert, then the favourite.
        XCTAssertEqual(VoiceNotes.taps.map(\.target), [
            .voiceMessage, .shareAction, .moreApps, .dictusInList, .messageField, .insert,
            .moreApps, .editApps, .addDictus, .doneEditing
        ])
    }

    /// #680 acceptance: "The voice-notes scene ends on the share-sheet favourites".
    func testVoiceNotesEndsOnTheShareSheetWithDictusAsAFavourite() {
        let lastTap = VoiceNotes.taps.last
        XCTAssertEqual(lastTap?.target, .doneEditing)
        // From the last tap until the sheet goes down, the share sheet holds Dictus as a
        // favourite, with no other tap after it.
        let ending = times(VoiceNotes.loopSeconds).filter { $0 >= (lastTap?.release ?? 0) && $0 < 15.4 }
        XCTAssertFalse(ending.isEmpty)
        for time in ending {
            let frame = VoiceNotes.frame(at: time)
            XCTAssertEqual(frame.sheet, .share, "\(time)")
            XCTAssertTrue(frame.dictusIsFavourite, "\(time)")
            XCTAssertNil(frame.keyboard, "\(time)")
        }
        // It holds long enough to be read.
        XCTAssertGreaterThanOrEqual(15.4 - (lastTap?.release ?? 0), 2)
    }

    func testDictusIsNotAFavouriteUntilThePlusIsTapped() {
        for time in times(VoiceNotes.loopSeconds) where time < 11.6 {
            XCTAssertFalse(VoiceNotes.frame(at: time).dictusIsFavourite, "\(time)")
        }
    }

    func testTheAddButtonExistsOnlyInEditMode() {
        // The finger presses the + while the list is in edit mode, never before.
        let add = VoiceNotes.taps.first { $0.target == .addDictus }
        XCTAssertEqual(VoiceNotes.frame(at: add?.press ?? 0).sheet, .apps(isEditing: true))
        let edit = VoiceNotes.taps.first { $0.target == .editApps }
        XCTAssertEqual(VoiceNotes.frame(at: edit?.press ?? 0).sheet, .apps(isEditing: false))
    }

    func testEveryTapLandsOnSomethingOnScreen() {
        for tap in VoiceNotes.taps {
            let frame = VoiceNotes.frame(at: tap.press)
            switch tap.target {
            case .voiceMessage:
                XCTAssertNil(frame.sheet)
                XCTAssertFalse(frame.contextMenuIsOpen)
            case .shareAction:
                XCTAssertTrue(frame.contextMenuIsOpen)
            case .moreApps:
                XCTAssertEqual(frame.sheet, .share)
            case .dictusInList:
                XCTAssertEqual(frame.sheet, .apps(isEditing: false))
            case .messageField:
                XCTAssertNil(frame.sheet)
                XCTAssertNil(frame.keyboard)
            case .insert:
                XCTAssertEqual(frame.keyboard, .reader)
            case .editApps:
                XCTAssertEqual(frame.sheet, .apps(isEditing: false))
            case .addDictus, .doneEditing:
                XCTAssertEqual(frame.sheet, .apps(isEditing: true))
            }
        }
    }

    func testInsertClosesTheReaderAndFillsTheField() {
        // `KeyboardVoiceNoteState.insert` writes the transcript, then closes the reader.
        let insert = VoiceNotes.taps.first { $0.target == .insert }
        let after = VoiceNotes.frame(at: (insert?.release ?? 0) + 0.01)
        XCTAssertEqual(after.keyboard, .keys)
        XCTAssertTrue(after.fieldHasTranscript)
        XCTAssertFalse(VoiceNotes.frame(at: (insert?.press ?? 0)).fieldHasTranscript)
    }

    func testTheFieldIsClearedOnlyUnderASheet() {
        // Never seen emptying: it changes while the share sheet covers it.
        var previous = VoiceNotes.frame(at: 0).fieldHasTranscript
        for time in times(VoiceNotes.loopSeconds) {
            let frame = VoiceNotes.frame(at: time)
            if previous && !frame.fieldHasTranscript {
                XCTAssertNotNil(frame.sheet, "\(time)")
            }
            previous = frame.fieldHasTranscript
        }
    }

    func testTheVoiceNotesLoopClosesOnItself() {
        let start = VoiceNotes.frame(at: 0)
        let end = VoiceNotes.frame(at: VoiceNotes.loopSeconds - 0.01)
        XCTAssertNil(start.sheet)
        XCTAssertNil(end.sheet)
        XCTAssertNil(start.keyboard)
        XCTAssertNil(end.keyboard)
        XCTAssertFalse(start.fieldHasTranscript)
        XCTAssertFalse(end.fieldHasTranscript)
        XCTAssertNil(start.finger)
        XCTAssertNil(end.finger)
    }

    func testTheVoiceNotesStillIsTheReader() {
        let still = VoiceNotes.frame(at: VoiceNotes.stillSeconds)
        XCTAssertEqual(still.keyboard, .reader)
        XCTAssertNil(still.finger)
        XCTAssertNil(still.sheet)
    }

    // MARK: - Vocabulary

    private typealias Vocabulary = VocabularySceneScript
    private let term = "Dr Nguyen"
    private let variants = "docteur Nguyen"

    private func vocabulary(at time: Double) -> Vocabulary.Frame {
        Vocabulary.frame(at: time, term: term, variants: variants)
    }

    func testVocabularyTapsDoNotOverlap() {
        assertTapsAreSequential(Vocabulary.taps, loopSeconds: Vocabulary.loopSeconds)
        XCTAssertGreaterThanOrEqual(Vocabulary.loopSeconds, 10)
        XCTAssertLessThanOrEqual(Vocabulary.loopSeconds, 20)
    }

    func testSaveFollowsTheRealEntryRule() {
        // #536: a term alone changes nothing, so the real sheet keeps Save grey.
        XCTAssertFalse(Vocabulary.canSave(term: "Dr Nguyen", variants: ""))
        XCTAssertFalse(Vocabulary.canSave(term: "", variants: "docteur Nguyen"))
        XCTAssertFalse(Vocabulary.canSave(term: "Dr Nguyen", variants: "Dr Nguyen"))
        XCTAssertTrue(Vocabulary.canSave(term: "Dr Nguyen", variants: "d"))
    }

    func testSaveIsTappedOnlyOnceEnabled() {
        let save = Vocabulary.taps.first { $0.target == .save }
        let frame = vocabulary(at: save?.press ?? 0)
        XCTAssertTrue(frame.editorIsOpen)
        XCTAssertTrue(frame.canSave)
        XCTAssertEqual(frame.term, term)
        XCTAssertEqual(frame.variants, variants)
        // And it was grey while only the term was typed.
        let variantsTap = Vocabulary.taps.first { $0.target == .variantsField }
        XCTAssertFalse(vocabulary(at: variantsTap?.press ?? 0).canSave)
    }

    func testTheFieldsAreTypedInOrder() {
        let termTap = Vocabulary.taps.first { $0.target == .termField }
        XCTAssertEqual(vocabulary(at: termTap?.release ?? 0).focusedField, .termField)
        XCTAssertEqual(vocabulary(at: termTap?.release ?? 0).term, "")
        XCTAssertEqual(vocabulary(at: 3.4).term, term)
        XCTAssertEqual(vocabulary(at: 3.4).variants, "")
        XCTAssertEqual(vocabulary(at: 5.7).variants, variants)
        XCTAssertEqual(vocabulary(at: 5.7).focusedField, .variantsField)
    }

    func testSavingListsTheNewTermThenTheLoopRemovesIt() {
        let save = Vocabulary.taps.first { $0.target == .save }
        let after = vocabulary(at: (save?.release ?? 0) + 0.01)
        XCTAssertFalse(after.editorIsOpen)
        XCTAssertTrue(after.newTermIsListed)
        XCTAssertFalse(vocabulary(at: 0).newTermIsListed)
        XCTAssertFalse(vocabulary(at: Vocabulary.loopSeconds - 0.01).newTermIsListed)
        XCTAssertFalse(vocabulary(at: Vocabulary.loopSeconds - 0.01).editorIsOpen)
    }

    func testTheVocabularyStillIsTheListWithTheNewTerm() {
        let still = vocabulary(at: Vocabulary.stillSeconds)
        XCTAssertTrue(still.newTermIsListed)
        XCTAssertFalse(still.editorIsOpen)
        XCTAssertNil(still.finger)
    }

    // MARK: - History

    private typealias History = HistorySceneScript

    func testHistoryTapsDoNotOverlap() {
        assertTapsAreSequential(History.taps, loopSeconds: History.loopSeconds)
        XCTAssertGreaterThanOrEqual(History.loopSeconds, 10)
        XCTAssertLessThanOrEqual(History.loopSeconds, 20)
    }

    func testTheSearchIsTypedThenClosed() {
        XCTAssertFalse(History.frame(at: 0.5, word: "dentiste").isSearching)
        XCTAssertEqual(History.frame(at: 0.5, word: "dentiste").query, "")
        XCTAssertTrue(History.frame(at: 1.6, word: "dentiste").isSearching)
        XCTAssertEqual(History.frame(at: 1.6, word: "dentiste").query, "")
        XCTAssertEqual(History.frame(at: 3.5, word: "dentiste").query, "dentiste")
        XCTAssertEqual(History.frame(at: 7.6, word: "dentiste").query, "")
        XCTAssertFalse(History.frame(at: 7.6, word: "dentiste").isSearching)
    }

    func testTheQueryOnlyGrows() {
        var previous = ""
        for time in times(History.loopSeconds) {
            let query = History.frame(at: time, word: "dentiste").query
            if !query.isEmpty {
                XCTAssertTrue(query.hasPrefix(previous), "\(time)")
            }
            previous = query
        }
    }

    func testTheCardsAreTheOnesTheAppWouldFind() {
        let records = [
            TranscriptionRecord(text: "Penser à rappeler le dentiste.", language: "fr", durationSeconds: 9,
                                sttProvider: "PK"),
            TranscriptionRecord(text: "Coucou, on dîne ensemble ce soir.", language: "fr", durationSeconds: 14,
                                sttProvider: "PK"),
            TranscriptionRecord(text: "Le DENTISTE a dit de revenir.", language: "fr", durationSeconds: 6,
                                sttProvider: "PK")
        ]
        let found = History.visibleRecords(records, query: "dentiste")
        XCTAssertEqual(found.map(\.id), [records[0].id, records[2].id])
        XCTAssertEqual(History.visibleRecords(records, query: "").count, 3)
    }

    func testTheHistoryStillIsTheSearchResult() {
        let still = History.frame(at: History.stillSeconds, word: "dentiste")
        XCTAssertTrue(still.isSearching)
        XCTAssertEqual(still.query, "dentiste")
        XCTAssertNil(still.finger)
    }

    func testTheHistoryLoopClosesOnItself() {
        let start = History.frame(at: 0, word: "dentiste")
        let end = History.frame(at: History.loopSeconds - 0.01, word: "dentiste")
        XCTAssertEqual(start, end)
    }
}
