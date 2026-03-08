// DictusKeyboard/Views/FullAccessBanner.swift
import SwiftUI
import DictusCore

/// Non-dismissible info banner shown when Full Access is disabled.
/// Simple centered layout inspired by Super Whisper: keyboard icon + text.
/// Non-interactive — just informs the user to enable Full Access in Settings.
struct FullAccessBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "keyboard")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Acces complet requis")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
