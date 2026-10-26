// DictusApp/Models/TurboMigrationRunner.swift
// Runs the move off Whisper Turbo on devices below the A15 (#660).
import Foundation
import Network
import DictusCore

/// Feeds `TurboMigration` what the device says and performs the actions it returns (#660).
///
/// The decisions live in DictusCore, where they are tested. This only reads inputs, runs
/// actions in order, and persists the phase once a step's actions all succeeded, so a step
/// that failed is asked again by the next run: a launch, an activation, a change to the
/// downloaded list or the load state, the end of a dictation.
@MainActor
final class TurboMigrationRunner: ObservableObject {

    /// The one message, waiting for the screen to be free. Read back from the App Group, so
    /// a kill before the user dismissed it shows it at the next launch.
    @Published private(set) var notice = AppGroup.defaults.string(forKey: SharedKeys.turboMigrationNotice)
        .flatMap(TurboMigration.Notice.init(storedValue:))

    private var isRunning = false
    /// One attempt per launch: a download that failed is retried by the next one, not by
    /// every load or dictation that triggers a run in between.
    private var downloadFailedThisLaunch = false
    private var lastLoggedState: TurboMigration.State?

    func dismissNotice() {
        AppGroup.defaults.removeObject(forKey: SharedKeys.turboMigrationNotice)
        notice = nil
    }

    /// `isIdle` is asked before every step: a download can last minutes, and a dictation
    /// that started meanwhile must not see its engine switched or its files deleted.
    func run(modelManager: ModelManager, isIdle: () -> Bool) async {
        guard !isRunning, DeviceCapabilities.current().isPreA15 else { return }
        isRunning = true
        defer { isRunning = false }

        let defaults = AppGroup.defaults
        var phase = defaults.string(forKey: SharedKeys.turboMigrationPhase)
            .flatMap(TurboMigration.Phase.init(rawValue:)) ?? .notStarted
        let target = ModelInfo.recommendedIdentifier()

        // Bounded: the longest run is started, pendingDownload, then whatever follows the download.
        for _ in 0..<5 {
            let inputs = await inputs(target: target, modelManager: modelManager, isIdle: isIdle())
            let step = TurboMigration.next(phase, inputs)
            if step.state != .notNeeded, step.state != .done, step.state != lastLoggedState {
                PersistentLog.log(.turboMigration(step: step.state.rawValue, model: target))
                lastLoggedState = step.state
            }
            for action in step.actions {
                guard await perform(action, modelManager: modelManager) else { return }
            }
            phase = step.phase
            defaults.set(phase.rawValue, forKey: SharedKeys.turboMigrationPhase)
            if !step.continues { return }
        }
    }

    private func inputs(target: String, modelManager: ModelManager, isIdle: Bool) async -> TurboMigration.Inputs {
        let status: TurboMigration.TargetStatus
        switch modelManager.modelStates[target] {
        case .downloading, .prewarming:
            status = .downloading
        case .error:
            // Listed with files missing (#558) or a failed download: downloading again is
            // what repairs it, and switching to it would leave nothing that transcribes.
            status = .missing
        default:
            status = modelManager.downloadedModels.contains(target) ? .ready : .missing
        }
        return TurboMigration.Inputs(
            isPreA15: true,
            activeModel: modelManager.activeModel,
            downloadedModels: modelManager.downloadedModels,
            target: target,
            targetStatus: status,
            isOnUnmeteredNetwork: status == .missing ? await Self.isOnUnmeteredNetwork() : false,
            isIdle: isIdle,
            isActiveModelLoaded: modelManager.modelLoadState == .ready && modelManager.loadStateIsFromThisLaunch
        )
    }

    private func perform(_ action: TurboMigration.Action, modelManager: ModelManager) async -> Bool {
        switch action {
        case .showNotice(let notice):
            AppGroup.defaults.set(notice.storedValue, forKey: SharedKeys.turboMigrationNotice)
            self.notice = notice
            return true
        case .startDownload(let identifier):
            guard !downloadFailedThisLaunch else { return false }
            do {
                try await modelManager.downloadModel(identifier)
                return true
            } catch {
                downloadFailedThisLaunch = true
                PersistentLog.log(.turboMigration(step: "downloadFailed", model: identifier))
                return false
            }
        case .switchTo(let identifier):
            modelManager.selectModel(identifier)
            return modelManager.activeModel == identifier
        case .deleteModels(let identifiers):
            for identifier in identifiers {
                // `deleteModel` logs its own failure.
                guard (try? modelManager.deleteModel(identifier)) != nil else { return false }
                PersistentLog.log(.turboMigration(step: "turboFilesDeleted", model: identifier))
            }
            return true
        }
    }

    /// Whether the current path is Wi-Fi or wired: not cellular, not a personal hotspot, and
    /// not Low Data Mode. The migration downloads hundreds of megabytes the user did not ask
    /// for, so anything that may cost them waits.
    private static func isOnUnmeteredNetwork() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "solutions.pivi.dictus.turboMigration.path")
            var answered = false
            monitor.pathUpdateHandler = { path in
                guard !answered else { return }
                answered = true
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied && !path.isExpensive && !path.isConstrained)
            }
            monitor.start(queue: queue)
        }
    }
}
