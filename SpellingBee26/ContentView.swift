import SwiftUI

struct ContentView: View {
    @State private var wordRepository = WordRepository()
    @State private var statsStore = StatsStore()
    @State private var practiceViewModel: PracticeViewModel?
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if let loadError = wordRepository.loadError {
                errorView(loadError)
            } else if let practiceViewModel {
                TabView(selection: $selectedTab) {
                    PracticeView(viewModel: practiceViewModel)
                        .tabItem {
                            Label("Practice", systemImage: "pencil.and.list.clipboard")
                        }
                        .tag(0)

                    StatsView(
                        wordRepository: wordRepository,
                        statsStore: statsStore
                    ) { wordID in
                        practiceViewModel.reloadQueue(startingWith: wordID)
                        selectedTab = 0
                    }
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar.fill")
                    }
                    .tag(1)
                }
            } else {
                ProgressView("Loading words…")
            }
        }
        .onAppear {
            if practiceViewModel == nil, wordRepository.loadError == nil {
                practiceViewModel = PracticeViewModel(
                    wordRepository: wordRepository,
                    statsStore: statsStore
                )
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Could Not Load Words", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
    }
}

#Preview {
    ContentView()
}
