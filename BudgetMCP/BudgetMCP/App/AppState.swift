import SwiftUI

/// Root application state — owns the dependency graph and exposes it via @Environment.
@Observable
@MainActor
final class AppState {
    let apiClient: APIClient

    init() {
        self.apiClient = APIClient()
    }
}
