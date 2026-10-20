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

    /// Pierre's device test of 2026-10-12: two chapters, the favourites once, then every
    /// voice note.
    func testVoiceNotesAddsTheFavouriteThenSharesAndInserts() {
        XCTAssertEqual(VoiceNotes.taps.map(\.target), [
            .moreApps, .editApps, .addDictus, .doneEditing,
            .voiceMessage, .shareAction, .dictusInRow, .messageField
        ])
    }

    func testEachTapBelongsToItsChapter() {
        let setUp: Set<VoiceNotes.Target> = [.moreApps, .editApps, .addDictus, .doneEditing]
        for tap in VoiceNotes.taps {
            let expected: VoiceNotes.Chapter = setUp.contains(tap.target) ? .setUp : .everyNote
            XCTAssertEqual(VoiceNotes.frame(at: tap.fingerIn).chapter, expected, "\(tap.target)")
            XCTAssertEqual(VoiceNotes.frame(at: tap.fingerOut - 0.01).chapter, expected, "\(tap.target)")
        }
    }

    /// The chapters change while the screen is faded out, so the caption and the chips
    /// never change over a moving picture.
    func testTheChapterChangesOnlyWhileTheScreenIsHidden() {
        var previous = VoiceNotes.frame(at: 0).chapter
        for time in times(VoiceNotes.loopSeconds) {
            let frame = VoiceNotes.frame(at: time)
            if frame.chapter != previous {
                XCTAssertLessThan(frame.screenOpacity, 0.05, "\(time)")
            }
            previous = frame.chapter
        }
        // And the loop's own wrap is a fade too.
        XCTAssertLessThan(VoiceNotes.frame(at: VoiceNotes.loopSeconds - 0.01).screenOpacity, 0.05)
        XCTAssertLessThan(VoiceNotes.frame(at: 0).screenOpacity, 0.05)
    }

    /// What a chapter leaves on screen at its end goes while the screen is dark, so the
    /// next chapter fades in on a clean conversation: the first chapter's share sheet, and
    /// the second chapter's keyboard at the loop's wrap.
    func testWhatAChapterLeavesGoesInTheDark() {
        var previous = VoiceNotes.frame(at: VoiceNotes.loopSeconds - 0.01)
        for time in times(VoiceNotes.loopSeconds) {
            let frame = VoiceNotes.frame(at: time)
            if previous.sheet != nil, frame.sheet == nil, previous.chapter == .setUp {
                XCTAssertEqual(frame.screenOpacity, 0, "the setup's sheet leaves at \(time)")
            }
            if previous.readerIsOpen, !frame.readerIsOpen {
                XCTAssertEqual(frame.screenOpacity, 0, "the keyboard leaves at \(time)")
            }
            previous = frame
        }
        // And the screen stays dark long enough for their 0.3 s slide to end unseen.
        XCTAssertNil(VoiceNotes.frame(at: 7.0).sheet)
        XCTAssertEqual(VoiceNotes.frame(at: 7.39).screenOpacity, 0)
        XCTAssertEqual(VoiceNotes.frame(at: 0.39).screenOpacity, 0)
    }

    func testNoTapHappensDuringAFade() {
        for tap in VoiceNotes.taps {
            for time in [tap.fingerIn, tap.press, tap.release, tap.fingerOut - 0.01] {
                XCTAssertEqual(VoiceNotes.frame(at: time).screenOpacity, 1, "\(tap.target) at \(time)")
            }
        }
    }

    func testTheFirstChapterEndsOnDictusLeadingTheShareSheet() {
        let done = VoiceNotes.taps.first { $0.target == .doneEditing }
        let held = times(VoiceNotes.loopSeconds).filter { $0 >= (done?.release ?? 0) && $0 < 6.7 }
        XCTAssertFalse(held.isEmpty)
        for time in held {
            let frame = VoiceNotes.frame(at: time)
            XCTAssertEqual(frame.sheet, .share, "\(time)")
            XCTAssertTrue(frame.dictusIsFavourite, "\(time)")
        }
        // Long enough to be read: about a second and a half.
        XCTAssertGreaterThanOrEqual(6.7 - (done?.release ?? 0), 1.5)
    }

    func testTheSecondChapterNeverGoesThroughMore() {
        for time in times(VoiceNotes.loopSeconds) where VoiceNotes.frame(at: time).chapter == .everyNote {
            let frame = VoiceNotes.frame(at: time)
            XCTAssertTrue(frame.dictusIsFavourite, "\(time)")
            if case .apps = frame.sheet {
                XCTFail("the list of apps is open at \(time)")
            }
        }
    }

    func testDictusIsNotAFavouriteUntilThePlusIsTapped() {
        let add = VoiceNotes.taps.first { $0.target == .addDictus }
        for time in times(VoiceNotes.loopSeconds) where time < (add?.release ?? 0) {
            XCTAssertFalse(VoiceNotes.frame(at: time).dictusIsFavourite, "\(time)")
        }
    }

    func testEveryTapLandsOnSomethingOnScreen() {
        for tap in VoiceNotes.taps {
            let frame = VoiceNotes.frame(at: tap.fingerIn)
            switch tap.target {
            case .moreApps:
                XCTAssertEqual(frame.sheet, .share)
                XCTAssertFalse(frame.dictusIsFavourite)
            case .editApps:
                XCTAssertEqual(frame.sheet, .apps(isEditing: false))
            case .addDictus, .doneEditing:
                XCTAssertEqual(frame.sheet, .apps(isEditing: true))
            case .voiceMessage:
                XCTAssertNil(frame.sheet)
                XCTAssertFalse(frame.contextMenuIsOpen)
            case .shareAction:
                XCTAssertTrue(VoiceNotes.frame(at: tap.press).contextMenuIsOpen)
            case .dictusInRow:
                XCTAssertEqual(frame.sheet, .share)
                XCTAssertTrue(frame.dictusIsFavourite)
            case .messageField:
                XCTAssertNil(frame.sheet)
                XCTAssertFalse(frame.readerIsOpen)
            }
        }
    }

    /// The scene ends on the reader holding the transcript (Pierre, second device test of
    /// 2026-10-12): no tap on *Insert*, the reader stays up to the loop's fade out.
    func testTheSceneEndsOnTheReaderHoldingTheTranscript() {
        let field = VoiceNotes.taps.first { $0.target == .messageField }
        XCTAssertEqual(VoiceNotes.taps.last?.target, .messageField)
        let held = times(VoiceNotes.loopSeconds).filter { $0 >= (field?.release ?? 0) }
        for time in held {
            let frame = VoiceNotes.frame(at: time)
            XCTAssertTrue(frame.readerIsOpen, "\(time)")
            XCTAssertNil(frame.sheet, "\(time)")
            XCTAssertEqual(frame.chapter, .everyNote, "\(time)")
        }
        // Held noticeably longer than any other beat: about three seconds in full view,
        // once the finger has gone.
        let fullyShown = held.filter {
            let frame = VoiceNotes.frame(at: $0)
            return frame.screenOpacity == 1 && frame.finger == nil
        }
        XCTAssertGreaterThanOrEqual(Double(fullyShown.count) * 0.01, 2.6)
    }

    func testTheVoiceNotesLoopStartsClean() {
        let start = VoiceNotes.frame(at: 0)
        XCTAssertEqual(start.chapter, .setUp)
        XCTAssertNil(start.sheet)
        XCTAssertFalse(start.readerIsOpen)
        XCTAssertFalse(start.dictusIsFavourite)
        XCTAssertNil(start.finger)
    }

    func testTheVoiceNotesStillIsTheReader() {
        let still = VoiceNotes.frame(at: VoiceNotes.stillSeconds)
        XCTAssertTrue(still.readerIsOpen)
        XCTAssertEqual(still.chapter, .everyNote)
        XCTAssertEqual(still.screenOpacity, 1)
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
