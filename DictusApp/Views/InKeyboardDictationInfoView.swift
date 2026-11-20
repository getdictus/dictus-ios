// DictusApp/Views/InKeyboardDictationInfoView.swift
import SwiftUI

/// Settings > Experiments > How dictation works (spike, #992).
///
/// Which engine transcribes depends on whether DictusApp is running when the user taps
/// the keyboard's mic, and the user cannot see that. This screen says it once, in plain
/// words: what each case uses, what works in both, and what only the app can do.
struct InKeyboardDictationInfoView: View {
    var body: some View {
        List {
            Section {
                Text("The keyboard dictates by itself with Apple's dictation, on your iPhone. Nothing leaves your iPhone.")
            } header: {
                Text("When the Dictus app is closed")
            }
            Section {
                Text("Dictus transcribes with the model you chose in Models, such as Parakeet or Whisper.")
            } header: {
                Text("When the Dictus app is open")
            }
            Section {
                Text("Your vocabulary, Polish transcription and Smart Modes apply to your text.")
            } header: {
                Text("In both cases")
            }
            Section {
                Text("The Dynamic Island and the Lock Screen activity only appear when the app is open.")
            } header: {
                Text("Only with the app")
            }
        }
        .navigationTitle("How dictation works")
        .navigationBarTitleDisplayMode(.inline)
    }
}
