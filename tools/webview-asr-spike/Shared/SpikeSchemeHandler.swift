import Foundation
import WebKit

/// Where the page's files live on disk.
struct SpikeResources: Sendable {
    /// The page: index.html, spike.js, the sherpa-onnx glue and wasm.
    let webRoot: URL
    /// One folder per model: `<modelsRoot>/<name>/encoder.int8.onnx` …
    let modelsRoot: URL
    /// Benchmark clips (the app only).
    let clipsRoot: URL?

    /// The models ship inside the keyboard extension's bundle, so the keyboard
    /// reads them without an App Group, without Full Access and without a copy
    /// step. The app finds them in the same place, through its PlugIns folder.
    static func current() -> SpikeResources {
        let main = Bundle.main.bundleURL
        let isExtension = main.pathExtension == "appex"
        let keyboardBundle = isExtension
            ? main
            : main.appendingPathComponent("PlugIns/SpikeKeyboard.appex")
        return SpikeResources(
            webRoot: main.appendingPathComponent("web"),
            modelsRoot: keyboardBundle.appendingPathComponent("models"),
            clipsRoot: isExtension ? nil : main.appendingPathComponent("clips")
        )
    }
}

/// Serves `spikeasr://app/<path>` from local files, streamed in 1 MB chunks so
/// a 650 MB encoder never sits whole in this (keyboard) process. Sends COOP/COEP
/// so the page can be cross-origin isolated if a threaded build is tried.
final class SpikeSchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {
    private let resources: SpikeResources
    private let queue = DispatchQueue(label: "spike.scheme", qos: .userInitiated)
    private let lock = NSLock()
    private var stopped = Set<ObjectIdentifier>()

    init(resources: SpikeResources) {
        self.resources = resources
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, let file = fileURL(for: url.path) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let id = ObjectIdentifier(urlSchemeTask)
        nonisolated(unsafe) let task = urlSchemeTask
        queue.async { [self] in
            stream(file: file, url: url, task: task, id: id)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        lock.lock()
        stopped.insert(ObjectIdentifier(urlSchemeTask))
        lock.unlock()
    }

    private func isStopped(_ id: ObjectIdentifier) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped.contains(id)
    }

    private func fileURL(for path: String) -> URL? {
        let parts = path.split(separator: "/").map(String.init)
        guard !parts.isEmpty, !parts.contains("..") else { return nil }
        let url: URL
        switch parts[0] {
        case "models":
            url = parts.dropFirst().reduce(resources.modelsRoot) { $0.appendingPathComponent($1) }
        case "clips":
            guard let root = resources.clipsRoot else { return nil }
            url = parts.dropFirst().reduce(root) { $0.appendingPathComponent($1) }
        default:
            url = parts.reduce(resources.webRoot) { $0.appendingPathComponent($1) }
        }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func mimeType(_ ext: String) -> String {
        switch ext {
        case "html": return "text/html"
        case "js": return "text/javascript"
        case "wasm": return "application/wasm"
        case "wav": return "audio/wav"
        case "txt": return "text/plain"
        default: return "application/octet-stream"
        }
    }

    private func stream(file: URL, url: URL, task: WKURLSchemeTask, id: ObjectIdentifier) {
        defer {
            lock.lock()
            stopped.remove(id)
            lock.unlock()
        }
        guard let handle = try? FileHandle(forReadingFrom: file),
              let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue
        else {
            DispatchQueue.main.sync { if !isStopped(id) { task.didFailWithError(URLError(.cannotOpenFile)) } }
            return
        }
        defer { try? handle.close() }
        // `Range: bytes=a-b` gives a 206 slice: the page loads the model in
        // slices so WebKit never holds a whole 650 MB response.
        var start = 0
        var end = size - 1
        var status = 200
        if let range = task.request.value(forHTTPHeaderField: "Range"), range.hasPrefix("bytes=") {
            let bounds = range.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
            if bounds.count == 2, let a = Int(bounds[0]) {
                start = min(a, max(size - 1, 0))
                end = min(Int(bounds[1]) ?? (size - 1), size - 1)
                status = 206
            }
        }
        let length = max(end - start + 1, 0)
        var headers = [
            "Content-Type": Self.mimeType(file.pathExtension),
            "Content-Length": String(length),
            "Accept-Ranges": "bytes",
            "Cross-Origin-Opener-Policy": "same-origin",
            "Cross-Origin-Embedder-Policy": "require-corp",
            "Cross-Origin-Resource-Policy": "cross-origin",
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "no-store",
        ]
        if status == 206 { headers["Content-Range"] = "bytes \(start)-\(end)/\(size)" }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        DispatchQueue.main.sync { if !isStopped(id) { task.didReceive(response) } }
        try? handle.seek(toOffset: UInt64(start))
        var remaining = length
        let chunk = 1 << 20
        while !isStopped(id), remaining > 0 {
            let data = autoreleasepool { (try? handle.read(upToCount: min(chunk, remaining))) ?? Data() }
            if data.isEmpty { break }
            remaining -= data.count
            // Synchronous hop: one chunk in flight, so this process never
            // buffers more than ~1 MB of model however fast the disk is.
            DispatchQueue.main.sync { if !isStopped(id) { task.didReceive(data) } }
        }
        DispatchQueue.main.sync { if !isStopped(id) { task.didFinish() } }
    }
}
