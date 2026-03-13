// DictusApp/Views/SoundSettingsView.swift
// Sound feedback settings sub-page: global toggle + 3 NavigationLink pickers.
import SwiftUI
import DictusCore

/// Settings sub-page for configuring recording sound feedback.
///
/// WHY NavigationLink to a picker list (not inline .menu Picker):
/// With 29 sounds, a .menu picker creates a scrollable dropdown overlay that's
/// hard to navigate and buggy on some devices. The iOS Settings pattern for many
/// choices is a NavigationLink that pushes a full-screen list with checkmarks
/// (like Settings > Sounds & Haptics > Ringtone). This also lets us auto-play
/// each sound when the user taps it, removing the need for a separate preview button.
struct SoundSettingsView: View {

    // MARK: - Preferences (App Group persisted)

    @AppStorage(SharedKeys.soundFeedbackEnabled, store: UserDefaults(suiteName: AppGroup.identifier))
    private var soundFeedbackEnabled = true

    @AppStorage(SharedKeys.recordStartSoundName, store: UserDefaults(suiteName: AppGroup.identifier))
    private var recordStartSoundName = "electronic_01a"

    @AppStorage(SharedKeys.recordStopSoundName, store: UserDefaults(suiteName: AppGroup.identifier))
    private var recordStopSoundName = "ui_chime_01"

    @AppStorage(SharedKeys.recordCancelSoundName, store: UserDefaults(suiteName: AppGroup.identifier))
    private var recordCancelSoundName = "electronic_02a"

    // MARK: - Body

    var body: some View {
        List {
            // Section 1: Global toggle
            Section {
                Toggle("Activer les sons", isOn: $soundFeedbackEnabled)
            } footer: {
                Text("Les sons respectent le bouton silencieux de l'iPhone.")
            }

            // Section 2: Sound pickers as NavigationLinks
            Section {
                soundNavigationRow(
                    label: "Début d'enregistrement",
                    selection: $recordStartSoundName
                )

                soundNavigationRow(
                    label: "Fin d'enregistrement",
                    selection: $recordStopSoundName
                )

                soundNavigationRow(
                    label: "Annulation",
                    selection: $recordCancelSoundName
                )
            }
            .disabled(!soundFeedbackEnabled)
        }
        .scrollContentBackground(.hidden)
        .background(Color.dictusBackground.ignoresSafeArea())
        .navigationTitle("Sons")
    }

    // MARK: - Private

    /// A NavigationLink row that shows the current selection and pushes a sound picker list.
    ///
    /// WHY NavigationLink with value display (not Picker):
    /// This follows the iOS Settings pattern: the row shows "Label" on the left and
    /// the current value on the right with a chevron. Tapping pushes a full list view
    /// where each sound has a checkmark and tapping plays a preview automatically.
    @ViewBuilder
    private func soundNavigationRow(label: String, selection: Binding<String>) -> some View {
        NavigationLink {
            SoundPickerListView(title: label, selection: selection)
        } label: {
            HStack {
                Text(label)
                Spacer()
                Text(SoundFeedbackService.displayName(for: selection.wrappedValue))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Sound Picker List View

/// Full-screen list of sounds with checkmark selection and auto-preview.
///
/// WHY a separate view (not inline):
/// NavigationLink destination needs its own view to manage the list and handle
/// auto-preview on selection. This is the same pattern as iOS ringtone picker:
/// tap a row → checkmark moves + sound plays.
private struct SoundPickerListView: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        List {
            ForEach(SoundFeedbackService.availableSounds(), id: \.self) { soundName in
                Button {
                    selection = soundName
                    SoundFeedbackService.play(soundName)
                } label: {
                    HStack {
                        Text(SoundFeedbackService.displayName(for: soundName))
                            .foregroundStyle(.primary)
                        Spacer()
                        if soundName == selection {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.dictusBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
