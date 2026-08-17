import Foundation

enum AppError: LocalizedError, Equatable {
    case network(NetworkError)
    case generic(String)

    var errorDescription: String? {
        switch self {
        case .network(let e): return e.localizedDescription
        case .generic(let msg): return msg
        }
    }
}

enum NetworkError: LocalizedError, Equatable {
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingFailed(String)
    case unauthorized
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .httpError(let code, let msg):
            return msg ?? "HTTP error \(code)."
        case .decodingFailed(let detail):
            return "Failed to parse response: \(detail)"
        case .unauthorized:
            return "Authentication required. Check the app's API token."
        case .timeout:
            return "The request timed out. Check your connection and try again."
        }
    }
}
