import SwiftUI

struct UsageView: View {
    @State private var viewModel = UsageViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.isLoading && viewModel.summary == nil {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                    } else if let summary = viewModel.summary {
                        totalCard(summary)
                        breakdownSection(
                            title: "LLM APIs",
                            icon: "brain",
                            total: summary.llm.totalCents,
                            rows: summary.llm.byOperation
                        )
                        breakdownSection(
                            title: "AWS",
                            icon: "cloud",
                            total: summary.aws.totalCents,
                            rows: summary.aws.byService
                        )
                    } else if let error = viewModel.error {
                        ContentUnavailableView(
                            "Couldn't load usage",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error)
                        )
                        .frame(minHeight: 300)
                    }
                }
                .padding()
            }
            .background(Theme.burntOrange.ignoresSafeArea())
            .navigationTitle("Usage")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
    }

    private func totalCard(_ summary: UsageSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(monthLabel) · month-to-date")
                .font(Theme.serif(.subheadline, weight: .medium))
                .foregroundStyle(Theme.parchment.opacity(0.8))
            Text(dollars(summary.totalCents))
                .font(Theme.sans(.largeTitle, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Theme.generalTint)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .shadow(color: Theme.generalTint.opacity(0.4), radius: 14, y: 6)
    }

    private func breakdownSection(title: String, icon: String, total: Double, rows: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(Theme.serif(.headline, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(dollars(total))
                    .font(Theme.serif(.headline))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
            }
            ForEach(rows.sorted { $0.key < $1.key }, id: \.key) { key, value in
                HStack {
                    Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(Theme.serif(.subheadline))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text(dollars(value))
                        .font(Theme.serif(.subheadline))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            if rows.isEmpty {
                Text("No spend recorded yet")
                    .font(Theme.serif(.footnote))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }

    private func dollars(_ cents: Double) -> String {
        "$\(String(format: "%.2f", cents / 100))"
    }
}
