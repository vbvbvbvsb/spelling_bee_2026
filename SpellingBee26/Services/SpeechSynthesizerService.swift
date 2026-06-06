import AVFoundation

@MainActor
final class SpeechSynthesizerService {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, rate: Float = 0.45) {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
