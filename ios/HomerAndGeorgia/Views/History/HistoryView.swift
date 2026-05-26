import SwiftUI

struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.days.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.days.isEmpty {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "clock",
                        description: Text("Past sessions will appear here after your first completed day.")
                    )
                } else {
                    List {
                        streakSection
                        daysSection
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading { ProgressView() }
                }
            }
            .background(Theme.burntOrange.ignoresSafeArea())
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .navigationDestination(for: HistoryDay.self) { day in
                HistoryDayDetailView(day: day)
            }
        }
    }

    // MARK: - Sections

    private var streakSection: some View {
        Section {
            HStack(spacing: 20) {
                StatChip(
                    value: "\(currentStreak)",
                    label: "Day streak",
                    icon: "flame.fill",
                    color: currentStreak > 0 ? Theme.generalTint : .secondary
                )
                StatChip(
                    value: "\(viewModel.days.count)",
                    label: "Days logged",
                    icon: "calendar",
                    color: Theme.steelBlue
                )
                StatChip(
                    value: overallAccuracy,
                    label: "Accuracy",
                    icon: "checkmark.circle.fill",
                    color: Theme.success
                )
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.white.opacity(0.06))
    }

    private var daysSection: some View {
        Section("Past sessions") {
            ForEach(viewModel.days) { day in
                NavigationLink(value: day) {
                    HistoryDayRow(day: day)
                }
                .buttonStyle(.plain)
            }
        }
        .listRowBackground(Color.white.opacity(0.06))
    }

    // MARK: - Computed

    private var currentStreak: Int {
        var streak = 0
        let calendar = Calendar.current
        var expected = calendar.startOfDay(for: Date()).addingTimeInterval(-86400)
        for day in viewModel.days {
            let dayStart = calendar.startOfDay(for: day.date)
            if dayStart == expected && day.isComplete {
                streak += 1
                expected = expected.addingTimeInterval(-86400)
            } else {
                break
            }
        }
        return streak
    }

    private var overallAccuracy: String {
        let totalAnswered = viewModel.days.reduce(0) { $0 + $1.answered }
        let totalCorrect  = viewModel.days.reduce(0) { $0 + $1.correct }
        guard totalAnswered > 0 else { return "—" }
        return "\(Int(Double(totalCorrect) / Double(totalAnswered) * 100))%"
    }
}

// MARK: - HistoryDayRow

struct HistoryDayRow: View {
    let day: HistoryDay

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: day.answered > 0 ? day.scorePercent : 0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(scoreLabel)
                    .font(Theme.serif(.caption2, weight: .bold))
                    .foregroundStyle(scoreColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(Self.dateFormatter.string(from: day.date))
                    .font(Theme.serif(.body, weight: .semibold))
                    .foregroundStyle(.white)
                Text(progressLabel)
                    .font(Theme.serif(.caption))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            if day.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.success)
            }
        }
        .padding(.vertical, 4)
    }

    private var scoreLabel: String {
        guard day.answered > 0 else { return "—" }
        return "\(Int(day.scorePercent * 100))%"
    }

    private var scoreColor: Color {
        guard day.answered > 0 else { return .secondary }
        switch day.scorePercent {
        case 0.8...: return Theme.success
        case 0.5...: return Theme.mathTint
        default:     return Theme.failure
        }
    }

    private var progressLabel: String {
        if day.totalQuestions == 0 { return "No questions" }
        if day.answered == 0      { return "Not started · \(day.totalQuestions) questions" }
        return "\(day.correct)/\(day.answered) correct · \(day.totalQuestions - day.answered) remaining"
    }
}

// MARK: - HistoryDayDetailView

struct HistoryDayDetailView: View {
    let day: HistoryDay
    @Namespace private var zoomNamespace
    @State private var topics: [Topic] = []
    @State private var questionsByTopic: [UUID: [QuestionMeta]] = [:]
    @State private var isLoading = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading && topics.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .tint(.white)
                } else {
                    let generalTopics = topics.filter { !$0.isMath }
                    let mathTopics = topics.filter(\.isMath)

                    if !generalTopics.isEmpty {
                        sectionHeader("General", icon: "sparkles", tint: Theme.amberFlame)
                        ForEach(generalTopics) { topic in
                            topicLink(topic)
                        }
                    }
                    if !mathTopics.isEmpty {
                        sectionHeader("Math", icon: "function", tint: Theme.mathTint)
                        ForEach(mathTopics) { topic in
                            topicLink(topic)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(Self.dateFormatter.string(from: day.date))
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.burntOrange.ignoresSafeArea())
        .navigationDestination(for: Topic.self) { topic in
            TopicDetailView(topic: topic, questions: questionsByTopic[topic.id] ?? [], namespace: zoomNamespace)
        }
        .task { await load() }
    }

    private func topicLink(_ topic: Topic) -> some View {
        NavigationLink(value: topic) {
            TopicRowView(topic: topic, questionCount: (questionsByTopic[topic.id] ?? []).count)
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(title)
                .font(Theme.sans(.title3, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        async let topicsCall = APIClient.shared.fetchTopics(scheduleId: day.id)
        async let questionsCall = APIClient.shared.fetchQuestions(scheduleId: day.id)
        guard let t = try? await topicsCall, let q = try? await questionsCall else { return }
        topics = t
        questionsByTopic = Dictionary(grouping: q, by: \.topicId)
    }
}

// MARK: - StatChip

struct StatChip: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(Theme.serif(.title3, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(Theme.serif(.caption2))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
