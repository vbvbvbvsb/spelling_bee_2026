import Foundation

@Observable
final class WordRepository {
    private(set) var words: [SpellingWord] = []
    private(set) var loadError: String?

    init() {
        loadWords()
    }

    func word(for id: String) -> SpellingWord? {
        words.first { $0.id == id }
    }

    private func loadWords() {
        guard let url = Bundle.main.url(forResource: "spelling_bee_words_app", withExtension: "json") else {
            loadError = "Could not find spelling_bee_words_app.json in the app bundle."
            return
        }

        do {
            let data = try Data(contentsOf: url)
            words = try JSONDecoder().decode([SpellingWord].self, from: data)
            loadError = nil
        } catch {
            loadError = "Failed to load words: \(error.localizedDescription)"
        }
    }
}
