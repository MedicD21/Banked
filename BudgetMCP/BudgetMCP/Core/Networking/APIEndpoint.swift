import Foundation

enum APIEndpoint {
    case categories
    case ledger(categoryId: String)
    case uncategorizedTransactions(limit: Int)
    case reconcile(ReconcileRequest)
    case syncStatus
    case linkToken
    case exchangeToken(ExchangeTokenRequest)

    var path: String {
        switch self {
        case .categories:
            return "/api/app/categories"
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
        case .reconcile, .linkToken, .exchangeToken:
            return "POST"
        }
    }

    var body: (any Encodable)? {
        switch self {
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

struct ReconcileRequest: Encodable, Sendable {
    let transactionId: String
    let categoryId: String
}

struct ExchangeTokenRequest: Encodable, Sendable {
    let publicToken: String
}
