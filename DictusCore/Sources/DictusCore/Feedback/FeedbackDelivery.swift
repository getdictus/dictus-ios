// DictusCore/Sources/DictusCore/Feedback/FeedbackDelivery.swift
// Sends a feedback report to the website route and reads its answer (#565).
import Foundation

/// Why a report did not arrive, at the level the form explains it to the user.
public enum FeedbackFailure: Equatable, Sendable {
    /// No answer from the server: offline, timeout, or a captive portal page.
    case unreachable
    /// `429`. The seconds come from `Retry-After` when the server sent them.
    case rateLimited(retryAfterSeconds: Int?)
    /// `502` or another 5xx: the server could not hand the report to Telegram.
    case deliveryFailed
    /// `503`, or `404` before the route is deployed.
    case unavailable
    /// `400`, `413`, `415` or any other answer: the app built a request the
    /// server refuses, so sending it again unchanged would fail the same way.
    case rejected(status: Int)

    public var allowsRetry: Bool {
        if case .rejected = self { return false }
        return true
    }
}

public enum FeedbackOutcome: Equatable, Sendable {
    case delivered
    case failed(FeedbackFailure)

    /// Reads the server's answer per `docs/feedback-api.md`. A `200` counts only
    /// with its `{"ok":true}` body: a Wi-Fi login page also answers `200`.
    public init(status: Int, retryAfter: String?, body: Data) {
        switch status {
        case 200:
            let ok = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
            self = ok?["ok"] as? Bool == true ? .delivered : .failed(.unreachable)
        case 429:
            let seconds = retryAfter.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            self = .failed(.rateLimited(retryAfterSeconds: seconds))
        case 404, 503:
            self = .failed(.unavailable)
        case 500...599:
            self = .failed(.deliveryFailed)
        default:
            self = .failed(.rejected(status: status))
        }
    }
}

public struct FeedbackClient: Sendable {
    // A compile-time constant URL cannot fail to parse.
    // swiftlint:disable:next force_unwrapping
    public static let productionEndpoint = URL(string: "https://getdictus.com/api/feedback")!

    let endpoint: URL
    let session: URLSession

    public init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    public func send(_ payload: FeedbackPayload) async -> FeedbackOutcome {
        guard let body = try? payload.body() else { return .failed(.rejected(status: 0)) }
        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed(.unreachable) }
            return FeedbackOutcome(status: http.statusCode,
                                   retryAfter: http.value(forHTTPHeaderField: "Retry-After"),
                                   body: data)
        } catch {
            return .failed(.unreachable)
        }
    }
}
