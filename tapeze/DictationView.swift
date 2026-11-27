import AVFoundation
import Speech
import SwiftUI

/// Listens for the keyboard's mic key. The keyboard can't record, so it opens
/// the app here; whatever the user says is handed back through
/// `DictationBridge` as soon as they leave, whether they tap Done or go
/// straight back with the system's top-left back arrow.
@MainActor
final class SpeechDictation: ObservableObject {
    enum Phase: Equatable {
        case starting
        case listening
        case finished
        case unavailable(String)
    }

    @Published private(set) var phase: Phase = .starting
    @Published private(set) var transcript = ""

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var hasTap = false

    func start() async {
        stopAudio()
        transcript = ""
        phase = .starting

        guard await Self.speechAuthorized() else {
            phase = .unavailable("Allow Speech Recognition for Tapeze in Settings to dictate.")
            return
        }
        guard await Self.microphoneAuthorized() else {
            phase = .unavailable("Allow Microphone access for Tapeze in Settings to dictate.")
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            phase = .unavailable("Speech recognition isn't available for your language right now.")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            if recognizer.supportsOnDeviceRecognition {
                // Keeps speech on the phone, and lifts the one-minute server limit.
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            let input = audioEngine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            hasTap = true
            audioEngine.prepare()
            try audioEngine.start()

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal == true
                Task { @MainActor in
                    guard let self else { return }
                    if let text { self.transcript = text }
                    if error != nil || isFinal { self.finish() }
                }
            }
            phase = .listening
        } catch {
            stopAudio()
            phase = .unavailable("Couldn't start the microphone: \(error.localizedDescription)")
        }
    }

    /// Stops listening and leaves the text for the keyboard.
    func finish() {
        guard phase == .listening else { return }
        stopAudio()
        DictationBridge.deliver(transcript)
        phase = .finished
    }

    /// Stops listening and throws the text away.
    func cancel() {
        stopAudio()
        DictationBridge.clear()
        transcript = ""
        phase = .finished
    }

    private func stopAudio() {
        if audioEngine.isRunning { audioEngine.stop() }
        if hasTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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

struct DictationView: View {
    let sessionID: UUID
    let onClose: () -> Void

    @StateObject private var speech = SpeechDictation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button("Cancel") {
                    speech.cancel()
                    onClose()
                }
                Spacer()
            }

            Spacer(minLength: 0)

            micBadge

            Text(headline)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            ScrollView {
                Text(speech.transcript.isEmpty ? placeholder : speech.transcript)
                    .font(.title3)
                    .foregroundColor(speech.transcript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 260)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Spacer(minLength: 0)

            actionButton
        }
        .padding(20)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task(id: sessionID) {
            await speech.start()
        }
        .onChange(of: scenePhase) { newPhase in
            // The user went back with the system's back arrow (or anywhere
            // else): hand over what we have so the keyboard can type it.
            if newPhase != .active {
                speech.finish()
            }
        }
    }

    private var micBadge: some View {
        ZStack {
            Circle()
                .fill(speech.phase == .listening ? Color.orange.opacity(0.18) : Color(.tertiarySystemFill))
                .frame(width: 120, height: 120)
            Image(systemName: speech.phase == .listening ? "mic.fill" : "mic")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(speech.phase == .listening ? .orange : .secondary)
        }
        .accessibilityHidden(true)
    }

    private var headline: String {
        switch speech.phase {
        case .starting: return "Getting ready…"
        case .listening: return "Listening"
        case .finished:
            return speech.transcript.isEmpty
                ? "Nothing to type"
                : "Tap ◀ in the top-left corner to go back. Tapeze will type it there."
        case .unavailable(let reason): return reason
        }
    }

    private var placeholder: String {
        speech.phase == .listening ? "Start speaking. Tap ◀ in the top-left corner when you're done." : ""
    }

    @ViewBuilder
    private var actionButton: some View {
        switch speech.phase {
        case .listening:
            Button {
                speech.finish()
            } label: {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
        case .unavailable:
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        case .starting, .finished:
            Button {
                onClose()
            } label: {
                Text("Close").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}
