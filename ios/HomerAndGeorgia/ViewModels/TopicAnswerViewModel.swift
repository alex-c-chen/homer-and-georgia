import Foundation

@Observable
final class TopicAnswerViewModel {
    var questions: [QuestionDetail] = []
    var answers: [UUID: String] = [:]          // questionId → free-text answer
    var selectedOptions: [UUID: String] = [:]  // questionId → MCQ selection
    var results: [UUID: AnswerResult] = [:]     // questionId → result after submit
    var isLoading = false
    var isSubmitting = false
    var error: String?

    struct AnswerResult {
        let sessionId: UUID
        let isCorrect: Bool?
        let answerKey: String
        let explanation: String
    }

    var hasSubmitted: Bool { !results.isEmpty }

    /// A question counts as answered when it has either an MCQ selection or non-empty text.
    func isAnswered(_ question: QuestionDetail) -> Bool {
        if question.isMultipleChoice {
            return selectedOptions[question.id] != nil
        }
        return !(answers[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var answeredCount: Int { questions.filter(isAnswered).count }
    var canSubmit: Bool { answeredCount > 0 && !isSubmitting && !hasSubmitted }

    func answerText(for question: QuestionDetail) -> String {
        question.isMultipleChoice ? (selectedOptions[question.id] ?? "") : (answers[question.id] ?? "")
    }

    func load(questionIds: [UUID]) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            try await withThrowingTaskGroup(of: QuestionDetail.self) { group in
                for id in questionIds {
                    group.addTask { try await APIClient.shared.fetchQuestionDetail(questionId: id) }
                }
                var loaded: [QuestionDetail] = []
                for try await detail in group { loaded.append(detail) }
                // Preserve the schedule's question order.
                let order = Dictionary(uniqueKeysWithValues: questionIds.enumerated().map { ($1, $0) })
                self.questions = loaded.sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func submitAll(timeSpent: Int?) async {
        let answered = questions.filter(isAnswered)
        guard !answered.isEmpty else { return }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }
        do {
            let collected = try await withThrowingTaskGroup(
                of: (UUID, AnswerResult).self
            ) { group -> [(UUID, AnswerResult)] in
                for question in answered {
                    let answer = answerText(for: question)
                    group.addTask {
                        let session = try await APIClient.shared.startSession(
                            questionId: question.id, answer: answer, timeSpent: timeSpent
                        )
                        let reveal = try await APIClient.shared.revealAnswer(questionId: question.id)
                        let correct = Self.grade(answer: answer, answerKey: reveal.answerKey)
                        return (question.id, AnswerResult(
                            sessionId: session.id,
                            isCorrect: correct,
                            answerKey: reveal.answerKey,
                            explanation: reveal.explanation
                        ))
                    }
                }
                var out: [(UUID, AnswerResult)] = []
                for try await pair in group { out.append(pair) }
                return out
            }
            for (id, result) in collected { results[id] = result }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Heuristic grade by string match; backend grading is a future TODO.
    private static func grade(answer: String, answerKey: String) -> Bool? {
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let b = answerKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !a.isEmpty, !b.isEmpty else { return nil }
        return a == b || a.contains(b) || b.contains(a)
    }
}
