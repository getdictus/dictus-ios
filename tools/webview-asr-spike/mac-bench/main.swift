// macOS WKWebView bench: the Safari engine (JavaScriptCore + WebKit) running
// web/spike.js on the Mac, as the desktop baseline for the iOS figures.
// Never shows a window. Prints one JSON line per page event, plus the
// WebContent process footprint sampled every 100 ms.
//
//   mac-bench <webRoot> <modelsRoot> <clipsRoot> <model> <repeats> <clip>...
import AppKit
import Darwin
import WebKit

let args = CommandLine.arguments
let resources = SpikeResources(
    webRoot: URL(fileURLWithPath: args[1]), modelsRoot: URL(fileURLWithPath: args[2]),
    clipsRoot: URL(fileURLWithPath: args[3]))
let model = args[4]
let repeats = Int(args[5]) ?? 1
let clips = Array(args.dropFirst(6))

func footprint(_ pid: Int32) -> UInt64 {
    var usage = rusage_info_v4()
    let r = withUnsafeMutablePointer(to: &usage) {
        $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
    }
    return r == 0 ? usage.ri_phys_footprint : 0
}

final class Bench: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    let webView: WKWebView
    var peak: UInt64 = 0
    var phasePeak: UInt64 = 0
    var timer: Timer?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        // The view is never on screen; without these SPI preferences WebKit
        // treats the page as hidden and throttles its process (measured: 2-4x
        // slower decodes than the same wasm under Node).
        for key in ["pageVisibilityBasedProcessSuppressionEnabled", "hiddenPageDOMTimerThrottlingEnabled"] {
            configuration.preferences.setValue(false, forKey: key)
        }
        configuration.setURLSchemeHandler(SpikeSchemeHandler(resources: resources), forURLScheme: "spikeasr")
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 300), configuration: configuration)
        super.init()
        configuration.userContentController.add(self, name: "spike")
        webView.navigationDelegate = self
        webView.load(URLRequest(url: URL(string: "spikeasr://app/index.html")!))
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.sample() }
    }

    var pid: Int32 { (webView.value(forKey: "_webProcessIdentifier") as? NSNumber)?.int32Value ?? 0 }

    func sample() {
        let f = footprint(pid)
        peak = max(peak, f)
        phasePeak = max(phasePeak, f)
    }

    func call(_ js: String) { webView.evaluateJavaScript(js + "; 0", completionHandler: nil) }

    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        guard var m = message.body as? [String: Any], let type = m["type"] as? String else { return }
        sample()
        m["webContentFootprintMB"] = Int(footprint(pid) >> 20)
        m["webContentPhasePeakMB"] = Int(phasePeak >> 20)
        phasePeak = footprint(pid)
        if type == "log" { return }
        if let d = try? JSONSerialization.data(withJSONObject: m, options: [.sortedKeys]), let s = String(data: d, encoding: .utf8) { print(s) }
        fflush(stdout)
        switch type {
        case "ready" where model.hasPrefix("js:"):
            // Debug mode: run arbitrary page script, report footprint per phase.
            call(String(model.dropFirst(3)))
        case "ready": call("spikeLoadModel(\"\(model)\")")
        case "modelLoaded":
            let list = clips.map { "{id:\"\($0)\",url:\"clips/\($0)\"}" }.joined(separator: ",")
            call("spikeRunBench([\(list)], \(repeats))")
        case "benchDone", "error":
            print("{\"type\":\"summary\",\"webContentPeakMB\":\(peak >> 20)}")
            exit(type == "error" ? 1 : 0)
        default: break
        }
    }

    func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { print("nav error \(e)"); exit(2) }
    func webViewWebContentProcessDidTerminate(_ w: WKWebView) { print("{\"type\":\"webContentTerminated\"}"); exit(3) }
}

let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "bench")
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 400, height: 300), styleMask: [.borderless], backing: .buffered, defer: false)
let bench = Bench()
window.contentView = bench.webView
app.run()
