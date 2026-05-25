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
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: ChatDestination.self) { dest in
                ChatView(sessionId: dest.sessionId, questionPrompt: dest.prompt, questionType: dest.typeLabel)
            }
    }

    // Math topics have no reading — go straight to the quiz.
    @ViewBuilder
    private var content: some View {
        if topic.isMath {
            QuizView(topic: topic, questions: questions, viewModel: quizVM, tint: tint)
        } else {
            VStack(spacing: 0) {
                GlassTabBar(selected: $selectedTab, labels: ["Read", "Quiz"], tint: tint)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                if selectedTab == 0 {
                    ArticleView(topicId: topic.id, viewModel: articleVM, tint: tint)
                        .transition(.opacity)
                } else {
                    QuizView(topic: topic, questions: questions, viewModel: quizVM, tint: tint)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)
        }
    }
}

/// Routing payload for opening the chat from a graded question card.
struct ChatDestination: Hashable {
    let sessionId: UUID
    let prompt: String
    let typeLabel: String
}
