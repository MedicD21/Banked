import SwiftUI
import OSLog

@Observable
@MainActor
final class CategoryDetailViewModel {

    private(set) var entries: [LedgerEntry] = []
    private(set) var isLoading = false
    var error: AppError?

    private let apiClient: any APIRequesting
    private let categoryId: String
    private let logger = Logger(subsystem: "com.dustinschaaf.BudgetMCP", category: "CategoryDetailViewModel")

    init(apiClient: any APIRequesting, categoryId: String) {
        self.apiClient = apiClient
        self.categoryId = categoryId
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: LedgerResponse = try await apiClient.request(.ledger(categoryId: categoryId))
            entries = response.entries
        } catch {
            self.error = .network(error as? NetworkError ?? .invalidResponse)
            logger.error("Load failed: \(error.localizedDescription)")
        }
    }

    func dismissError() {
        error = nil
    }
}
