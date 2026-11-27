import Foundation
import Speech
import AVFoundation

/// Mic in the composer and "Hold to ask" on the Duo in tabletop: speech to text on the phone
/// (on-device recognition when available). Audio is never stored or sent anywhere.
@Observable
final class Dictation {
    enum State: Equatable { case idle, listening, denied, unavailable }

    private(set) var state: State = .idle
    private(set) var text = ""
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB")) ?? SFSpeechRecognizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var isListening: Bool { state == .listening }

    func start() async {
        guard state != .listening else { return }
        guard let recognizer, recognizer.isAvailable else { state = .unavailable; return }
        let speech = await SpeechBridge.authorize()
        let mic = await AVAudioApplication.requestRecordPermission()
        guard speech == .authorized, mic else { state = .denied; return }

        text = ""
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request

        SpeechBridge.installTap(on: engine.inputNode, feeding: request)
        engine.prepare()
        do { try engine.start() } catch { state = .unavailable; return }
        state = .listening

        task = SpeechBridge.recognize(with: recognizer, request: request) { [weak self] text, done in
            Task { @MainActor in
                guard let self else { return }
                if let text { self.text = text }
                if done { self.stop() }
            }
        }
    }

    /// Stops listening; the text so far stays in `text`.
    func stop() {
        guard state == .listening else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        state = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Speech and audio call back on background threads. These helpers are nonisolated so their
/// closures never assume the main thread (that assumption crashed the app on the first mic tap).
nonisolated private enum SpeechBridge {
    static func authorize() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) } }
    }

    static func installTap(on input: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) {
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
    }

    static func recognize(with recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest,
                          onUpdate: @escaping @Sendable (String?, Bool) -> Void) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            onUpdate(result?.bestTranscription.formattedString, error != nil || (result?.isFinal ?? false))
        }
    }
}
