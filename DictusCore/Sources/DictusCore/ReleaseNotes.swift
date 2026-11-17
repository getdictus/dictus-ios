// DictusCore/Sources/DictusCore/ReleaseNotes.swift
// One version's release notes, read from the file App Store Connect gets too (#974).
import Foundation

/// The release notes of one version in one language: `ReleaseNotes/<version>/<locale>.txt` at
/// the root of the repository, copied whole into the app bundle.
///
/// WHY ONE FILE FOR THE APP AND APP STORE CONNECT: the text users read in the store's « What's
/// New » and the one the app shows after the update are the same words, written once and
/// approved once. `scripts/release-notes.sh` sends the file as it is; the app reads the same
/// file, so the two cannot drift. The format is the store's: a title line, then one `• ` line
/// per change. See `ReleaseNotes/README.md`.
public struct ReleaseNotes: Equatable, Sendable {

    /// The first line, « Nouveautés de la 2.0.2 ».
    public let title: String
    /// One entry per `• ` line, without the bullet.
    public let lines: [String]

    /// The languages a version's notes are written in. Every other language reads English,
    /// as the app does (en-GB included, which App Store Connect gets from `en` too).
    public static let locales = ["fr", "en", "de", "es"]

    /// The folder's name inside the app bundle.
    public static let bundleFolder = "ReleaseNotes"

    /// Reads the store's text: the first non-empty line is the title, every `• ` line after
    /// it is one change. Nil when there is no title or no change, so a broken file shows
    /// nothing rather than an empty screen.
    public init?(text: String) {
        let rows = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let title = rows.first else { return nil }
        let lines = rows.dropFirst()
            .filter { $0.hasPrefix("•") }
            .map { $0.dropFirst().trimmingCharacters(in: .whitespaces) }
        guard !lines.isEmpty else { return nil }
        self.title = title
        self.lines = lines
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
