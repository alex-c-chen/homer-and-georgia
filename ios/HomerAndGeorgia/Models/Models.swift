import Foundation

// MARK: - Schedule

struct DaySchedule: Codable, Identifiable {
    let id: UUID
    let date: Date
    let status: String
}

struct Topic: Codable, Identifiable {
    let id: UUID
    let name: String
    let topicTypeId: Int
    let description: String?

    /// Emoji prefix derived from the topic type ID convention (see CLAUDE.md).
    var emoji: String {
        switch topicTypeId {
        case 1000...1999: return "👤"
        case 2000...2999: return "📜"
        case 3000...3999: return "🌍"
        case 4100...4199: return "🎨"
        case 4200...4299: return "🎵"
        case 4300...4399: return "🎭"
        case 4400...4499: return "📚"
        case 4500...4599: return "🎬"
        case 5100...5199: return "⚛️"
        case 5200...5299: return "🧪"
        case 5300...5399: return "🧬"
        case 5400...5499: return "🌌"
        case 6100: return "∫"
        case 6200: return "𝐌"
        case 6300: return "📊"
        case 6400: return "🎲"
        default: return "📖"
        }
    }

    var isMath: Bool { topicTypeId >= 6000 }
}

struct QuestionMeta: Codable, Identifiable {
    let id: UUID
    let topicId: UUID
    let questionTypeId: Int
    let s3Key: String
    let difficulty: Int
    let priorQuestionId: UUID?

    var difficultyLabel: String {
        switch difficulty {
        case 1: return "Easy"
        case 2: return "Medium"
        case 3: return "Hard"
        default: return ""
        }
    }

    var typeLabel: String {
        switch questionTypeId {
        case 1: return "Mental"
        case 2: return "Short Answer"
        case 3: return "Intermediate"
        default: return ""
        }
    }
}

struct QuestionDetail: Codable, Identifiable {
    let id: UUID
    let topicId: UUID
    let questionTypeId: Int
    let difficulty: Int
    let priorQuestionId: UUID?
    let prompt: String
    let answerKey: String
    let explanation: String
    let options: [String]?

    var isMultipleChoice: Bool { options != nil }
}

// MARK: - Chat

struct ChatSessionResponse: Codable, Identifiable {
    let id: UUID
    let questionId: UUID
}

struct ChatMessageResponse: Codable, Identifiable {
    let id: UUID
    let role: String
    let content: String
    let createdAt: Date
}

struct SSEDelta: Codable {
    let delta: String
}

// MARK: - Usage

struct LLMBreakdown: Codable {
    let totalCents: Double
    let byOperation: [String: Double]
}

struct AWSBreakdown: Codable {
    let totalCents: Double
    let byService: [String: Double]
}

struct UsageSummary: Codable {
    let llm: LLMBreakdown
    let aws: AWSBreakdown
    let totalCents: Double

    var totalDollars: Double { totalCents / 100 }
}
