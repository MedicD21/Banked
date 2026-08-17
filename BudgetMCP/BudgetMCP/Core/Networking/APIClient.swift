import Foundation
import OSLog

/// Thread-safe HTTP client for the budget-mcp Vercel backend's `api/app/*` routes.
actor APIClient {

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger = Logger(subsystem: "com.dustinschaaf.BudgetMCP", category: "APIClient")
    private let appAPIToken: String

    init(configuration: AppConfiguration = .shared) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.baseURL = configuration.apiBaseURL
        self.appAPIToken = configuration.appAPIToken
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Public

    func request<T: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> T {
        let urlRequest = try buildRequest(for: endpoint)
        logger.debug("→ \(endpoint.method) \(urlRequest.url?.path ?? "")")

        let (data, response) = try await fetch(urlRequest)
        try validate(response: response, data: data)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)!
        components.queryItems = endpoint.queryItems

        guard let url = components.url else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !appAPIToken.isEmpty {
            request.setValue("Bearer \(appAPIToken)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return request
    }

    private func fetch(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw NetworkError.timeout
        } catch {
            throw error
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        default:
            let parsed = try? decoder.decode(APIErrorResponse.self, from: data)
            let message = parsed?.error ?? parsed?.message
            throw NetworkError.httpError(statusCode: http.statusCode, message: message)
        }
    }
}

/// Covers both plain `{ error }` responses and `{ success: false, message }`
/// responses (e.g. reconcile's business-logic failures, sent with a 4xx status).
private struct APIErrorResponse: Decodable {
    let error: String?
    let message: String?
}

// MARK: - AnyEncodable helper

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        _encode = { encoder in try value.encode(to: encoder) }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
