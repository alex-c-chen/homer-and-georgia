import SwiftUI

struct ArticleView: View {
    let topicId: UUID
    @Bindable var viewModel: ArticleViewModel
    var tint: Color = Theme.generalTint

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if viewModel.isLoading && viewModel.article == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if let article = viewModel.article {
                    articleBody(article)
                } else if viewModel.unavailable {
                    ContentUnavailableView(
                        "No article available",
                        systemImage: "book.closed",
                        description: Text("This topic doesn't have a reading yet.")
                    )
                    .frame(minHeight: 320)
                } else if let error = viewModel.error {
                    ContentUnavailableView {
                        Label("Couldn't load article", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            viewModel.unavailable = false
                            Task { await viewModel.load(topicId: topicId) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(minHeight: 320)
                }
            }
            .padding(.top, 12)
        }
        .task { await viewModel.load(topicId: topicId) }
    }

    @ViewBuilder
    private func articleBody(_ article: Article) -> some View {
        if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Rectangle().fill(.thinMaterial)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                default:
                    Shimmer()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)
        }

        Text(article.title)
            .font(.title2.bold())
            .padding(.horizontal)

        Text(rendered(article.body))
            .font(.body)
            .padding(.horizontal)

        if let url = URL(string: article.sourceUrl) {
            Link(destination: url) {
                Text("Source: Wikipedia →")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    /// Parse markdown prose, preserving paragraph whitespace. Falls back to plain text
    /// rather than crashing on malformed markdown.
    private func rendered(_ body: String) -> AttributedString {
        (try? AttributedString(
            markdown: body,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(body)
    }
}

/// Animated gradient sweep used as an image-loading placeholder.
private struct Shimmer: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        LinearGradient(
            colors: [Color(.systemGray5), Color(.systemGray6), Color(.systemGray5)],
            startPoint: .leading, endPoint: .trailing
        )
        .overlay {
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, .white.opacity(0.35), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.6)
                .offset(x: phase * geo.size.width)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}
