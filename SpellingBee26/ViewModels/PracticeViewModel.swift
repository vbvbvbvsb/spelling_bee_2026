import Foundation

enum PracticeResult: Equatable {
    case none
    case correct
    case incorrect(correctSpelling: String, attemptedSpelling: String)
}

@MainActor
@Observable
final class PracticeViewModel {
    private let wordRepository: WordRepository
    private let statsStore: StatsStore
    private let speechService = SpeechSynthesizerService()
    let recognitionService = SpellingRecognitionService()

    private(set) var queue: [SpellingWord] = []
    private(set) var currentIndex = 0
    private(set) var result: PracticeResult = .none
    private(set) var isProcessing = false
    private(set) var sessionAttempts = 0
    private(set) var sessionCorrect = 0
    private(set) var statusMessage: String?

    var currentWord: SpellingWord? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var progressLabel: String {
        guard !queue.isEmpty else { return "No words loaded" }
        return "Word \(min(currentIndex + 1, queue.count)) of \(queue.count)"
    }

    var sessionSuccessRateLabel: String {
        guard sessionAttempts > 0 else { return "—" }
        let rate = Int((Double(sessionCorrect) / Double(sessionAttempts) * 100).rounded())
        return "\(rate)% today"
    }

    var heardLettersDisplay: String {
        let parsed = recognitionService.parsedSpelling()
        if !parsed.isEmpty {
            return parsed.uppercased().map(String.init).joined(separator: " ")
        }
        return recognitionService.liveTranscript
    }

    init(wordRepository: WordRepository, statsStore: StatsStore) {
        self.wordRepository = wordRepository
        self.statsStore = statsStore
        recognitionService.refreshAuthorizationStatus()
        reloadQueue()
    }

    func reloadQueue(startingWith wordID: String? = nil) {
        queue = statsStore.buildQueue(from: wordRepository.words)
        if let wordID, let index = queue.firstIndex(where: { $0.id == wordID }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
        result = .none
        statusMessage = nil
    }

    func speakWord() {
        guard let word = currentWord else { return }
        speechService.speak(word.primarySpelling)
    }

    func speakDefinition() {
        guard let word = currentWord else { return }
        speechService.speak(word.definition, rate: 0.5)
    }

    func startSpelling() async {
        guard currentWord != nil, result == .none else { return }
        statusMessage = nil

        do {
            try await recognitionService.startListening()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func finishSpelling() {
        guard let word = currentWord, result == .none else { return }

        recognitionService.stopListening()

        let transcript = recognitionService.liveTranscript
        let attemptedSpelling = SpellingNormalizer.parseSpelling(from: transcript)
        let isCorrect = SpellingNormalizer.matches(
            recognized: transcript,
            acceptedSpellings: word.acceptedSpellings
        )

        sessionAttempts += 1
        statsStore.recordAttempt(
            wordID: word.id,
            correct: isCorrect,
            attemptedSpelling: attemptedSpelling.isEmpty ? transcript : attemptedSpelling,
            rawTranscript: transcript
        )

        if isCorrect {
            sessionCorrect += 1
            result = .correct
            FeedbackService.playSuccess()
            scheduleAdvance()
        } else {
            let displayAttempt = attemptedSpelling.isEmpty ? transcript : attemptedSpelling
            result = .incorrect(
                correctSpelling: word.primarySpelling,
                attemptedSpelling: displayAttempt
            )
            FeedbackService.playMiss()
            scheduleAdvance()
        }
    }

    func dismissResultAndAdvance() {
        guard result != .none else { return }
        advanceWord()
    }

    private func scheduleAdvance() {
        isProcessing = true
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            advanceWord()
            isProcessing = false
        }
    }

    private func advanceWord() {
        result = .none
        statusMessage = nil
        recognitionService.stopListening()

        if currentIndex + 1 < queue.count {
            currentIndex += 1
        } else {
            reloadQueue()
        }
    }
}
