import SwiftUI

struct TopicDetailView: View {
    let topic: Topic
    let questions: [QuestionMeta]

    @State private var quizVM = TopicAnswerViewModel()
    @State private var articleVM = ArticleViewModel()
    @State private var selectedTab = 0

    private var tint: Color { topic.isMath ? Theme.mathTint : Theme.generalTint }

    var body: some View {
        content
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.06), Color(.systemBackground)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()
            )
            .navigationTitle(topic.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $selectedTab) {
                        Text("Read").tag(0)
                        Text("Quiz").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            .navigationDestination(for: ChatDestination.self) { dest in
                ChatView(sessionId: dest.sessionId, questionPrompt: dest.prompt, questionType: dest.typeLabel)
            }
    }

    @ViewBuilder
    private var content: some View {
        if topic.isMath || selectedTab == 1 {
            QuizView(topic: topic, questions: questions, viewModel: quizVM, tint: tint)
                .transition(.opacity)
        } else {
            ArticleView(topicId: topic.id, viewModel: articleVM, tint: tint)
                .transition(.opacity)
        }
    }
}

/// Routing payload for opening the chat from a graded question card.
struct ChatDestination: Hashable {
    let sessionId: UUID
    let prompt: String
    let typeLabel: String
}
