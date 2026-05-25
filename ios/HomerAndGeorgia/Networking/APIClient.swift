import Foundation

enum APIError: LocalizedError {
    case notFound
    case server(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .notFound: return "Not found"
        case .server(let code): return "Server error (\(code))"
        case .decoding(let error): return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

/// Stateless after init: `session`, `decoder`, and `encoder` are immutable and only used
/// for thread-safe request/decode operations, so concurrent use across tasks is safe.
final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    private let session = URLSession.shared

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        // The backend emits both date-only strings ("2026-05-24") and datetimes with
        // 6-digit microseconds — neither of which the built-in .iso8601 strategy accepts.
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = BackendDate.parse(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unrecognized date format: \(raw)"
            )
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private init() {}

    // MARK: - Request building

    private func request(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: Config.apiBaseURL.appending(path: path))
        req.httpMethod = method
        if !Config.apiSecret.isEmpty {
            req.setValue("Bearer \(Config.apiSecret)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        return req
    }

    private func fetch<T: Decodable>(_ path: String) async throws -> T {
        let (data, response) = try await session.data(for: request(path: path))
        try validate(response)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let req = request(path: path, method: "POST", body: try encoder.encode(body))
        let (data, response) = try await session.data(for: req)
        try validate(response)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300: return
        case 404: throw APIError.notFound
        default: throw APIError.server(http.statusCode)
        }
    }

    // MARK: - Schedule

    func fetchToday() async throws -> DaySchedule {
        try await fetch("/schedule/today")
    }

    func fetchTopics(scheduleId: UUID) async throws -> [Topic] {
        try await fetch("/schedule/\(scheduleId)/topics")
    }

    func fetchQuestions(scheduleId: UUID) async throws -> [QuestionMeta] {
        try await fetch("/schedule/\(scheduleId)/questions")
    }

    func fetchQuestionDetail(questionId: UUID) async throws -> QuestionDetail {
        try await fetch("/schedule/questions/\(questionId)")
    }

    func revealAnswer(questionId: UUID) async throws -> RevealResponse {
        try await fetch("/schedule/questions/\(questionId)/reveal")
    }

    func fetchHistory(limit: Int = 30) async throws -> [HistoryDay] {
        try await fetch("/schedule/history?limit=\(limit)")
    }

    // MARK: - Article

    /// Returns nil when the topic has no article (math topic or not yet generated, i.e. 404).
    func fetchArticle(topicId: UUID) async throws -> Article? {
        do {
            return try await fetch("/topics/\(topicId)/article")
        } catch APIError.notFound {
            return nil
        }
    }

    // MARK: - Chat

    private struct StartSessionBody: Encodable {
        let questionId: UUID
        let initialAnswer: String
        let timeSpentSeconds: Int?
    }

    func startSession(questionId: UUID, answer: String, timeSpent: Int?) async throws -> ChatSessionResponse {
        try await post(
            "/chat/sessions",
            body: StartSessionBody(questionId: questionId, initialAnswer: answer, timeSpentSeconds: timeSpent)
        )
    }

    func fetchMessages(sessionId: UUID) async throws -> [ChatMessageResponse] {
        try await fetch("/chat/sessions/\(sessionId)/messages")
    }

    /// Streams assistant response deltas for a follow-up message via SSE.
    func sendMessage(sessionId: UUID, content: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let body = try JSONEncoder().encode(["content": content])
                    let req = request(path: "/chat/sessions/\(sessionId)/messages", method: "POST", body: body)
                    let (bytes, response) = try await session.bytes(for: req)
                    try validate(response)
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        if let json = payload.data(using: .utf8),
                           let delta = try? decoder.decode(SSEDelta.self, from: json) {
                            continuation.yield(delta.delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Usage

    func fetchUsage() async throws -> UsageSummary {
        try await fetch("/usage/summary")
    }
}

/// Parses the date string shapes the FastAPI backend emits: date-only values,
/// and datetimes with optional fractional (microsecond) precision and offset.
enum BackendDate {
    private static let formats = [
        "yyyy-MM-dd",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss",            // naive datetime, assumed UTC
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",     // naive datetime with microseconds
    ]

    private static let formatters: [DateFormatter] = formats.map { format in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = format
        return f
    }

    static func parse(_ string: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
