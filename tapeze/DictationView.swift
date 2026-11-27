import AVFoundation
import Speech
import SwiftUI

/// Runs the microphone for the keyboard's mic key.
///
/// The keyboard can't record, and iOS only lets an app turn the mic on while
/// it's in the foreground. So the first mic tap opens Tapeze, which starts
/// the audio engine and keeps it running in the background (the `audio`
/// background mode) for `DictationBridge.warmIdleTimeout`. Buffers are only
/// fed to the recognizer between a start and a stop from the keyboard; the
/// rest of the time they're dropped.
@MainActor
final class DictationService: ObservableObject {
    static let shared = DictationService()

    @Published private(set) var status = DictationStatus()

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest? {
        didSet { requestBox.set(request) }
    }
    /// The tap runs on the audio thread and must append each buffer before it
    /// returns (the engine reuses them), so it reads the request from here.
    private let requestBox = RequestBox()
    private var task: SFSpeechRecognitionTask?
    private var heartbeatTimer: Timer?
    private var lastActivity = Date()
    private var lastLevelWrite = Date.distantPast
    private var isWarm: Bool { audioEngine.isRunning }

    private init() {
        // Keep counting sessions from wherever a previous launch left off, so
        // the keyboard never mistakes a new session for one it already handled.
        status.session = DictationBridge.readStatus().session
        DictationBridge.observe(DictationBridge.startNotification) { [weak self] in
            self?.startListening()
        }
        DictationBridge.observe(DictationBridge.stopNotification) { [weak self] in
            self?.stopListening()
        }
        DictationBridge.observe(DictationBridge.cancelNotification) { [weak self] in
            self?.cancelListening()
        }
    }

    /// The mic key opened the app: switch the mic on and start listening.
    func openedFromKeyboard() async {
        if !isWarm {
            guard await warmUp() else { return }
        }
        startListening()
    }

    // MARK: Warm mic

    private func warmUp() async -> Bool {
        guard await Self.speechAuthorized() else {
            publishUnavailable("Allow Speech Recognition for Tapeze in Settings to dictate.")
            return false
        }
        guard await Self.microphoneAuthorized() else {
            publishUnavailable("Allow Microphone access for Tapeze in Settings to dictate.")
            return false
        }
        guard let recognizer, recognizer.isAvailable else {
            publishUnavailable("Speech recognition isn't available for your language right now.")
            return false
        }

        do {
            let session = AVAudioSession.sharedInstance()
            // mixWithOthers keeps the user's music playing while the mic is warm.
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)

            let input = audioEngine.inputNode
            let box = requestBox
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { [weak self] buffer, _ in
                guard let request = box.get() else { return }
                request.append(buffer)
                let level = Self.level(of: buffer)
                Task { @MainActor in self?.handleLevel(level) }
            }
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            shutDown()
            publishUnavailable("Couldn't start the microphone: \(error.localizedDescription)")
            return false
        }

        lastActivity = Date()
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: DictationBridge.heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        status.message = nil
        if status.phase == .unavailable { status.phase = .idle }
        publish()
        return true
    }

    private func tick() {
        if status.phase != .listening,
           Date().timeIntervalSince(lastActivity) > DictationBridge.warmIdleTimeout {
            shutDown()
            return
        }
        publish()
    }

    /// Turns the mic off; the next mic tap opens the app again.
    func shutDown() {
        endRecognition()
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if status.phase == .listening { status.phase = .finished }
        status.level = 0
        status.heartbeat = 0
        DictationBridge.writeStatus(status)
    }

    // MARK: Listening

    private func startListening() {
        guard isWarm, let recognizer else { return }
        endRecognition()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            // Keeps speech on the phone, and lifts the one-minute server limit.
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        status.session += 1
        status.phase = .listening
        status.transcript = ""
        status.message = nil
        let session = status.session
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal == true
            Task { @MainActor in
                guard let self, self.status.session == session, self.status.phase == .listening else { return }
                if let text { self.status.transcript = text }
                if isFinal || error != nil {
                    self.stopListening()
                } else {
                    self.publish()
                }
            }
        }
        lastActivity = Date()
        publish()
    }

    private func stopListening() {
        guard status.phase == .listening else { return }
        endRecognition()
        status.phase = .finished
        status.level = 0
        lastActivity = Date()
        publish()
    }

    private func cancelListening() {
        guard status.phase == .listening else { return }
        endRecognition()
        status.phase = .cancelled
        status.transcript = ""
        status.level = 0
        lastActivity = Date()
        publish()
    }

    private func endRecognition() {
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }

    private func handleLevel(_ level: Float) {
        guard status.phase == .listening else { return }
        status.level = level
        // The waveform wants ~15 updates a second, not one per buffer.
        if Date().timeIntervalSince(lastLevelWrite) > 0.066 {
            publish()
        }
    }

    private func publish() {
        status.heartbeat = isWarm ? Date().timeIntervalSince1970 : 0
        lastLevelWrite = Date()
        DictationBridge.writeStatus(status)
    }

    private func publishUnavailable(_ message: String) {
        status.phase = .unavailable
        status.message = message
        status.heartbeat = 0
        DictationBridge.writeStatus(status)
    }

    // MARK: Helpers

    nonisolated private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<count { sum += samples[index] * samples[index] }
        let rms = (sum / Float(count)).squareRoot()
        // Speech sits around -40...-10 dBFS; map that range onto 0...1.
        let decibels = 20 * log10(max(rms, 0.000_01))
        return min(max((decibels + 50) / 40, 0), 1)
    }

    private static func speechAuthorized() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private static func microphoneAuthorized() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

private final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock(); defer { lock.unlock() }
        self.request = request
    }

    func get() -> SFSpeechAudioBufferRecognitionRequest? {
        lock.lock(); defer { lock.unlock() }
        return request
    }
}

/// The small card shown for the one hop into the app.
struct MicReadyView: View {
    let launch: UUID
    let onClose: () -> Void

    @ObservedObject private var service = DictationService.shared
    @State private var isStarting = true

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "mic")
                .font(.system(size: 54, weight: .light))
                .foregroundColor(isUnavailable ? .secondary : .orange)
            Text(headline)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if isUnavailable {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            Button("Close", action: onClose)
                .foregroundColor(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task(id: launch) {
            isStarting = true
            await service.openedFromKeyboard()
            isStarting = false
        }
    }

    private var isUnavailable: Bool { service.status.phase == .unavailable }

    private var headline: String {
        if isUnavailable { return "Can't dictate yet" }
        return isStarting ? "Starting the mic…" : "Mic ready"
    }

    private var detail: String {
        if isUnavailable { return service.status.message ?? "" }
        return "Tap ◀ in the top-left corner to go back. You're already being heard, and the keyboard will show your words.\n\nFor the next few minutes, the mic key works without coming here."
    }
}
