// DictusCore/Sources/DictusCore/ReleaseNotes.swift
// One version's release notes, read from the file App Store Connect gets too (#974).
import Foundation

/// The release notes of one version in one language: `ReleaseNotes/<version>/<locale>.txt` at
/// the root of the repository, copied whole into the app bundle.
///
/// WHY ONE FILE FOR THE APP AND APP STORE CONNECT: the store's « What's New » and the app's
/// sheet tell the same version, written once and approved once. The app shows at most three
/// highlights, picked by Pierre at the version bump; App Store Connect gets the full list,
/// which `scripts/release-notes.sh` turns into its plain text. See `docs/release-notes.md`.
///
/// The format, blocks separated by a blank line:
///
///     Nouveautés de la 2.0.2
///
///     ## Highlights
///
///     Écrivez-nous depuis l'app
///     Réglages > À propos > Envoyer un retour.
///
///     ## All changes
///
///     Écrivez-nous depuis l'app
///     Réglages > À propos > Envoyer un retour, journal de débogage en option.
///
/// The first block is the title. `## Highlights` and `## All changes` (in English in every
/// language) open their sections; every block in a section is one change: a title, then one
/// sentence.
public struct ReleaseNotes: Equatable, Sendable {

    /// One change.
    public struct Item: Equatable, Sendable {
        public let title: String
        public let text: String
    }

    /// « Nouveautés de la 2.0.2 ».
    public let title: String
    /// What the app's sheet shows after the update: one to three changes.
    public let highlights: [Item]
    /// Every change, for App Store Connect and the Settings row.
    public let changes: [Item]

    /// The most highlights the sheet shows (#974, Pierre and Titus, 2026-11-19).
    public static let maxHighlights = 3

    /// The languages a version's notes are written in. Every other language reads English,
    /// as the app does (en-GB included, which App Store Connect gets from `en` too).
    public static let locales = ["fr", "en", "de", "es"]

    /// The folder's name inside the app bundle.
    public static let bundleFolder = "ReleaseNotes"

    static let highlightsHeading = "## Highlights"
    static let changesHeading = "## All changes"

    /// Reads the format above. Nil when the file is not exactly a title, then one to three
    /// highlights, then at least one change, so a broken file shows nothing rather than a
    /// half-drawn sheet.
    public init?(text: String) {
        let blocks = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .split(separator: "", omittingEmptySubsequences: true)
            .map(Array.init)
        guard blocks.first?.count == 1,
              blocks.count > 1, blocks[1] == [Self.highlightsHeading],
              let changesIndex = blocks.firstIndex(of: [Self.changesHeading]) else { return nil }
        // A block that is not "title, sentence" drops out of compactMap, and the counts no
        // longer match the blocks.
        let highlightBlocks = blocks[2..<changesIndex]
        let changeBlocks = blocks[(changesIndex + 1)...]
        let highlights = highlightBlocks.compactMap(Self.item)
        let changes = changeBlocks.compactMap(Self.item)
        guard highlights.count == highlightBlocks.count, (1...Self.maxHighlights).contains(highlights.count),
              changes.count == changeBlocks.count, !changes.isEmpty else { return nil }
        self.title = blocks[0][0]
        self.highlights = highlights
        self.changes = changes
    }

    /// One change from its block: a title and a sentence, nothing else.
    private static func item(_ block: [String]) -> Item? {
        block.count == 2 ? Item(title: block[0], text: block[1]) : nil
    }

    /// The notes file's language for an app language: « fr-CA » reads `fr`, anything not
    /// written reads `en`.
    public static func locale(forLanguage language: String?) -> String {
        let code = language?.split(separator: "-").first.map(String.init)?.lowercased()
        return code.flatMap { locales.contains($0) ? $0 : nil } ?? "en"
    }

    /// The notes of `version` in `language` from `directory` (the `ReleaseNotes` folder), nil
    /// when that version has none.
    public static func load(version: String, language: String?, from directory: URL) -> ReleaseNotes? {
        let file = directory
            .appendingPathComponent(version, isDirectory: true)
            .appendingPathComponent(locale(forLanguage: language))
            .appendingPathExtension("txt")
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        return ReleaseNotes(text: text)
    }

    /// The running version's notes in the app's language, nil when it has none.
    ///
    /// WHY `preferredLocalizations`: it is the language the rest of the app speaks, the one
    /// chosen in iOS Settings for Dictus, not the device's.
    public static func current(bundle: Bundle = .main,
                               version: String = WhatsNew.runningVersion) -> ReleaseNotes? {
        guard let directory = bundle.url(forResource: bundleFolder, withExtension: nil) else { return nil }
        return load(version: version, language: bundle.preferredLocalizations.first, from: directory)
    }
}
