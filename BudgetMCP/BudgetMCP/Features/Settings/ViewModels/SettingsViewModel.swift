import SwiftUI
import OSLog

@Observable
@MainActor
final class SettingsViewModel {

    private(set) var items: [PlaidItemStatus] = []
    private(set) var isLoading = false
    var error: AppError?
    var showingLinkBank = false

    private let apiClient: any APIRequesting
    private let logger = Logger(subsystem: "com.dustinschaaf.BudgetMCP", category: "SettingsViewModel")

    init(apiClient: any APIRequesting) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: SyncStatusResponse = try await apiClient.request(.syncStatus)
            items = response.items
        } catch {
            self.error = .network(error as? NetworkError ?? .invalidResponse)
            logger.error("Load failed: \(error.localizedDescription)")
        }
    }

    func dismissError() {
        error = nil
    }
}
