// DictusKeyboard/InKeyboardWebCapture.swift
//
// Microphone capture from inside the keyboard extension, through a hidden WKWebView (spike).
//
// Adapted from two MIT-licensed projects, architecture only:
// - stephancill/ios-keyboard-dictation, `WebAudioCapture.swift` (MIT License):
//   the hidden 1 pt web view kept in the window, the https base URL that gives the page a
//   secure context, the WKUIDelegate grant, ScriptProcessor → 16 kHz Int16 → base64 →
//   postMessage, and the native heartbeat that lets the page stop itself.
// - anomalyco/hex, branch dev, `ios/HEXKeyboard/KeyboardLocalDictation.swift` (MIT License):
//   reporting `webViewWebContentProcessDidTerminate` as a capture failure, and transcribing
//   the finished recording from a PCM file.
import UIKit
import WebKit

/// Records 16 kHz mono Int16 PCM by running `getUserMedia` in a hidden web view.
///
/// WHY a web view: the keyboard process itself is not entitled to record
/// (`AVAudioEngine` there is refused or gets the extension killed). WebKit captures in its
/// own GPU and WebContent processes, attributed to the containing app's microphone
/// permission, and hands the samples back to native code. That is also why the audio
/// buffers do not count against the extension's memory: they are allocated in WebKit's
/// processes until each 100 ms chunk is posted across.
@MainActor
final class InKeyboardWebCapture: NSObject {
    static let sampleRate: Double = 16_000

    enum Event {
        case started(contextSampleRate: Double, device: String)
        /// One chunk of 16 kHz mono Int16 little-endian PCM, and its RMS in 0...1.
        case samples(Data, rms: Float)
        /// The page stopped capturing on its own (track ended, heartbeat lost, interruption).
        case interrupted(String)
        case failed(String)
    }

    var onEvent: ((Event) -> Void)?
    /// The page finished loading (once per load, again after a content-process restart).
    var onLoaded: (() -> Void)?

    private(set) var isLoaded = false
    private(set) var isCapturing = false
    private var startWhenLoaded: String?
    private var heartbeat: Timer?
    private let webView: WKWebView

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // Nothing to persist: no cookies, no cache, no storage on disk.
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: configuration)
        super.init()
        configuration.userContentController.add(WeakScriptHandler(self), name: "capture")
        webView.uiDelegate = self
        webView.navigationDelegate = self
        // In the window but invisible. Hidden or detached, WebKit treats the view as
        // inactive and throttles it, and capture does not start.
        webView.alpha = 0.01
        webView.isUserInteractionEnabled = false
        webView.isOpaque = false
        webView.accessibilityElementsHidden = true
        webView.loadHTMLString(Self.page, baseURL: Self.baseURL)
    }

    /// Put the web view in `view`'s hierarchy. Moving it to a newer controller's view is
    /// harmless: `addSubview` re-parents.
    func attach(to view: UIView) {
        guard webView.superview !== view else { return }
        view.addSubview(webView)
        view.sendSubviewToBack(webView)
    }

    /// Start the microphone. When `testAudioBase64` is given (Debug builds only, from the
    /// simulator test file), the page decodes that WAV and streams it through the exact
    /// same chunk path instead of opening the microphone.
    func start(testAudioBase64: String? = nil) {
        guard !isCapturing else { return }
        isCapturing = true
        let call: String
        if let testAudioBase64 {
            call = "startTestAudio('\(testAudioBase64)'); 0"
        } else {
            call = "startCapture(); 0"
        }
        heartbeat = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.webView.evaluateJavaScript("captureHeartbeat(); 0") }
        }
        guard isLoaded else {
            startWhenLoaded = call
            return
        }
        run(call)
    }

    func stop() {
        startWhenLoaded = nil
        heartbeat?.invalidate()
        heartbeat = nil
        guard isCapturing else { return }
        isCapturing = false
        webView.evaluateJavaScript("stopCapture(); 0")
    }

    private func run(_ call: String) {
        webView.evaluateJavaScript(call) { [weak self] _, error in
            guard let error else { return }
            MainActor.assumeIsolated { self?.fail("evaluate: \(error.localizedDescription)") }
        }
    }

    private func fail(_ reason: String) {
        let wasCapturing = isCapturing
        stop()
        if wasCapturing { onEvent?(.failed(reason)) }
    }

    fileprivate func handle(_ body: Any) {
        guard let message = body as? [String: Any], let type = message["type"] as? String else { return }
        switch type {
        case "started":
            let rate = (message["sampleRate"] as? NSNumber)?.doubleValue ?? 0
            onEvent?(.started(contextSampleRate: rate, device: message["device"] as? String ?? "unknown"))
        case "audio":
            guard isCapturing,
                  let encoded = message["data"] as? String,
                  let data = Data(base64Encoded: encoded) else { return }
            onEvent?(.samples(data, rms: (message["rms"] as? NSNumber)?.floatValue ?? 0))
        case "interrupted":
            let reason = message["reason"] as? String ?? "unknown"
            let wasCapturing = isCapturing
            stop()
            if wasCapturing { onEvent?(.interrupted(reason)) }
        case "failed":
            fail(message["reason"] as? String ?? "unknown")
        default:
            break
        }
    }

    /// Never fetched: it only makes the inline page a secure context, which
    /// `getUserMedia` requires.
    private static let baseURL = URL(string: "https://keyboard.dictus.invalid/")

    // The page. `startCapture` follows stephancill's capture loop; `startTestAudio` is the
    // Debug-only simulator path, which feeds a decoded WAV through the same `emit`.
    private static let page = """
    <!doctype html><html><head><meta charset="utf-8"></head><body><script>
    const targetRate = \(Int(sampleRate));
    const post = m => window.webkit.messageHandlers.capture.postMessage(m);
    const encode = samples => {
      const bytes = new Uint8Array(samples.buffer, samples.byteOffset, samples.length * 2);
      let binary = '';
      for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
      return btoa(binary);
    };
    const emit = (int16, rms) => post({ type: 'audio', data: encode(int16), rms });
    let lastHeartbeat = performance.now();
    window.captureHeartbeat = () => { lastHeartbeat = performance.now(); };
    let stopCapture = () => {};
    window.stopCapture = () => stopCapture();
    const startWatchdog = interrupted => setInterval(() => {
      if (performance.now() - lastHeartbeat > 3000) interrupted('native-heartbeat-expired');
    }, 500);

    window.startCapture = async () => {
      let stopping = false, stream, context, source, processor, sink, watchdog;
      const audioSession = navigator.audioSession;
      const previousType = audioSession ? audioSession.type : 'auto';
      const cleanup = () => {
        if (stopping) return;
        stopping = true;
        clearInterval(watchdog);
        if (processor) { processor.onaudioprocess = null; processor.disconnect(); }
        if (source) source.disconnect();
        if (sink) sink.disconnect();
        if (stream) stream.getTracks().forEach(t => t.stop());
        if (context) context.close().catch(() => {});
        try { if (audioSession) audioSession.type = previousType; } catch (_) {}
      };
      const interrupted = reason => { if (!stopping) { cleanup(); post({ type: 'interrupted', reason }); } };
      stopCapture = cleanup;
      try {
        try { if (audioSession) audioSession.type = 'play-and-record'; } catch (_) {}
        stream = await navigator.mediaDevices.getUserMedia({
          audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true, autoGainControl: true }
        });
        if (stopping) { stream.getTracks().forEach(t => t.stop()); return; }
        const track = stream.getAudioTracks()[0];
        track.onended = () => interrupted('track-ended');
        // Created at capture, never earlier: an AudioContext can take audio focus.
        context = new AudioContext({ latencyHint: 'interactive' });
        await context.resume();
        processor = context.createScriptProcessor(4096, 1, 1);
        sink = context.createGain();
        sink.gain.value = 0;
        processor.connect(sink);
        sink.connect(context.destination);
        source = context.createMediaStreamSource(stream);
        source.connect(processor);
        context.onstatechange = () => { if (context.state !== 'running') interrupted('context-' + context.state); };
        if (audioSession) audioSession.onstatechange = () => { if (audioSession.state === 'interrupted') interrupted('audio-session-interrupted'); };
        lastHeartbeat = performance.now();
        watchdog = startWatchdog(interrupted);
        const step = context.sampleRate / targetRate;
        let position = 0, sum = 0, count = 0;
        processor.onaudioprocess = event => {
          const input = event.inputBuffer.getChannelData(0);
          const output = new Int16Array(Math.ceil(input.length / step) + 1);
          let written = 0, energy = 0;
          for (let i = 0; i < input.length; i++) {
            const s = input[i];
            energy += s * s; sum += s; count += 1; position += 1;
            if (position >= step) {
              position -= step;
              output[written++] = Math.max(-1, Math.min(1, sum / count)) * 32767;
              sum = 0; count = 0;
            }
          }
          if (written > 0) emit(output.subarray(0, written), Math.sqrt(energy / input.length));
        };
        post({ type: 'started', sampleRate: context.sampleRate, device: track.label || 'unknown' });
      } catch (error) {
        if (stopping) return;
        cleanup();
        post({ type: 'failed', reason: (error && (error.name + ': ' + error.message)) || String(error) });
      }
    };

    window.startTestAudio = async base64 => {
      let stopping = false, timer, watchdog;
      const cleanup = () => { if (stopping) return; stopping = true; clearInterval(timer); clearInterval(watchdog); };
      const interrupted = reason => { if (!stopping) { cleanup(); post({ type: 'interrupted', reason }); } };
      stopCapture = cleanup;
      try {
        const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
        const context = new OfflineAudioContext(1, 1, targetRate);
        const decoded = await context.decodeAudioData(bytes.buffer);
        const samples = decoded.getChannelData(0);
        lastHeartbeat = performance.now();
        watchdog = startWatchdog(interrupted);
        post({ type: 'started', sampleRate: decoded.sampleRate, device: 'test-audio-file' });
        // Real time, cut like a 4096-frame ScriptProcessor buffer at 48 kHz (1365
        // samples every ~85 ms), then silence until stopped. Delivered in bursts of one
        // to four chunks, the way WebKit hands messages over on a device, from a fixed
        // pseudo-random sequence so two runs see the same arrival pattern.
        const chunk = 1365, period = chunk / targetRate * 1000;
        let offset = 0, queue = [], seed = 7;
        const random = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
        timer = setInterval(() => {
          const out = new Int16Array(chunk);
          let energy = 0;
          for (let i = 0; i < chunk; i++) {
            const s = offset + i < samples.length ? samples[offset + i] : 0;
            energy += s * s;
            out[i] = Math.max(-1, Math.min(1, s)) * 32767;
          }
          offset += chunk;
          queue.push([out, Math.sqrt(energy / chunk)]);
          if (queue.length >= 4 || random() < 0.35) { queue.forEach(([o, r]) => emit(o, r)); queue = []; }
        }, period);
      } catch (error) {
        if (stopping) return;
        cleanup();
        post({ type: 'failed', reason: (error && (error.name + ': ' + error.message)) || String(error) });
      }
    };
    </script></body></html>
    """
}

extension InKeyboardWebCapture: WKUIDelegate, WKNavigationDelegate {
    /// Skips WebKit's per-origin prompt only. The microphone permission that applies is
    /// still DictusApp's, granted once in the app.
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void
    ) {
        decisionHandler(type == .microphone ? .grant : .deny)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoaded = true
        onLoaded?()
        if let call = startWhenLoaded {
            startWhenLoaded = nil
            run(call)
        }
    }

    /// WebKit's content process can be killed under memory pressure. The capture dies
    /// with it; reload so the next dictation finds a page.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        isLoaded = false
        fail("web content process terminated")
        webView.loadHTMLString(Self.page, baseURL: Self.baseURL)
    }
}

/// `WKUserContentController` retains its handlers; this breaks the cycle.
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: InKeyboardWebCapture?
    init(_ target: InKeyboardWebCapture) { self.target = target }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated { target?.handle(message.body) }
    }
}
