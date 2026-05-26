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
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.deepSpaceBlue.opacity(0.3))
                        Text("No reading available")
                            .font(Theme.serif(.title3, weight: .semibold))
                            .foregroundStyle(Theme.deepSpaceBlue)
                        Text("This topic doesn't have an article yet.")
                            .font(Theme.serif(.subheadline))
                            .foregroundStyle(Theme.deepSpaceBlue.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else if let error = viewModel.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.failure.opacity(0.6))
                        Text("Couldn't load article")
                            .font(Theme.serif(.title3, weight: .semibold))
                            .foregroundStyle(Theme.deepSpaceBlue)
                        Text(error)
                            .font(Theme.serif(.subheadline))
                            .foregroundStyle(Theme.deepSpaceBlue.opacity(0.5))
                        Button("Retry") {
                            viewModel.unavailable = false
                            Task { await viewModel.load(topicId: topicId) }
                        }
                        .font(Theme.serif(.body, weight: .semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.generalTint)
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
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
            .clipShape(RoundedRectangle(cornerRadius: Theme.iconCorner, style: .continuous))
            .padding(.horizontal)
        }

        Text(article.title)
            .font(Theme.serif(.title2, weight: .bold))
            .padding(.horizontal)

        Text(rendered(article.body))
            .font(Theme.serif(.body))
            .padding(.horizontal)

        if let url = URL(string: article.sourceUrl) {
            Link(destination: url) {
                Text("Source: Wikipedia →")
                    .font(Theme.serif(.caption))
                    .foregroundStyle(tint.opacity(0.8))
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
