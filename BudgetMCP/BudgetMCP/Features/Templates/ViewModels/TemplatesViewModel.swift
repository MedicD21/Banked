import SwiftUI
import OSLog

@Observable
@MainActor
final class TemplatesViewModel {

    private(set) var isApplying = false
    var error: AppError?

    private let apiClient: any APIRequesting
    private let logger = Logger(subsystem: "com.dustinschaaf.BudgetMCP", category: "TemplatesViewModel")

    init(apiClient: any APIRequesting) {
        self.apiClient = apiClient
    }

    /// Creates every category in the template, one request at a time so a
    /// mid-way failure still leaves the categories created so far. Returns
    /// the categories that were successfully created.
    func apply(_ template: BudgetTemplate) async -> [BudgetCategory] {
        isApplying = true
        defer { isApplying = false }

        var created: [BudgetCategory] = []
        for seed in template.categories {
            let request = CategoryRequest(
                name: seed.name,
                allocatedDollars: seed.allocatedDollars,
                period: seed.period.rawValue,
                dueDate: nil,
                groupName: seed.groupName,
                autoAssign: true,
                rollover: seed.rollover
            )
            do {
                let category: BudgetCategory = try await apiClient.request(.createCategory(request))
                created.append(category)
            } catch {
                self.error = .network(error as? NetworkError ?? .invalidResponse)
                logger.error("Template apply failed on \(seed.name): \(error.localizedDescription)")
                break
            }
        }
        return created
    }

    func dismissError() {
        error = nil
    }
}
