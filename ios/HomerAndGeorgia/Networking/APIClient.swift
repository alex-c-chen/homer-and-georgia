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

@Observable
final class APIClient {
    static let shared = APIClient()

    private let session = URLSession.shared

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
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
