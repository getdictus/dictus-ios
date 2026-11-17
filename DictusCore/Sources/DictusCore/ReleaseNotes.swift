// DictusCore/Sources/DictusCore/ReleaseNotes.swift
// One version's release notes, read from the file App Store Connect gets too (#974).
import Foundation

/// The release notes of one version in one language: `ReleaseNotes/<version>/<locale>.txt` at
/// the root of the repository, copied whole into the app bundle.
///
/// WHY ONE FILE FOR THE APP AND APP STORE CONNECT: the text users read in the store's « What's
/// New » and the one the app shows after the update are the same words, written once and
/// approved once. The app shows each change as a symbol, a short title and one sentence;
/// `scripts/release-notes.sh` turns the same file into the store's plain text, one `• ` line
/// per change. See `docs/release-notes.md`.
///
/// The format, blocks separated by a blank line:
///
///     Nouveautés de la 2.0.2
///
///     envelope.fill
///     Écrivez-nous depuis l'app
///     Réglages > À propos > Envoyer un retour.
///
/// The first block is the title. Every other block is one change: an SF Symbol name, a title,
/// one sentence.
public struct ReleaseNotes: Equatable, Sendable {

    /// One change.
    public struct Item: Equatable, Sendable {
        /// An SF Symbol name, the same in every language.
        public let symbol: String
        public let title: String
        public let text: String
    }

    /// « Nouveautés de la 2.0.2 ».
    public let title: String
    public let items: [Item]

    /// The languages a version's notes are written in. Every other language reads English,
    /// as the app does (en-GB included, which App Store Connect gets from `en` too).
    public static let locales = ["fr", "en", "de", "es"]

    /// The folder's name inside the app bundle.
    public static let bundleFolder = "ReleaseNotes"

    /// Reads the format above. Nil when a block is not one line (the title) or three (a
    /// change), or when there is no change, so a broken file shows nothing rather than a
    /// half-drawn screen.
    public init?(text: String) {
        let blocks = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .split(separator: "", omittingEmptySubsequences: true)
            .map(Array.init)
        guard let head = blocks.first, head.count == 1 else { return nil }
        var items: [Item] = []
        for block in blocks.dropFirst() {
            guard block.count == 3 else { return nil }
            items.append(Item(symbol: block[0], title: block[1], text: block[2]))
        }
        guard !items.isEmpty else { return nil }
        self.title = head[0]
        self.items = items
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
