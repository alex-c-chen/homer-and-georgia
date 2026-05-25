import SwiftUI

struct QuestionAnswerCard: View {
    let question: QuestionDetail
    @Bindable var viewModel: TopicAnswerViewModel
    var tint: Color = Theme.generalTint

    @State private var expanded = true

    private var result: TopicAnswerViewModel.AnswerResult? { viewModel.results[question.id] }
    private var locked: Bool { viewModel.hasSubmitted }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader

            if expanded {
                Text(question.prompt)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                if let result {
                    resultSection(result)
                } else {
                    answerInput
                }
            }
        }
        .glassCard(tint: result == nil ? tint : (result?.isCorrect == true ? Theme.success : Theme.failure))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: expanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: result?.sessionId)
    }

    // MARK: - Header

    private var cardHeader: some View {
        Button {
            expanded.toggle()
        } label: {
            HStack(spacing: 8) {
                Badge(text: typeLabel, color: tint)
                Badge(text: difficultyLabel)
                Spacer()
                if let result {
                    Image(systemName: result.isCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.isCorrect == true ? Theme.success : Theme.failure)
                } else if viewModel.isAnswered(question) {
                    Image(systemName: "circle.inset.filled").foregroundStyle(tint)
                }
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input

    @ViewBuilder
    private var answerInput: some View {
        if let options = question.options {
            VStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    optionButton(option)
                }
            }
        } else {
            ZStack(alignment: .topLeading) {
                if (viewModel.answers[question.id] ?? "").isEmpty {
                    Text("Type your answer…")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: Binding(
                    get: { viewModel.answers[question.id] ?? "" },
                    set: { viewModel.answers[question.id] = $0 }
                ))
                .frame(minHeight: 90)
                .scrollContentBackground(.hidden)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func optionButton(_ option: String) -> some View {
        let selected = viewModel.selectedOptions[question.id] == option
        return Button {
            viewModel.selectedOptions[question.id] = option
        } label: {
            HStack {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? tint : .secondary)
                Text(option)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(14)
            .background(
                selected ? tint.opacity(0.12) : Color(.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }

    // MARK: - Result

    private func resultSection(_ result: TopicAnswerViewModel.AnswerResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: result.isCorrect == true ? "checkmark.seal.fill" : "xmark.seal.fill")
                Text(gradeLabel(result.isCorrect))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(result.isCorrect == true ? Theme.success : Theme.failure)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your answer").font(.caption).foregroundStyle(.secondary)
                Text(viewModel.answerText(for: question))
                    .font(.subheadline)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Answer key").font(.caption).foregroundStyle(.secondary)
                Text(result.answerKey)
                    .font(.subheadline.weight(.medium))
            }

            if !result.explanation.isEmpty {
                Text(result.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink(value: ChatDestination(
                sessionId: result.sessionId,
                prompt: question.prompt,
                typeLabel: typeLabel
            )) {
                HStack {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                    Text("Discuss with AI")
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: Capsule())
                .foregroundStyle(tint)
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Labels

    private func gradeLabel(_ correct: Bool?) -> String {
        switch correct {
        case .some(true): return "Correct"
        case .some(false): return "Let's review"
        case .none: return "Submitted"
        }
    }

    private var typeLabel: String {
        switch question.questionTypeId {
        case 1: return "Mental"
        case 2: return "Short Answer"
        case 3: return "Intermediate"
        default: return "Question"
        }
    }

    private var difficultyLabel: String {
        switch question.difficulty {
        case 1: return "Easy"
        case 2: return "Medium"
        case 3: return "Hard"
        default: return ""
        }
    }
}
