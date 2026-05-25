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
            .background(
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()
            )
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
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Text(dollars(summary.totalCents))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            MeshHero(colors: [.indigo, .purple, .blue, .indigo])
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .shadow(color: .indigo.opacity(0.25), radius: 14, y: 6)
    }

    private func breakdownSection(title: String, icon: String, total: Double, rows: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                Spacer()
                Text(dollars(total))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ForEach(rows.sorted { $0.value > $1.value }, id: \.key) { key, value in
                HStack {
                    Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline)
                    Spacer()
                    Text(dollars(value))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if rows.isEmpty {
                Text("No spend recorded yet")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func dollars(_ cents: Double) -> String {
        "$\(String(format: "%.2f", cents / 100))"
    }
}
