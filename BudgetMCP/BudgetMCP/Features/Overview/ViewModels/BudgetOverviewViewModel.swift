import SwiftUI
import OSLog
import WidgetKit

@Observable
@MainActor
final class BudgetOverviewViewModel {

    struct CategoryGroup: Identifiable {
        let name: String
        let categories: [BudgetCategory]
        var id: String { name }
    }

    private(set) var categories: [BudgetCategory] = []
    private(set) var availableDollars: Double?
    private(set) var isLoading = false
    private(set) var deletingCategoryIds: Set<String> = []
    var error: AppError?
    var showingAddCategory = false
    var showingTemplates = false
    var showingMoveFunds = false

    let apiClient: any APIRequesting
    private let logger = Logger(subsystem: "com.dustinschaaf.BudgetMCP", category: "BudgetOverviewViewModel")

    private static let ungroupedName = "Other"

    /// Total dollars currently allocated across all categories.
    var assignedDollars: Double {
        categories.reduce(0) { $0 + $1.allocatedDollars }
    }

    /// Bank balance minus the unspent portion of every category's allocation —
    /// i.e. money that isn't earmarked for anything and is free to spend.
    var safeToSpendDollars: Double? {
        guard let availableDollars else { return nil }
        let stillAssigned = categories.reduce(0) { $0 + max(0, $1.remainingDollars) }
        return availableDollars - stillAssigned
    }

    /// Categories bucketed by `groupName`, alphabetical, with ungrouped ones in a trailing "Other" bucket.
    var groupedCategories: [CategoryGroup] {
        let buckets = Dictionary(grouping: categories) { $0.groupName?.isEmpty == false ? $0.groupName! : Self.ungroupedName }
        return buckets.keys.sorted { lhs, rhs in
            if lhs == Self.ungroupedName { return false }
            if rhs == Self.ungroupedName { return true }
            return lhs < rhs
        }.map { CategoryGroup(name: $0, categories: buckets[$0] ?? []) }
    }

    /// Distinct group names in use, for the editor's quick-pick chips.
    var existingGroupNames: [String] {
        Array(Set(categories.compactMap { $0.groupName?.isEmpty == false ? $0.groupName : nil })).sorted()
    }

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

        // Best-effort: the balance strip degrades gracefully (shows placeholders)
        // if this fails, rather than blocking the whole screen on it.
        do {
            let response: BalancesResponse = try await apiClient.request(.balances)
            availableDollars = response.totalAvailableDollars
        } catch {
            logger.error("Balance load failed: \(error.localizedDescription)")
        }

        BudgetSnapshotStore.save(
            BudgetSnapshot(availableDollars: availableDollars, assignedDollars: assignedDollars, safeToSpendDollars: safeToSpendDollars)
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    func moveFunds(fromCategoryId: String, toCategoryId: String, amountDollars: Double) async -> MoveFundsResponse? {
        do {
            let response: MoveFundsResponse = try await apiClient.request(
                .moveFunds(MoveFundsRequest(fromCategoryId: fromCategoryId, toCategoryId: toCategoryId, amountDollars: amountDollars))
            )
            if response.success {
                upsert(response.from)
                upsert(response.to)
            }
            return response
        } catch {
            self.error = .network(error as? NetworkError ?? .invalidResponse)
            logger.error("Move funds failed: \(error.localizedDescription)")
            return nil
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
