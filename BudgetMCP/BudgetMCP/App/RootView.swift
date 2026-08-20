import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            BudgetOverviewView(viewModel: BudgetOverviewViewModel(apiClient: appState.apiClient))
                .tabItem { Label("Overview", systemImage: "chart.pie.fill") }

            ReconcileView(viewModel: ReconcileViewModel(apiClient: appState.apiClient))
                .tabItem { Label("Reconcile", systemImage: "checkmark.circle.fill") }

            SettingsView(viewModel: SettingsViewModel(apiClient: appState.apiClient))
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .toolbarBackground(Theme.Colors.surfaceElevated, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .themedRoot()
    }
}
