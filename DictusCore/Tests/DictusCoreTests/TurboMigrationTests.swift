// DictusCore/Tests/DictusCoreTests/TurboMigrationTests.swift
// Moving a pre-A15 device off Whisper Turbo (#660).
import XCTest
@testable import DictusCore

final class TurboMigrationTests: XCTestCase {

    private let turbo = "openai_whisper-large-v3-v20240930_turbo_632MB"
    private let legacyTurbo = "openai_whisper-large-v3_turbo_954MB"
    private let parakeet = "parakeet-tdt-0.6b-v3"
    private let small = "openai_whisper-small"

    /// A device the actions are applied to, run the way the app runs the machine: step,
    /// perform every action, persist the phase, and go on while the step says so.
    private struct Device {
        var isPreA15 = true
        var active: String?
        var downloaded: [String]
        var target: String
        var onWiFi = true
        var idle = true
        var downloadInFlight = false
        var downloadFails = false
        /// The model loaded in this launch. A switch or a finished download leaves the new
        /// active model unloaded until `load()`, like the app's asynchronous preload.
        var loaded: String?
        var phase: TurboMigration.Phase = .notStarted
        var notices: [TurboMigration.Notice] = []
        var log: [TurboMigration.Action] = []

        var inputs: TurboMigration.Inputs {
            TurboMigration.Inputs(
                isPreA15: isPreA15,
                activeModel: active,
                downloadedModels: downloaded,
                target: target,
                targetStatus: downloadInFlight ? .downloading
                    : downloaded.contains(target) ? .ready : .missing,
                isOnUnmeteredNetwork: onWiFi,
                isIdle: idle,
                isActiveModelLoaded: active != nil && loaded == active
            )
        }

        /// The preload of the active model finishes.
        mutating func load() { loaded = active }

        /// What the app sees over time: a run, then the load it started, then the run that
        /// load triggers.
        @discardableResult
        mutating func runAndLoad() -> [TurboMigration.State] {
            var states = run()
            if loaded != active {
                load()
                states += run()
            }
            return states
        }

        /// One app run: a launch, an activation, or a change to the downloaded list.
        @discardableResult
        mutating func run() -> [TurboMigration.State] {
            var states: [TurboMigration.State] = []
            for _ in 0..<8 {
                let step = TurboMigration.next(phase, inputs)
                states.append(step.state)
                for action in step.actions {
                    log.append(action)
                    guard perform(action) else { return states }
                }
                phase = step.phase
                if !step.continues { return states }
            }
            XCTFail("the migration did not settle")
            return states
        }

        private mutating func perform(_ action: TurboMigration.Action) -> Bool {
            switch action {
            case .showNotice(let notice):
                notices.append(notice)
            case .startDownload(let identifier):
                if downloadFails { return false }
                // Like ModelManager: a finished download becomes the active model.
                downloaded.append(identifier)
                active = identifier
            case .switchTo(let identifier):
                active = identifier
            case .deleteModels(let identifiers):
                downloaded.removeAll(where: identifiers.contains)
            }
            return true
        }
    }

    private func a14(active: String?, downloaded: [String], target: String? = nil) -> Device {
        Device(active: active, downloaded: downloaded, target: target ?? parakeet, loaded: active)
    }

    // MARK: - Who it applies to

    func testA15AndNewerAreUntouched() {
        var device = a14(active: turbo, downloaded: [turbo])
        device.isPreA15 = false

        XCTAssertEqual(device.run(), [.notNeeded])
        XCTAssertEqual(device.active, turbo)
        XCTAssertEqual(device.downloaded, [turbo])
        XCTAssertTrue(device.log.isEmpty)
        XCTAssertEqual(device.phase, .notStarted)
    }

    func testPreA15DeviceNotOnTurboIsUntouched() {
        var device = a14(active: small, downloaded: [small, turbo])

        XCTAssertEqual(device.run(), [.notNeeded])
        XCTAssertEqual(device.downloaded, [small, turbo], "Turbo is only deleted after a switch")
        XCTAssertTrue(device.log.isEmpty)
    }

    func testBothTurboVariantsAreMigrated() {
        var device = a14(active: legacyTurbo, downloaded: [legacyTurbo, parakeet])

        device.runAndLoad()

        XCTAssertEqual(device.active, parakeet)
        XCTAssertEqual(device.downloaded, [parakeet])
    }

    // MARK: - The three paths

    func testTargetAlreadyDownloadedSwitchesImmediately() {
        var device = a14(active: turbo, downloaded: [turbo, parakeet])

        // The switch ends the run; the target's load is what lets Turbo go.
        XCTAssertEqual(device.run(), [.started, .readyToSwitch])
        XCTAssertEqual(device.active, parakeet)
        XCTAssertEqual(device.downloaded, [turbo, parakeet], "Turbo stays until the target has loaded")
        device.load()
        XCTAssertEqual(device.run(), [.switched, .done])
        XCTAssertEqual(device.active, parakeet)
        XCTAssertEqual(device.downloaded, [parakeet])
        XCTAssertEqual(device.notices, [.switched(to: parakeet)])
        XCTAssertEqual(device.phase, .done)
    }

    func testTargetMissingOnWiFiDownloadsThenSwitches() {
        var device = a14(active: turbo, downloaded: [turbo])

        XCTAssertEqual(device.runAndLoad(), [.started, .pendingDownload, .waitingForLoad, .switched, .done])
        XCTAssertEqual(device.active, parakeet)
        XCTAssertEqual(device.downloaded, [parakeet])
        XCTAssertEqual(device.notices, [.pending(to: parakeet)])
    }

    func testTargetMissingOnCellularDoesNotDownload() {
        var device = a14(active: turbo, downloaded: [turbo])
        device.onWiFi = false

        XCTAssertEqual(device.run(), [.started, .waitingForWiFi])
        XCTAssertFalse(device.log.contains(.startDownload(parakeet)))
        XCTAssertEqual(device.active, turbo, "dictation keeps working on Turbo")
        XCTAssertEqual(device.phase, .started)

        // Still on cellular at the next launch: still waiting, no second notice.
        XCTAssertEqual(device.run(), [.waitingForWiFi])

        // Back on Wi-Fi: the download runs and the switch follows.
        device.onWiFi = true
        XCTAssertEqual(device.runAndLoad(), [.pendingDownload, .waitingForLoad, .switched, .done])
        XCTAssertEqual(device.active, parakeet)
        XCTAssertEqual(device.notices.count, 1)
    }

    func testDownloadFailureKeepsTurboAndRetriesLater() {
        var device = a14(active: turbo, downloaded: [turbo])
        device.downloadFails = true

        XCTAssertEqual(device.run(), [.started, .pendingDownload])
        XCTAssertEqual(device.active, turbo)
        XCTAssertEqual(device.downloaded, [turbo])
        XCTAssertEqual(device.phase, .started)

        device.downloadFails = false
        XCTAssertEqual(device.runAndLoad(), [.pendingDownload, .waitingForLoad, .switched, .done])
        XCTAssertEqual(device.active, parakeet)
    }

    // MARK: - Deletion only after the switch

    func testTurboIsNeverDeletedWhileActive() {
        for onWiFi in [true, false] {
            for downloadFails in [true, false] {
                for targetDownloaded in [true, false] {
                    var device = a14(active: turbo, downloaded: targetDownloaded ? [turbo, parakeet] : [turbo])
                    device.onWiFi = onWiFi
                    device.downloadFails = downloadFails
                    device.runAndLoad()
                    let deleted = device.log.contains { action in
                        if case .deleteModels(let ids) = action { return !ids.isEmpty }
                        return false
                    }
                    if deleted {
                        XCTAssertNotEqual(device.active, turbo)
                        XCTAssertTrue(device.downloaded.contains(device.active ?? ""),
                                      "the active model is on the device once Turbo is gone")
                    } else {
                        XCTAssertEqual(device.active, turbo)
                        XCTAssertTrue(device.downloaded.contains(turbo))
                    }
                }
            }
        }
    }

    func testAFailedDeletionIsRetriedAndThenDone() {
        let step = TurboMigration.next(.started, a14(active: parakeet, downloaded: [parakeet, turbo]).inputs)
        XCTAssertEqual(step.state, .switched)
        XCTAssertEqual(step.actions, [.deleteModels([turbo])])
        // The app persists `done` only once the deletion succeeded, so a failed one is
        // asked again by the next run, from `.started`.
        XCTAssertEqual(TurboMigration.next(.started, a14(active: parakeet, downloaded: [parakeet, turbo]).inputs),
                       step)
    }

    func testAModelTheUserPickedMeanwhileEndsTheMigration() {
        var device = a14(active: turbo, downloaded: [turbo, small])
        device.onWiFi = false
        device.run()

        device.active = small
        XCTAssertEqual(device.runAndLoad(), [.waitingForLoad, .switched, .done])
        XCTAssertEqual(device.downloaded, [small])
        XCTAssertEqual(device.active, small)
    }

    // MARK: - Idempotence

    func testNoReplayOnceDone() {
        var device = a14(active: turbo, downloaded: [turbo, parakeet])
        device.runAndLoad()
        XCTAssertEqual(device.phase, .done)
        let actionsSoFar = device.log.count

        // Even if Turbo came back somehow, a finished migration does nothing.
        device.downloaded.append(turbo)
        device.active = turbo
        XCTAssertEqual(device.run(), [.done])
        XCTAssertEqual(device.log.count, actionsSoFar)
    }

    func testResumesAfterAKillMidDownload() {
        var device = a14(active: turbo, downloaded: [turbo])
        // The first process persisted `.started`, began the download, and was killed.
        device.phase = .started
        device.downloadInFlight = true

        // The relaunch adopts the transfer still running: nothing to start a second time.
        XCTAssertEqual(device.run(), [.downloading])
        XCTAssertEqual(device.log, [])
        XCTAssertEqual(device.active, turbo)

        // The adopted transfer lands; ModelManager makes the target active.
        device.downloadInFlight = false
        device.downloaded.append(parakeet)
        device.active = parakeet
        XCTAssertEqual(device.runAndLoad(), [.waitingForLoad, .switched, .done])
        XCTAssertEqual(device.downloaded, [parakeet])
        XCTAssertTrue(device.notices.isEmpty, "the notice was the first process's")
    }

    func testAKillBetweenTheSwitchAndTheDeletionStillDeletes() {
        // `.started` is persisted before any switch can happen, so a process killed right
        // after selecting the target leaves a phase that still licenses the deletion.
        var device = a14(active: parakeet, downloaded: [turbo, parakeet])
        device.phase = .started

        XCTAssertEqual(device.run(), [.switched, .done])
        XCTAssertEqual(device.downloaded, [parakeet])
    }

    // MARK: - The notice

    func testNoticeIsShownExactlyOnceOnEveryPath() {
        let paths: [(onWiFi: Bool, targetDownloaded: Bool, failsFirst: Bool)] = [
            (true, true, false), (true, false, false), (false, false, false), (true, false, true)
        ]
        for path in paths {
            var device = a14(active: turbo, downloaded: path.targetDownloaded ? [turbo, parakeet] : [turbo])
            device.onWiFi = path.onWiFi
            device.downloadFails = path.failsFirst
            device.runAndLoad()
            device.onWiFi = true
            device.downloadFails = false
            device.runAndLoad()
            device.runAndLoad()
            XCTAssertEqual(device.phase, .done, "\(path)")
            XCTAssertEqual(device.notices.count, 1, "\(path)")
        }
    }

    // MARK: - Never under a dictation, never before the target has loaded

    func testADictationHoldsTheSwitchAndTheDeletion() {
        var device = a14(active: turbo, downloaded: [turbo, parakeet])
        device.idle = false

        XCTAssertEqual(device.run(), [.started, .waitingForIdle])
        XCTAssertEqual(device.active, turbo, "the engine is not switched under a dictation")

        device.idle = true
        XCTAssertEqual(device.run(), [.readyToSwitch])
        device.load()
        device.idle = false
        XCTAssertEqual(device.run(), [.waitingForIdle])
        XCTAssertTrue(device.downloaded.contains(turbo), "no deletion under a dictation")

        device.idle = true
        XCTAssertEqual(device.run(), [.switched, .done])
        XCTAssertEqual(device.downloaded, [parakeet])
    }

    func testADownloadThatLandsDuringADictationDeletesNothingUntilItEnds() {
        var device = a14(active: turbo, downloaded: [turbo])
        device.run()
        // The download finished and ModelManager adopted the target while a dictation ran.
        device.idle = false
        device.load()
        XCTAssertEqual(device.run(), [.waitingForIdle])
        XCTAssertTrue(device.downloaded.contains(turbo))
    }

    func testATargetThatNeverLoadsKeepsTurboOnTheDevice() {
        var device = a14(active: turbo, downloaded: [turbo, parakeet])
        device.run()
        device.run()
        device.run()

        XCTAssertEqual(device.active, parakeet)
        XCTAssertTrue(device.downloaded.contains(turbo))
        XCTAssertEqual(device.phase, .started, "the migration stays open until the target loads")
    }

    // MARK: - The persisted notice

    func testNoticeSurvivesARoundTripThroughItsStoredValue() {
        for notice in [TurboMigration.Notice.switched(to: parakeet), .pending(to: small)] {
            XCTAssertEqual(TurboMigration.Notice(storedValue: notice.storedValue), notice)
        }
        XCTAssertNil(TurboMigration.Notice(storedValue: ""))
        XCTAssertNil(TurboMigration.Notice(storedValue: "switched:"))
        XCTAssertNil(TurboMigration.Notice(storedValue: "other:\(parakeet)"))
    }

    // MARK: - The target

    /// The machine moves to whatever the app passes as the target, and the app passes the
    /// recommendation. On a pre-A15 device that is never Turbo, so the target is always a
    /// model the device can run.
    func testTheRecommendationOnAPreA15DeviceIsNeverTurboAndAlwaysRunnable() {
        let devices = [("iPhone13,3", 6), ("iPhone13,2", 4), ("iPhone12,1", 4), ("iPad13,4", 8)]
        for (identifier, ram) in devices {
            let capabilities = DeviceCapabilities(
                physicalMemoryGB: ram, availableMemoryMB: 3000,
                deviceModelIdentifier: identifier, thermalState: .nominal
            )
            XCTAssertTrue(capabilities.isPreA15, identifier)
            for language in ["fr", "en", "zh", "ja"] {
                let target = ModelInfo.recommendedIdentifier(forSpokenLanguage: language, on: capabilities)
                XCTAssertFalse(ModelInfo.turboIdentifiers.contains(target), "\(identifier) \(language)")
                XCTAssertEqual(ModelInfo.forIdentifier(target)?.isSupported(on: capabilities), true,
                               "\(identifier) \(language) → \(target)")
            }
        }
    }

    func testTurboIdentifiersAreBothCatalogueVariants() {
        XCTAssertEqual(ModelInfo.turboIdentifiers, [turbo, legacyTurbo])
        for identifier in ModelInfo.turboIdentifiers {
            XCTAssertNotNil(ModelInfo.forIdentifier(identifier), identifier)
        }
    }
}
