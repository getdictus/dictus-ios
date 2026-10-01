// DictusApp/VoiceNotes/VoiceNoteSettingsView.swift
// The voice note defaults: one screen, ready to be pushed from the Pro hub (#620).
import SwiftUI
import DictusCore

/// Language and mode for shared voice notes (#620 decision 4: no choice screen at
/// share time, defaults set here instead).
///
/// ### Where it is mounted, and where it is going
///
/// The decision puts this in a section of the Dictus Pro hub (#216). The hub is in
/// open PRs (#614/#615) and not on `develop`, so this screen is self-contained and
/// is pushed for now from Settings › Pro Features, beside "Keyboard modes" and "My
/// terms". Once the hub lands, the hub's Voice notes card pushes this same view and
/// adds its `ProFeatureSwitchSection` on top, as it does for the other features.
///
/// WHY a `List` of sections and no switch of its own: Settings already draws the
/// feature's switch in its Pro Features section on `develop`, and the hub will draw
/// it above this content. A second switch here would be the one too many.
struct VoiceNoteSettingsView: View {

    @State private var settings = VoiceNoteSettings.load()

    var body: some View {
        List {
            VoiceNoteSettingsSections(settings: $settings)
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

    var body: some View {
        Section {
            Text("Long-press a voice message in WhatsApp, Telegram, Signal or Messages, tap Share, then Dictus. Audio files from Voice Memos, Files or Mail work the same way.")
                .font(.dictusCaption)
                .foregroundColor(.secondary)
        } header: {
            Text("How it works")
        }

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

        Section {
            Text("Voice notes up to 10 minutes. The audio is deleted as soon as it is transcribed, and everything stays on this iPhone.")
                .font(.dictusCaption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        VoiceNoteSettingsView()
    }
}
