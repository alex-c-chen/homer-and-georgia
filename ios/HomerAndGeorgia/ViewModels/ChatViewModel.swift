import Foundation

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessageResponse] = []   // excludes role == "system"
    var streamingText: String = ""
    var isStreaming = false
    var isCorrect: Bool?
    var sessionId: UUID?
    var error: String?

    /// Create a fresh session, then load its seeded messages.
    func startSession(questionId: UUID, answer: String, timeSpent: Int?) async {
        do {
            let session = try await APIClient.shared.startSession(
                questionId: questionId, answer: answer, timeSpent: timeSpent
            )
            sessionId = session.id
            await fetchMessages()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Attach to an already-created session (the new TopicDetail submit flow).
    func loadExistingSession(sessionId: UUID) async {
        self.sessionId = sessionId
        await fetchMessages()
    }

    func fetchMessages() async {
        guard let sessionId else { return }
        do {
            let all = try await APIClient.shared.fetchMessages(sessionId: sessionId)
            messages = all.filter { $0.role != "system" }
            updateGrade()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendMessage(_ text: String) async {
        guard let sessionId else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessageResponse(
            id: UUID(), role: "user", content: trimmed, createdAt: Date()
        ))

        isStreaming = true
        streamingText = ""
        defer { isStreaming = false }

        do {
            for try await delta in APIClient.shared.sendMessage(sessionId: sessionId, content: trimmed) {
                streamingText += delta
            }
            if !streamingText.isEmpty {
                messages.append(ChatMessageResponse(
                    id: UUID(), role: "assistant", content: streamingText, createdAt: Date()
                ))
            }
            streamingText = ""
            updateGrade()
        } catch {
            self.error = error.localizedDescription
            streamingText = ""
        }
    }

    /// Parse the first assistant message for ✓/✗ as a grade heuristic until backend grading lands.
    private func updateGrade() {
        guard let first = messages.first(where: { $0.role == "assistant" }) else { return }
        if first.content.contains("✓") {
            isCorrect = true
        } else if first.content.contains("✗") {
            isCorrect = false
        }
    }
}
