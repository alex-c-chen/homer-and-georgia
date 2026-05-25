import SwiftUI

struct TodayView: View {
    @State private var viewModel = TodayViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.notReady {
                        emptyState
                    } else if let error = viewModel.error, viewModel.topics.isEmpty {
                        errorState(error)
                    } else if viewModel.isLoading && viewModel.topics.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        heroCard
                        if !viewModel.generalTopics.isEmpty {
                            sectionHeader("General", icon: "sparkles", tint: Theme.generalTint)
                            ForEach(viewModel.generalTopics) { topic in
                                topicLink(topic)
                            }
                        }
                        if !viewModel.mathTopics.isEmpty {
                            sectionHeader("Math", icon: "function", tint: Theme.mathTint)
                            ForEach(viewModel.mathTopics) { topic in
                                topicLink(topic, tint: Theme.mathTint)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(backgroundGradient)
            .navigationTitle(greeting)
            .navigationDestination(for: Topic.self) { topic in
                TopicDetailView(topic: topic, questions: viewModel.questions(for: topic))
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }

    private func topicLink(_ topic: Topic, tint: Color = Theme.generalTint) -> some View {
        NavigationLink(value: topic) {
            TopicRowView(topic: topic, questionCount: viewModel.questions(for: topic).count, tint: tint)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dateString)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            Text("\(viewModel.topics.count) topics ready")
                .font(.title.bold())
                .foregroundStyle(.white)
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .symbolEffect(.pulse)
                Text("\(viewModel.totalQuestions) questions to sharpen up")
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            MeshHero(colors: [.indigo, .purple, .blue, .cyan, .indigo, .purple])
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .shadow(color: .indigo.opacity(0.25), radius: 14, y: 6)
    }

    private func sectionHeader(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(title).font(.title3.bold())
        }
        .padding(.top, 8)
    }

    // MARK: - States

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No questions yet", systemImage: "moon.stars")
        } description: {
            Text("Check back after 2 AM — tonight's set is still generating.")
        }
        .frame(minHeight: 320)
    }

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load today", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") { Task { await viewModel.load() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(minHeight: 320)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Formatting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}
