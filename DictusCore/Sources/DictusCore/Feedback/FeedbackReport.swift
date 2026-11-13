// DictusCore/Sources/DictusCore/Feedback/FeedbackReport.swift
// The in-app feedback form's data (#565): what the user writes, what the device
// adds, and the JSON body `POST /api/feedback` accepts.
import Foundation

/// The three kinds the form offers. The raw values are the contract's `type`.
public enum FeedbackKind: String, CaseIterable, Sendable {
    case bug, idea, other
}

/// Why the form cannot be sent yet. Each one matches a server-side `400`, so a
/// draft with no problem never meets one.
public enum FeedbackDraftProblem: Hashable, Sendable {
    case nameMissing, nameTooLong, emailInvalid, emailTooLong, messageMissing, messageTooLong
}

/// What the user typed, kept as typed so nothing is lost between edits.
/// The cleaned values the server sees are derived on demand.
public struct FeedbackDraft: Equatable, Sendable {
    public var kind: FeedbackKind = .bug
    public var name = ""
    public var email = ""
    public var message = ""
    /// Off for every kind until the user turns it on (#939 security review):
    /// the log leaves the device only by an explicit choice.
    public var attachesLog = false

    public init() {}

    public var problems: Set<FeedbackDraftProblem> {
        var problems: Set<FeedbackDraftProblem> = []
        let name = cleanName
        if name.isEmpty { problems.insert(.nameMissing) }
        if name.unicodeScalars.count > FeedbackLimits.name { problems.insert(.nameTooLong) }
        let email = cleanEmail
        // The server measures the email in UTF-16 units (JavaScript `length`).
        if email.utf16.count > FeedbackLimits.email {
            problems.insert(.emailTooLong)
        } else if !email.isEmpty, email.wholeMatch(of: #/[^\s@]+@[^\s@]+\.[^\s@]+/#) == nil {
            problems.insert(.emailInvalid)
        }
        let message = cleanMessage
        if message.isEmpty { problems.insert(.messageMissing) }
        if message.unicodeScalars.count > FeedbackLimits.message { problems.insert(.messageTooLong) }
        return problems
    }

    /// How many characters the message is over the cap, for the form to say so.
    public var messageOverflow: Int {
        max(0, cleanMessage.unicodeScalars.count - FeedbackLimits.message)
    }

    var cleanName: String { Self.trimmed(name.removingControlCharacters(keepingLineBreaks: false)) }
    var cleanEmail: String { Self.trimmed(email.removingControlCharacters(keepingLineBreaks: false)) }
    var cleanMessage: String { Self.trimmed(message.removingControlCharacters(keepingLineBreaks: true)) }

    /// JavaScript's `trim()` also strips U+FEFF, which Foundation's set does not.
    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(["\u{FEFF}"]))
    }
}

/// The server's caps (getdictus/dictus-website `docs/feedback-api.md`).
public enum FeedbackLimits {
    public static let name = 100
    public static let email = 254
    public static let message = 4000
    public static let logBytes = 1_572_864
    public static let bodyBytes = 2_097_152
}

/// What the app says about itself in every report. Shown in the form before Send.
public struct FeedbackDeviceInfo: Equatable, Sendable {
    public let appVersion: String
    public let build: String
    public let gitRevision: String
    public let iosVersion: String
    public let deviceModel: String
    public let locale: String

    /// Each value is cut down to the character set the server accepts, so a
    /// branch name in the revision or an odd locale cannot turn a report into a `400`.
    public init(appVersion: String, build: String, gitRevision: String,
                iosVersion: String, deviceModel: String, locale: String) {
        self.appVersion = Self.restricted(appVersion, to: "._+-", max: 32)
        self.build = Self.restricted(build, to: "._-", max: 32)
        // `PersistentLog.codeRevision` reads `sha@branch`; `@` and `/` are refused.
        let sha = gitRevision.split(separator: "@", maxSplits: 1).first.map(String.init) ?? ""
        self.gitRevision = Self.restricted(sha, to: "._+-", max: 64)
        self.iosVersion = Self.restricted(iosVersion, to: " .()_+-", max: 64)
        self.deviceModel = Self.restricted(deviceModel, to: " ,._()+-", max: 64)
        self.locale = locale.wholeMatch(of: Self.localeShape) != nil && locale.count <= 64 ? locale : "und"
    }

    private static let localeShape =
        #/[A-Za-z]{2,3}(?:[_-][A-Za-z0-9]{2,8})*(?:@[A-Za-z0-9]+=[A-Za-z0-9-]+(?:;[A-Za-z0-9]+=[A-Za-z0-9-]+)*)?/#

    private static func restricted(_ value: String, to punctuation: String, max: Int) -> String {
        let kept = value.filter { $0.isASCII && ($0.isLetter || $0.isNumber || punctuation.contains($0)) }
        let cut = String(kept.prefix(max)).trimmingCharacters(in: .whitespaces)
        return cut.isEmpty ? "unknown" : cut
    }
}

/// The JSON body of `POST /api/feedback`. Built only from a draft with no problem.
public struct FeedbackPayload: Encodable, Equatable, Sendable {
    public let type: String
    public let name: String
    public let email: String?
    public let message: String
    public let appVersion: String
    public let build: String
    public let gitRevision: String
    public let iosVersion: String
    public let deviceModel: String
    public let locale: String
    public let log: String?

    /// `log` is the `PersistentLog.exportContent()` snapshot the user could read,
    /// and is dropped when the draft does not attach it.
    public init?(draft: FeedbackDraft, device: FeedbackDeviceInfo, log: String?) {
        guard draft.problems.isEmpty else { return nil }
        type = draft.kind.rawValue
        name = draft.cleanName
        email = draft.cleanEmail.isEmpty ? nil : draft.cleanEmail
        message = draft.cleanMessage
        appVersion = device.appVersion
        build = device.build
        gitRevision = device.gitRevision
        iosVersion = device.iosVersion
        deviceModel = device.deviceModel
        locale = device.locale
        let attached = draft.attachesLog ? log.map { Self.newestLines(of: $0, maxBytes: FeedbackLimits.logBytes) } : nil
        self.log = attached?.isEmpty == false ? attached : nil
    }

    private init(copying other: FeedbackPayload, log: String?) {
        type = other.type; name = other.name; email = other.email; message = other.message
        appVersion = other.appVersion; build = other.build; gitRevision = other.gitRevision
        iosVersion = other.iosVersion; deviceModel = other.deviceModel; locale = other.locale
        self.log = log
    }

    /// The request body, at most `FeedbackLimits.bodyBytes`. JSON escaping can
    /// grow the log past the wire cap even under its own cap, so the oldest lines
    /// go first until it fits.
    public func body() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var payload = self
        while true {
            let data = try encoder.encode(payload)
            guard data.count > FeedbackLimits.bodyBytes, let log = payload.log else { return data }
            let target = log.utf8.count - (data.count - FeedbackLimits.bodyBytes) - 1
            let shorter = target > 0 ? Self.newestLines(of: log, maxBytes: target) : ""
            payload = FeedbackPayload(copying: payload, log: shorter.isEmpty ? nil : shorter)
        }
    }

    /// The report as plain text, for the share sheet when sending fails. The log
    /// travels next to it as a file.
    public var shareText: String {
        var lines = ["Dictus feedback: \(type)", "Name: \(name)"]
        if let email { lines.append("Email: \(email)") }
        lines.append("Dictus \(appVersion) (\(build)) rev \(gitRevision) | iOS \(iosVersion) | \(deviceModel) | \(locale)")
        lines.append("")
        lines.append(message)
        return lines.joined(separator: "\n")
    }

    /// The end of `text` within `maxBytes` of UTF-8, starting at a line boundary
    /// so the first line the reader sees is whole.
    static func newestLines(of text: String, maxBytes: Int) -> String {
        let utf8 = text.utf8
        guard utf8.count > maxBytes else { return text }
        var start = utf8.index(utf8.endIndex, offsetBy: -maxBytes)
        // Move off a UTF-8 continuation byte, then past the next line break.
        while start < utf8.endIndex, utf8[start] & 0xC0 == 0x80 { start = utf8.index(after: start) }
        let tail = text[start...]
        guard let newline = tail.firstIndex(of: "\n") else { return String(tail) }
        return String(tail[tail.index(after: newline)...])
    }
}

private extension String {
    /// Drops the characters the server refuses: C0, DEL and C1 controls. A message
    /// keeps tab, line feed and carriage return.
    func removingControlCharacters(keepingLineBreaks: Bool) -> String {
        String(String.UnicodeScalarView(unicodeScalars.filter { scalar in
            let value = scalar.value
            let isControl = value < 0x20 || (0x7F...0x9F).contains(value)
            return !isControl || (keepingLineBreaks && (value == 0x09 || value == 0x0A || value == 0x0D))
        }))
    }
}
