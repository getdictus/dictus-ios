// DictusApp/Views/SmartModeListView.swift
// Choosing which Smart Modes the keyboard's long-press fan holds (issue #79).
import SwiftUI
import DictusCore

/// The mode list: which modes are in the keyboard's fan, and in what order.
///
/// ### Why pinning exists at all
///
/// The fan is not the catalogue. It holds Normal plus the modes the user pinned,
/// and it holds four entries because that is what fits above 44 pt on the smallest
/// supported screen — see `SmartModeFanLayout`. The catalogue is eight built-in modes
/// (four structure and register modes, four translation targets), plus any language the
/// user adds through "Other language…" (#622), and grows with #269, so a choice has to
/// be made somewhere. It is made here rather than in the keyboard because the keyboard
/// has 52 pt of chrome and no room for a settings screen, and because this is a
/// decision taken once rather than during a dictation.
///
/// ### Order is the user's
///
/// `SmartModeStore.setPinned` preserves it and `SmartModeCatalogue.pinnedModes`
/// honours it, so the fan draws the rows in the order arranged here. That is worth a
/// drag handle: the fan deploys downward from a top-right mic and the nearest row is
/// the cheapest to reach, so which mode sits first is a real ergonomic choice.
struct SmartModeListView: View {

    /// The pinned identifiers, in order. Local state so a reorder is smooth, written
    /// through to the App Group on every change — there is no Save button, and a
    /// screen the user backs out of must not lose what they just arranged.
    @State private var pinnedIdentifiers: [String] = SmartModeStore.pinnedIdentifiers

    /// The Translate modes the user added through "Other language…" (#622), most recent
    /// first. Local state for the reason `pinnedIdentifiers` is: the store publishes
    /// nothing, so the list re-reads it after every change it makes.
    @State private var addedTranslateModes: [SmartMode] = SmartModeCatalogue.addedTranslateModes

    /// Whether the "Other language…" sheet is up.
    @State private var isPickingLanguage = false

    /// Whether this iPhone can run Smart Modes at all. Read once: it cannot change
    /// while this screen is open, short of an OS update.
    private let deviceIsCapable = SmartModeAvailability.deviceIsCapable

    private var pinnedModes: [SmartMode] {
        pinnedIdentifiers.compactMap(SmartModeCatalogue.mode(withIdentifier:))
    }

    /// Every mode not in the fan: the built-ins in catalogue order, then the languages the
    /// user added, so the added rows sit right after the four built-in translations and
    /// right above "Other language…" — the translation group the brief places it in.
    private var unpinnedModes: [SmartMode] {
        (SmartModeCatalogue.builtIns + addedTranslateModes).filter { !pinnedIdentifiers.contains($0.id) }
    }

    private var isFull: Bool {
        pinnedIdentifiers.count >= SmartModeCatalogue.maximumPinnedModes
    }

    /// The feature's switch, observed so the content dims and unlocks as it moves
    /// (#216). The same object the switch above writes and the hub row reads.
    @ObservedObject private var switches = ProFeatureSwitches.shared

    /// Observed so an entitlement that changes while this screen is open (Pro lapsing,
    /// the DEBUG force flipped) relocks or unlocks it: `FeatureGate` reads the App
    /// Group, which publishes nothing.
    @EnvironmentObject private var proStatus: ProStatusManager

    /// The UI language, which the added rows name their language in.
    @Environment(\.locale) private var locale

    /// Whether the list below the switch is live: `FeatureGate.isAvailable`, the one
    /// predicate. Off, the arrangement stays visible and cannot be edited, since the
    /// keyboard applies none of it (#216 decision 5).
    private var isAvailable: Bool {
        _ = switches.isOn(.smartMode)
        _ = proStatus.isProActive
        return FeatureGate.isAvailable(.smartMode)
    }

    var body: some View {
        List {
            // The feature's switch, first (#216): this screen is reached from the
            // Dictus Pro hub's Smart Mode row, which carries no switch of its own.
            ProFeatureSwitchSection(feature: .smartMode)

            // What the feature does, and its demo (#686).
            ProFeatureHowItWorksSection(feature: .smartMode, isAvailable: isAvailable)

            if !deviceIsCapable {
                Section {
                    unsupportedNotice
                }
            }

            Section {
                if pinnedModes.isEmpty {
                    Text("No modes pinned. The keyboard will offer only Normal.")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(pinnedModes) { mode in
                        row(mode, isPinned: true)
                    }
                    .onMove(perform: move)
                }
            } header: {
                Text("In the keyboard fan")
            } footer: {
                Text(
                    "Hold the microphone on the keyboard to open these, then slide onto one. Up to \(SmartModeCatalogue.maximumPinnedModes), plus Normal."
                )
            }
            .proFeatureContent(isAvailable: isAvailable)

            // Never empty: the catalogue holds eight built-ins and the fan three, so this
            // section always carries at least five rows, then the "Other language…" entry.
            Section {
                ForEach(unpinnedModes) { mode in
                    row(mode, isPinned: false)
                }
                otherLanguageRow
            } header: {
                Text("Other modes")
            } footer: {
                if isFull {
                    Text("Remove one above to add another.")
                }
            }
            .proFeatureContent(isAvailable: isAvailable)
        }
        .navigationTitle("Smart Modes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPickingLanguage) {
            TranslationTargetPickerView { _ in
                addedTranslateModes = SmartModeCatalogue.addedTranslateModes
            }
        }
        .toolbar {
            // Only useful with something to reorder, and a lone EditButton over one
            // row reads as an unfinished screen.
            if pinnedModes.count > 1 {
                EditButton()
                    .disabled(!isAvailable)
            }
        }
    }

    // MARK: - Rows

    private func row(_ mode: SmartMode, isPinned: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: mode.icon)
                .foregroundColor(isPinned ? .dictusAccent : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(Self.listName(for: mode))
                    .foregroundColor(.primary)
                // An added language says which one in words (#622): "→ PT" is enough for
                // the four everyone knows, not for "→ MS" or "→ 繁". The name is the
                // system's, in the UI language. The four built-in rows are unchanged.
                if let target = Self.addedTarget(of: mode) {
                    Text(verbatim: TranslationTargetPickerView.listName(target, locale: locale))
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                toggle(mode, isPinned: isPinned)
            } label: {
                Image(systemName: isPinned ? "minus.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundColor(isPinned ? .secondary : .dictusAccent)
            }
            // `.borderless` and not `.plain`: inside a List row a plain button style
            // makes the whole row tappable, so a tap meant for the drag handle would
            // unpin instead.
            .buttonStyle(.borderless)
            .disabled(!isPinned && isFull)
            .opacity(!isPinned && isFull ? 0.35 : 1)
            .accessibilityLabel(
                isPinned
                    ? Text("Remove \(Self.listName(for: mode)) from the keyboard")
                    : Text("Add \(Self.listName(for: mode)) to the keyboard")
            )
        }
        .accessibilityIdentifier("smartModeRow.\(mode.id)")
        // An added language can be taken out of the list again; a built-in cannot. Only
        // from "Other modes": a pinned row is unpinned first, which is the gesture that
        // already exists there, and a swipe beside a drag handle invites the wrong one.
        .swipeActions(edge: .trailing) {
            if !isPinned, let target = Self.addedTarget(of: mode) {
                Button(role: .destructive) {
                    TranslationTargetStore.remove(target)
                    addedTranslateModes = SmartModeCatalogue.addedTranslateModes
                    pinnedIdentifiers = SmartModeStore.pinnedIdentifiers
                } label: {
                    Text("Remove", comment: "Swipe action that takes a translation language the user added out of the Smart Mode list (#622).")
                }
            }
        }
    }

    /// The row that opens "Other language…" (#622), at the end of the translation rows.
    private var otherLanguageRow: some View {
        Button {
            isPickingLanguage = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .foregroundColor(.dictusAccent)
                    .frame(width: 24)
                Text("Other language…", comment: "Row at the end of the Smart Mode list that opens the list of every other translation language (#622).")
                    .foregroundColor(.dictusAccent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityIdentifier("smartModes.otherLanguage")
    }

    /// The target of a Translate mode the user added, or nil for a built-in or any
    /// other mode.
    private static func addedTarget(of mode: SmartMode) -> TranslationTarget? {
        guard let target = SmartModeCatalogue.translateTarget(ofIdentifier: mode.id), target.builtIn == nil else {
            return nil
        }
        return target
    }

    /// The line a device that cannot run Smart Modes is owed, on the screen where it
    /// would otherwise silently arrange a fan that never works (#79).
    ///
    /// The list stays usable underneath. The choice persists, and it becomes real the
    /// day the user changes phone — hiding it would mean losing the arrangement they
    /// made, for no gain.
    private var unsupportedNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.secondary)

            Text("Smart Modes need Apple Intelligence, which this \(DeviceNoun.current) does not support. Your choices are saved for a device that does.")
                .font(.dictusCaption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Editing

    /// The list name, which is deliberately not the fan's.
    ///
    /// `SmartModeCatalogue` names translation modes "→ EN" so one string fits a 46 pt
    /// fan row in every UI locale. That is right there and wrong in a settings list,
    /// where there is width to spare and an arrow with no verb reads as a glyph
    /// rather than a mode. The catalogue's own doc comment leaves this to the app.
    static func listName(for mode: SmartMode) -> String {
        guard mode.id.hasPrefix("translate.") else { return mode.localizedDisplayName }
        // Through the catalog since #620: the plain interpolation it was showed
        // "Translate → EN" in a French UI, here and on the voice note card.
        return String(localized: "Translate \(mode.displayName)",
                      comment: "List name of a translation Smart Mode; the placeholder is the arrow and target, e.g. \"→ EN\".")
    }

    private func toggle(_ mode: SmartMode, isPinned: Bool) {
        var updated = pinnedIdentifiers
        if isPinned {
            updated.removeAll { $0 == mode.id }
        } else {
            guard updated.count < SmartModeCatalogue.maximumPinnedModes else { return }
            updated.append(mode.id)
        }
        apply(updated)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var updated = pinnedIdentifiers
        updated.move(fromOffsets: source, toOffset: destination)
        apply(updated)
    }

    /// Write through immediately.
    ///
    /// The store caps the list as well, and that duplication is deliberate: this
    /// screen enforces the cap so the user never sees a fourth row appear and vanish,
    /// and the store enforces it because it is the thing the keyboard reads.
    private func apply(_ identifiers: [String]) {
        pinnedIdentifiers = identifiers
        SmartModeStore.setPinned(identifiers)
    }
}
