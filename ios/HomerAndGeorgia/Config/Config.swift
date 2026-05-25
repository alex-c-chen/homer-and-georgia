import Foundation

enum Config {
    /// Base URL for the Fly.io backend. Set this to your deployed URL.
    /// For local dev, use "http://localhost:8080".
    static let apiBaseURL = URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"]
        ?? "https://homer-and-georgia.fly.dev")!

    /// Bearer token sent on every request. Set via the Debug scheme's API_SECRET env var.
    static let apiSecret = ProcessInfo.processInfo.environment["API_SECRET"] ?? ""
}
