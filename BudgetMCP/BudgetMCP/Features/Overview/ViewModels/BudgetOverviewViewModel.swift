import SwiftUI
import OSLog

@Observable
@MainActor
final class BudgetOverviewViewModel {

    private(set) var categories: [BudgetCategory] = []
    private(set) var isLoading = false
    var error: AppError?

    private let apiClient: any APIRequesting
    private let logger = Logger(subsystem: "com.dustinschaaf.BudgetMCP", category: "BudgetOverviewViewModel")

    init(apiClient: any APIRequesting) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: CategoryListResponse = try await apiClient.request(.categories)
            categories = response.categories
        } catch {
            self.error = .network(error as? NetworkError ?? .invalidResponse)
            logger.error("Load failed: \(error.localizedDescription)")
        }
    }

    func dismissError() {
        error = nil
    }
}
