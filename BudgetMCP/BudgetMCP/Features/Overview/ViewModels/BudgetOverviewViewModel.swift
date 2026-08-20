import SwiftUI
import OSLog

@Observable
@MainActor
final class BudgetOverviewViewModel {

    private(set) var categories: [BudgetCategory] = []
    private(set) var isLoading = false
    private(set) var deletingCategoryIds: Set<String> = []
    var error: AppError?
    var showingAddCategory = false

    let apiClient: any APIRequesting
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

    func remove(_ category: BudgetCategory) {
        categories.removeAll { $0.id == category.id }
    }

    /// Inserts a newly created category, or replaces an existing one after an edit.
    func upsert(_ category: BudgetCategory) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
        } else {
            categories.append(category)
        }
    }

    func deleteCategory(_ category: BudgetCategory) async {
        deletingCategoryIds.insert(category.id)
        defer { deletingCategoryIds.remove(category.id) }

        do {
            let response: CategoryDeleteResponse = try await apiClient.request(.deleteCategory(categoryId: category.id))
            if response.success {
                categories.removeAll { $0.id == category.id }
            }
        } catch {
            self.error = .network(error as? NetworkError ?? .invalidResponse)
            logger.error("Delete failed: \(error.localizedDescription)")
        }
    }

    func dismissError() {
        error = nil
    }
}
