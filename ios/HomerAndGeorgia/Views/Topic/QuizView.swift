import SwiftUI

struct QuizView: View {
    let topic: Topic
    let questions: [QuestionMeta]
    @Bindable var viewModel: TopicAnswerViewModel
    var tint: Color = Theme.generalTint

    @State private var startedAt = Date()

    private var hasPriorContext: Bool { questions.contains { $0.priorQuestionId != nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if hasPriorContext {
                    priorContextRow
                }

                if viewModel.isLoading && viewModel.questions.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ForEach(viewModel.questions) { question in
                        QuestionAnswerCard(
                            question: question,
                            viewModel: viewModel,
                            tint: tint
                        )
                    }
                }

                if let error = viewModel.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.failure)
                }

                if !viewModel.hasSubmitted {
                    submitButton
                } else {
                    completedBanner
                }
            }
            .padding()
        }
        .task {
            startedAt = Date()
            if viewModel.questions.isEmpty {
                await viewModel.load(questionIds: questions.map(\.id))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(topic.emoji).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.isMath ? "Mathematics" : "General Knowledge")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                    Text("\(viewModel.answeredCount) of \(viewModel.questions.count) answered")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let description = topic.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: tint)
    }

    private var priorContextRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundStyle(tint)
            Text("Builds on a question from a previous day")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .glassBackground(in: RoundedRectangle(cornerRadius: Theme.inputCorner, style: .continuous))
    }

    // MARK: - Submit / completed

    private var submitButton: some View {
        Button {
            Task {
                let elapsed = Int(Date().timeIntervalSince(startedAt))
                await viewModel.submitAll(timeSpent: elapsed)
            }
        } label: {
            HStack {
                if viewModel.isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(viewModel.isSubmitting ? "Grading…" : "Submit All Answers")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: Theme.ctaCorner, style: .continuous))
            .foregroundStyle(.white)
        }
        .disabled(!viewModel.canSubmit)
        .opacity(viewModel.canSubmit ? 1 : 0.5)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.canSubmit)
        .padding(.top, 4)
    }

    private var completedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.success)
                .symbolEffect(.bounce, value: viewModel.hasSubmitted)
            Text("Answers submitted — expand a card to review or discuss.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassBackground(in: RoundedRectangle(cornerRadius: Theme.inputCorner, style: .continuous))
    }
}
