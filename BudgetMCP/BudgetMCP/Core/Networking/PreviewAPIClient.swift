import Foundation

/// In-memory stub for SwiftUI previews — returns canned data instead of hitting the network.
struct PreviewAPIClient: APIRequesting {
    func request<T: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> T {
        let json: Data
        switch endpoint {
        case .categories:
            json = Data("""
            { "categories": [
                { "id": "1", "name": "Groceries", "allocatedDollars": 500, "spentDollars": 210.5, "remainingDollars": 289.5, "period": "monthly" },
                { "id": "2", "name": "Dining Out", "allocatedDollars": 150, "spentDollars": 162, "remainingDollars": -12, "period": "monthly" }
            ] }
            """.utf8)
        case .ledger:
            json = Data("""
            { "entries": [
                { "id": "e1", "entryType": "allocation", "amountDollars": 500, "memo": "Initial allocation for Groceries", "plaidTransactionId": null, "createdAt": "2026-08-01T00:00:00Z" },
                { "id": "e2", "entryType": "expense", "amountDollars": -42.10, "memo": "Farmers market cash", "plaidTransactionId": null, "createdAt": "2026-08-05T00:00:00Z" }
            ] }
            """.utf8)
        case .uncategorizedTransactions:
            json = Data("""
            { "transactions": [
                { "transactionId": "t1", "date": "2026-08-10", "merchantName": "Trader Joe's", "name": "TRADER JOE S #123", "plaidCategory": "GROCERIES", "amountDollars": 38.21 }
            ] }
            """.utf8)
        case .syncStatus:
            json = Data("""
            { "items": [
                { "institutionName": "Chase", "status": "active", "lastSyncedAt": "2026-08-17T07:00:00Z" }
            ] }
            """.utf8)
        default:
            json = Data("{}".utf8)
        }
        return try JSONDecoder().decode(T.self, from: json)
    }
}
