import Foundation

@Observable
final class UsageViewModel {
    var summary: UsageSummary?
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            summary = try await APIClient.shared.fetchUsage()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
