import SwiftUI

struct TopicDetailView: View {
    let topic: Topic
    let questions: [QuestionMeta]
    var namespace: Namespace.ID? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var quizVM = TopicAnswerViewModel()
    @State private var articleVM = ArticleViewModel()
    @State private var selectedTab = 0

    // Article link colour follows topic type; quiz is always amber
    private var articleTint: Color { topic.isMath ? Theme.mathTint : Theme.generalTint }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .clipped()
                .animation(.easeInOut(duration: 0.25), value: selectedTab)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .lightInterfaceStyle()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: ChatDestination.self) { dest in
            ChatView(sessionId: dest.sessionId, questionPrompt: dest.prompt, questionType: dest.typeLabel)
        }
        .zoomNavigationTransition(sourceID: topic.id, namespace: namespace)
    }

    private var header: some View {
        ZStack {
            Picker("", selection: $selectedTab) {
                Text("Read").tag(0)
                Text("Quiz").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.deepSpaceBlue)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                }
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if selectedTab == 1 {
            QuizView(topic: topic, questions: questions, viewModel: quizVM, tint: Theme.mathTint)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
        } else {
            ArticleView(topicId: topic.id, viewModel: articleVM, tint: articleTint)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .trailing)
                ))
        }
    }
}

/// Routing payload for opening the chat from a graded question card.
struct ChatDestination: Hashable {
    let sessionId: UUID
    let prompt: String
    let typeLabel: String
}
