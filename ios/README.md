# iOS App

SwiftUI app for Homer & Georgia. Requires iOS 17+.

## Setup

1. Open Xcode → **File → New → Project** → iOS App (SwiftUI, no Core Data)
2. Name it `HomerAndGeorgia`, set Bundle ID to `com.alexchen.homerandgeorgia`
3. Delete the auto-generated `ContentView.swift`
4. Add all files from `ios/HomerAndGeorgia/` to the project target
5. Set the API base URL in `Config/Config.swift` (or set `API_BASE_URL` in the scheme's env vars for local dev)

## Screens

| Screen | Description |
|---|---|
| **Today** | Daily topic list split into General + Math; progress chip shows answered/total |
| **Topic Detail** | 3 questions per topic (mental / short / intermediate); linked prior-topic context |
| **Question** | Prompt + answer input (MCQ for mental, free-text for short/intermediate) |
| **Chat** | SSE streaming thread; initial answer seeds grading; unlimited follow-ups |
| **Usage** | Month-to-date spend: LLM by operation + AWS by service |

## Navigation

```
TabView
├── TodayView
│   └── TopicDetailView
│       └── QuestionView
│           └── ChatView
└── UsageView
```

## Networking

All API calls go through `APIClient` (singleton). SSE streaming uses `URLSession.bytes(for:)` — no third-party dependencies.

```swift
// SSE example
for try await line in bytes.lines {
    if line.hasPrefix("data: ") {
        let json = String(line.dropFirst(6))
        // decode SSEDelta or check for "[DONE]"
    }
}
```

## Configuration

| Setting | Where |
|---|---|
| API base URL | `Config/Config.swift` or `API_BASE_URL` env var in Xcode scheme |
| Model/pricing | Set via backend env vars — not in the app |

## Requirements

- Xcode 16+
- iOS 17+ deployment target
- No third-party Swift packages
