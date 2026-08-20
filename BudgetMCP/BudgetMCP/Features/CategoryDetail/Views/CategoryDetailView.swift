import SwiftUI

struct CategoryDetailView: View {
    @State var viewModel: CategoryDetailViewModel
    var onCategoryUpdated: (BudgetCategory) -> Void = { _ in }
    var onCategoryDeleted: (BudgetCategory) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                LabeledContent("Allocated") { Text(viewModel.category.allocatedDollars, format: .currency(code: "USD")) }
                LabeledContent("Spent") { Text(viewModel.category.spentDollars, format: .currency(code: "USD")) }
                LabeledContent("Remaining") {
                    Text(viewModel.category.remainingDollars, format: .currency(code: "USD"))
                        .foregroundStyle(viewModel.category.remainingDollars < 0 ? Theme.Colors.negative : Theme.Colors.textPrimary)
                }
                LabeledContent("Period", value: viewModel.category.period.capitalized)
            }
            .listRowBackground(Theme.Colors.surface)

            Section("Ledger History") {
                if viewModel.entries.isEmpty && !viewModel.isLoading {
                    Text("No activity yet.")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                ForEach(viewModel.entries) { entry in
                    LedgerEntryRow(entry: entry)
                }
            }
            .listRowBackground(Theme.Colors.surface)
        }
        .themedScreenBackground()
        .navigationTitle(viewModel.category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showingEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(isPresented: $viewModel.showingEditor) {
            CategoryEditorView(
                viewModel: CategoryEditorViewModel(apiClient: viewModel.apiClient, mode: .edit(viewModel.category)),
                onSave: { updated in
                    viewModel.apply(updated)
                    onCategoryUpdated(updated)
                },
                onDelete: {
                    onCategoryDeleted(viewModel.category)
                    dismiss()
                }
            )
        }
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
                    .foregroundStyle(entry.amountDollars < 0 ? Theme.Colors.negative : Theme.Colors.positive)
            }
            Text(entry.createdAt, format: .dateTime.month().day().year().hour().minute())
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
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
            viewModel: CategoryDetailViewModel(
                apiClient: PreviewAPIClient(),
                category: BudgetCategory(id: "1", name: "Groceries", allocatedDollars: 500, spentDollars: 210.5, remainingDollars: 289.5, period: "monthly")
            )
        )
    }
    .themedRoot()
}
