import SwiftUI

@main
struct BudgetMCPApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onOpenURL { url in
                    // Resumes Plaid Link after an institution's OAuth hand-off
                    // redirects back into the app via the "budgetmcp://" scheme.
                    PlaidLinkOAuthCoordinator.activeHandler?.continue(from: url)
                }
        }
    }
}
