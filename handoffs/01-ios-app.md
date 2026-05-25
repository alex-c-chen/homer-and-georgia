# Handoff 01 — iOS App

## What you're building

A SwiftUI iOS app (iOS 17+) for a daily study tool. The user sees 5–10 topics per day,
answers 3 questions per topic (mental / short answer / intermediate), then chats with
an LLM about each answer via SSE streaming.

**Before starting:** open `mockup.html` in a browser — that is the visual spec.
Open `architecture.html` for the system diagram.

---

## Existing files

The following stubs already exist in `ios/HomerAndGeorgia/` — do not recreate them:

```
Config/Config.swift      — API base URL
Models/Models.swift      — all Codable structs matching the backend API
```

Read both files before writing anything.

---

## File structure to create

```
ios/HomerAndGeorgia/
├── App/
│   ├── HomerAndGeorgiaApp.swift
│   └── ContentView.swift            ← root TabView
├── Networking/
│   └── APIClient.swift              ← all URLSession calls + SSE streaming
├── ViewModels/
│   ├── TodayViewModel.swift
│   ├── ChatViewModel.swift
│   └── UsageViewModel.swift
└── Views/
    ├── Today/
    │   ├── TodayView.swift
    │   └── TopicRowView.swift
    ├── Topic/
    │   └── TopicDetailView.swift
    ├── Question/
    │   └── QuestionView.swift
    ├── Chat/
    │   ├── ChatView.swift
    │   └── MessageBubbleView.swift
    ├── History/
    │   └── HistoryView.swift        ← ALREADY WRITTEN — do not recreate
    └── Usage/
        └── UsageView.swift
```

`Views/History/HistoryView.swift` and `ViewModels/HistoryViewModel.swift` are already
implemented. Do not overwrite them — add `fetchHistory` to `APIClient` to wire it up.

---

## API contract

Base URL is `Config.apiBaseURL`. All responses are JSON with `snake_case` keys —
use a custom `JSONDecoder` with `.convertFromSnakeCase`.

### Endpoints

```
GET  /schedule/today
     → DaySchedule { id, date, status }
     404 if cron hasn't run yet — show "No questions today yet" empty state

GET  /schedule/{scheduleId}/topics
     → [Topic] { id, name, topicTypeId, description? }

GET  /schedule/{scheduleId}/questions
     → [QuestionMeta] { id, topicId, questionTypeId, s3Key, difficulty, priorQuestionId? }

GET  /schedule/questions/{questionId}
     → QuestionDetail { id, topicId, questionTypeId, difficulty, priorQuestionId?,
                        prompt, answerKey, explanation, options? }
     options is nil for free-text; non-nil for MCQ (mental questions)

POST /chat/sessions
     body: { "question_id": UUID, "initial_answer": String, "time_spent_seconds": Int? }
     → ChatSessionResponse { id, questionId }
     201 Created

POST /chat/sessions/{sessionId}/messages
     body: { "content": String }
     → text/event-stream
     events:
       event: delta   data: {"delta":"text chunk"}
       event: done    data: "[DONE]"

GET  /chat/sessions/{sessionId}/messages
     → [ChatMessageResponse] { id, role, content, createdAt }
     roles: system | user_initial_answer | user | assistant
     Note: filter out role=="system" — never show it in the UI

GET  /usage/summary
     → UsageSummary { llm: { totalCents, byOperation }, aws: { totalCents, byService }, totalCents }

GET  /schedule/history?limit=30
     → [HistoryDay] { id, date, status, totalQuestions, answered, correct }
     ordered newest-first; used by the History tab
```

All `Codable` structs matching these shapes are already defined in `Models/Models.swift`.

---

## APIClient implementation

Create `Networking/APIClient.swift` as a singleton `@Observable` class.

```swift
@Observable
final class APIClient {
    static let shared = APIClient()
    private let session = URLSession.shared
    private let decoder: JSONDecoder  // .convertFromSnakeCase + .iso8601

    // Standard fetch helper
    private func fetch<T: Decodable>(_ path: String) async throws -> T

    // All endpoints as async methods matching the contract above
    func fetchToday() async throws -> DaySchedule
    func fetchTopics(scheduleId: UUID) async throws -> [Topic]
    func fetchQuestions(scheduleId: UUID) async throws -> [QuestionMeta]
    func fetchQuestionDetail(questionId: UUID) async throws -> QuestionDetail
    func startSession(questionId: UUID, answer: String, timeSpent: Int?) async throws -> ChatSessionResponse
    func sendMessage(sessionId: UUID, content: String) -> AsyncThrowingStream<String, Error>  // yields text deltas
    func fetchMessages(sessionId: UUID) async throws -> [ChatMessageResponse]
    func fetchHistory(limit: Int) async throws -> [HistoryDay]
    func fetchUsage() async throws -> UsageSummary
}
```

### SSE streaming (critical — read carefully)

`sendMessage` must return an `AsyncThrowingStream<String, Error>` that yields text deltas.
Internally use `URLSession.bytes(for:)`:

```swift
func sendMessage(sessionId: UUID, content: String) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            var request = URLRequest(url: Config.apiBaseURL.appending(path: "/chat/sessions/\(sessionId)/messages"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try! JSONEncoder().encode(["content": content])

            let (bytes, _) = try await URLSession.shared.bytes(for: request)
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let data = String(line.dropFirst(6))
                    if data == "[DONE]" { break }
                    if let json = data.data(using: .utf8),
                       let delta = try? JSONDecoder().decode(SSEDelta.self, from: json) {
                        continuation.yield(delta.delta)
                    }
                }
            }
            continuation.finish()
        }
    }
}
```

---

## ViewModels

### TodayViewModel

```swift
@Observable
final class TodayViewModel {
    var schedule: DaySchedule?
    var topics: [Topic] = []
    var questionsByTopic: [UUID: [QuestionMeta]] = [:]
    var isLoading = false
    var error: String?

    func load() async  // fetches today → topics → questions, groups by topicId
}
```

Topics with `topicTypeId >= 6000` are math — display them in a separate "Math" section.
Topics with `topicTypeId < 6000` go in "General".

### ChatViewModel

```swift
@Observable
final class ChatViewModel {
    var messages: [ChatMessageResponse] = []   // excludes role=="system"
    var streamingText: String = ""             // accumulates during SSE
    var isStreaming = false
    var isCorrect: Bool?                       // set after first assistant message arrives
    var sessionId: UUID?

    // Call this immediately after QuestionView submits
    func startSession(questionId: UUID, answer: String, timeSpent: Int?) async

    // Call for follow-up messages
    func sendMessage(_ text: String) async
}
```

When streaming completes, append the full accumulated text as a new `ChatMessageResponse`
(role = "assistant") and clear `streamingText`.

**Grading note:** the backend sets `is_correct` on the session after the first assistant
message. For now, parse the assistant's first message for "✓" / "✗" as a heuristic to
show the grade banner — the backend grading endpoint is a future TODO.

### UsageViewModel

```swift
@Observable
final class UsageViewModel {
    var summary: UsageSummary?
    var isLoading = false

    func load() async
}
```

---

## View specs (reference mockup.html screens)

### ContentView — root TabView

Three tabs: "Today" (calendar icon), "History" (clock icon), "Usage" (chart icon).

### TodayView (Screen 1)

- `NavigationStack` wrapping the list
- Large title "Good morning" (or time-appropriate greeting)
- Subtitle: today's date + "{n} topics ready"
- Greeting card (dark gradient): progress "X of Y questions", generated time
- `Section("General")` → `ForEach` general topics → `TopicRowView`
- `Section("Math")` → `ForEach` math topics → `TopicRowView` (amber tint)
- `TopicRowView`: emoji (from `Topic.emoji`), name, description, type badges
- Tap → `TopicDetailView`
- On appear: `await viewModel.load()`
- 404 state: "No questions yet — check back after 2 AM" placeholder

### TopicDetailView (Screen 2)

- `NavigationStack` title = topic name
- Subtitle = topic type + description
- List of 3 question rows: type label + difficulty label + ✓ if answered
- Tap → `QuestionView`
- "Prior context" row if any question has `priorQuestionId` (show linked topic name)

### QuestionView (Screen 3 + 5)

- Shows `QuestionDetail.prompt`
- Type + difficulty badges
- If `question.isMultipleChoice` (options != nil): show 4 MCQ option buttons, single-select
- Else: `TextEditor` for free-text answer
- Timer: start on appear, pass `timeSpent` on submit
- "Submit Answer →" button → calls `ChatViewModel.startSession` → navigates to `ChatView`

### ChatView (Screen 4)

- `NavigationStack` title = question type
- Quoted question prompt at top (italic, left-bordered)
- Grade banner: green "✓ Correct" or red "✗ Let's review" (shown after first assistant reply)
- `ScrollView` of `MessageBubbleView` items
  - `user_initial_answer`: right-aligned blue bubble (slightly dimmed)
  - `user`: right-aligned blue bubble
  - `assistant`: left-aligned white bubble with shadow
  - Skip `system` role entirely
- While `isStreaming`: show animated typing dots in a left bubble
- Streaming text: show partial `streamingText` in a live left bubble
- Bottom input bar: `TextField` + send button → `ChatViewModel.sendMessage`
- Auto-scroll to bottom on new message

### MessageBubbleView

```swift
struct MessageBubbleView: View {
    let message: ChatMessageResponse
    // right-align user/user_initial_answer, left-align assistant
    // blue bg for user, white bg for assistant
}
```

### UsageView (Screen 6)

- Large title "Usage"
- Subtitle: current month + "month-to-date"
- Total spend card (dark gradient): "$X.XX" large
- "LLM APIs" section: total + rows for each `byOperation` entry
- Cache hit rate progress bar if available (future — placeholder for now)
- "AWS" section: total + rows for each `byService` entry
- Amounts always displayed as dollars: `totalCents / 100`
- Format: `"$\(String(format: "%.2f", amount))"`
- On appear: `await viewModel.load()`

---

## Xcode project setup instructions

Since this repo only has Swift source files (no `.xcodeproj`), the agent should:

1. Create a new Xcode project: **iOS App**, SwiftUI, no Core Data, Bundle ID `com.alexchen.homerandgeorgia`
2. Delete the auto-generated `ContentView.swift` and `[AppName]App.swift`
3. Drag all files from `ios/HomerAndGeorgia/` into the project navigator, ensuring "Copy items if needed" is **unchecked** (they're already in place)
4. Set deployment target to **iOS 17.0**
5. In the Debug scheme, add environment variable `API_BASE_URL = http://localhost:8080`

---

## Verification

After building:

1. Run on iOS Simulator (iPhone 15 Pro)
2. Start the backend locally (`uv run uvicorn main:app --reload`)
3. Manually insert a `daily_schedule` row for today in Neon (or trigger `cron.py`)
4. Verify:
   - [ ] TodayView loads topics split into General / Math sections
   - [ ] Tapping a topic shows 3 questions
   - [ ] Tapping a question shows the prompt + input
   - [ ] Submitting an answer navigates to ChatView
   - [ ] Assistant response streams in token-by-token
   - [ ] Follow-up messages work
   - [ ] UsageView loads and shows dollar amounts
   - [ ] 404 empty state shows when no schedule exists
