import SwiftUI

struct PracticeView: View {
    @Bindable var viewModel: PracticeViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    heardSection
                    actionButtons
                    resultSection
                }
                .padding()
            }
            .background(AppTheme.backgroundColor)
            .navigationTitle("Practice")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.progressLabel)
                .font(.headline)

            Text("Session: \(viewModel.sessionSuccessRateLabel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var heardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heard so far")
                .font(.headline)

            Text(viewModel.heardLettersDisplay.isEmpty ? "Tap Start Spelling, say letters, then Done." : viewModel.heardLettersDisplay)
                .font(.system(.title2, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .minimumScaleFactor(0.5)
                .lineLimit(3)

            if viewModel.recognitionService.isListening {
                Label("Listening…", systemImage: "mic.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                practiceButton(AppTheme.speakWordLabel, systemImage: "speaker.wave.2.fill") {
                    viewModel.speakWord()
                }

                practiceButton(AppTheme.speakDefinitionLabel, systemImage: "text.book.closed.fill") {
                    viewModel.speakDefinition()
                }
            }

            HStack(spacing: 12) {
                practiceButton(
                    AppTheme.startSpellingLabel,
                    systemImage: "mic.circle.fill",
                    isProminent: true,
                    disabled: viewModel.recognitionService.isListening || viewModel.result != .none
                ) {
                    Task { await viewModel.startSpelling() }
                }

                practiceButton(
                    AppTheme.doneSpellingLabel,
                    systemImage: "checkmark.circle.fill",
                    isProminent: true,
                    disabled: !viewModel.recognitionService.isListening
                ) {
                    viewModel.finishSpelling()
                }
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.result {
        case .none:
            EmptyView()
        case .correct:
            VStack(spacing: 12) {
                Image(systemName: AppTheme.successSystemImage)
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.successColor)
                Text("Correct!")
                    .font(.title.bold())
                    .foregroundStyle(AppTheme.successColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        case .incorrect(let correctSpelling, let attemptedSpelling):
            VStack(spacing: 8) {
                if !attemptedSpelling.isEmpty {
                    Text("You spelled:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(attemptedSpelling)
                        .font(.title2.bold())
                }
                Text("Correct spelling:")
                    .font(.headline)
                Text(correctSpelling)
                    .font(.title.bold())
                    .foregroundStyle(AppTheme.errorColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func practiceButton(
        _ title: String,
        systemImage: String,
        isProminent: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            if isProminent {
                Button(action: action) {
                    buttonLabel(title: title, systemImage: systemImage)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) {
                    buttonLabel(title: title, systemImage: systemImage)
                }
                .buttonStyle(.bordered)
            }
        }
        .disabled(disabled)
    }

    private func buttonLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
    }
}
