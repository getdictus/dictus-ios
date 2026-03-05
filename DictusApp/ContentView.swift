// DictusApp/ContentView.swift
import SwiftUI
import DictusCore

struct ContentView: View {
    @EnvironmentObject var coordinator: DictationCoordinator
    @StateObject private var modelManager = ModelManager()
    @State private var diagnosticResult: DiagnosticResult?

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Dictus")
                        .font(.largeTitle.bold())

                    // Show last transcription result when idle
                    if let result = coordinator.lastResult, coordinator.status == .idle {
                        Text("Last result: \(result)")
                            .font(.body)
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                    }

                    // Get Started prompt when no model is downloaded yet
                    // WHY a prominent card instead of just a nav link:
                    // First-time users need clear guidance. Without a model,
                    // the app can't transcribe anything. This makes the first
                    // required action obvious.
                    if !modelManager.isModelReady {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.accentColor)
                            Text("Telecharger un modele pour commencer")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            NavigationLink("Gerer les modeles") {
                                ModelManagerView(modelManager: modelManager)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                    } else {
                        // Normal navigation to model manager
                        NavigationLink {
                            ModelManagerView(modelManager: modelManager)
                        } label: {
                            Label("Modeles", systemImage: "cpu")
                        }
                    }

                    Divider()

                    if let result = diagnosticResult {
                        DiagnosticView(result: result)
                    } else {
                        ProgressView("Running diagnostics...")
                    }
                }
                .padding()
                .navigationTitle("Dictus")
            }

            // Full-screen overlay when dictation is active
            // WHY a ZStack overlay instead of NavigationStack push:
            // RecordingView is a full-screen takeover (dark background, focused UI).
            // It doesn't belong in a navigation hierarchy — it appears when dictation
            // starts and disappears when it ends, like a modal.
            if coordinator.status != .idle {
                RecordingView()
                    .transition(.opacity)
            }
        }
        .task {
            diagnosticResult = AppGroupDiagnostic.run()
        }
    }
}

struct DiagnosticView: View {
    let result: DiagnosticResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                "App Group: \(result.appGroupID)",
                systemImage: result.containerExists ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundColor(result.containerExists ? .green : .red)

            Label(
                "Read: \(result.canRead ? "OK" : "Failed")",
                systemImage: result.canRead ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundColor(result.canRead ? .green : .red)

            Label(
                "Write: \(result.canWrite ? "OK" : "Failed")",
                systemImage: result.canWrite ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundColor(result.canWrite ? .green : .red)
        }
        .font(.system(.body, design: .monospaced))
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
        .environmentObject(DictationCoordinator.shared)
}
