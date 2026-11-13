// DictusCore/Tests/DictusCoreTests/FeedbackDeliveryTests.swift
// The request the client sends and how it reads each server answer (#565).
import XCTest
@testable import DictusCore

final class FeedbackDeliveryTests: XCTestCase {

    private let ok = Data(#"{"ok":true}"#.utf8)

    func testStatusCodesMapToWhatTheFormSays() {
        let cases: [(Int, String?, Data, FeedbackOutcome)] = [
            (200, nil, ok, .delivered),
            (200, nil, Data("<html>Wi-Fi login</html>".utf8), .failed(.unreachable)),
            (400, nil, Data(#"{"ok":false,"error":"invalid_payload"}"#.utf8), .failed(.rejected(status: 400))),
            (413, nil, Data(), .failed(.rejected(status: 413))),
            (415, nil, Data(), .failed(.rejected(status: 415))),
            (429, "600", Data(), .failed(.rateLimited(retryAfterSeconds: 600))),
            (429, nil, Data(), .failed(.rateLimited(retryAfterSeconds: nil))),
            (429, "Wed, 21 Oct 2026 07:28:00 GMT", Data(), .failed(.rateLimited(retryAfterSeconds: nil))),
            (502, nil, Data(), .failed(.deliveryFailed)),
            (500, nil, Data(), .failed(.deliveryFailed)),
            (503, nil, Data(), .failed(.unavailable)),
            (404, nil, Data(), .failed(.unavailable)),
            (405, nil, Data(), .failed(.rejected(status: 405)))
        ]
        for (status, retryAfter, body, expected) in cases {
            XCTAssertEqual(FeedbackOutcome(status: status, retryAfter: retryAfter, body: body), expected, "\(status)")
        }
    }

    func testOnlyARequestTheServerRefusedIsNotWorthRetrying() {
        XCTAssertFalse(FeedbackFailure.rejected(status: 400).allowsRetry)
        for failure in [FeedbackFailure.unreachable, .rateLimited(retryAfterSeconds: 1), .deliveryFailed, .unavailable] {
            XCTAssertTrue(failure.allowsRetry, "\(failure)")
        }
    }

    func testRetryWaitsForRetryAfterOrAMinuteAfterA429() throws {
        let failedAt = Date(timeIntervalSince1970: 1_000)
        let withHeader = try XCTUnwrap(FeedbackRetryWindow(failure: .rateLimited(retryAfterSeconds: 600), failedAt: failedAt))
        XCTAssertFalse(withHeader.isOpen(at: failedAt))
        XCTAssertFalse(withHeader.isOpen(at: failedAt.addingTimeInterval(599.9)))
        XCTAssertTrue(withHeader.isOpen(at: failedAt.addingTimeInterval(600)))

        for missing in [nil, 0, -5] as [Int?] {
            let window = try XCTUnwrap(FeedbackRetryWindow(failure: .rateLimited(retryAfterSeconds: missing),
                                                           failedAt: failedAt))
            XCTAssertEqual(window.opensAt, failedAt.addingTimeInterval(60), "\(String(describing: missing))")
        }
    }

    func testOtherRetryableFailuresOpenRetryAtOnceAndARejectionNever() throws {
        let failedAt = Date(timeIntervalSince1970: 1_000)
        for failure in [FeedbackFailure.unreachable, .deliveryFailed, .unavailable] {
            XCTAssertTrue(try XCTUnwrap(FeedbackRetryWindow(failure: failure, failedAt: failedAt)).isOpen(at: failedAt))
        }
        XCTAssertNil(FeedbackRetryWindow(failure: .rejected(status: 400), failedAt: failedAt))
    }

    func testTheClientPostsJSONAndReadsTheAnswer() async throws {
        let payload = try XCTUnwrap(Self.payload())
        StubProtocol.reply = (429, ["Retry-After": "42"], Data())
        let outcome = await Self.client().send(payload)
        XCTAssertEqual(outcome, .failed(.rateLimited(retryAfterSeconds: 42)))

        let request = try XCTUnwrap(StubProtocol.lastRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://stub.test/api/feedback")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json; charset=utf-8")
        XCTAssertEqual(StubProtocol.lastBody, try payload.body())

        StubProtocol.reply = (200, [:], ok)
        let delivered = await Self.client().send(payload)
        XCTAssertEqual(delivered, .delivered)
    }

    func testATransportErrorIsUnreachable() async throws {
        StubProtocol.reply = nil
        let outcome = await Self.client().send(try XCTUnwrap(Self.payload()))
        XCTAssertEqual(outcome, .failed(.unreachable))
    }

    func testTheProductionEndpointIsTheWebsiteRoute() {
        XCTAssertEqual(FeedbackClient.productionEndpoint.absoluteString, "https://getdictus.com/api/feedback")
    }

    private static func payload() -> FeedbackPayload? {
        var draft = FeedbackDraft()
        draft.name = "Pierre"
        draft.message = "Hello"
        draft.attachesLog = true
        let device = FeedbackDeviceInfo(appVersion: "2.0.1", build: "41", gitRevision: "abc", iosVersion: "26.5",
                                        deviceModel: "iPhone16,1", locale: "fr_FR")
        return FeedbackPayload(draft: draft, device: device, log: "log line\n")
    }

    private static func client() -> FeedbackClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        // swiftlint:disable:next force_unwrapping
        return FeedbackClient(endpoint: URL(string: "http://stub.test/api/feedback")!,
                              session: URLSession(configuration: configuration))
    }
}

/// Answers every request with `reply`, or fails it with a network error when nil.
private final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var reply: (Int, [String: String], Data)?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        // URLSession hands a protocol the body as a stream, not as `httpBody`.
        Self.lastBody = request.httpBody ?? request.httpBodyStream.map(Self.read)
        guard let (status, headers, body) = Self.reply, let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                             headerFields: headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
