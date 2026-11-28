import AVFoundation
import Speech
import UIKit
import WebKit

/// Dictation that runs entirely inside the keyboard, with no trip to the app.
///
/// A keyboard extension's own audio engine gets shut off by the host app, so
/// the microphone is read through `getUserMedia` in a hidden web view instead:
/// WebKit records in its own processes and hands 16 kHz PCM back here, which
/// goes to Apple's speech recognizer. It needs Full Access, and the mic and
/// Speech Recognition permissions the Tapeze app already asks for.
///
/// The web-view capture follows stephancill/ios-keyboard-dictation (MIT).
@MainActor
final class InKeyboardDictation {
    enum Unavailable {
        /// Full Access, the mic, or speech recognition isn't allowed yet. The
        /// app can ask for them.
        case needsPermission
        /// Recognition or capture isn't possible right now.
        case notNow
    }

    /// Partial and final text for the current session.
    var onTranscript: ((String) -> Void)?
    /// Input loudness, 0...1.
    var onLevel: ((Float) -> Void)?
    /// The mic is open and audio is flowing.
    var onStarted: (() -> Void)?
    /// The session ended. `failedBeforeStart` is true when no audio ever
    /// arrived, so the caller can fall back to another way of dictating.
    var onEnded: ((_ failedBeforeStart: Bool) -> Void)?

    private let capture = WebAudioCapture()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var hasAudio = false
    private var transcript = ""
    private(set) var isActive = false
    private let audioFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: WebAudioCapture.sampleRate,
        channels: 1,
        interleaved: true
    )!

    init() {
        capture.onStarted = { [weak self] in self?.captureStarted() }
        capture.onAudio = { [weak self] data, rms in self?.append(data, rms: rms) }
        capture.onEnded = { [weak self] _ in self?.captureEnded() }
    }

    /// Puts the hidden web view in the keyboard's view tree. WebKit only
    /// captures from a web view that's in a window.
    func attach(to view: UIView) {
        capture.attach(to: view)
    }

    /// Why dictating here can't start right now, or nil if it can.
    func unavailableReason(hasFullAccess: Bool) -> Unavailable? {
        guard hasFullAccess,
              AVAudioSession.sharedInstance().recordPermission == .granted,
              SFSpeechRecognizer.authorizationStatus() == .authorized
        else { return .needsPermission }
        guard capture.isReady, let recognizer = currentRecognizer(), recognizer.isAvailable
        else { return .notNow }
        return nil
    }

    func start() {
        guard !isActive, let recognizer = currentRecognizer() else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            // Keeps speech on the phone, and lifts the one-minute server limit.
            request.requiresOnDeviceRecognition = true
        }
        self.request = request
        isActive = true
        hasAudio = false
        transcript = ""
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal == true
            let failed = error != nil
            Task { @MainActor in
                guard let self, self.request === request else { return }
                if let text {
                    self.transcript = text
                    self.onTranscript?(text)
                }
                if isFinal || failed { self.end() }
            }
        }
        capture.start()
    }

    /// Stops listening and keeps what was heard.
    func stop() {
        guard isActive else { return }
        request?.endAudio()
        capture.stop()
        end()
    }

    /// Stops listening and throws the text away.
    func cancel() {
        guard isActive else { return }
        task?.cancel()
        capture.stop()
        end()
    }

    func tearDown() {
        cancel()
        capture.tearDown()
    }

    // MARK: Private

    private func currentRecognizer() -> SFSpeechRecognizer? {
        if recognizer == nil { recognizer = SFSpeechRecognizer() }
        return recognizer
    }

    private func captureStarted() {
        onStarted?()
    }

    private func append(_ data: Data, rms: Float) {
        guard isActive else { return }
        let frames = AVAudioFrameCount(data.count / 2)
        guard frames > 0,
              let request,
              let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frames),
              let channel = buffer.int16ChannelData?[0]
        else { return }
        buffer.frameLength = frames
        data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: Int16.self).baseAddress else { return }
            channel.update(from: base, count: Int(frames))
        }
        request.append(buffer)
        hasAudio = true
        onLevel?(Self.level(rms: rms))
    }

    private func captureEnded() {
        // Interrupted (a call, Siri, another app's audio) or stopped: finish
        // with what we have rather than lose it.
        guard isActive else { return }
        request?.endAudio()
        end()
    }

    private func end() {
        guard isActive else { return }
        isActive = false
        let failedBeforeStart = !hasAudio
        capture.stop()
        task = nil
        request = nil
        onEnded?(failedBeforeStart)
    }

    /// Speech sits around -40...-10 dBFS; map that range onto 0...1, the same
    /// way the app does.
    private static func level(rms: Float) -> Float {
        let decibels = 20 * log10(max(rms, 0.000_01))
        return min(max((decibels + 50) / 40, 0), 1)
    }
}

/// Reads the microphone through `getUserMedia` in a hidden `WKWebView`. WebKit
/// records in its own processes, which the host app can't shut off the way it
/// does a keyboard's `AVAudioEngine`. Emits 16 kHz mono Int16 PCM.
///
/// Adapted from WebAudioCapture in stephancill/ios-keyboard-dictation,
/// Copyright (c) 2026 Stephan Cilliers, MIT License.
@MainActor
final class WebAudioCapture: NSObject {
    static let sampleRate: Double = 16_000
    private static let baseURL = URL(string: "https://tapeze-dictation.invalid/")

    var onStarted: (() -> Void)?
    var onAudio: ((Data, Float) -> Void)?
    var onEnded: ((String) -> Void)?

    private(set) var isReady = false
    private(set) var isCapturing = false
    private let webView: WKWebView
    private var heartbeat: Timer?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: configuration)
        super.init()
        configuration.userContentController.add(WeakMessageHandler(self), name: "capture")
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.alpha = 0.01
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.isUserInteractionEnabled = false
        webView.accessibilityElementsHidden = true
    }

    func attach(to view: UIView) {
        guard webView.superview == nil else { return }
        view.addSubview(webView)
        view.sendSubviewToBack(webView)
        // An https base URL makes a secure context, which getUserMedia needs.
        webView.loadHTMLString(Self.page, baseURL: Self.baseURL)
    }

    func start() {
        guard isReady, !isCapturing else {
            onEnded?("not ready")
            return
        }
        isCapturing = true
        heartbeat = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.webView.evaluateJavaScript("captureHeartbeat(); 0") }
        }
        webView.evaluateJavaScript("startCapture(); 0") { [weak self] _, error in
            if let error {
                Task { @MainActor in self?.finish(reason: "start failed: \(error.localizedDescription)") }
            }
        }
    }

    func stop() {
        guard isCapturing else { return }
        webView.evaluateJavaScript("stopCapture(); 0")
        finish(reason: "stopped")
    }

    func tearDown() {
        stop()
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "capture")
        webView.removeFromSuperview()
    }

    private func finish(reason: String) {
        heartbeat?.invalidate()
        heartbeat = nil
        guard isCapturing else { return }
        isCapturing = false
        onEnded?(reason)
    }

    fileprivate func handle(_ body: Any) {
        guard let message = body as? [String: Any], let type = message["type"] as? String else { return }
        switch type {
        case "ready":
            isReady = true
        case "started":
            onStarted?()
        case "audio":
            guard isCapturing,
                  let base64 = message["data"] as? String,
                  let data = Data(base64Encoded: base64) else { return }
            onAudio?(data, (message["rms"] as? NSNumber)?.floatValue ?? 0)
        case "interrupted", "failed":
            finish(reason: "\(type): \(message["reason"] as? String ?? "unknown")")
        default:
            break
        }
    }

    private static let page = """
    <!doctype html><html><body><script>
    const targetRate = \(Int(sampleRate));
    const post = message => window.webkit.messageHandlers.capture.postMessage(message);
    const encode = samples => {
      const bytes = new Uint8Array(samples.buffer, 0, samples.length * 2);
      let binary = '';
      for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
      return btoa(binary);
    };
    let lastHeartbeat = performance.now();
    window.captureHeartbeat = () => { lastHeartbeat = performance.now(); };
    let stopCapture = () => {};
    window.stopCapture = () => stopCapture();
    window.startCapture = async () => {
      let stopping = false, stream, context, source, processor, sink, watchdog;
      const audioSession = navigator.audioSession;
      const previousType = audioSession?.type ?? 'auto';
      const cleanup = () => {
        if (stopping) return;
        stopping = true;
        clearInterval(watchdog);
        if (processor) { processor.onaudioprocess = null; processor.disconnect(); }
        source?.disconnect();
        sink?.disconnect();
        stream?.getTracks().forEach(track => track.stop());
        context?.close().catch(() => {});
        try { if (audioSession) audioSession.type = previousType; } catch (_) {}
      };
      const interrupted = reason => { if (!stopping) { cleanup(); post({ type: 'interrupted', reason }); } };
      stopCapture = cleanup;
      try {
        try { if (audioSession) audioSession.type = 'play-and-record'; } catch (_) {}
        stream = await navigator.mediaDevices.getUserMedia({
          audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
        });
        if (stopping) { stream.getTracks().forEach(track => track.stop()); return; }
        const track = stream.getAudioTracks()[0];
        track.onended = () => interrupted('track-ended');
        // Create the AudioContext only now: making one early can take audio focus.
        context = new AudioContext({ latencyHint: 'interactive' });
        await context.resume();
        processor = context.createScriptProcessor(1024, 1, 1);
        sink = context.createGain();
        sink.gain.value = 0;
        processor.connect(sink);
        sink.connect(context.destination);
        source = context.createMediaStreamSource(stream);
        source.connect(processor);
        context.onstatechange = () => { if (context.state !== 'running') interrupted('context-' + context.state); };
        if (audioSession) audioSession.onstatechange = () => { if (audioSession.state === 'interrupted') interrupted('audio-session-interrupted'); };
        lastHeartbeat = performance.now();
        // If the keyboard goes away without saying so, let go of the mic.
        watchdog = setInterval(() => { if (performance.now() - lastHeartbeat > 3000) interrupted('native-heartbeat-expired'); }, 500);
        const step = context.sampleRate / targetRate;
        let position = 0, sum = 0, count = 0;
        processor.onaudioprocess = event => {
          const input = event.inputBuffer.getChannelData(0);
          const output = new Int16Array(Math.ceil(input.length / step) + 1);
          let written = 0, energy = 0;
          for (const sample of input) {
            energy += sample * sample; sum += sample; count += 1; position += 1;
            if (position >= step) {
              position -= step;
              output[written++] = Math.max(-1, Math.min(1, sum / count)) * 32767;
              sum = 0; count = 0;
            }
          }
          if (written > 0) post({ type: 'audio', data: encode(output.subarray(0, written)), rms: Math.sqrt(energy / input.length) });
        };
        post({ type: 'started', sampleRate: context.sampleRate });
      } catch (error) {
        if (stopping) return;
        cleanup();
        post({ type: 'failed', reason: error.name + ': ' + error.message });
      }
    };
    post({ type: 'ready' });
    </script></body></html>
    """
}

extension WebAudioCapture: WKUIDelegate, WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        // The system mic permission still applies; this only skips WebKit's
        // own per-site prompt for our local page.
        decisionHandler(type == .microphone ? .grant : .deny)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        isReady = false
        finish(reason: "web content process terminated")
        webView.loadHTMLString(Self.page, baseURL: Self.baseURL)
    }
}

/// Breaks the retain cycle between `WKUserContentController` and its handler.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WebAudioCapture?
    init(_ target: WebAudioCapture) { self.target = target }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        // WebKit calls script message handlers on the main thread, in order;
        // keeping that order matters for the audio chunks.
        MainActor.assumeIsolated { target?.handle(message.body) }
    }
}
