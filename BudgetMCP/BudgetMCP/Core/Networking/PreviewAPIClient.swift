import Foundation

/// In-memory stub for SwiftUI previews — returns canned data instead of hitting the network.
struct PreviewAPIClient: APIRequesting {
    func request<T: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> T {
        let json: Data
        switch endpoint {
        case .categories:
            json = Data("""
            { "categories": [
                { "id": "1", "name": "Groceries", "allocatedDollars": 500, "spentDollars": 210.5, "remainingDollars": 289.5, "period": "monthly", "dueDate": null, "groupName": "Everyday", "autoAssign": true, "rollover": false },
                { "id": "2", "name": "Dining Out", "allocatedDollars": 150, "spentDollars": 162, "remainingDollars": -12, "period": "biweekly", "dueDate": null, "groupName": "Everyday", "autoAssign": true, "rollover": false },
                { "id": "3", "name": "Rent", "allocatedDollars": 1800, "spentDollars": 1800, "remainingDollars": 0, "period": "monthly", "dueDate": "2026-08-22", "groupName": "Bills", "autoAssign": true, "rollover": false },
                { "id": "4", "name": "Vacation Fund", "allocatedDollars": 200, "spentDollars": 0, "remainingDollars": 500, "period": "monthly", "dueDate": null, "groupName": "Savings", "autoAssign": true, "rollover": true }
            ] }
            """.utf8)
        case .ledger:
            json = Data("""
            { "entries": [
                { "id": "e1", "entryType": "allocation", "amountDollars": 500, "memo": "Initial allocation for Groceries", "plaidTransactionId": null, "createdAt": "2026-08-01T00:00:00Z" },
                { "id": "e2", "entryType": "expense", "amountDollars": -42.10, "memo": "Farmers market cash", "plaidTransactionId": null, "createdAt": "2026-08-05T00:00:00Z" },
                { "id": "e3", "entryType": "expense", "amountDollars": -18.35, "memo": "Corner store", "plaidTransactionId": null, "createdAt": "2026-08-09T00:00:00Z" },
                { "id": "e4", "entryType": "expense", "amountDollars": -64.20, "memo": "Weekly groceries", "plaidTransactionId": null, "createdAt": "2026-08-14T00:00:00Z" }
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
        case .createCategory(let req), .updateCategory(_, let req):
            let dueDateJSON = req.dueDate.map { "\"\($0)\"" } ?? "null"
            let groupJSON = req.groupName.map { "\"\($0)\"" } ?? "null"
            json = Data("""
            { "id": "1", "name": "\(req.name)", "allocatedDollars": \(req.allocatedDollars), "spentDollars": 0, "remainingDollars": \(req.allocatedDollars), "period": "\(req.period)", "dueDate": \(dueDateJSON), "groupName": \(groupJSON), "autoAssign": \(req.autoAssign), "rollover": \(req.rollover) }
            """.utf8)
        case .deleteCategory:
            json = Data("""
            { "success": true }
            """.utf8)
        case .balances:
            json = Data("""
            { "totalAvailableDollars": 2140.37 }
            """.utf8)
        case .moveFunds(let req):
            json = Data("""
            { "success": true, "message": "Moved $\(req.amountDollars) between categories.",
              "from": { "id": "\(req.fromCategoryId)", "name": "From", "allocatedDollars": 100, "spentDollars": 0, "remainingDollars": 100, "period": "monthly", "dueDate": null, "groupName": null, "autoAssign": true, "rollover": false },
              "to": { "id": "\(req.toCategoryId)", "name": "To", "allocatedDollars": 100, "spentDollars": 0, "remainingDollars": 100, "period": "monthly", "dueDate": null, "groupName": null, "autoAssign": true, "rollover": false } }
            """.utf8)
        default:
            json = Data("{}".utf8)
        }
        return try JSONDecoder().decode(T.self, from: json)
    }
}
