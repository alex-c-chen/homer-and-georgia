import Foundation
import Security

enum Config {
    /// Base URL for the Fly.io backend. Set this to your deployed URL.
    /// For local dev, use "http://localhost:8080".
    static let apiBaseURL = URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"]
        ?? "https://homer-and-georgia.fly.dev")!

    /// Bearer token. Resolution order:
    ///   1. Keychain (persisted from a previous Xcode launch)
    ///   2. Scheme env var API_SECRET (Xcode launch only) → saved to Keychain for future use
    ///   3. Empty string (auth will fail until a keyed launch occurs)
    static let apiSecret: String = {
        if let stored = Keychain.load("APISecret") { return stored }
        if let env = ProcessInfo.processInfo.environment["API_SECRET"], !env.isEmpty {
            Keychain.save("APISecret", value: env)
            return env
        }
        return ""
    }()
}

private enum Keychain {
    private static let service = "com.alexchen.homerandgeorgia"

    static func load(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var ref: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &ref) == errSecSuccess,
              let data = ref as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
