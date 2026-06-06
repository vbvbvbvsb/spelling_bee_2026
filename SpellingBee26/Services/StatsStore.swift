import Foundation

struct MissRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let attemptedSpelling: String
    let rawTranscript: String
    let date: Date

    init(attemptedSpelling: String, rawTranscript: String, date: Date = Date()) {
        self.id = UUID()
        self.attemptedSpelling = attemptedSpelling
        self.rawTranscript = rawTranscript
        self.date = date
    }
}

struct WordStat: Codable, Hashable {
    var attempts: Int = 0
    var misses: Int = 0
    var lastAttempt: Date?
    var missHistory: [MissRecord] = []

    var wrongSpellingCounts: [String: Int] {
        Dictionary(grouping: missHistory, by: \.attemptedSpelling)
            .mapValues(\.count)
            .filter { !$0.key.isEmpty }
    }

    var topWrongSpellings: [(spelling: String, count: Int)] {
        wrongSpellingCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .map { (spelling: $0.key, count: $0.value) }
    }
}

struct SessionStats: Codable {
    var perWord: [String: WordStat] = [:]
    var totalAttempts: Int = 0
    var totalCorrect: Int = 0
}

@Observable
final class StatsStore {
    private let storageKey = "spellingStats.v2"
    private let maxMissHistoryPerWord = 20
    private(set) var stats = SessionStats()

    init() {
        load()
    }

    var successRate: Double {
        guard stats.totalAttempts > 0 else { return 0 }
        return Double(stats.totalCorrect) / Double(stats.totalAttempts)
    }

    var successRatePercent: Int {
        Int((successRate * 100).rounded())
    }

    var hardWordIDs: [String] {
        stats.perWord
            .filter { $0.value.misses >= 2 }
            .map(\.key)
            .sorted()
    }

    func neverPracticedCount(allWordIDs: [String]) -> Int {
        allWordIDs.filter { stats.perWord[$0]?.attempts ?? 0 == 0 }.count
    }

    func suggestedDailyTarget(for words: [SpellingWord]) -> Int {
        let remaining = neverPracticedCount(allWordIDs: words.map(\.id))
        guard AppTheme.daysUntilBee > 0 else { return remaining }
        return max(1, Int(ceil(Double(remaining) / Double(AppTheme.daysUntilBee))))
    }

    func stat(for wordID: String) -> WordStat {
        stats.perWord[wordID] ?? WordStat()
    }

    func recordAttempt(
        wordID: String,
        correct: Bool,
        attemptedSpelling: String? = nil,
        rawTranscript: String? = nil
    ) {
        var wordStat = stats.perWord[wordID] ?? WordStat()
        wordStat.attempts += 1
        wordStat.lastAttempt = Date()
        if !correct {
            wordStat.misses += 1
            if let attemptedSpelling, !attemptedSpelling.isEmpty {
                wordStat.missHistory.append(
                    MissRecord(
                        attemptedSpelling: attemptedSpelling,
                        rawTranscript: rawTranscript ?? attemptedSpelling
                    )
                )
                if wordStat.missHistory.count > maxMissHistoryPerWord {
                    wordStat.missHistory.removeFirst(wordStat.missHistory.count - maxMissHistoryPerWord)
                }
            }
        }
        stats.perWord[wordID] = wordStat
        stats.totalAttempts += 1
        if correct {
            stats.totalCorrect += 1
        }
        save()
    }

    func globalWrongSpellingPatterns(limit: Int = 10) -> [(spelling: String, count: Int)] {
        var totals: [String: Int] = [:]
        for wordStat in stats.perWord.values {
            for record in wordStat.missHistory where !record.attemptedSpelling.isEmpty {
                totals[record.attemptedSpelling, default: 0] += 1
            }
        }
        return totals
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(limit)
            .map { (spelling: $0.key, count: $0.value) }
    }

    func buildQueue(from words: [SpellingWord]) -> [SpellingWord] {
        let hard = words.filter { stat(for: $0.id).misses >= 2 }.shuffled()
        let unseen = words.filter { stat(for: $0.id).attempts == 0 }.shuffled()
        let rest = words.filter {
            let s = stat(for: $0.id)
            return s.misses < 2 && s.attempts > 0
        }.shuffled()

        return hard + unseen + rest
    }

    func hardWords(from words: [SpellingWord]) -> [SpellingWord] {
        let ids = Set(hardWordIDs)
        return words.filter { ids.contains($0.id) }
            .sorted { lhs, rhs in
                stat(for: lhs.id).misses > stat(for: rhs.id).misses
            }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(SessionStats.self, from: data) {
            stats = decoded
            return
        }

        if let legacyData = UserDefaults.standard.data(forKey: "spellingStats.v1"),
           let legacy = try? JSONDecoder().decode(SessionStats.self, from: legacyData) {
            stats = legacy
            save()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
