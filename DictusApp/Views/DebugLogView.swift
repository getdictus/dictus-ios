// DictusApp/Views/DebugLogView.swift
// Displays persistent debug logs from App Group file.
import SwiftUI
import DictusCore

/// Displays persistent debug logs that survive debugger disconnection.
///
/// WHY this view exists:
/// When the app is opened via URL scheme from the keyboard, iOS often kills
/// the Xcode debugger (Signal 9). os.log messages are lost. This view reads
/// from a persistent log file in the App Group container, allowing the user
/// to check what happened after the fact.
struct DebugLogView: View {
    @State private var logContent = ""

    var body: some View {
        ScrollView {
            if logContent.isEmpty || logContent == "(no logs)" {
                Text("Aucun log disponible")
                    .foregroundColor(.secondary)
                    .padding(.top, 40)
            } else {
                Text(logContent)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.dictusBackground.ignoresSafeArea())
        .navigationTitle("Debug Logs")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        PersistentLog.clear()
                        logContent = PersistentLog.read()
                    } label: {
                        Label("Effacer", systemImage: "trash")
                    }

                    Button {
                        UIPasteboard.general.string = logContent
                    } label: {
                        Label("Copier", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            logContent = PersistentLog.read()
        }
        .refreshable {
            logContent = PersistentLog.read()
        }
    }
}
