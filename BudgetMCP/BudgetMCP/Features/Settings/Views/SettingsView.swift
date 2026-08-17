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
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.items) { item in
                        InstitutionRow(item: item)
                    }
                }

                Section {
                    Button("Link a Bank Account") {
                        viewModel.showingLinkBank = true
                    }
                }

                Section {
                    Text("Balances and transactions sync once a day via a scheduled job. There's no manual sync — this keeps the app well within Plaid's rate limits.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .sheet(isPresented: $viewModel.showingLinkBank) {
                LinkBankView(viewModel: LinkBankViewModel(apiClient: appState.apiClient))
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
            if let lastSyncedAt = item.lastSyncedAt, let date = ISO8601DateFormatter.withFractionalSeconds.date(from: lastSyncedAt)
                ?? ISO8601DateFormatter.standard.date(from: lastSyncedAt) {
                Text("Last synced \(date, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Never synced")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct StatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "active": return .green
        case "error": return .red
        default: return .secondary
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

private extension ISO8601DateFormatter {
    nonisolated(unsafe) static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(apiClient: PreviewAPIClient()))
        .environment(AppState())
}
