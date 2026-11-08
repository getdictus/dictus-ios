// DictusCore/Tests/DictusCoreTests/SettingsFrenchCopyTests.swift
// The Settings strings that reached a French iPhone in English (#792), pinned in
// the app's catalogue and at their call site.

import XCTest

/// #792 found two defects behind the same symptom, English on a French Settings
/// screen. The polish footer was built as a `String`, which `Text` shows verbatim
/// whatever the catalogue says; and a handful of keys sat in the catalogue with no
/// French value at all. DictusApp has no test bundle and a catalogue is data, so this
/// reads the repo, the way `SmartModeLanguageCopyTests` does for #490.
final class SettingsFrenchCopyTests: XCTestCase {

    private static let catalogue = "DictusApp/Localizable.xcstrings"
    private static let settingsSource = "DictusApp/Views/SettingsView.swift"

    /// Every Settings string #792 found without a French value. The polish footer's
    /// six sentences, one per `PolishAvailabilityState` that has a message, are all
    /// here: the simulator shows only one of them, so the catalogue is the only place
    /// the other five can be checked.
    private static let keys = [
        "Apple Intelligence is required for polish. Enable it in iPhone Settings → Apple Intelligence & Siri. Apple requires Siri and your iPhone to use the same language — if Siri is in English and your iPhone is in French (or vice versa), Apple Intelligence stays off.",
        "The Apple Intelligence model is downloading on your device. Try again in a few minutes.",
        "Apple Intelligence isn't supported on this device. Polish requires an iPhone 15 Pro / 15 Pro Max or newer.",
        "Polish requires iOS 26 or later.",
        "Polish isn't available in this build of Dictus.",
        "Apple Intelligence is unavailable (%@).",
        "Open iPhone Settings",
        "Reset learned words",
        "Reset learned words?",
        "Forget %lld learned words",
        "Words the keyboard learned from your typing will be forgotten and autocorrect will apply to them again.",
        "Live Activity",
        "Dynamic Island and Lock Screen notification are disabled."
    ]

    func testEverySettingsKeyHasAFrenchValue() throws {
        let strings = try catalogueStrings()
        for key in Self.keys {
            let entry = try XCTUnwrap(strings[key], "the catalogue has no entry for \(key)")
            let values = frenchValues(of: entry)
            XCTAssertFalse(values.isEmpty, "no French value for \(key)")
            for value in values {
                XCTAssertNotEqual(value, key, "the French value is the English source: \(key)")
                XCTAssertFalse(value.contains("—"), "no em dashes in user-facing copy: \(value)")
            }
        }
    }

    /// The format arguments survive translation, so the French sentence still shows
    /// Apple's reason and the word count.
    func testFrenchValuesKeepTheirPlaceholders() throws {
        let strings = try catalogueStrings()
        for key in Self.keys {
            let entry = try XCTUnwrap(strings[key])
            for placeholder in ["%@", "%lld"] where key.contains(placeholder) {
                for value in frenchValues(of: entry) {
                    XCTAssertTrue(value.contains(placeholder), "\(value) drops \(placeholder)")
                }
            }
        }
    }

    /// The footer has to reach `Text` as a key. Returned as a `String`, it is shown
    /// verbatim and the catalogue entries above are never read, which is how #792
    /// shipped with the sentences sitting in the code.
    func testThePolishFooterIsLookedUpAsAKey() throws {
        let source = try String(
            contentsOf: repoRoot().appendingPathComponent(Self.settingsSource), encoding: .utf8
        )
        XCTAssertTrue(
            source.contains("func polishStateMessage(for state: PolishAvailabilityState) -> LocalizedStringKey"),
            "the polish footer is no longer a LocalizedStringKey, so Text will show it untranslated"
        )
    }

    // MARK: - Reading the repo

    /// The French `stringUnit` values of an entry, or every plural form's when the
    /// entry varies by count.
    private func frenchValues(of entry: [String: Any]) -> [String] {
        guard let localizations = entry["localizations"] as? [String: Any],
              let french = localizations["fr"] as? [String: Any] else { return [] }
        if let unit = french["stringUnit"] as? [String: Any], let value = unit["value"] as? String {
            return [value]
        }
        let plural = (french["variations"] as? [String: Any])?["plural"] as? [String: Any] ?? [:]
        return plural.values.compactMap {
            (($0 as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
        }
    }

    private func catalogueStrings() throws -> [String: [String: Any]] {
        let data = try Data(contentsOf: repoRoot().appendingPathComponent(Self.catalogue))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["strings"] as? [String: [String: Any]]) ?? [:]
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // DictusCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // DictusCore
            .deletingLastPathComponent()  // repo root
    }
}
