import XCTest
@testable import DictusCore

/// The rule that answers a record tap arriving during a model load (#484).
///
/// The bug this replaces was a button that swallowed twelve taps in silence, so the tests
/// that matter are the ones that pin *which* taps get a screen and which are handed to the
/// coordinator — including the three statuses #458 says must never be covered.
final class RecordTapRoutingTests: XCTestCase {

    /// `warm: true` is the default so every test written before #542 keeps asking exactly
    /// the question it was written to ask: a model that has already run an inference in this
    /// install, which is what "the model is downloaded and fine" meant when they were written.
    private func decide(
        _ status: DictationStatus,
        downloaded: Bool = true,
        load: ModelLoadState = .loading,
        warm: Bool = true
    ) -> RecordTapRouting.Decision {
        RecordTapRouting.decide(
            dictationStatus: status,
            isModelDownloaded: downloaded,
            loadState: load,
            isModelWarm: warm
        )
    }

    // MARK: - The bug

    /// Home. `MainTabView` covers the tabs with `RecordingView` for every status but `.idle`,
    /// so a Home tap is always this one.
    func testAnIdleTapDuringALoadPresentsInsteadOfStarting() {
        XCTAssertEqual(decide(.idle), .presentPreparation)
    }

    /// The start-again mic on the result screen — the second entry point, and the one the
    /// gate's `status != .idle` would have refused. `.ready` is a finished dictation the user
    /// is choosing to leave; `.failed` is the cold-start refusal they are retrying.
    func testTheResultScreenTapPresentsToo() {
        XCTAssertEqual(decide(.ready), .presentPreparation)
        XCTAssertEqual(decide(.failed), .presentPreparation)
    }

    // MARK: - #458: a running dictation is never covered

    func testALiveDictationIsNeverGivenAPreparationScreen() {
        for status in [DictationStatus.recording, .transcribing, .processing] {
            XCTAssertEqual(
                decide(status), .startDictation,
                "\(status.rawValue) is a dictation still running — #458 forbids covering it"
            )
        }
    }

    /// The refusal list is the coordinator's own, not a second one written here. If
    /// `canStartNewDictation` ever changes its mind about a status, this notices.
    func testTheRefusalListIsTheCoordinatorsList() {
        for status in DictationStatus.allCases {
            let mayStart = ColdStartResolutionPolicy.canStartNewDictation(from: status)
            XCTAssertEqual(
                decide(status), mayStart ? .presentPreparation : .startDictation,
                "\(status.rawValue) routes differently from the dictation it would have started"
            )
        }
    }

    // MARK: - Everything that is not a load

    /// The ordinary path. Nothing about this issue may touch a tap made with a ready model.
    func testAReadyModelStartsDictationAsBefore() {
        for status in DictationStatus.allCases {
            XCTAssertEqual(decide(status, load: .ready), .startDictation)
            XCTAssertEqual(decide(status, load: .idle), .startDictation)
        }
    }

    /// No model on disk is an error the coordinator words, not a wait. A preparation screen
    /// here would name a model that can never become ready, on a screen with no exit (#428).
    func testNoModelDownloadedFallsThroughToTheCoordinatorsError() {
        XCTAssertEqual(decide(.idle, downloaded: false), .startDictation)
        XCTAssertEqual(decide(.ready, downloaded: false), .startDictation)
    }

    // MARK: - #542: the model file is present and the Core ML cache is not

    /// The bug itself. The App Group said `ready` because the model FILE was on disk; the
    /// compile had not started, because it starts when the app launches, which is the same
    /// instant the keyboard is handing off. A dictation ran into a 3 min 40 wait and was lost
    /// with no text and no history entry.
    func testAColdModelPresentsEvenThoughTheLoadStateSaysReady() {
        XCTAssertEqual(decide(.idle, load: .ready, warm: false), .presentPreparation)
    }

    /// `.idle` is the same story with the last load having failed rather than succeeded. The
    /// record, not the load state, is what says whether a transcription can happen now.
    func testAColdModelPresentsOnIdleToo() {
        XCTAssertEqual(decide(.idle, load: .idle, warm: false), .presentPreparation)
    }

    /// Decision 6, and the one that must not move: a dead app process with a warm cache is the
    /// ordinary cold start #23 just shipped. Refusing here would put a preparation screen in
    /// front of an 8-second load every time iOS killed the app, which is most of the time.
    func testAWarmModelIsUntouchedOnEveryLoadState() {
        for status in DictationStatus.allCases {
            XCTAssertEqual(decide(status, load: .ready, warm: true), .startDictation)
            XCTAssertEqual(decide(status, load: .idle, warm: true), .startDictation)
        }
    }

    /// Coldness never outranks the two questions asked before it. A dictation already running
    /// is still never covered (#458), and a missing model is still the coordinator's error to
    /// word rather than a wait that will never end (#428).
    func testColdnessDoesNotReorderTheQuestionsAboveIt() {
        for status in [DictationStatus.recording, .transcribing, .processing] {
            XCTAssertEqual(decide(status, load: .ready, warm: false), .startDictation)
        }
        XCTAssertEqual(decide(.idle, downloaded: false, load: .ready, warm: false), .startDictation)
    }

    /// A load in flight presents whatever the warmth record says, which is #484 unchanged.
    /// If this ever diverges, the cold-cache rule has been written into the wrong arm.
    func testALoadInFlightIsUnaffectedByTheWarmthRecord() {
        XCTAssertEqual(decide(.idle, load: .loading, warm: true), .presentPreparation)
        XCTAssertEqual(decide(.idle, load: .loading, warm: false), .presentPreparation)
    }
}
