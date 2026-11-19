import AVFoundation
import SwiftUI
import UIKit

@main
struct SpikeApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

/// Runs the same page and the same WebAssembly recognizer as the keyboard,
/// in the app's own WKWebView: Phase 1 benchmark on the simulator, and a
/// device-side reference before trying the keyboard.
@MainActor
final class BenchRunner: ObservableObject {
    static let clips = [
        "fr-01-spoken-punctuation.wav", "fr-02-appointment-numbers.wav", "fr-03-shopping.wav",
        "fr-04-question-mark.wav", "fr-concat-4short.wav", "fr-long-first60s.wav",
        "fr-long-01-workday-sync-fix.wav",
    ]

    @Published var lines: [String] = []
    @Published var running = false
    private var host: AsrWebHost?
    private var queue: [String] = []
    private var repeats = 2
    private var outputURL: URL?
    private var pendingAction: (() -> Void)?

    func attach(to view: UIView) {
        guard host == nil else { return }
        let host = AsrWebHost(resources: SpikeResources.current())
        host.onEvent = { [weak self] event in self?.handle(event) }
        host.attach(to: view, visible: true)
        self.host = host
    }

    func run(models: [String], repeats: Int = 2) {
        guard !running, let host else { return }
        running = true
        queue = models
        self.repeats = repeats
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let stamp = Int(Date().timeIntervalSince1970)
        outputURL = docs.appendingPathComponent("bench-\(stamp).jsonl")
        write(["type": "benchStart", "models": models, "repeats": repeats, "device": UIDevice.current.model,
               "system": UIDevice.current.systemVersion])
        try? "running\n".write(to: docs.appendingPathComponent("phase.txt"), atomically: true, encoding: .utf8)
        if host.isReady { next() } else { pendingAction = { [weak self] in self?.next() } }
        host.call("spikeProbeWasmMemory()")
    }

    private func next() {
        guard let model = queue.first else {
            running = false
            write(["type": "allDone"])
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? "done\n".write(to: docs.appendingPathComponent("phase.txt"), atomically: true, encoding: .utf8)
            return
        }
        // A wasm heap never shrinks: each model gets a freshly loaded page.
        if loadedOnce {
            pendingAction = { [weak self] in self?.host?.loadModel(model) }
            host?.load()
        } else {
            host?.loadModel(model)
        }
        loadedOnce = true
    }

    private var loadedOnce = false

    private func handle(_ event: [String: Any]) {
        guard let type = event["type"] as? String, type != "log" else { return }
        var entry = event
        entry["appFootprintMB"] = SpikeMetrics.megabytes(SpikeMetrics.physFootprint())
        if let pid = host?.webContentPID {
            let usage = SpikeMetrics.footprint(ofPID: pid)
            if let bytes = usage.bytes { entry["webContentFootprintMB"] = SpikeMetrics.megabytes(bytes) } else { entry["webContentFootprintErrno"] = usage.errno }
        }
        write(entry)
        switch type {
        case "ready":
            pendingAction?()
            pendingAction = nil
        case "modelLoaded":
            if running { host?.runBench(clips: Self.clips.map { ($0, $0) }, repeats: repeats) }
        case "benchDone":
            if !queue.isEmpty { queue.removeFirst() }
            next()
        case "error", "webContentTerminated":
            if running {
                if !queue.isEmpty { queue.removeFirst() }
                next()
            }
        default:
            break
        }
    }

    private func write(_ entry: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]),
              let line = String(data: data, encoding: .utf8) else { return }
        lines.append(String(line.prefix(220)))
        SpikeLog.shared.write(entry)
        guard let url = outputURL, let bytes = (line + "\n").data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: bytes)
            try? handle.close()
        } else {
            try? bytes.write(to: url)
        }
    }
}

struct BenchWebView: UIViewRepresentable {
    let runner: BenchRunner
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        runner.attach(to: view)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.subviews.first?.frame = uiView.bounds
    }
}

struct ContentView: View {
    @StateObject private var runner = BenchRunner()
    @State private var micStatus = ""
    @State private var testText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("1. Permissions") {
                    Button("Allow microphone") {
                        AVAudioApplication.requestRecordPermission { granted in
                            Task { @MainActor in micStatus = granted ? "granted" : "denied" }
                        }
                    }
                    .accessibilityIdentifier("spike.allowMic")
                    Text("Microphone: \(micStatus.isEmpty ? Self.micPermission : micStatus)")
                }
                Section("2. Keyboard") {
                    Text("Settings › General › Keyboard › Keyboards › Add New Keyboard › Spike ASR. Full Access is optional: the protocol tests both.")
                        .font(.footnote)
                    TextField("Type here with the spike keyboard", text: $testText, axis: .vertical)
                        .accessibilityIdentifier("spike.testField")
                }
                Section("3. In-app bench (same page, same wasm)") {
                    Button(runner.running ? "Running…" : "Run bench: parakeet-v3 + fastconformer") {
                        runner.run(models: ["parakeet-v3", "fastconformer-14288"])
                    }
                    .disabled(runner.running)
                    .accessibilityIdentifier("spike.runBench")
                    BenchWebView(runner: runner).frame(height: 60)
                    ForEach(Array(runner.lines.suffix(40).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(size: 9, design: .monospaced))
                    }
                }
            }
            .navigationTitle("WebView ASR spike")
        }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-autobench"), i + 1 < args.count {
                let models = args[i + 1].split(separator: ",").map(String.init)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { runner.run(models: models) }
            }
        }
    }

    private static var micPermission: String {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return "granted"
        case .denied: return "denied"
        default: return "not asked"
        }
    }
}
