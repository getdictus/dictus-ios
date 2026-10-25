// DictusCore/Sources/DictusCore/TurboMigration.swift
// Moves a device below the A15 off Whisper Turbo (#660).
import Foundation

/// The decision behind moving a pre-A15 device off Whisper Turbo (#660).
///
/// Argmax lists no Turbo variant below the A15, so Settings stopped offering it there. A user
/// who installed it under an earlier build is moved to the model recommended for their device,
/// without ever being left with nothing to dictate with: Turbo stays active until the target is
/// ready, its files go only once the target is active, and nothing downloads on a metered
/// network.
///
/// WHY ONLY ONE PERSISTED FIELD: every step is derived from what the device says now (the
/// active model, what is downloaded, the network), so a run cut short anywhere is picked up by
/// the next one with nothing to repair. The persisted `Phase` exists for the two facts the
/// device cannot answer on its own: that this install has started moving off Turbo, which is
/// what licenses deleting it once something else is active, and that the move is finished,
/// which is what stops it ever replaying.
public enum TurboMigration {

    /// The part that outlives the process, stored under `SharedKeys.turboMigrationPhase`.
    public enum Phase: String, Sendable {
        case notStarted, started, done
    }

    /// Where the target model is.
    public enum TargetStatus: Sendable {
        case missing
        /// A transfer or a compile is in flight, possibly adopted from a previous process.
        case downloading
        /// Listed as downloaded: selecting it runs at worst a compile, never a download.
        case ready
    }

    /// What the device says now.
    public struct Inputs: Sendable {
        public let isPreA15: Bool
        public let activeModel: String?
        public let downloadedModels: [String]
        /// The model to move to: the recommendation for this device and language.
        public let target: String
        public let targetStatus: TargetStatus
        /// Wi-Fi or wired, not cellular and not a personal hotspot.
        public let isOnUnmeteredNetwork: Bool

        public init(
            isPreA15: Bool,
            activeModel: String?,
            downloadedModels: [String],
            target: String,
            targetStatus: TargetStatus,
            isOnUnmeteredNetwork: Bool
        ) {
            self.isPreA15 = isPreA15
            self.activeModel = activeModel
            self.downloadedModels = downloadedModels
            self.target = target
            self.targetStatus = targetStatus
            self.isOnUnmeteredNetwork = isOnUnmeteredNetwork
        }
    }

    /// Where a step left the migration. The raw value is what the log prints.
    public enum State: String, Sendable {
        case notNeeded
        case started
        case pendingDownload
        case downloading
        case waitingForWiFi
        case readyToSwitch
        case switched
        case done
    }

    /// The one message the user gets, at the start.
    public enum Notice: Equatable, Sendable {
        /// The target is already on the device and becomes active right away.
        case switched(to: String)
        /// The target still has to download, over Wi-Fi; Turbo stays active until then.
        case pending(to: String)
    }

    public enum Action: Equatable, Sendable {
        case showNotice(Notice)
        case startDownload(String)
        case switchTo(String)
        case deleteModels([String])
    }

    public struct Step: Equatable, Sendable {
        public let state: State
        /// To persist once every action has succeeded.
        public let phase: Phase
        /// In order. A step with actions is followed by another step; one without is where
        /// the run stops until the next launch, activation, or change to the downloaded list.
        public let actions: [Action]
    }

    /// The next step from the persisted phase and what the device says now.
    public static func next(_ phase: Phase, _ inputs: Inputs) -> Step {
        guard phase != .done else { return Step(state: .done, phase: .done, actions: []) }
        guard inputs.isPreA15 else { return Step(state: .notNeeded, phase: phase, actions: []) }

        let onTurbo = inputs.activeModel.map(ModelInfo.turboIdentifiers.contains) ?? false

        switch (phase, onTurbo) {
        case (.notStarted, false):
            return Step(state: .notNeeded, phase: .notStarted, actions: [])
        case (.notStarted, true):
            let notice: Notice = inputs.targetStatus == .ready
                ? .switched(to: inputs.target)
                : .pending(to: inputs.target)
            return Step(state: .started, phase: .started, actions: [.showNotice(notice)])
        case (_, false):
            // Something other than Turbo is active: the target this migration selected or
            // downloaded, or a model the user picked meanwhile. Either way Turbo is no longer
            // in use, and only now may its files go.
            let turbos = inputs.downloadedModels.filter(ModelInfo.turboIdentifiers.contains)
            return Step(state: .switched, phase: .done, actions: [.deleteModels(turbos)])
        case (_, true):
            switch inputs.targetStatus {
            case .ready:
                return Step(state: .readyToSwitch, phase: .started, actions: [.switchTo(inputs.target)])
            case .downloading:
                return Step(state: .downloading, phase: .started, actions: [])
            case .missing where inputs.isOnUnmeteredNetwork:
                return Step(state: .pendingDownload, phase: .started, actions: [.startDownload(inputs.target)])
            case .missing:
                return Step(state: .waitingForWiFi, phase: .started, actions: [])
            }
        }
    }
}
