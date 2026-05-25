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
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
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
                    color: currentStreak > 0 ? .orange : .secondary
                )
                StatChip(
                    value: "\(viewModel.days.count)",
                    label: "Days logged",
                    icon: "calendar",
                    color: .blue
                )
                StatChip(
                    value: overallAccuracy,
                    label: "Accuracy",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
            .padding(.vertical, 4)
        }
    }

    private var daysSection: some View {
        Section("Past sessions") {
            ForEach(viewModel.days) { day in
                HistoryDayRow(day: day)
            }
        }
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
            // Score ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: day.answered > 0 ? day.scorePercent : 0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(scoreLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(Self.dateFormatter.string(from: day.date))
                    .font(.body)
                    .fontWeight(.semibold)
                Text(progressLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if day.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
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
        case 0.8...: return .green
        case 0.5...: return .orange
        default:     return .red
        }
    }

    private var progressLabel: String {
        if day.totalQuestions == 0 { return "No questions" }
        if day.answered == 0      { return "Not started · \(day.totalQuestions) questions" }
        return "\(day.correct)/\(day.answered) correct · \(day.totalQuestions - day.answered) remaining"
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
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
