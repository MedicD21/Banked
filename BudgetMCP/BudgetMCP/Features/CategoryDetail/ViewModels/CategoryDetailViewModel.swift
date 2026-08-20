import SwiftUI
import OSLog

@Observable
@MainActor
final class CategoryDetailViewModel {

    private(set) var category: BudgetCategory
    private(set) var entries: [LedgerEntry] = []
    private(set) var isLoading = false
    var error: AppError?
    var showingEditor = false

    let apiClient: any APIRequesting
    private let logger = Logger(subsystem: "com.dustinschaaf.BudgetMCP", category: "CategoryDetailViewModel")

    init(apiClient: any APIRequesting, category: BudgetCategory) {
        self.apiClient = apiClient
        self.category = category
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: LedgerResponse = try await apiClient.request(.ledger(categoryId: category.id))
            entries = response.entries
        } catch {
            self.error = .network(error as? NetworkError ?? .invalidResponse)
            logger.error("Load failed: \(error.localizedDescription)")
        }
    }

    /// Applies a category returned by the editor after a successful create/edit save.
    func apply(_ updated: BudgetCategory) {
        category = updated
    }

    func dismissError() {
        error = nil
    }
}
