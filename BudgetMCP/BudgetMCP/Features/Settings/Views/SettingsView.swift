import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("Linked Institutions") {
                    if viewModel.items.isEmpty && !viewModel.isLoading {
                        Text("No linked accounts yet.")
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    ForEach(viewModel.items) { item in
                        InstitutionRow(item: item)
                    }
                }
                .listRowBackground(Theme.Colors.surface)

                Section {
                    Button("Link a Bank Account") {
                        viewModel.showingLinkBank = true
                    }
                }
                .listRowBackground(Theme.Colors.surface)

                Section {
                    Text("Balances and transactions sync once a day via a scheduled job. There's no manual sync — this keeps the app well within Plaid's rate limits.")
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .listRowBackground(Color.clear)
            }
            .themedScreenBackground()
            .navigationTitle("Settings")
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .sheet(isPresented: $viewModel.showingLinkBank, onDismiss: {
                Task { await viewModel.load() }
            }) {
                LinkBankView(viewModel: LinkBankViewModel(apiClient: appState.apiClient))
                    .presentationBackground(Theme.Colors.canvas)
                    .presentationCornerRadius(Theme.Radius.lg)
                    .presentationDragIndicator(.visible)
            }
            .alert("Couldn't Load Sync Status", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.dismissError() }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
        }
    }
}

private struct InstitutionRow: View {
    let item: PlaidItemStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.institutionName ?? "Unknown Institution")
                Spacer()
                StatusBadge(status: item.status)
            }
            if let lastSyncedAt = item.lastSyncedAt, let date = AppDateFormatting.date(fromISOTimestamp: lastSyncedAt) {
                Text("Last synced \(date, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                Text("Never synced")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct StatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "active": return Theme.Colors.positive
        case "error": return Theme.Colors.negative
        default: return Theme.Colors.textSecondary
        }
    }

    var body: some View {
        ThemedBadge(text: status.capitalized, color: color)
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(apiClient: PreviewAPIClient()))
        .environment(AppState())
        .themedRoot()
}
