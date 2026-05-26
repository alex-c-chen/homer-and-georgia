import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessageResponse

    private var isUser: Bool {
        message.role == "user" || message.role == "user_initial_answer"
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if message.role == "user_initial_answer" {
                    Text("Your answer")
                        .font(Theme.serif(.caption2))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(message.content)
                    .font(Theme.serif(.body))
                    .foregroundStyle(isUser ? .white : .primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleCorner, style: .continuous))
            .shadow(color: isUser ? .clear : .black.opacity(0.06), radius: 4, y: 2)

            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == "user_initial_answer" {
            Color.blue.opacity(0.75)
        } else if isUser {
            Color.blue
        } else {
            AnyView(Rectangle().fill(.regularMaterial))
        }
    }
}

/// Animated three-dot typing indicator shown while the assistant streams.
struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(.secondary)
                    .frame(width: 8, height: 8)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.bubbleCorner, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                phase = 2
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                phase = (phase + 1) % 3
            }
        }
    }
}
