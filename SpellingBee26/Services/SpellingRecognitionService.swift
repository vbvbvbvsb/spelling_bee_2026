import AVFoundation
import Foundation
import Speech

@MainActor
@Observable
final class SpellingRecognitionService {
    enum AuthorizationState {
        case notDetermined
        case authorized
        case denied
        case restricted
    }

    private(set) var authorizationState: AuthorizationState = .notDetermined
    private(set) var isListening = false
    private(set) var liveTranscript = ""
    private(set) var errorMessage: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func refreshAuthorizationStatus() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            authorizationState = .authorized
        case .denied:
            authorizationState = .denied
        case .restricted:
            authorizationState = .restricted
        case .notDetermined:
            authorizationState = .notDetermined
        @unknown default:
            authorizationState = .denied
        }
    }

    func requestAuthorization() async -> AuthorizationState {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        switch speechStatus {
        case .authorized:
            authorizationState = .authorized
        case .denied:
            authorizationState = .denied
        case .restricted:
            authorizationState = .restricted
        case .notDetermined:
            authorizationState = .notDetermined
        @unknown default:
            authorizationState = .denied
        }

        return authorizationState
    }

    func startListening() async throws {
        errorMessage = nil

        if authorizationState != .authorized {
            let status = await requestAuthorization()
            guard status == .authorized else {
                throw RecognitionError.notAuthorized
            }
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            throw RecognitionError.microphoneDenied
        }

        stopListening()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw RecognitionError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition

        recognitionRequest = request
        liveTranscript = ""

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.liveTranscript = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    self.teardownAudioEngine()
                }
            }
        }
    }

    func stopListening() {
        recognitionRequest?.endAudio()
        teardownAudioEngine()
    }

    func parsedSpelling() -> String {
        SpellingNormalizer.parseSpelling(from: liveTranscript)
    }

    private func teardownAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    enum RecognitionError: LocalizedError {
        case notAuthorized
        case microphoneDenied
        case recognizerUnavailable

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                "Speech recognition permission is required to check spelling."
            case .microphoneDenied:
                "Microphone permission is required to hear spelling."
            case .recognizerUnavailable:
                "Speech recognition is not available right now."
            }
        }
    }
}
