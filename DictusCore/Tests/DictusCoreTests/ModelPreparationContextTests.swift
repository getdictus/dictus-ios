import XCTest
@testable import DictusCore

final class ModelPreparationContextTests: XCTestCase {

    func testOnlyTapDrivenContextsUsePrepareOnlyFlow() {
        XCTAssertFalse(ModelPreparationContext.onboarding.isPrepareOnly)
        XCTAssertFalse(ModelPreparationContext.modelSelection.isPrepareOnly)
        XCTAssertTrue(ModelPreparationContext.keyboardColdStart.isPrepareOnly)
        XCTAssertTrue(ModelPreparationContext.appRecordTap.isPrepareOnly)
    }

    // MARK: - The two halves `isPrepareOnly` used to conflate (#484)

    /// The in-app tap is the case that separates them: it must not auto-start a recording,
    /// and the user never left Dictus. A `startedFromAnotherApp` that tracked `isPrepareOnly`
    /// would put "Return to your app and tap the microphone again." in front of someone who
    /// is looking at Dictus.
    func testOnlyTheKeyboardBringsTheUserFromAnotherApp() {
        XCTAssertTrue(ModelPreparationContext.keyboardColdStart.startedFromAnotherApp)
        XCTAssertFalse(ModelPreparationContext.appRecordTap.startedFromAnotherApp)
        XCTAssertFalse(ModelPreparationContext.onboarding.startedFromAnotherApp)
        XCTAssertFalse(ModelPreparationContext.modelSelection.startedFromAnotherApp)
    }

    /// Whatever else changes, the two flags must not collapse back into one: at least one
    /// context has to disagree with itself across them, or the split has been undone.
    func testTheTwoFlagsAreNotTheSameQuestion() {
        XCTAssertTrue(
            ModelPreparationContext.allCases.contains {
                $0.isPrepareOnly != $0.startedFromAnotherApp
            },
            "isPrepareOnly and startedFromAnotherApp agree on every context — the #484 split is gone"
        )
    }

    // MARK: - Gave up vs finished (#428, third review finding D)

    /// Both outcomes write `.idle`, so a screen that cannot tell them apart congratulates
    /// the user on a model that is not loaded — on the keyboard cold start this issue
    /// exists for. One reason means the app stopped waiting: the launch deadline.
    func testTheDeadlineIsTheWayTheAppStopsWaiting() {
        XCTAssertTrue(ModelPreparationOutcome.reasonMeansGaveUp(
            ModelPreparationOutcome.deadlineExpiredReason))
        XCTAssertEqual(ModelPreparationOutcome.gaveUpReasons.count, 1)
    }

    /// Every reason that means the load actually resolved must NOT be treated as giving
    /// up, or a finished load would stop showing its completion.
    func testAFinishedLoadIsNotGivingUp() {
        let finished = [
            "init-preload-success",
            "init-preload-failed",
            "didBecomeActive-success",
            "didBecomeActive-failed",
            "selectModel-proactive-success",
            "selectModel-proactive-failed",
            "init-preload",
            "stale-loading-cleared-at-launch"
        ]
        for reason in finished {
            XCTAssertFalse(
                ModelPreparationOutcome.reasonMeansGaveUp(reason),
                "\(reason) is a resolved load, not the app giving up on one"
            )
        }
    }

    /// The strings are shared constants precisely so the writer and the reader cannot
    /// drift. If someone retypes one at a call site, this is what notices.
    func testTheReasonsAreTheLiteralsTheCoordinatorWrites() {
        XCTAssertEqual(ModelPreparationOutcome.deadlineExpiredReason, "init-preload-deadline")
    }

    // MARK: - A `ready` nobody alive wrote (#579)

    /// The measured bug, as a table: a keyboard cold start reads `ready` at `onAppear`
    /// because the App Group kept the answer of a process iOS had already killed. Two
    /// seconds later the real load started; the screen was gone by then.
    func testAReadyLeftBehindByADeadProcessIsNotAFinishedPreparation() {
        XCTAssertFalse(ModelPreparationOutcome.preparationWasAlreadyReady(
            context: .keyboardColdStart,
            isModelOnDisk: true,
            loadState: .ready,
            loadStateIsFromThisLaunch: false
        ))
    }

    /// Freshness is the question, not the context. The load that lands between the
    /// keyboard's read and the app's presentation writes `ready` from a live process,
    /// and that value is a fact — the screen owes the user its checkmark and its exit,
    /// not a wait with nothing left to end it.
    func testAReadyThisLaunchWroteIsAFinishedPreparation() {
        for context in [ModelPreparationContext.keyboardColdStart, .appRecordTap] {
            XCTAssertTrue(
                ModelPreparationOutcome.preparationWasAlreadyReady(
                    context: context,
                    isModelOnDisk: true,
                    loadState: .ready,
                    loadStateIsFromThisLaunch: true
                ),
                "\(context.rawValue) hangs on a model that really is loaded"
            )
        }
    }

    /// No context escapes the freshness test — including the in-app tap, which cannot
    /// meet a stale value today only because the launch preload always writes first.
    /// Nothing should depend on that ordering staying true.
    func testNoContextIsAllowedToBelieveAStaleReady() {
        for context in ModelPreparationContext.allCases {
            XCTAssertFalse(
                ModelPreparationOutcome.preparationWasAlreadyReady(
                    context: context,
                    isModelOnDisk: true,
                    loadState: .ready,
                    loadStateIsFromThisLaunch: false
                ),
                "\(context.rawValue) celebrates a load state no live process wrote"
            )
        }
    }

    /// Onboarding and model selection raise this screen BEFORE their own work starts, so
    /// the `ready` they read is about the model they are replacing. `hasSeenWorkPhase` is
    /// what carries them, and this path must stay shut for them (the f5ba7ab race).
    func testOnlyPrepareOnlyContextsTakeThisPath() {
        for context in [ModelPreparationContext.onboarding, .modelSelection] {
            XCTAssertFalse(
                ModelPreparationOutcome.preparationWasAlreadyReady(
                    context: context,
                    isModelOnDisk: true,
                    loadState: .ready,
                    loadStateIsFromThisLaunch: true
                ),
                "\(context.rawValue) can now dismiss itself before its own work starts"
            )
        }
    }

    /// A load in flight and a load that failed are both the screen's whole reason to be
    /// up. Only `ready` ends it early.
    func testAnythingButReadyKeepsTheScreenUp() {
        for state in [ModelLoadState.loading, .idle] {
            XCTAssertFalse(
                ModelPreparationOutcome.preparationWasAlreadyReady(
                    context: .keyboardColdStart,
                    isModelOnDisk: true,
                    loadState: state,
                    loadStateIsFromThisLaunch: true
                ),
                "\(state.rawValue) was read as a finished preparation"
            )
        }
    }

    /// `ready` about RAM while the files are not on disk is not a preparation anyone can
    /// celebrate, and the download this screen is waiting for has not even started.
    func testAModelThatIsNotOnDiskIsNeverAlreadyPrepared() {
        XCTAssertFalse(ModelPreparationOutcome.preparationWasAlreadyReady(
            context: .keyboardColdStart,
            isModelOnDisk: false,
            loadState: .ready,
            loadStateIsFromThisLaunch: true
        ))
    }

}
