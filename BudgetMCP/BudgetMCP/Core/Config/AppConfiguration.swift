import Foundation

/// Build-environment-aware configuration. Never hardcode secrets here —
/// use environment variables injected at build time or at runtime from Keychain.
struct AppConfiguration: Sendable {
    static let shared = AppConfiguration()

    let apiBaseURL: URL
    let appAPIToken: String

    /// Reads a config value. In DEBUG, prefers Xcode scheme environment variables
    /// (for local/simulator runs); in Release it reads from the app's Info.plist,
    /// because scheme env vars do NOT ship in Archive/TestFlight/App Store builds.
    private static func value(env: String, plist: String) -> String? {
        #if DEBUG
        if let v = ProcessInfo.processInfo.environment[env], !v.isEmpty { return v }
        #endif
        if let v = Bundle.main.object(forInfoDictionaryKey: plist) as? String, !v.isEmpty {
            return v
        }
        return nil
    }

    private init() {
        let urlString = Self.value(env: "BUDGET_API_URL", plist: "BudgetAPIURL") ?? "https://budget-mcp.vercel.app"
        guard let url = URL(string: urlString) else {
            fatalError("Invalid BUDGET_API_URL / BudgetAPIURL: \(urlString)")
        }
        apiBaseURL = url
        appAPIToken = Self.value(env: "BUDGET_APP_API_TOKEN", plist: "BudgetAppAPIToken") ?? ""
    }
}
