import SwiftUI

struct StatsView: View {
    let wordRepository: WordRepository
    let statsStore: StatsStore
    var onPracticeWord: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                summarySection
                countdownSection
                patternsSection
                hardWordsSection
            }
            .navigationTitle("Stats")
        }
    }

    private var summarySection: some View {
        Section("Overall") {
            LabeledContent("Total attempts", value: "\(statsStore.stats.totalAttempts)")
            LabeledContent("Success rate", value: "\(statsStore.successRatePercent)%")
            LabeledContent("Correct", value: "\(statsStore.stats.totalCorrect)")
        }
    }

    private var countdownSection: some View {
        Section("9-day plan") {
            LabeledContent(
                "Never practiced",
                value: "\(statsStore.neverPracticedCount(allWordIDs: wordRepository.words.map(\.id)))"
            )
            LabeledContent(
                "Suggested daily target",
                value: "\(statsStore.suggestedDailyTarget(for: wordRepository.words)) words"
            )
            LabeledContent("Days until bee", value: "\(AppTheme.daysUntilBee)")
        }
    }

    private var patternsSection: some View {
        Section("Common wrong spellings") {
            let patterns = statsStore.globalWrongSpellingPatterns()

            if patterns.isEmpty {
                Text("Wrong spellings will show up here after missed words.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(patterns, id: \.spelling) { pattern in
                    LabeledContent(pattern.spelling, value: "\(pattern.count)×")
                }
            }
        }
    }

    private var hardWordsSection: some View {
        Section(AppTheme.hardWordsLabel) {
            let hardWords = statsStore.hardWords(from: wordRepository.words)

            if hardWords.isEmpty {
                Text("No hard words yet — keep practicing!")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(hardWords) { word in
                    Button {
                        onPracticeWord(word.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(word.primarySpelling)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("Missed \(statsStore.stat(for: word.id).misses) times")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .foregroundStyle(.secondary)
                            }

                            let wrongSpellings = statsStore.stat(for: word.id).topWrongSpellings.prefix(3)
                            if !wrongSpellings.isEmpty {
                                Text(
                                    wrongSpellings
                                        .map { "\($0.spelling) (\($0.count)×)" }
                                        .joined(separator: " · ")
                                )
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        }
    }
}
