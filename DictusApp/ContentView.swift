// DictusApp/ContentView.swift
import SwiftUI
import DictusCore

struct ContentView: View {
    @EnvironmentObject var coordinator: DictationCoordinator
    @State private var diagnosticResult: DiagnosticResult?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Dictus")
                    .font(.largeTitle.bold())

                // Show dictation state when active
                if coordinator.status != .idle {
                    DictationStatusView(status: coordinator.status)
                }

                if let result = coordinator.lastResult {
                    Text("Last result: \(result)")
                        .font(.body)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
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
