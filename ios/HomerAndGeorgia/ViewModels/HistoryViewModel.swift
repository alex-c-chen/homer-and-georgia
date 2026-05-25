import Foundation

@MainActor
@Observable
final class HistoryViewModel {
    var days: [HistoryDay] = []
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            days = try await APIClient.shared.fetchHistory()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
