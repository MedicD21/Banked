import Foundation

enum APIEndpoint {
    case categories
    case createCategory(CategoryRequest)
    case updateCategory(categoryId: String, CategoryRequest)
    case deleteCategory(categoryId: String)
    case ledger(categoryId: String)
    case uncategorizedTransactions(limit: Int)
    case reconcile(ReconcileRequest)
    case syncStatus
    case linkToken
    case exchangeToken(ExchangeTokenRequest)

    var path: String {
        switch self {
        case .categories, .createCategory:
            return "/api/app/categories"
        case .updateCategory(let categoryId, _), .deleteCategory(let categoryId):
            return "/api/app/categories/\(categoryId)"
        case .ledger(let categoryId):
            return "/api/app/categories/\(categoryId)/ledger"
        case .uncategorizedTransactions:
            return "/api/app/uncategorized-transactions"
        case .reconcile:
            return "/api/app/reconcile"
        case .syncStatus:
            return "/api/app/sync-status"
        case .linkToken:
            return "/api/plaid/link-token"
        case .exchangeToken:
            return "/api/plaid/exchange-token"
        }
    }

    var method: String {
        switch self {
        case .categories, .ledger, .uncategorizedTransactions, .syncStatus:
            return "GET"
        case .createCategory, .reconcile, .linkToken, .exchangeToken:
            return "POST"
        case .updateCategory:
            return "PATCH"
        case .deleteCategory:
            return "DELETE"
        }
    }

    var body: (any Encodable)? {
        switch self {
        case .createCategory(let req): return req
        case .updateCategory(_, let req): return req
        case .reconcile(let req): return req
        case .exchangeToken(let req): return req
        default: return nil
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .uncategorizedTransactions(let limit):
            return [URLQueryItem(name: "limit", value: "\(limit)")]
        default:
            return nil
        }
    }
}

/// Shared payload shape for both creating and updating a category.
struct CategoryRequest: Encodable, Sendable {
    let name: String
    let allocatedDollars: Double
    let period: String
}

struct ReconcileRequest: Encodable, Sendable {
    let transactionId: String
    let categoryId: String
}

struct ExchangeTokenRequest: Encodable, Sendable {
    let publicToken: String
}
