import Foundation

@MainActor
@Observable
final class ArticleViewModel {
    var article: Article?
    var isLoading = false
    var unavailable = false  // true if 404 (math topic or not yet generated)
    var error: String?

    func load(topicId: UUID) async {
        guard article == nil, !unavailable, !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            if let article = try await APIClient.shared.fetchArticle(topicId: topicId) {
                self.article = article
            } else {
                unavailable = true
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
