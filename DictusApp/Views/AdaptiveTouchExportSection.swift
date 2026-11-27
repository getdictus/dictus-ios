// DictusApp/Views/AdaptiveTouchExportSection.swift
// DEBUG-only: shares what Adaptive touch learned, the App Group file and a readable summary (#1081).
#if DEBUG
import DictusCore
import SwiftUI

/// The Developer section's « Exporter le toucher adaptatif » button.
///
/// WHY a button in the app: the file lives in the App Group container, which `devicectl`
/// could not copy from the Mac on 2026-11-26 (container access policy), and the keyboard
/// extension cannot present a share sheet. The app reads the same container.
///
/// WHY `#if DEBUG` around the whole type: Release builds (TestFlight, App Store) must not
/// contain the button, its strings or the export code. Strings are verbatim, so nothing
/// reaches the string catalogue, the same as `ProTrialDebugSection`.
struct AdaptiveTouchExportSection: View {
    /// The two files to share, wrapped for `.sheet(item:)`.
    private struct Export: Identifiable {
        let id = UUID()
        let files: [URL]
    }

    @State private var export: Export?
    @State private var message: String?

    var body: some View {
        Section {
            Button {
                run()
            } label: {
                Text(verbatim: "Exporter le toucher adaptatif")
            }
            .accessibilityIdentifier("settings.debug.exportAdaptiveTouch")
            .sheet(item: $export) { export in
                ShareSheet(items: export.files)
            }
        } footer: {
            if let message {
                Text(verbatim: message)
                    .foregroundColor(.orange)
                    .accessibilityIdentifier("settings.debug.exportAdaptiveTouch.message")
            } else {
                Text(verbatim: "Partage AdaptiveTouch/adaptive-touch.bin et son résumé (.txt) : taps appris, sessions, profil, actif, décalage max. Debug uniquement.")
            }
        }
    }

    private func run() {
        let source = AdaptiveTouchStore.defaultURL
        let resetAt = AdaptiveTouchStore.resetAt(AppGroup.defaults)
        message = "Préparation…"
        // Off the main thread: naming the keys tries every pitch of every letter page, about a
        // second in a Debug build.
        Task.detached(priority: .userInitiated) {
            let result = Self.prepare(source: source, resetAt: resetAt)
            await MainActor.run {
                switch result {
                case .success(let files):
                    message = nil
                    export = Export(files: files)
                case .failure(let failure):
                    message = failure.message
                }
            }
        }
    }

    private enum Failure: Error, Sendable {
        case noAppGroup
        case noFile(String)
        case notWritten(String)

        var message: String {
            switch self {
            case .noAppGroup:
                return "Pas de conteneur App Group : rien à exporter."
            case .noFile(let path):
                return "Aucun fichier \(path) : le clavier n'a encore rien appris (toucher adaptatif éteint, ou réinitialisé)."
            case .notWritten(let reason):
                return "Export impossible : \(reason)"
            }
        }
    }

    /// Copies the file into a temporary folder under a dated name, with the report beside it.
    /// A file that does not decode is still shared, and the report says so.
    nonisolated private static func prepare(source: URL?, resetAt: TimeInterval, now: Date = Date()) -> Result<[URL], Failure> {
        guard let source else { return .failure(.noAppGroup) }
        let shown = "AdaptiveTouch/\(source.lastPathComponent)"
        guard let data = FileManager.default.contents(atPath: source.path) else { return .failure(.noFile(shown)) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: now)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("adaptive-touch-export", isDirectory: true)
        let bin = folder.appendingPathComponent("adaptive-touch-\(stamp).bin")
        let txt = folder.appendingPathComponent("adaptive-touch-\(stamp).txt")
        var report = "Dictus adaptive touch export, \(stamp), \(shown), \(data.count) bytes\n"
        if let model = AdaptiveTouchModel(data: data) {
            // The file holds no letters: its keys are named from the letter page whose rows give
            // the geometry's hash, the same way the decode tool names them.
            let matches = AdaptiveTouchGeometry.identify(model)
            for (geometry, match) in matches.sorted(by: { $0.key < $1.key }) {
                report += "geometry \(String(format: "%016llx", geometry)): \(match.page) letter page, key pitch "
                    + "\(match.pitch.width) x \(match.pitch.height) pt\n"
            }
            report += AdaptiveTouchStatus.report(model: model, letters: matches.mapValues(\.letters), resetAt: resetAt)
        } else {
            report += "unreadable: not a whole version-1 file of \(AdaptiveTouchModel.byteCount) bytes with a valid checksum\n"
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: bin, options: .atomic)
            try report.write(to: txt, atomically: true, encoding: .utf8)
        } catch {
            return .failure(.notWritten(error.localizedDescription))
        }
        return .success([bin, txt])
    }
}
#endif
