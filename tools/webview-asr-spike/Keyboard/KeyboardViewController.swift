import UIKit

/// Spike keyboard: a mic button that records and transcribes entirely inside a
/// hidden WKWebView (WebKit's WebContent process), then types the text with
/// textDocumentProxy. Every step is logged with this process's memory.
final class KeyboardViewController: UIInputViewController {
    private static let models = ["parakeet-v3", "fastconformer-14288"]

    private var host: AsrWebHost?
    private let status = UILabel()
    private let micButton = UIButton(type: .system)
    private let modelButton = UIButton(type: .system)
    private var isRecording = false
    private var appearedAt = Date()
    private var report: [String] = []
    private var memoryTimer: Timer?
    private var peakFootprint: UInt64 = 0
    private var minAvailable: UInt64 = .max

    private var model: String {
        get { UserDefaults.standard.string(forKey: "spike.model") ?? Self.models[0] }
        set { UserDefaults.standard.set(newValue, forKey: "spike.model") }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        appearedAt = Date()
        buildUI()
        log(["type": "keyboardViewDidLoad", "hasFullAccess": hasFullAccess, "logLocation": SpikeLog.shared.location])
        let host = AsrWebHost(resources: SpikeResources.current())
        host.onEvent = { [weak self] event in self?.handle(event) }
        host.attach(to: view)
        self.host = host
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleMemory() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isRecording { toggleRecording() }
        log(["type": "keyboardWillDisappear"])
    }

    // MARK: - Page events

    private func handle(_ event: [String: Any]) {
        guard let type = event["type"] as? String else { return }
        if type == "log" { return }
        var entry = event
        if let pid = host?.webContentPID {
            entry["webContentPID"] = pid
            let usage = SpikeMetrics.footprint(ofPID: pid)
            if let bytes = usage.bytes { entry["webContentFootprintMB"] = SpikeMetrics.megabytes(bytes) } else { entry["webContentFootprintErrno"] = usage.errno }
        }
        log(entry)
        switch type {
        case "ready":
            setStatus("Page ready, loading \(model)…")
            host?.loadModel(model)
        case "modelLoaded":
            let ms = event["totalMs"] as? Int ?? 0
            let heap = (event["heapBytes"] as? NSNumber)?.uint64Value ?? 0
            let sinceAppear = Int(Date().timeIntervalSince(appearedAt) * 1000)
            note("loaded \(model) in \(ms) ms (\(sinceAppear) ms since keyboard load), wasm heap \(SpikeMetrics.megabytes(heap)) MB")
            setStatus("Ready (\(model)). Tap the mic.")
            micButton.isEnabled = true
        case "captureStarted":
            setStatus("● Recording… tap to stop")
        case "captureFailed", "captureInterrupted":
            isRecording = false
            updateMic()
            note("\(type): \(event["reason"] ?? "")")
            setStatus("\(type): \(event["reason"] ?? "")")
        case "transcript":
            let text = event["text"] as? String ?? ""
            if !text.isEmpty { textDocumentProxy.insertText(text + " ") }
            note(String(format: "%.1f s audio → %@ ms decode (rtf %@)", event["audioSec"] as? Double ?? 0,
                        "\(event["decodeMs"] ?? "?")", "\(event["rtf"] ?? "?")"))
            setStatus("Ready (\(model)). Tap the mic.")
            micButton.isEnabled = true
        case "error":
            note("error \(event["where"] ?? ""): \(event["message"] ?? "")")
            setStatus("Error: \(event["message"] ?? "")")
            micButton.isEnabled = true
        case "webContentTerminated":
            isRecording = false
            updateMic()
            micButton.isEnabled = false
            note("WebContent terminated (#\(event["count"] ?? 0))")
            setStatus("WebContent process terminated, reloading…")
        default:
            break
        }
    }

    // MARK: - Actions

    @objc private func toggleRecording() {
        guard let host else { return }
        if isRecording {
            isRecording = false
            micButton.isEnabled = false
            setStatus("Transcribing in WebContent…")
            host.stopCapture()
        } else {
            isRecording = true
            setStatus("Starting microphone…")
            host.startCapture()
        }
        updateMic()
    }

    @objc private func switchModel() {
        let index = (Self.models.firstIndex(of: model) ?? 0) + 1
        model = Self.models[index % Self.models.count]
        modelButton.setTitle(model, for: .normal)
        micButton.isEnabled = false
        setStatus("Reloading page for \(model)…")
        // A wasm heap never shrinks: a fresh page (and WebContent process
        // memory) per model, which `ready` then loads.
        host?.load()
    }

    /// Types the session's figures into the host field: the one log channel
    /// that works with or without Full Access and without a cable.
    @objc private func insertReport() {
        let lines = [
            "[spike \(ISO8601DateFormatter().string(from: Date()))] fullAccess=\(hasFullAccess) model=\(model)",
            "keyboard footprint now \(SpikeMetrics.megabytes(SpikeMetrics.physFootprint())) MB, peak \(SpikeMetrics.megabytes(peakFootprint)) MB, min available \(minAvailable == .max ? -1 : SpikeMetrics.megabytes(minAvailable)) MB",
            "webContent terminations \(host?.terminations ?? 0), log \(SpikeLog.shared.location)",
        ] + report
        textDocumentProxy.insertText("\n" + lines.joined(separator: "\n") + "\n")
    }

    @objc private func space() { textDocumentProxy.insertText(" ") }
    @objc private func backspace() { textDocumentProxy.deleteBackward() }
    @objc private func newline() { textDocumentProxy.insertText("\n") }

    // MARK: - Helpers

    private func sampleMemory() {
        let footprint = SpikeMetrics.physFootprint()
        let available = SpikeMetrics.availableMemory()
        peakFootprint = max(peakFootprint, footprint)
        if available > 0 { minAvailable = min(minAvailable, available) }
    }

    private func log(_ event: [String: Any]) {
        var entry = event
        entry["keyboardFootprintMB"] = SpikeMetrics.megabytes(SpikeMetrics.physFootprint())
        entry["keyboardAvailableMB"] = SpikeMetrics.megabytes(SpikeMetrics.availableMemory())
        entry["model"] = entry["model"] ?? model
        SpikeLog.shared.write(entry)
    }

    private func note(_ line: String) {
        report.append(line)
        if report.count > 30 { report.removeFirst() }
    }

    private func setStatus(_ text: String) { status.text = text }

    private func updateMic() {
        micButton.setTitle(isRecording ? "■ Stop" : "🎙 Dictate", for: .normal)
        micButton.tintColor = isRecording ? .systemRed : .systemBlue
    }

    private func button(_ title: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        b.backgroundColor = .secondarySystemBackground
        b.layer.cornerRadius = 8
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func buildUI() {
        status.text = "Loading page…"
        status.numberOfLines = 2
        status.font = .systemFont(ofSize: 13)
        status.textAlignment = .center

        micButton.titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)
        micButton.backgroundColor = .secondarySystemBackground
        micButton.layer.cornerRadius = 12
        micButton.isEnabled = false
        micButton.accessibilityIdentifier = "spike.mic"
        micButton.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
        updateMic()

        modelButton.setTitle(model, for: .normal)
        modelButton.titleLabel?.font = .systemFont(ofSize: 13)
        modelButton.addTarget(self, action: #selector(switchModel), for: .touchUpInside)

        let globe = UIButton(type: .system)
        globe.setTitle("🌐", for: .normal)
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        let bottom = UIStackView(arrangedSubviews: [
            globe, button("report", #selector(insertReport)), button("space", #selector(space)),
            button("⌫", #selector(backspace)), button("⏎", #selector(newline)),
        ])
        bottom.distribution = .fillEqually
        bottom.spacing = 6

        let stack = UIStackView(arrangedSubviews: [status, modelButton, micButton, bottom])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            micButton.heightAnchor.constraint(equalToConstant: 90),
            bottom.heightAnchor.constraint(equalToConstant: 44),
            status.heightAnchor.constraint(greaterThanOrEqualToConstant: 34),
        ])
    }
}
