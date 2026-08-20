import SwiftUI
import OSLog

@Observable
@MainActor
final class CategoryEditorViewModel {

    enum Mode {
        case create
        case edit(BudgetCategory)

        var title: String {
            switch self {
            case .create: return "New Category"
            case .edit: return "Edit Category"
            }
        }
    }

    var name: String
    var allocatedText: String
    var period: BudgetPeriod
    var hasDueDate: Bool
    var dueDate: Date
    var groupName: String
    var autoAssign: Bool
    var rollover: Bool
    private(set) var isSaving = false
    private(set) var isDeleting = false
    var error: AppError?

    let mode: Mode
    /// Distinct group names already in use, offered as quick-pick chips.
    let existingGroups: [String]
    private let apiClient: any APIRequesting
    private let logger = Logger(subsystem: "com.dustinschaaf.BudgetMCP", category: "CategoryEditorViewModel")

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && allocatedDollars != nil
    }

    private var allocatedDollars: Double? {
        Double(allocatedText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    init(apiClient: any APIRequesting, mode: Mode, existingGroups: [String] = []) {
        self.apiClient = apiClient
        self.mode = mode
        self.existingGroups = existingGroups

        switch mode {
        case .create:
            self.name = ""
            self.allocatedText = ""
            self.period = .monthly
            self.hasDueDate = false
            self.dueDate = Date()
            self.groupName = ""
            self.autoAssign = true
            self.rollover = false
        case .edit(let category):
            self.name = category.name
            self.allocatedText = String(format: "%.2f", category.allocatedDollars)
            self.period = BudgetPeriod(rawValue: category.period.lowercased()) ?? .monthly
            if let dueDateString = category.dueDate, let parsed = AppDateFormatting.date(fromPlainDate: dueDateString) {
                self.hasDueDate = true
                self.dueDate = parsed
            } else {
                self.hasDueDate = false
                self.dueDate = Date()
            }
            self.groupName = category.groupName ?? ""
            self.autoAssign = category.autoAssign
            self.rollover = category.rollover
        }
    }

    /// Creates or updates the category. Returns the saved category on success.
    func save() async -> BudgetCategory? {
        guard let allocatedDollars, isValid else { return nil }
        isSaving = true
        defer { isSaving = false }

        let trimmedGroup = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = CategoryRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            allocatedDollars: allocatedDollars,
            period: period.rawValue,
            dueDate: hasDueDate ? AppDateFormatting.plainDateString(from: dueDate) : nil,
            groupName: trimmedGroup.isEmpty ? nil : trimmedGroup,
            autoAssign: autoAssign,
            rollover: rollover
        )

        do {
            switch mode {
            case .create:
                return try await apiClient.request(.createCategory(request))
            case .edit(let category):
                return try await apiClient.request(.updateCategory(categoryId: category.id, request))
            }
        } catch {
            self.error = .network(error as? NetworkError ?? .invalidResponse)
            logger.error("Save failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Deletes the category being edited. No-op (returns `false`) in create mode.
    func delete() async -> Bool {
        guard case .edit(let category) = mode else { return false }
        isDeleting = true
        defer { isDeleting = false }

        do {
            let response: CategoryDeleteResponse = try await apiClient.request(.deleteCategory(categoryId: category.id))
            return response.success
        } catch {
            self.error = .network(error as? NetworkError ?? .invalidResponse)
            logger.error("Delete failed: \(error.localizedDescription)")
            return false
        }
    }

    func dismissError() {
        error = nil
    }
}
