// DictusApp/Views/InKeyboardDictationInfoView.swift
import DictusCore
import SwiftUI

/// Settings > Experiments > How dictation works (spike, #992).
///
/// Which engine transcribes depends on whether DictusApp is running when the user taps
/// the keyboard's mic, and the user cannot see that. This screen says it once, in plain
/// words: what each case uses, what works in both, and what only the app can do.
struct InKeyboardDictationInfoView: View {
    /// `InKeyboardLanguageEligibility.storedValue`, written by the app when either
    /// language changes. Absent reads as covered: no line.
    @AppStorage(SharedKeys.inKeyboardLanguageEligibility, store: UserDefaults(suiteName: AppGroup.identifier))
    private var eligibility = "covered"

    var body: some View {
        List {
            if eligibility == "notCovered" {
                Section {
                    Text("Your dictation language is not available for Apple's dictation, so the keyboard opens the app, as before.")
                }
            } else if eligibility == "speechTranscriberUnavailable" {
                Section {
                    Text("Apple's dictation is not available on this iPhone, so the keyboard opens the app, as before.")
                }
            } else if eligibility == "autoDetect" {
                Section {
                    Text("With automatic language detection, the keyboard opens the app, as before: Apple's dictation needs one language.")
                }
            }
            Section {
                Text("The keyboard dictates by itself with Apple's dictation, on your iPhone. Your voice stays on your iPhone.")
            } header: {
                Text("When the Dictus app is closed")
            }
            Section {
                Text("Dictus uses the model you chose, such as Parakeet.")
            } header: {
                Text("When the Dictus app is open")
            }
            Section {
                Text("Your vocabulary, Polish transcription and Smart Modes work the same way.")
            } header: {
                Text("In both cases")
            }
            Section {
                Text("The Dynamic Island and the Lock Screen activity appear only when the app is open.")
            } header: {
                Text("Only with the app")
            }
        }
        .navigationTitle("How dictation works")
        .navigationBarTitleDisplayMode(.inline)
    }
}
