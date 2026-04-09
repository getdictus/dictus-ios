// DictusApp/Views/SettingsView.swift
// iOS-style grouped settings list with preferences persisted via App Group.
import SwiftUI
import UIKit
import DictusCore

/// Settings screen with 3 sections: Transcription, Keyboard, About.
///
/// WHY @AppStorage with App Group store:
/// Preferences need to be readable by both the main app AND the keyboard extension.
/// @AppStorage with the App Group suite writes to the shared UserDefaults container,
/// making preferences available across processes without any additional sync logic.
///
/// WHY grouped List style:
/// iOS standard settings pattern — users immediately recognize the familiar
/// grouped rows with section headers and footers.
struct SettingsView: View {

    @EnvironmentObject var proStatus: ProStatusManager

    // MARK: - Preferences (App Group persisted)

    @AppStorage(SharedKeys.language, store: UserDefaults(suiteName: AppGroup.identifier))
    private var language = "fr"

    @AppStorage(SharedKeys.keyboardLayout, store: UserDefaults(suiteName: AppGroup.identifier))
    private var keyboardLayout = "azerty"

    @AppStorage(SharedKeys.hapticsEnabled, store: UserDefaults(suiteName: AppGroup.identifier))
    private var hapticsEnabled = true

    @AppStorage(SharedKeys.activeModel, store: UserDefaults(suiteName: AppGroup.identifier))
    private var activeModel = "openai_whisper-small"

    /// WHY default true: Most users expect autocorrect to be active by default.
    /// Power users who find it annoying can toggle it off here.
    @AppStorage(SharedKeys.autocorrectEnabled, store: UserDefaults(suiteName: AppGroup.identifier))
    private var autocorrectEnabled = true

    @AppStorage(SharedKeys.liveActivityEnabled, store: UserDefaults(suiteName: AppGroup.identifier))
    private var liveActivityEnabled = true

    /// Whether the currently active model uses the Parakeet engine (CTC/TDT).
    /// Parakeet auto-detects language — the language picker has no effect on it.
    private var isParakeetActive: Bool {
        ModelInfo.forIdentifier(activeModel)?.engine == .parakeet
    }

    /// Tracks log export async operation for spinner display.
    @State private var isExporting = false
    @State private var exportURL: URL?

    // MARK: - Body

    var body: some View {
        List {
            // Section 0: Dictus Pro — always first
            Section {
                NavigationLink {
                    PaywallView()
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.dictusAccent)
                        Text("Dictus Pro")
                        Spacer()
                        if ProConfig.effectiveBeta {
                            Text("BETA")
                                .font(.dictusCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.dictusAccent)
                                .clipShape(Capsule())
                                .accessibilityLabel("Beta — all features free")
                        } else if proStatus.isProActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.dictusSuccess)
                                .accessibilityLabel("Pro active")
                        }
                    }
                }
            }

            // Section 1: Transcription
            Section {
                Picker("Transcription language", selection: $language) {
                    Text("Fran\u{00E7}ais").tag("fr")
                    Text("English").tag("en")
                    Text("Espa\u{00F1}ol").tag("es")
                }
                .onChange(of: language) { _, newLang in
                    // Auto-switch keyboard layout to the language's default.
                    // French -> AZERTY, English/Spanish -> QWERTY.
                    if let lang = SupportedLanguage(rawValue: newLang) {
                        keyboardLayout = lang.defaultLayout.rawValue
                    }
                }
                if isParakeetActive {
                    Text("Parakeet automatically detects the spoken language. This setting only applies to Whisper models.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Transcription")
            }

            // Section 2: Clavier
            // All toggles are always visible — there's only one keyboard type now.
            Section {
                DefaultLayerPicker()

                Picker("Layout", selection: $keyboardLayout) {
                    Text("AZERTY").tag("azerty")
                    Text("QWERTY").tag("qwerty")
                }

                Toggle("Haptic feedback", isOn: $hapticsEnabled)

                NavigationLink("Sounds") {
                    SoundSettingsView()
                }

                Toggle("Autocorrect", isOn: $autocorrectEnabled)

                Toggle("Live Activity", isOn: $liveActivityEnabled)
                    .onChange(of: liveActivityEnabled) { _, enabled in
                        if !enabled {
                            LiveActivityManager.shared.stopStandbyActivity()
                        }
                    }
            } header: {
                Text("Keyboard")
            } footer: {
                if !liveActivityEnabled {
                    Text("Dynamic Island and Lock Screen notification are disabled.")
                }
            }

            // Section 3: Pro Features
            Section("Pro Features") {
                ForEach(ProFeature.allCases, id: \.self) { feature in
                    if proStatus.isProActive || ProConfig.effectiveBeta {
                        // Unlocked: show toggle
                        Toggle(isOn: Binding(
                            get: { AppGroup.defaults.bool(forKey: feature.settingsKey) },
                            set: { AppGroup.defaults.set($0, forKey: feature.settingsKey) }
                        )) {
                            HStack(spacing: 8) {
                                Image(systemName: feature.icon)
                                    .foregroundColor(.dictusAccent)
                                Text(LocalizedStringKey(feature.displayName))
                            }
                        }
                    } else {
                        // Locked: show lock + PRO pill, tap opens paywall
                        NavigationLink {
                            PaywallView()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: feature.icon)
                                    .foregroundColor(.secondary)
                                Text(LocalizedStringKey(feature.displayName))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.dictusAccent)
                                    .accessibilityHidden(true)
                                Text("PRO")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 6)
                                    .background(Color.dictusAccent)
                                    .clipShape(Capsule())
                                    .accessibilityLabel("Pro feature")
                            }
                        }
                    }
                }
            }

            // Section 4: A propos
            Section("About") {
                LabeledContent("Version", value: appVersion)

                // WHY Button instead of Link:
                // Link doesn't respond to ButtonStyle and gets no press highlight
                // in a List with .scrollContentBackground(.hidden). Using Button
                // with UIApplication.shared.open gives native row press feedback.
                Button {
                    UIApplication.shared.open(URL(string: "https://github.com/Pivii/dictus")!)
                } label: {
                    HStack {
                        Text("GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink("Licenses") {
                    LicensesView()
                }

                NavigationLink("Diagnostic") {
                    diagnosticView
                }

                NavigationLink("Debug Logs") {
                    DebugLogView()
                }

                Button {
                    exportLogs()
                } label: {
                    HStack {
                        Text("Export logs")
                        Spacer()
                        if isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(isExporting)

                #if DEBUG
                Toggle(isOn: Binding(
                    get: { AppGroup.defaults.bool(forKey: SharedKeys.debugForceFreeTier) },
                    set: { newValue in
                        AppGroup.defaults.set(newValue, forKey: SharedKeys.debugForceFreeTier)
                        // Re-evaluate Pro status immediately so all UI updates
                        proStatus.setProActive(AppGroup.defaults.bool(forKey: SharedKeys.proActive))
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "ladybug")
                            .foregroundColor(.orange)
                        Text("Force Free Tier")
                    }
                }
                #endif
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.dictusBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .sheet(isPresented: Binding(
            get: { exportURL != nil },
            set: { isPresented in
                if !isPresented {
                    exportURL = nil
                }
            }
        )) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    // MARK: - Private

    /// Export logs via iOS share sheet.
    ///
    /// WHY write to a temp file instead of sharing raw text:
    /// UIActivityViewController with a file URL shows the file name ("dictus-logs.txt")
    /// in the share sheet and lets the user save, AirDrop, or attach it to email/GitHub.
    /// Raw text sharing doesn't give a meaningful filename.
    /// WHY async with isExporting flag:
    /// Log gathering reads from disk and can take a moment on large log files.
    /// The spinner gives visual feedback that something is happening. The share
    /// sheet presentation must happen on the main thread (UIKit requirement).
    private func exportLogs() {
        guard !isExporting else { return }
        isExporting = true
        Task {
            let start = CFAbsoluteTimeGetCurrent()
            let content = PersistentLog.exportContent()
            let duration = CFAbsoluteTimeGetCurrent() - start
            PersistentLog.log(.logExportCompleted(durationMs: Int(duration * 1000), sizeBytes: content.utf8.count))
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("dictus-logs.txt")
            try? content.write(to: tempURL, atomically: true, encoding: .utf8)

            await MainActor.run {
                isExporting = false
                exportURL = tempURL
            }
        }
    }

    /// App version string from Info.plist.
    ///
    /// WHY Bundle.main.infoDictionary:
    /// This reads CFBundleShortVersionString (marketing version like "1.0")
    /// directly from the compiled Info.plist. It updates automatically when
    /// the version is bumped in Xcode project settings.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Diagnostic detail view showing App Group health.
    ///
    /// WHY inline computation:
    /// DiagnosticDetailView requires a DiagnosticResult, which we compute
    /// on demand by running the diagnostic check. This is cheap (reads/writes
    /// a single UserDefaults key) and always shows fresh results.
    private var diagnosticView: some View {
        DiagnosticDetailView(result: AppGroupDiagnostic.run())
            .navigationTitle("Diagnostic")
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
