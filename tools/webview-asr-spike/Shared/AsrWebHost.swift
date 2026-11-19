import UIKit
import WebKit

/// Hosts the spike page in a WKWebView: microphone capture (getUserMedia) and
/// speech recognition (sherpa-onnx compiled to WebAssembly) both run in
/// WebKit's WebContent process, not in the process that owns this object.
///
/// Native code talks to the page with `evaluateJavaScript` and hears back on
/// the `spike` script message handler. Everything the page needs — HTML, the
/// wasm, the ONNX model — is served by `SpikeSchemeHandler` from local files,
/// so nothing goes to the network.
@MainActor
final class AsrWebHost: NSObject {
    static let scheme = "spikeasr"
    static let pageURL = URL(string: "\(scheme)://app/index.html")!

    /// Every message the page posts, as a dictionary with at least `type`.
    var onEvent: (([String: Any]) -> Void)?

    let webView: WKWebView
    private(set) var isReady = false
    private(set) var terminations = 0
    private var heartbeat: Timer?

    init(resources: SpikeResources) {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(SpikeSchemeHandler(resources: resources), forURLScheme: Self.scheme)
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: configuration)
        super.init()
        configuration.userContentController.add(WeakMessageHandler(self), name: "spike")
        webView.uiDelegate = self
        webView.navigationDelegate = self
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif
    }

    /// The web view must sit in a window: WebKit throttles a detached one
    /// (stephancill/ios-keyboard-dictation keeps it at 1x1 pt, alpha 0.01).
    func attach(to view: UIView, visible: Bool = false) {
        if !visible {
            webView.alpha = 0.01
            webView.isUserInteractionEnabled = false
            webView.accessibilityElementsHidden = true
        }
        view.addSubview(webView)
        if !visible { view.sendSubviewToBack(webView) }
        load()
    }

    func load() {
        isReady = false
        webView.load(URLRequest(url: Self.pageURL))
    }

    /// The WebContent process pid, through WebKit SPI (spike only, never shipped).
    var webContentPID: Int32? {
        (webView.value(forKey: "_webProcessIdentifier") as? NSNumber)?.int32Value
    }

    func call(_ script: String) {
        webView.evaluateJavaScript(script + "; 0") { [weak self] _, error in
            if let error {
                self?.onEvent?(["type": "error", "where": "evaluateJavaScript", "message": "\(script): \(error.localizedDescription)"])
            }
        }
    }

    func loadModel(_ name: String) { call("spikeLoadModel(\(Self.jsString(name)))") }

    func startCapture() {
        heartbeat?.invalidate()
        heartbeat = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.webView.evaluateJavaScript("spikeHeartbeat(); 0") }
        }
        call("spikeStartCapture()")
    }

    func stopCapture() {
        heartbeat?.invalidate()
        heartbeat = nil
        call("spikeStopCapture()")
    }

    func runBench(clips: [(id: String, file: String)], repeats: Int) {
        let list = clips.map { "{id:\(Self.jsString($0.id)),url:\(Self.jsString("clips/" + $0.file))}" }.joined(separator: ",")
        call("spikeRunBench([\(list)], \(repeats))")
    }

    static func jsString(_ value: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [value])
        let array = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return String(array.dropFirst().dropLast())
    }

    fileprivate func handle(_ body: Any) {
        guard let message = body as? [String: Any], let type = message["type"] as? String else { return }
        if type == "ready" { isReady = true }
        if type == "captureInterrupted" || type == "captureFailed" {
            heartbeat?.invalidate()
            heartbeat = nil
        }
        onEvent?(message)
    }
}

extension AsrWebHost: WKUIDelegate, WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void
    ) {
        decisionHandler(type == .microphone ? .grant : .deny)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        terminations += 1
        heartbeat?.invalidate()
        heartbeat = nil
        isReady = false
        onEvent?(["type": "webContentTerminated", "count": terminations])
        load()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onEvent?(["type": "error", "where": "navigation", "message": error.localizedDescription])
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onEvent?(["type": "error", "where": "provisionalNavigation", "message": error.localizedDescription])
    }
}

/// Breaks the retain cycle between WKUserContentController and its handler.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: AsrWebHost?
    init(_ target: AsrWebHost) { self.target = target }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated { target?.handle(message.body) }
    }
}
