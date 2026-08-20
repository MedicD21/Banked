import Foundation

struct BudgetCategory: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let allocatedDollars: Double
    let spentDollars: Double
    let remainingDollars: Double
    let period: String
    /// Plain `yyyy-MM-dd` date, e.g. a bill's due date. Optional — most categories have none.
    var dueDate: String? = nil
    /// Free-text bucket for the Overview list (e.g. "Bills", "Fun"). `nil`/empty means ungrouped.
    var groupName: String? = nil
    /// Whether this category's allocation is expected to auto-refill each period.
    var autoAssign: Bool = true
    /// Whether unspent (or overspent) balance carries into the next period instead of resetting.
    var rollover: Bool = false
}

struct CategoryListResponse: Decodable, Sendable {
    let categories: [BudgetCategory]
}

enum BudgetPeriod: String, CaseIterable, Identifiable, Sendable {
    case weekly
    case biweekly
    case monthly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Biweekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    /// Used in "resets ___" copy, e.g. "resets every two weeks".
    var cadenceDescription: String {
        switch self {
        case .weekly: return "every week"
        case .biweekly: return "every two weeks"
        case .monthly: return "every month"
        case .yearly: return "every year"
        }
    }
}

extension BudgetCategory {
    enum DueStatus: Equatable {
        case dueToday
        case upcoming(daysLeft: Int)
        case overdue(daysPast: Int)

        var isUrgent: Bool {
            switch self {
            case .dueToday, .overdue: return true
            case .upcoming(let daysLeft): return daysLeft <= 3
            }
        }
    }

    var dueStatus: DueStatus? {
        guard let dueDate, let due = AppDateFormatting.date(fromPlainDate: dueDate) else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: due)
        ).day ?? 0

        if days == 0 { return .dueToday }
        if days > 0 { return .upcoming(daysLeft: days) }
        return .overdue(daysPast: -days)
    }
}

struct BalancesResponse: Decodable, Sendable {
    let totalAvailableDollars: Double
}

struct CategoryDeleteResponse: Decodable, Sendable {
    let success: Bool
}

struct MoveFundsResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    let from: BudgetCategory
    let to: BudgetCategory
}

struct LedgerEntry: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let entryType: String
    let amountDollars: Double
    let memo: String?
    let plaidTransactionId: String?
    let createdAt: String
}

struct LedgerResponse: Decodable, Sendable {
    let entries: [LedgerEntry]
}

struct UncategorizedTransaction: Codable, Identifiable, Sendable, Equatable {
    let transactionId: String
    let date: String
    let merchantName: String?
    let name: String
    let plaidCategory: String?
    let amountDollars: Double

    var id: String { transactionId }
}

struct UncategorizedTransactionsResponse: Decodable, Sendable {
    let transactions: [UncategorizedTransaction]
}

struct ReconcileResult: Codable, Sendable {
    let success: Bool
    let message: String
}

struct PlaidItemStatus: Codable, Identifiable, Sendable, Equatable {
    let institutionName: String?
    let status: String
    let lastSyncedAt: String?

    var id: String { institutionName ?? status }
}

struct SyncStatusResponse: Decodable, Sendable {
    let items: [PlaidItemStatus]
}

struct LinkTokenResponse: Decodable, Sendable {
    let linkToken: String
}

struct ExchangeTokenResponse: Decodable, Sendable {
    let success: Bool
    let itemId: String
}
