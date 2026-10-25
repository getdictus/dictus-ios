// DictusApp/Models/TurboMigrationRunner.swift
// Runs the move off Whisper Turbo on devices below the A15 (#660).
import Foundation
import Network
import DictusCore

/// Feeds `TurboMigration` what the device says and performs the actions it returns (#660).
///
/// The decisions live in DictusCore, where they are tested. This only reads inputs, runs
/// actions in order, and persists the phase once a step's actions all succeeded, so a step
/// that failed is asked again by the next run: a launch, an activation, or a change to the
/// downloaded list.
@MainActor
final class TurboMigrationRunner: ObservableObject {

    /// The one message, waiting for the screen to be free.
    @Published var notice: TurboMigration.Notice?

    private var isRunning = false

    func run(modelManager: ModelManager) async {
        guard !isRunning, DeviceCapabilities.current().isPreA15 else { return }
        isRunning = true
        defer { isRunning = false }

        let defaults = AppGroup.defaults
        var phase = defaults.string(forKey: SharedKeys.turboMigrationPhase)
            .flatMap(TurboMigration.Phase.init(rawValue:)) ?? .notStarted
        let target = ModelInfo.recommendedIdentifier()

        // Bounded: the longest path is started, readyToSwitch or pendingDownload, switched, done.
        for _ in 0..<5 {
            let step = TurboMigration.next(phase, await inputs(target: target, modelManager: modelManager))
            if step.state != .notNeeded, step.state != .done {
                PersistentLog.log(.turboMigration(step: step.state.rawValue, model: target))
            }
            for action in step.actions {
                guard await perform(action, modelManager: modelManager) else { return }
            }
            phase = step.phase
            defaults.set(phase.rawValue, forKey: SharedKeys.turboMigrationPhase)
            if step.actions.isEmpty { return }
        }
    }

    private func inputs(target: String, modelManager: ModelManager) async -> TurboMigration.Inputs {
        let status: TurboMigration.TargetStatus
        switch modelManager.modelStates[target] {
        case .downloading, .prewarming:
            status = .downloading
        default:
            status = modelManager.downloadedModels.contains(target) ? .ready : .missing
        }
        return TurboMigration.Inputs(
            isPreA15: true,
            activeModel: modelManager.activeModel,
            downloadedModels: modelManager.downloadedModels,
            target: target,
            targetStatus: status,
            isOnUnmeteredNetwork: status == .missing ? await Self.isOnUnmeteredNetwork() : false
        )
    }

    private func perform(_ action: TurboMigration.Action, modelManager: ModelManager) async -> Bool {
        switch action {
        case .showNotice(let notice):
            self.notice = notice
            return true
        case .startDownload(let identifier):
            do {
                try await modelManager.downloadModel(identifier)
                return true
            } catch {
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
