import SwiftUI
import OSLog

@Observable
@MainActor
final class ReconcileViewModel {

    private(set) var transactions: [UncategorizedTransaction] = []
    private(set) var categories: [BudgetCategory] = []
    private(set) var isLoading = false
    private(set) var isReconciling = false
    var error: AppError?
    var lastResultMessage: String?

    private let apiClient: any APIRequesting
    private let logger = Logger(subsystem: "com.dustinschaaf.BudgetMCP", category: "ReconcileViewModel")

    init(apiClient: any APIRequesting) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let transactionsResponse: UncategorizedTransactionsResponse = apiClient.request(.uncategorizedTransactions(limit: 25))
            async let categoriesResponse: CategoryListResponse = apiClient.request(.categories)
            let (txns, cats) = try await (transactionsResponse, categoriesResponse)
            transactions = txns.transactions
            categories = cats.categories
        } catch {
            self.error = .network(error as? NetworkError ?? .invalidResponse)
            logger.error("Load failed: \(error.localizedDescription)")
        }
    }

    func reconcile(transactionId: String, categoryId: String) async {
        isReconciling = true
        defer { isReconciling = false }

        do {
            let result: ReconcileResult = try await apiClient.request(.reconcile(ReconcileRequest(transactionId: transactionId, categoryId: categoryId)))
            lastResultMessage = result.message
            if result.success {
                transactions.removeAll { $0.transactionId == transactionId }
            }
        } catch {
            self.error = .network(error as? NetworkError ?? .invalidResponse)
            logger.error("Reconcile failed: \(error.localizedDescription)")
        }
    }

    func dismissError() {
        error = nil
    }

    func dismissResultMessage() {
        lastResultMessage = nil
    }
}
