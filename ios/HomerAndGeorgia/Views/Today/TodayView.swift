import SwiftUI

struct TodayView: View {
    @State private var viewModel = TodayViewModel()
    @Namespace private var zoomNamespace

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(greeting)
                        .font(Theme.sans(.largeTitle, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)

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
                            sectionHeader("General", icon: "sparkles", tint: Theme.amberFlame)
                            ForEach(viewModel.generalTopics) { topic in
                                topicLink(topic)
                            }
                        }

                        if !viewModel.mathTopics.isEmpty {
                            sectionHeader("Math", icon: "function", tint: Theme.mathTint)
                            ForEach(viewModel.mathTopics) { topic in
                                topicLink(topic)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Theme.burntOrange.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Topic.self) { topic in
                TopicDetailView(topic: topic, questions: viewModel.questions(for: topic), namespace: zoomNamespace)
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }

    private func topicLink(_ topic: Topic) -> some View {
        NavigationLink(value: topic) {
            if #available(iOS 18.0, *) {
                TopicRowView(topic: topic, questionCount: viewModel.questions(for: topic).count)
                    .matchedTransitionSource(id: topic.id, in: zoomNamespace)
            } else {
                TopicRowView(topic: topic, questionCount: viewModel.questions(for: topic).count)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dateString)
                .font(Theme.serif(.subheadline, weight: .medium))
                .foregroundStyle(Theme.parchment.opacity(0.8))
            Text("\(viewModel.topics.count) topics ready")
                .font(Theme.sans(.title, weight: .bold))
                .foregroundStyle(.white)
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                Text("\(viewModel.totalQuestions) questions to sharpen up")
                    .font(Theme.serif(.subheadline))
            }
            .foregroundStyle(Theme.parchment.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Theme.generalTint)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .shadow(color: Theme.generalTint.opacity(0.4), radius: 14, y: 6)
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
