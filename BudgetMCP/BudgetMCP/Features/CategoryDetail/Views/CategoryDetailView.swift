import SwiftUI

struct CategoryDetailView: View {
    let category: BudgetCategory
    @State var viewModel: CategoryDetailViewModel

    var body: some View {
        List {
            Section {
                LabeledContent("Allocated") { Text(category.allocatedDollars, format: .currency(code: "USD")) }
                LabeledContent("Spent") { Text(category.spentDollars, format: .currency(code: "USD")) }
                LabeledContent("Remaining") {
                    Text(category.remainingDollars, format: .currency(code: "USD"))
                        .foregroundStyle(category.remainingDollars < 0 ? .red : .primary)
                }
                LabeledContent("Period", value: category.period.capitalized)
            }

            Section("Ledger History") {
                if viewModel.entries.isEmpty && !viewModel.isLoading {
                    Text("No activity yet.")
                        .foregroundStyle(.secondary)
                }

                ForEach(viewModel.entries) { entry in
                    LedgerEntryRow(entry: entry)
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .alert("Couldn't Load History", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }
}

private struct LedgerEntryRow: View {
    let entry: LedgerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.memo ?? entry.entryType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.body)
                Spacer()
                Text(entry.amountDollars, format: .currency(code: "USD"))
                    .foregroundStyle(entry.amountDollars < 0 ? .red : .green)
            }
            Text(entry.createdAt, format: .dateTime.month().day().year().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private extension Text {
    init(_ isoString: String, format: Date.FormatStyle) {
        if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: isoString)
            ?? ISO8601DateFormatter.standard.date(from: isoString) {
            self.init(date, format: format)
        } else {
            self.init(isoString)
        }
    }
}

private extension ISO8601DateFormatter {
    // Read-only after creation, so safe to share across isolation domains despite
    // ISO8601DateFormatter not being Sendable.
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
    NavigationStack {
        CategoryDetailView(
            category: BudgetCategory(id: "1", name: "Groceries", allocatedDollars: 500, spentDollars: 210.5, remainingDollars: 289.5, period: "monthly"),
            viewModel: CategoryDetailViewModel(apiClient: PreviewAPIClient(), categoryId: "1")
        )
    }
}
