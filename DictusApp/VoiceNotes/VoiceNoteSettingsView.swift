// DictusApp/VoiceNotes/VoiceNoteSettingsView.swift
// The voice note defaults: one screen, ready to be pushed from the Pro hub (#620).
import SwiftUI
import DictusCore

/// Language and mode for shared voice notes (#620 decision 4: no choice screen at
/// share time, defaults set here instead).
///
/// ### Where it is mounted
///
/// Pushed from the Dictus Pro hub's Voice notes row (#216), like the other Pro
/// feature screens: the feature's switch first (`ProFeatureSwitchSection`), then the
/// defaults, dimmed and locked while the switch is off. Settings' provisional link to
/// it went away with its Pro Features section.
struct VoiceNoteSettingsView: View {

    @State private var settings = VoiceNoteSettings.load()

    /// The feature's switch, observed so the defaults dim and unlock as it moves
    /// (#216). The same object the switch above writes and the hub row reads.
    @ObservedObject private var switches = ProFeatureSwitches.shared

    /// Observed so an entitlement that changes while this screen is open (Pro lapsing,
    /// the DEBUG force flipped) relocks or unlocks it: `FeatureGate` reads the App
    /// Group, which publishes nothing.
    @EnvironmentObject private var proStatus: ProStatusManager

    /// Whether the defaults are live: `FeatureGate.isAvailable`, the one predicate,
    /// which the share extension reads too (`VoiceNoteAvailability`).
    private var isAvailable: Bool {
        _ = switches.isOn(.voiceNotes)
        _ = proStatus.isProActive
        return FeatureGate.isAvailable(.voiceNotes)
    }

    var body: some View {
        List {
            ProFeatureSwitchSection(feature: .voiceNotes)

            VoiceNoteSettingsSections(settings: $settings, isAvailable: isAvailable)
        }
        .navigationTitle("Voice notes")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings) { _, updated in
            updated.save()
        }
    }
}

/// The sections themselves, separate from the screen so the hub can host them under
/// its own switch without a second `List`.
struct VoiceNoteSettingsSections: View {

    @Binding var settings: VoiceNoteSettings

    /// Off, every section is dimmed and locked (#216 decision 5). Applied per
    /// section rather than on the whole group, so each List section carries it.
    var isAvailable = true

    var body: some View {
        Section {
            Text("Long-press a voice message in WhatsApp, Telegram, Signal or Messages, tap Share, then Dictus. Audio files from Voice Memos, Files or Mail work the same way.")
                .font(.dictusCaption)
                .foregroundColor(.secondary)
        } header: {
            Text("How it works")
        }
        .proFeatureContent(isAvailable: isAvailable)

        Section {
            Picker("Language", selection: $settings.language) {
                Text("Detect automatically").tag(VoiceNoteLanguage.autoDetect)
                ForEach(SupportedLanguage.allCases, id: \.self) { language in
                    Text(language.displayName).tag(VoiceNoteLanguage.fixed(language))
                }
            }
        } footer: {
            Text("Automatic detection transcribes each voice note in the language it was spoken in.")
        }
        .proFeatureContent(isAvailable: isAvailable)

        Section {
            Picker("After transcription", selection: $settings.mode) {
                Text("Transcript only").tag(VoiceNoteMode.transcriptOnly)
                ForEach(VoiceNoteSettings.availableModes) { mode in
                    Text(SmartModeListView.listName(for: mode)).tag(VoiceNoteMode.smartMode(mode.id))
                }
            }
        } footer: {
            Text("Shown above the transcript when you open the voice note. It uses Apple Intelligence, on this iPhone, and runs when you open the result.")
        }
        .proFeatureContent(isAvailable: isAvailable)

        Section {
            Text("Voice notes up to 10 minutes. The audio is deleted as soon as it is transcribed, and everything stays on this iPhone.")
                .font(.dictusCaption)
                .foregroundColor(.secondary)
        }
        .proFeatureContent(isAvailable: isAvailable)
    }
}

#Preview {
    NavigationStack {
        VoiceNoteSettingsView()
            .environmentObject(ProStatusManager())
    }
}
