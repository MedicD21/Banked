import Foundation

struct BudgetCategory: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let allocatedDollars: Double
    let spentDollars: Double
    let remainingDollars: Double
    let period: String
}

struct CategoryListResponse: Decodable, Sendable {
    let categories: [BudgetCategory]
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
