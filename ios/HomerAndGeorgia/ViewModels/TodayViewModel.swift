import Foundation

@Observable
final class TodayViewModel {
    var schedule: DaySchedule?
    var topics: [Topic] = []
    var questionsByTopic: [UUID: [QuestionMeta]] = [:]
    var isLoading = false
    var error: String?
    var notReady = false

    var generalTopics: [Topic] { topics.filter { !$0.isMath } }
    var mathTopics: [Topic] { topics.filter(\.isMath) }

    var totalQuestions: Int { questionsByTopic.values.reduce(0) { $0 + $1.count } }

    func questions(for topic: Topic) -> [QuestionMeta] {
        questionsByTopic[topic.id] ?? []
    }

    func load() async {
        isLoading = true
        error = nil
        notReady = false
        defer { isLoading = false }
        do {
            let schedule = try await APIClient.shared.fetchToday()
            self.schedule = schedule
            async let topicsCall = APIClient.shared.fetchTopics(scheduleId: schedule.id)
            async let questionsCall = APIClient.shared.fetchQuestions(scheduleId: schedule.id)
            let (topics, questions) = try await (topicsCall, questionsCall)
            self.topics = topics
            self.questionsByTopic = Dictionary(grouping: questions, by: \.topicId)
        } catch APIError.notFound {
            notReady = true
            schedule = nil
            topics = []
            questionsByTopic = [:]
        } catch {
            self.error = error.localizedDescription
        }
    }
}
