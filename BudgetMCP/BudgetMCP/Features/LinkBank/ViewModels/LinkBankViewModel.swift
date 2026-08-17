import SwiftUI
import OSLog

@Observable
@MainActor
final class LinkBankViewModel {

    enum LinkStatus: Equatable {
        case idle
        case fetchingLinkToken
        case readyToPresent(linkToken: String)
        case exchanging
        case success
    }

    private(set) var status: LinkStatus = .idle
    var error: AppError?

    private let apiClient: any APIRequesting
    private let logger = Logger(subsystem: "com.dustinschaaf.BudgetMCP", category: "LinkBankViewModel")

    init(apiClient: any APIRequesting) {
        self.apiClient = apiClient
    }

    /// Calls the backend for a Plaid Link token, then hands it to the caller to
    /// present Plaid's LinkKit UI (kept out of the view model — LinkKit's
    /// presentation APIs are UIKit-based and belong in the view layer).
    func startLink() async {
        status = .fetchingLinkToken
        do {
            let response: LinkTokenResponse = try await apiClient.request(.linkToken)
            status = .readyToPresent(linkToken: response.linkToken)
        } catch {
            self.error = .network(error as? NetworkError ?? .invalidResponse)
            status = .idle
            logger.error("Link token fetch failed: \(error.localizedDescription)")
        }
    }

    /// Called once Plaid Link finishes successfully with a `publicToken`.
    func completeLink(publicToken: String) async {
        status = .exchanging
        do {
            let _: ExchangeTokenResponse = try await apiClient.request(.exchangeToken(ExchangeTokenRequest(publicToken: publicToken)))
            status = .success
        } catch {
            self.error = .network(error as? NetworkError ?? .invalidResponse)
            status = .idle
            logger.error("Token exchange failed: \(error.localizedDescription)")
        }
    }

    func cancelLink() {
        status = .idle
    }

    func dismissError() {
        error = nil
    }
}
