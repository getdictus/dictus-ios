// DictusKeyboard/Views/EmojiCategoryBar.swift
import SwiftUI
import AudioToolbox
import DictusCore

/// Bottom bar for emoji picker matching Apple/SuperWhisper style:
/// ABC button (left) | search icon | category icons (center) | delete button (right).
/// Icons act as bookmarks into the continuous horizontal emoji grid.
struct EmojiCategoryBar: View {
    let sections: [CategoryInfo]
    let selectedCategoryID: String
    let onSelectCategory: (String) -> Void
    let onSearch: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // ABC button — return to letter keyboard (fixed left)
            Button {
                onDismiss()
            } label: {
                Text("ABC")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .fixedSize()

            // Search button (fixed)
            Button {
                HapticFeedback.keyTapped()
                onSearch()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(Color(.label))
                    .frame(width: 26, height: 26)
            }
            .fixedSize()

            // Category icons — scrollable to fit many categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sections) { section in
                        let isSelected = selectedCategoryID == section.id
                        Button {
                            onSelectCategory(section.id)
                        } label: {
                            Image(systemName: section.icon)
                                .font(.system(size: 16))
                                .foregroundColor(isSelected ? Color(.label) : Color(.tertiaryLabel))
                                .frame(width: 26, height: 26)
                                .background(
                                    Circle()
                                        .fill(isSelected ? Color(.systemGray4) : Color.clear)
                                )
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            // Delete button (fixed right)
            Button {
                HapticFeedback.keyTapped()
                AudioServicesPlaySystemSound(KeySound.delete)
                onDelete()
            } label: {
                Image(systemName: "delete.backward")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .fixedSize()
        }
        .frame(height: 36)
    }
}
