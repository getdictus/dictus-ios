// DictusCore/VoiceNotes/VoiceNoteRoute.swift
import Foundation

/// Who transcribes a shared voice note (#992, voice notes without the app).
///
/// The share extension drops the note in the App Group inbox and waits 1.5 s for DictusApp
/// to take it. A running app takes it and transcribes with the model the user chose, as
/// before. When nothing takes it, the extension used to open Dictus; it now transcribes
/// the file itself with Apple's on-device model, under the same conditions as the
/// keyboard's own dictation — so the rule is the keyboard's (`InKeyboardDictationRoute`),
/// with "the app took the note" in place of "the app answered the start".
public enum VoiceNoteRoute: String, Equatable, Sendable {
    /// DictusApp took the note: today's path, unchanged.
    case appTookIt
    /// Nobody took it and the device can transcribe it on its own: the extension does.
    case shareExtension
    /// Nobody took it and the extension cannot: open Dictus, as before.
    case openApp

    public static func decide(appTookIt: Bool,
                              settingEnabled: Bool,
                              systemMajorVersion: Int,
                              localeInstalled: Bool?) -> VoiceNoteRoute {
        switch InKeyboardDictationRoute.decide(
            settingEnabled: settingEnabled,
            appAnswered: appTookIt,
            systemMajorVersion: systemMajorVersion,
            localeInstalled: localeInstalled
        ) {
        case .appIsRecording: return .appTookIt
        case .inKeyboard: return .shareExtension
        case .openAppURL, .microphoneDenied: return .openApp
        }
    }
}

/// What the share extension produced for a note it transcribed itself, left in the App
/// Group for DictusApp. The app adopts it — completing the note in its queue and running
/// what only it can run (the Smart Mode, the card) — instead of transcribing again.
public struct VoiceNoteExtensionResult: Codable, Equatable, Sendable {
    public let id: UUID
    public let transcript: String
    public let language: String
    public let durationSeconds: Int
    public let savedToHistory: Bool
    public let engine: String
    public let transcribedAt: Date

    public init(id: UUID, transcript: String, language: String, durationSeconds: Int,
                savedToHistory: Bool, engine: String, transcribedAt: Date = Date()) {
        self.id = id
        self.transcript = transcript
        self.language = language
        self.durationSeconds = durationSeconds
        self.savedToHistory = savedToHistory
        self.engine = engine
        self.transcribedAt = transcribedAt
    }

    static func directory(in storage: VoiceNoteStorage) -> URL {
        storage.root.appendingPathComponent("ExtensionResults", isDirectory: true)
    }

    static func file(for id: UUID, in storage: VoiceNoteStorage) -> URL {
        directory(in: storage).appendingPathComponent("\(id.uuidString).json")
    }

    public func write(to storage: VoiceNoteStorage) throws {
        try FileManager.default.createDirectory(at: Self.directory(in: storage), withIntermediateDirectories: true)
        try JSONEncoder.voiceNotes.encode(self).write(to: Self.file(for: id, in: storage), options: .atomic)
    }

    public static func read(_ id: UUID, from storage: VoiceNoteStorage) -> VoiceNoteExtensionResult? {
        guard let data = try? Data(contentsOf: file(for: id, in: storage)) else { return nil }
        return try? JSONDecoder.voiceNotes.decode(VoiceNoteExtensionResult.self, from: data)
    }

    public static func remove(_ id: UUID, from storage: VoiceNoteStorage) {
        try? FileManager.default.removeItem(at: file(for: id, in: storage))
    }
}
