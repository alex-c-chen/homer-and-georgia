import SwiftUI

struct ChatView: View {
    let sessionId: UUID
    let questionPrompt: String
    let questionType: String

    @State private var viewModel = ChatViewModel()
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            promptBanner

            if let correct = viewModel.isCorrect {
                gradeBanner(correct)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                        if viewModel.isStreaming {
                            streamingBubble
                                .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { scrollToBottom(proxy) }
                .onChange(of: viewModel.streamingText) { scrollToBottom(proxy) }
            }

            inputBar
        }
        .background(
            LinearGradient(
                colors: [Theme.mathTint.opacity(0.05), Color(.systemBackground)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
        .navigationTitle(questionType)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadExistingSession(sessionId: sessionId) }
    }

    // MARK: - Banners

    private var promptBanner: some View {
        Text(questionPrompt)
            .font(.subheadline)
            .italic()
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
            .padding(.vertical, 10)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Theme.mathTint)
                    .frame(width: 3)
            }
            .glassBackground()
    }

    private func gradeBanner(_ correct: Bool) -> some View {
        HStack {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(correct ? "Correct" : "Let's review")
                .fontWeight(.semibold)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(12)
        .background((correct ? Theme.success : Theme.failure).gradient)
    }

    private var streamingBubble: some View {
        HStack {
            Group {
                if viewModel.streamingText.isEmpty {
                    TypingIndicator()
                } else {
                    Text(viewModel.streamingText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.bubbleCorner, style: .continuous))
                }
            }
            Spacer(minLength: 40)
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask a follow-up…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .symbolEffect(.bounce, value: viewModel.messages.count)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
            .foregroundStyle(Theme.mathTint)
        }
        .padding(12)
        .background(.bar)
    }

    private func send() {
        let text = draft
        draft = ""
        Task { await viewModel.sendMessage(text) }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if viewModel.isStreaming {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
