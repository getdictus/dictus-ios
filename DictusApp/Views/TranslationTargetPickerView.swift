// DictusApp/Views/TranslationTargetPickerView.swift
// "Other language…": choosing a Translate target beyond the four built-ins (issue #622).
import SwiftUI
import DictusCore

/// The sheet "Other language…" opens: every Translate target the four built-in modes do
/// not cover, the recently chosen ones first.
///
/// ### What choosing does, and what it does not
///
/// Choosing **adds a mode**, `translate.<code>`, to the mode list — option B of #622,
/// approved 2026-11-21. It does not pin it and it does not arm it: the mode list is where
/// a mode is pinned, the fan and the home picker are where it is armed, and a sheet that
/// did either would be a second, partial copy of those screens. The user comes back to
/// the list, finds the new row under "Other modes", and pins it like any other.
///
/// ### Why the names are not in the string catalog
///
/// Every language name comes from `Locale` in the UI language (`TranslationTarget.localizedName`),
/// so French reads "portugais" and English "Portuguese" with no entry per language, and
/// a later UI locale gets all 22 for free. The catalog only carries this screen's chrome.
struct TranslationTargetPickerView: View {

    /// Called with the target the user chose, after it is recorded.
    let onChoose: (TranslationTarget) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var query = ""

    private var order: (recent: [TranslationTarget], others: [TranslationTarget]) {
        TranslationTargetStore.pickerOrder(locale: locale)
    }

    /// A target matches on its name in the UI language, its English name or its code,
    /// so "port", "portu", "pt" and, in a French UI, "portugais" all find Portuguese.
    private func matches(_ target: TranslationTarget) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }
        return [target.localizedName(in: locale), target.englishName, target.code].contains {
            $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var body: some View {
        NavigationStack {
            List {
                let recent = order.recent.filter(matches)
                if !recent.isEmpty {
                    Section {
                        ForEach(recent, id: \.code, content: row)
                    } header: {
                        Text("Recent", comment: "Header of the recently chosen translation languages in the Other language sheet (#622).")
                    }
                }

                let others = order.others.filter(matches)
                if !others.isEmpty {
                    Section {
                        ForEach(others, id: \.code, content: row)
                    } header: {
                        Text("All languages", comment: "Header of every translation language not chosen yet, in the Other language sheet (#622).")
                    } footer: {
                        Text("The language is added to Other modes, where you can put it in the keyboard fan.",
                             comment: "Footer of the Other language sheet: choosing a language adds a Translate mode to the list, which the user then pins (#622).")
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text("Search languages", comment: "Search field prompt of the Other language sheet (#622)."))
            .navigationTitle(Text("Other language", comment: "Title of the sheet that adds a translation language beyond French, English, Spanish and German (#622)."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(_ target: TranslationTarget) -> some View {
        Button {
            TranslationTargetStore.choose(target)
            onChoose(target)
            dismiss()
        } label: {
            HStack {
                // `verbatim`: the name is the system's, already in the UI language, and
                // must not be looked up as a catalog key.
                Text(verbatim: Self.listName(target, locale: locale))
                    .foregroundColor(.primary)
                Spacer()
                Text(verbatim: target.shortCode)
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityIdentifier("translationTargetPicker.\(target.code)")
    }
}

extension TranslationTargetPickerView {

    /// The system's name for `target` as a list entry: its first letter capitalised,
    /// since French writes language names in lower case ("portugais") and a row label
    /// starts with a capital. Only the first letter — "Chinois simplifié", not
    /// "Chinois Simplifié".
    static func listName(_ target: TranslationTarget, locale: Locale) -> String {
        let name = target.localizedName(in: locale)
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }
}

#Preview {
    TranslationTargetPickerView { _ in }
}
