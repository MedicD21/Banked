import SwiftUI

@Observable
@MainActor
final class MoveFundsViewModel {

    let categories: [BudgetCategory]
    var fromCategoryId: String?
    var toCategoryId: String?
    var amountText: String = ""
    private(set) var isMoving = false
    var error: AppError?

    private let onMove: (String, String, Double) async -> MoveFundsResponse?

    init(categories: [BudgetCategory], onMove: @escaping (String, String, Double) async -> MoveFundsResponse?) {
        self.categories = categories
        self.onMove = onMove
        self.fromCategoryId = categories.first?.id
        self.toCategoryId = categories.dropFirst().first?.id
    }

    private var amountDollars: Double? {
        Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var isValid: Bool {
        guard let fromCategoryId, let toCategoryId, let amountDollars else { return false }
        return fromCategoryId != toCategoryId && amountDollars > 0
    }

    var fromCategory: BudgetCategory? {
        categories.first { $0.id == fromCategoryId }
    }

    /// Moving more than what's left in the source category is allowed (it can go
    /// negative there), but it's worth warning about before submitting.
    var wouldOverdraftSource: Bool {
        guard let fromCategory, let amountDollars else { return false }
        return amountDollars > fromCategory.remainingDollars
    }

    func move() async -> MoveFundsResponse? {
        guard let fromCategoryId, let toCategoryId, let amountDollars, isValid else { return nil }
        isMoving = true
        defer { isMoving = false }
        return await onMove(fromCategoryId, toCategoryId, amountDollars)
    }

    func dismissError() {
        error = nil
    }
}
