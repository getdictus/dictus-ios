// DictusApp/VoiceNotes/VoiceNoteResultView.swift
// One voice note pushed on its own, from History (#620).
import SwiftUI
import DictusCore

/// A voice note opened from History: the same card the stack shows, alone.
///
/// History is where read voice notes live (#620 rework, 2026-10-01), so this is the
/// way back to one. Opening it here counts as reading it, exactly as in the stack.
struct VoiceNoteResultView: View {

    let noteID: UUID

    var body: some View {
        VoiceNoteCardView(noteID: noteID, isActive: true)
            .background(Color.dictusBackground.ignoresSafeArea())
            .navigationTitle("Voice note")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "stack", action: "present",
                                                   details: "source=history ids=\(noteID.uuidString.prefix(8))"))
            }
    }
}
