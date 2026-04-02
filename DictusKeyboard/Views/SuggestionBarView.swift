// DictusKeyboard/Views/SuggestionBarView.swift
// Displays up to 3 word/accent suggestions in a horizontal row within the toolbar.
import SwiftUI

/// A 3-slot suggestion bar that appears in the toolbar while the user is typing.
///
/// WHY a separate view:
/// The suggestion bar has its own layout logic (equal-width slots, dividers,
/// bold center slot) that would clutter ToolbarView. Extracting it keeps
/// both views focused on a single responsibility.
///
/// WHY .frame(maxWidth: .infinity) per slot:
/// This ensures all slots take equal width regardless of text length,
/// matching Apple's native keyboard suggestion bar layout.
struct SuggestionBarView: View {
    let suggestions: [String]
    let mode: SuggestionMode
    let onTap: (Int) -> Void

    var body: some View {
        if suggestions.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    if index > 0 {
                        // Thin vertical divider between slots (Apple keyboard style)
                        Rectangle()
                            .fill(Color(.systemGray3))
                            .frame(width: 0.5)
                            .padding(.vertical, 8)
                    }

                    Button {
                        onTap(index)
                    } label: {
                        // In correction mode:
                        //   index 0 = original word in quotes (tapping keeps it as-is)
                        //   index 1 = bold correction (auto-applied on space)
                        //   index 2 = alternative correction
                        // In completion mode:
                        //   index 1 = bold (best completion)
                        //   others = regular weight
                        // This matches standard iOS keyboard suggestion bar behavior.
                        Text(displayText(suggestion, at: index))
                            .font(.system(size: 15))
                            .fontWeight(index == 1 ? .semibold : .regular)
                            .foregroundColor(Color(.label))
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: suggestions)
        }
    }

    /// In correction mode, the original word (index 0) is shown in quotes
    /// to indicate it's the "as-typed" option. Matches iOS native behavior
    /// where the unquoted bold center word is the one that gets auto-applied.
    private func displayText(_ suggestion: String, at index: Int) -> String {
        if mode == .corrections && index == 0 {
            return "\u{201C}\(suggestion)\u{201D}"
        }
        return suggestion
    }
}
